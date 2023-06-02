import 'dart:async';

import 'package:ds_ads/src/applovin_ads/applovin_ads.dart';
import 'package:ds_ads/src/ds_ads_manager.dart';
import 'package:ds_ads/src/generic_ads/export.dart';
import 'package:ds_ads/src/google_ads/export.dart';
import 'package:fimber/fimber.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'ds_ads_types.dart';

part 'ds_ads_rewarded_types.dart';

class DSAdsRewarded {
  static var _lastShowTime = DateTime(0);
  static const _tag = 'ads_rewarded';

  static var _showNum = 0;

  String _adUnitId(DSAdMediation mediation) {
    switch (mediation) {
      case DSAdMediation.google:
        return DSAdsManager.instance.rewardedGoogleUnitId!;
      case DSAdMediation.appLovin:
        return DSAdsManager.instance.rewardedAppLovinUnitId!;
    }
  }
  final int loadRetryMaxCount;
  final Duration loadRetryDelay;

  var _isDisposed = false;
  DSRewardedAd? _ad;
  DSAdMediation? _mediation;
  var _adState = DSAdState.none;
  var _loadRetryCount = 0;

  DSAdsRewarded({
    this.loadRetryMaxCount = 3,
    this.loadRetryDelay = const Duration(seconds: 1),
  });

  void dispose() {
    _isDisposed = true;
    cancelCurrentAd(location: const DSAdLocation('internal_dispose'));
  }

  void _report(String eventName, {
    required DSAdLocation location,
    required DSAdMediation? mediation,
    String? customAdId,
    Map<String, Object>? attributes,
  }) {
    DSAdsManager.instance.onReportEvent?.call(eventName, {
      if (mediation != null)
        'adUnitId': customAdId ?? _adUnitId(mediation),
      'location': location.val,
      'mediation': '$mediation',
      ...?attributes,
    });
  }

  static final _locationErrReports = <DSAdLocation>{};

  static bool _isDisabled(DSAdLocation location) {
    if (!location.isInternal && DSAdsManager.instance.locations?.contains(location) == false) {
      final msg = '$_tag: location $location not in locations';
      assert(false, msg);
      if (!_locationErrReports.contains(location)) {
        _locationErrReports.add(location);
        Fimber.e(msg, stacktrace: StackTrace.current);
      }
    }
    if (DSAdsManager.instance.isAdAllowedCallback?.call(DSAdSource.rewarded, location) == false) {
      Fimber.i('$_tag: disabled (location: $location)');
      return true;
    }
    if (DSAdsManager.instance.currentMediation(DSMediationType.main) == null) {
      Fimber.i('$_tag: disabled (no mediation)');
      return true;
    }
    return false;
  }

  bool _checkCustomAttributes(Map<String, Object>? attrs) {
    if (attrs == null) return true;
    return attrs.keys.every((e) => e.startsWith('custom_attr_'));
  }

  /// Fetch rewarded ad
  void fetchAd({
    required final DSAdLocation location,
    Map<String, Object>? customAttributes,
    @internal
    final Function()? then,
  }) {
    assert(_checkCustomAttributes(customAttributes), 'custom attributes must have custom_attr_ prefix');

    if (DSAdsManager.instance.appState.isPremium || _isDisposed) {
      then?.call();
      return;
    }

    DSAdsManager.instance.updateMediations(DSMediationType.main);

    if (_isDisabled(location)) {
      then?.call();
      return;
    }

    if ([DSAdState.loading, DSAdState.loaded].contains(_adState)) {
      then?.call();
      return;
    }
    if ([DSAdState.preShowing, DSAdState.showing].contains(_adState)) {
      Fimber.i('$_tag: fetching is prohibited when ad is showing',
        stacktrace: LimitedStackTrace(stackTrace: StackTrace.current),
      );
      then?.call();
      return;
    }

    final rewardedFetchDelay = DSAdsManager.instance.rewardedFetchDelayCallback?.call() ?? const Duration();
    if (DateTime.now().difference(_lastShowTime) < (rewardedFetchDelay)) {
      then?.call();
      unawaited(() async {
        final spent = DateTime.now().difference(_lastShowTime);
        final delay = rewardedFetchDelay - spent;
        await Future.delayed(delay);
        fetchAd(location: const DSAdLocation('internal_fetch_delayed'), customAttributes: customAttributes);
      }());
      return;
    }

    final startTime = DateTime.now();
    final mediation = DSAdsManager.instance.currentMediation(DSMediationType.main);
    _mediation = mediation;
    if (mediation == null) {
      _report('$_tag: no mediation', location: location, mediation: mediation, attributes: customAttributes);
      return;
    }
    _report('$_tag: start loading', location: location, mediation: mediation, attributes: customAttributes);
    switch (mediation) {
      case DSAdMediation.google:
        DSGoogleRewardedAd(adUnitId: _adUnitId(mediation)).load(
          onAdLoaded: (ad) async {
            try {
              final duration = DateTime.now().difference(startTime);
              _report('$_tag: loaded', location: location, mediation: mediation, customAdId: ad.adUnitId, attributes: {
                'mediation': '$mediation', // override
                'google_ads_loaded_seconds': duration.inSeconds,
                'google_ads_loaded_milliseconds': duration.inMilliseconds,
                ...?customAttributes,
              });
              await _ad?.dispose();
              _ad = ad;
              _adState = DSAdState.loaded;
              _loadRetryCount = 0;
              then?.call();
              DSAdsManager.instance.emitEvent(DSAdsRewardedLoadedEvent._(ad: ad));
            } catch (e, stack) {
              Fimber.e('$e', stacktrace: stack);
            }
          },
          onAdFailedToLoad: (DSAd ad, int errCode, String errDescription) async {
            try {
              final duration = DateTime.now().difference(startTime);
              await _ad?.dispose();
              _ad = null;
              _adState = DSAdState.error;
              _loadRetryCount++;
              _report('$_tag: failed to load', location: location, mediation: mediation, attributes: {
                'error_text': errDescription,
                'error_code': '$errCode ($mediation)',
                'mediation': '$mediation', // override
                'google_ads_load_error_seconds': duration.inSeconds,
                'google_ads_load_error_milliseconds': duration.inMilliseconds,
                ...?customAttributes,
              });
              final oldMediation = DSAdsManager.instance.currentMediation(DSMediationType.main);
              await DSAdsManager.instance.onLoadAdError(errCode, errDescription, mediation, DSAdSource.rewarded);
              if (DSAdsManager.instance.currentMediation(DSMediationType.main) != oldMediation) {
                _loadRetryCount = 0;
              }
              if (_loadRetryCount < loadRetryMaxCount) {
                await Future.delayed(loadRetryDelay);
                if ({DSAdState.none, DSAdState.error}.contains(_adState) && !_isDisposed) {
                  _report('$_tag: retry loading', location: location, mediation: mediation, attributes: customAttributes);
                  fetchAd(location: location, then: then, customAttributes: customAttributes);
                }
              } else {
                Fimber.w('$errDescription ($errCode)', stacktrace: StackTrace.current);
                _adState = DSAdState.none;
                then?.call();
                DSAdsManager.instance.emitEvent(DSAdsRewardedLoadFailedEvent._(
                  errCode: errCode,
                  errText: errDescription,
                ));
              }
            } catch (e, stack) {
              Fimber.e('$e', stacktrace: stack);
            }
          },
        );
        break;
      case DSAdMediation.appLovin:
      // ToDo: deduplicate with DSAdMediation.google case
        DSAppLovinRewardedAd(adUnitId: _adUnitId(mediation)).load(
          onAdLoaded: (ad) async {
            try {
              final duration = DateTime.now().difference(startTime);
              _report('$_tag: loaded', location: location, mediation: mediation, customAdId: ad.adUnitId, attributes: {
                'applovin_ads_loaded_seconds': duration.inSeconds,
                'applovin_ads_loaded_milliseconds': duration.inMilliseconds,
                ...?customAttributes,
              });
              await _ad?.dispose();
              _ad = ad;
              _adState = DSAdState.loaded;
              _loadRetryCount = 0;

              then?.call();
              DSAdsManager.instance.emitEvent(DSAdsRewardedLoadedEvent._(ad: ad));
            } catch (e, stack) {
              Fimber.e('$e', stacktrace: stack);
            }
          },
          onAdFailedToLoad: (DSAd ad, int errCode, String errDescription) async {
            try {
              final duration = DateTime.now().difference(startTime);
              await _ad?.dispose();
              _ad = null;
              _mediation = null;
              _adState = DSAdState.error;
              _loadRetryCount++;
              _report('$_tag: failed to load', location: location, mediation: mediation, attributes: {
                'error_text': errDescription,
                'error_code': '$errCode ($mediation)',
                'applovin_ads_load_error_seconds': duration.inSeconds,
                'applovin_ads_load_error_milliseconds': duration.inMilliseconds,
                ...?customAttributes,
              });
              final oldMediation = DSAdsManager.instance.currentMediation(DSMediationType.main);
              await DSAdsManager.instance.onLoadAdError(errCode, errDescription, mediation, DSAdSource.rewarded);
              if (DSAdsManager.instance.currentMediation(DSMediationType.main) != oldMediation) {
                _loadRetryCount = 0;
              }
              if (_loadRetryCount < loadRetryMaxCount) {
                await Future.delayed(loadRetryDelay);
                if ({DSAdState.none, DSAdState.error}.contains(_adState) && !_isDisposed) {
                  _report('$_tag: retry loading', location: location, mediation: mediation, attributes: {
                    ...?customAttributes,
                  });
                  fetchAd(location: location, then: then, customAttributes: customAttributes);
                }
              } else {
                Fimber.w('$errDescription ($errCode)', stacktrace: StackTrace.current);
                _adState = DSAdState.none;
                then?.call();
                DSAdsManager.instance.emitEvent(DSAdsRewardedLoadFailedEvent._(
                  errCode: errCode,
                  errText: errDescription,
                ));
              }
            } catch (e, stack) {
              Fimber.e('$e', stacktrace: stack);
            }
          },
        );
        break;
    }

    _adState = DSAdState.loading;
  }

  void cancelCurrentAd({
    required final DSAdLocation location,
  }) {
    _report('$_tag: cancel current ad (adState: $_adState)', location: location, mediation: _mediation);
    if (_adState == DSAdState.showing) return;
    _ad?.dispose();
    _ad = null;
    _mediation = null;
    _adState = DSAdState.none;
  }

  /// Show rewarded ad. Can wait fetching if [dismissAdAfter] (or [dismissAdAfterCallback]) more than zero.
  /// [allowFetchNext] allows start fetching after show rewarded ad.
  /// [location] sets location attribute to report (any string allowed)
  /// [beforeAdShow] allows to cancel ad by return false
  Future<void> showAd({
    required final DSAdLocation location,
    final Duration dismissAdAfter = const Duration(),
    final Duration Function()? dismissAdAfterCallback,
    final Future<bool> Function()? beforeAdShow,
    final Function()? onAdShow,
    final DSOnRewardEventCallback? onRewarded,
    final Function(int errCode, String errText)? onFailedToShow,
    final Function()? onAdClosed,
    final Function()? then,
    Map<String, Object>? customAttributes,
  }) async {
    assert(!location.isInternal);
    assert(_checkCustomAttributes(customAttributes), 'custom attributes must have custom_attr_ prefix');

    if (DSAdsManager.instance.appState.isPremium || _isDisposed) {
      then?.call();
      return;
    }

    if (_isDisabled(location)) {
      then?.call();
      return;
    }

    if (!DSAdsManager.instance.appState.isInForeground) {
      then?.call();
      fetchAd(location: location, customAttributes: customAttributes);
      // https://support.google.com/admob/answer/6201362#zippy=%2Cdisallowed-example-user-launches-app
      return;
    }

    final mediation = _mediation;

    if ([DSAdState.preShowing, DSAdState.showing].contains(_adState)) {
      Fimber.e('showAd recall (state: $_adState)', stacktrace: StackTrace.current);
      _report('$_tag: showing canceled by error',
        location: location,
        mediation: mediation,
        attributes: customAttributes,
      );
      then?.call();
      return;
    }

    Duration calcDismissAdAfter() {
      if (dismissAdAfterCallback != null) {
        return dismissAdAfterCallback();
      }
      return dismissAdAfter;
    }

    if ([DSAdState.none, DSAdState.loading, DSAdState.error].contains(_adState)) {
      if (calcDismissAdAfter().inSeconds <= 0) {
        _report('$_tag: showing canceled: not ready immediately (dismiss ad after ${calcDismissAdAfter().inSeconds}s)',
          location: location,
          mediation: mediation,
          attributes: customAttributes,
        );
        then?.call();
        DSAdsManager.instance.emitEvent(const DSAdsRewardedShowErrorEvent._());
      } else {
        var processed = false;
        Timer(calcDismissAdAfter(), () {
          if (processed) return;
          processed = true;
          _report('$_tag: showing canceled: not ready after ${calcDismissAdAfter().inSeconds}s',
            location: location,
            mediation: mediation,
            attributes: customAttributes,
          );
          then?.call();
        });
        fetchAd(
          location: location,
          customAttributes: customAttributes,
          then: () async {
            while (_adState == DSAdState.loading || _adState == DSAdState.error) {
              await Future.delayed(const Duration(milliseconds: 100));
            }
            if (processed) return;
            processed = true;
            if (_isDisposed) {
              _report('$_tag: showing canceled: manager disposed',
                location: location,
                mediation: mediation,
                attributes: customAttributes,
              );
              then?.call();
              DSAdsManager.instance.emitEvent(const DSAdsRewardedShowErrorEvent._());
              return;
            }
            if (_adState == DSAdState.none) {
              // Failed to fetch ad
              then?.call();
              DSAdsManager.instance.emitEvent(const DSAdsRewardedShowErrorEvent._());
              return;
            }
            await showAd(
              location: location,
              beforeAdShow: beforeAdShow,
              onAdShow: onAdShow,
              onRewarded: onRewarded,
              onFailedToShow: onFailedToShow,
              onAdClosed: onAdClosed,
              then: then,
              customAttributes: customAttributes,
            );
          },
        );
      }
      return;
    }

    final rewardedShowLock = DSAdsManager.instance.rewardedShowLockCallback?.call() ?? const Duration();
    if (DateTime.now().difference(_lastShowTime) < (rewardedShowLock)) {
      _report('$_tag: showing canceled: locked for ${rewardedShowLock.inSeconds}s',
        location: location,
        mediation: _mediation,
        attributes: customAttributes,
      );
      then?.call();
      return;
    }

    final ad = _ad;
    if (ad == null) {
      Fimber.e('ad is null but state: $_adState', stacktrace: StackTrace.current);
      _report('$_tag: showing canceled by error',
        location: location,
        mediation: _mediation,
        attributes: customAttributes,
      );
      then?.call();
      cancelCurrentAd(location: location);
      DSAdsManager.instance.emitEvent(const DSAdsRewardedShowErrorEvent._());
      return;
    }

    final attrs = customAttributes ?? {};

    ad.onAdImpression = (ad) {
      try {
        _report('$_tag: impression', location: location, mediation: _mediation, attributes: attrs);
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onPaidEvent = (ad, valueMicros, precision, currencyCode, appLovinDspName) {
      try {
        DSAdsManager.instance.onPaidEvent(ad, _mediation!, location, valueMicros, precision, currencyCode,
            DSAdSource.rewarded, appLovinDspName, attrs);
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdShown = (ad) {
      try {
        _report('$_tag: showed full screen content', location: location, mediation: _mediation, attributes: attrs);
        if (_isDisposed) {
          Fimber.e('$_tag: showing disposed ad', stacktrace: StackTrace.current);
        }
        _adState = DSAdState.showing;
        onAdShow?.call();
        DSAdsManager.instance.emitEvent(DSAdsRewardedShowedEvent._(ad: ad));
        then?.call();
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdDismissed = (ad) {
      try {
        _report('$_tag: full screen content dismissed', location: location, mediation: _mediation, attributes: attrs);
        ad.dispose();
        _ad = null;
        _adState = DSAdState.none;
        _mediation = null;
        _lastShowTime = DateTime.now();
        // если перенести then?.call() сюда, возникает краткий показ предыдущего экрана при закрытии интерстишла
        DSAdsManager.instance.emitEvent(DSAdsRewardedShowDismissedEvent._(ad: ad));
        onAdClosed?.call();
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdFailedToShow = (ad, int errCode, String errText) {
      try {
        _report('$_tag: showing canceled by error', location: location, mediation: _mediation, attributes: attrs);
        Fimber.e('$errText ($errCode)', stacktrace: StackTrace.current);
        ad.dispose();
        _ad = null;
        _adState = DSAdState.none;
        _mediation = null;
        _lastShowTime = DateTime.now();
        onFailedToShow?.call(errCode, errText);
        then?.call();
        DSAdsManager.instance.emitEvent(const DSAdsRewardedShowErrorEvent._());
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdClicked = (ad) {
      try {
        _report('$_tag: ad clicked', location: location, mediation: _mediation, attributes: attrs);
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onRewardEvent = (DSAd ad, num amount, String type) {
      try {
        onRewarded?.call(ad, amount, type);
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };

    if (_isDisposed) {
      _report('$_tag: showing canceled: manager disposed', location: location, mediation: _mediation, attributes: attrs);
      then?.call();
      DSAdsManager.instance.emitEvent(const DSAdsRewardedShowErrorEvent._());
      return;
    }

    final res = await beforeAdShow?.call() ?? true;
    if (!res) {
      _report('$_tag: showing canceled by caller', location: location, mediation: _mediation, attributes: attrs);
      then?.call();
      return;
    }

    _adState = DSAdState.preShowing;
    _lastShowTime = DateTime.now();
    DSAdsManager.instance.emitEvent(DSAdsRewardedPreShowingEvent._(ad: ad));

    _showNum++;
    attrs['rewarded_show_num'] = _showNum;

    _report('$_tag: start showing', location: location, mediation: _mediation, attributes: customAttributes);
    await ad.show();
  }

  @Deprecated('use updateLastShowTime() instead')
  void updateLastShowedTime() {
    updateLastShowTime();
  }

  void updateLastShowTime() {
    _lastShowTime = DateTime.now();
  }

}
