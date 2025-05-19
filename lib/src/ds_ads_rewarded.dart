import 'dart:async';

import 'package:ds_ads/src/applovin_ads/applovin_ads.dart';
import 'package:ds_ads/src/ds_ads_manager.dart';
import 'package:ds_ads/src/generic_ads/export.dart';
import 'package:ds_ads/src/google_ads/export.dart';
import 'package:ds_common/ds_common.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'ds_ads_app_open.dart';
import 'ds_ads_types.dart';
import 'ds_ads_types_internal.dart';

part 'ds_ads_rewarded_types.dart';

/// Allows to pre fetch and show Google and AppLovin MAX rewarded ads
class DSAdsRewarded {
  static var _lastShowTime = DateTime(0);
  static const _tag = 'ads_rewarded';

  static var _showNum = 0;

  var _startLoadTime = DateTime(0);
  var _finishLoadTime = DateTime(0);
  var _totalLoadDuration = Duration.zero;
  final _loadConditions = <DSAdsLoadCondition>{};

  String _adUnitId(DSAdMediation mediation) {
    switch (mediation) {
      case DSAdMediation.google:
        return DSAdsManager.I.rewardedGoogleUnitId;
      case DSAdMediation.appLovin:
        return DSAdsManager.I.rewardedAppLovinUnitId;
    }
  }

  final Duration loadRetryDelay;

  var _isDisposed = false;
  DSRewardedAd? _ad;
  DSAdMediation? _mediation;
  var _adState = DSAdState.none;
  var _loadRetryCount = 0;

  DSAdState get adState => _adState;

  DSAdsRewarded({
    this.loadRetryDelay = const Duration(seconds: 1),
  });

  @internal
  void dispose() {
    _isDisposed = true;
    cancelCurrentAd(location: const DSAdLocation('internal_dispose'));
  }

  void _report(
    String eventName, {
    required DSAdLocation location,
    required DSAdMediation? mediation,
    String? customAdId,
    String? adapter,
    Map<String, Object>? attributes,
  }) {
    DSAdsManager.I.onReportEvent?.call(eventName, {
      if (mediation != null) 'adUnitId': customAdId ?? _adUnitId(mediation),
      'location': location.val,
      'mediation': '$mediation',
      if (adapter != null) 'adapter': adapter,
      ...?attributes,
    });
  }

  static final _locationErrReports = <DSAdLocation>{};

  bool _isDisabled(DSAdLocation location) {
    if (!location.isInternal && DSAdsManager.I.locations?.contains(location) == false) {
      final msg = '$_tag: location $location not in locations';
      assert(false, msg);
      if (!_locationErrReports.contains(location)) {
        _locationErrReports.add(location);
        Fimber.e(msg, stacktrace: StackTrace.current);
      }
    }
    if (DSAdsManager.I.isAdAllowedCallbackProc(DSAdSource.rewarded, location) == false) {
      Fimber.i('$_tag: disabled (location: $location)');
      return true;
    }
    if (DSAdsManager.I.currentMediation(DSAdSource.rewarded) == null) {
      _report('$_tag: disabled (no mediation)', location: location, mediation: null);
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
    @internal final Function()? then,
  }) {
    assert(_checkCustomAttributes(customAttributes), 'custom attributes must have custom_attr_ prefix');

    if (DSAdsManager.I.isPremium || _isDisposed) {
      then?.call();
      return;
    }

    DSAdsManager.I.updateMediations(DSAdSource.rewarded);

    if (_isDisabled(location)) {
      then?.call();
      return;
    }

    if ([DSAdState.loading, DSAdState.loaded].contains(adState)) {
      then?.call();
      return;
    }
    if ([DSAdState.preShowing, DSAdState.showing].contains(adState)) {
      Fimber.i(
        '$_tag: fetching is prohibited when ad is showing',
        stacktrace: LimitedStackTrace(stackTrace: StackTrace.current),
      );
      then?.call();
      return;
    }

    final rewardedFetchDelay = DSAdsManager.I.rewardedFetchDelayCallback?.call() ?? const Duration();
    if (DateTime.timestamp().difference(_lastShowTime) < (rewardedFetchDelay)) {
      then?.call();
      unawaited(() async {
        final spent = DateTime.timestamp().difference(_lastShowTime);
        final delay = rewardedFetchDelay - spent;
        await Future.delayed(delay);
        fetchAd(location: const DSAdLocation('internal_fetch_delayed'), customAttributes: customAttributes);
      }());
      return;
    }

    final mediation = DSAdsManager.I.currentMediation(DSAdSource.rewarded);
    _mediation = mediation;
    if (mediation == null) {
      _report('$_tag: no mediation', location: location, mediation: mediation, attributes: customAttributes);
      return;
    }
    _report('$_tag: start loading', location: location, mediation: mediation, attributes: customAttributes);
    if (_startLoadTime.year == 0) {
      _startLoadTime = DateTime.timestamp();
      _finishLoadTime = DateTime(0);
    }

    Future<void> onAdLoaded(DSRewardedAd ad) async {
      try {
        unawaited(DSMetrica.putErrorEnvironmentValue('ads_last_action', 'rewarded_loaded'));
        unawaited(DSMetrica.putErrorEnvironmentValue('ads_rewarded_adapter', ad.mediationAdapterClassName));
        _totalLoadDuration = DateTime.timestamp().difference(_startLoadTime);
        _startLoadTime = DateTime(0);
        _finishLoadTime = DateTime.timestamp();
        _report(
          '$_tag: loaded',
          location: location,
          mediation: mediation,
          customAdId: ad.adUnitId,
          adapter: ad.mediationAdapterClassName,
          attributes: {
            ...ad.getReportAttributes(),
            ...?customAttributes,
          },
        );
        await _ad?.dispose();
        _ad = ad;
        _adState = DSAdState.loaded;
        _loadRetryCount = 0;
        then?.call();
        DSAdsManager.I.emitEvent(DSAdsRewardedLoadedEvent._(source: DSAdSource.rewarded, ad: ad));
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    }

    Future<void> onAdFailedToLoad(DSAd ad, int errCode, String errDescription) async {
      try {
        final attrs = ad.getReportAttributes();
        await _ad?.dispose();
        _ad = null;
        _adState = DSAdState.error;
        _loadRetryCount++;
        unawaited(DSMetrica.putErrorEnvironmentValue('ads_last_action', 'rewarded_loading_failed'));
        unawaited(DSMetrica.putErrorEnvironmentValue('ads_rewarded_adapter', ad.mediationAdapterClassName));
        _report(
          '$_tag: failed to load',
          location: location,
          mediation: mediation,
          attributes: {
            'error_text': errDescription,
            'error_code': '$errCode ($mediation)',
            ...attrs,
            ...?customAttributes,
          },
        );
        final oldMediation = DSAdsManager.I.currentMediation(DSAdSource.rewarded);
        await DSAdsManager.I.onLoadAdError(errCode, errDescription, mediation, DSAdSource.rewarded);
        if (DSAdsManager.I.currentMediation(DSAdSource.rewarded) != oldMediation) {
          _loadRetryCount = 0;
        }
        if (_loadRetryCount < DSAdsManager.I.getRetryMaxCount(DSAdSource.rewarded)) {
          await Future.delayed(loadRetryDelay);
          if ({DSAdState.none, DSAdState.error}.contains(adState) && !_isDisposed) {
            _report('$_tag: retry loading', location: location, mediation: mediation, attributes: customAttributes);
            fetchAd(location: location, then: then, customAttributes: customAttributes);
          }
        } else {
          Fimber.w('$errDescription ($errCode)', stacktrace: StackTrace.current);
          _adState = DSAdState.none;
          then?.call();
          DSAdsManager.I.emitEvent(DSAdsRewardedLoadFailedEvent._(
            source: DSAdSource.rewarded,
            errCode: errCode,
            errText: errDescription,
          ));
          _startLoadTime = DateTime(0);
        }
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    }

    switch (mediation) {
      case DSAdMediation.google:
        DSGoogleRewardedAd(adUnitId: _adUnitId(mediation)).load(
          onAdLoaded: onAdLoaded,
          onAdFailedToLoad: onAdFailedToLoad,
        );
        break;
      case DSAdMediation.appLovin:
        DSAppLovinRewardedAd(adUnitId: _adUnitId(mediation)).load(
          onAdLoaded: onAdLoaded,
          onAdFailedToLoad: onAdFailedToLoad,
        );
        break;
    }

    _adState = DSAdState.loading;
  }

  void cancelCurrentAd({
    required final DSAdLocation location,
  }) {
    _report('$_tag: cancel current ad (adState: $adState)', location: location, mediation: _mediation);
    if (adState == DSAdState.showing) return;
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
    final Function()? onShowLock,
    Map<String, Object>? customAttributes,
  }) async {
    assert(!location.isInternal);
    assert(_checkCustomAttributes(customAttributes), 'custom attributes must have custom_attr_ prefix');

    if (DSAdsManager.I.isPremium || _isDisposed) {
      then?.call();
      return;
    }

    if (_isDisabled(location)) {
      then?.call();
      return;
    }

    final mediation = _mediation;
    final startTime = DateTime.timestamp();

    if (!DSAdsManager.I.isInForeground) {
      _report('$_tag: app in background', location: location, mediation: mediation, attributes: customAttributes);
      then?.call();
      fetchAd(location: location, customAttributes: customAttributes);
      // https://support.google.com/admob/answer/6201362#zippy=%2Cdisallowed-example-user-launches-app
      return;
    }

    if ([DSAdState.preShowing, DSAdState.showing].contains(adState)) {
      Fimber.e('showAd recall (state: $adState)', stacktrace: StackTrace.current);
      _report(
        '$_tag: showing canceled by error',
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

    if ([DSAdState.none, DSAdState.loading, DSAdState.error].contains(adState)) {
      if (calcDismissAdAfter().inSeconds <= 0) {
        _report(
          '$_tag: showing canceled: not ready immediately (dismiss ad after ${calcDismissAdAfter().inSeconds}s)',
          location: location,
          mediation: mediation,
          attributes: customAttributes,
        );
        then?.call();
        DSAdsManager.I.emitEvent(DSAdsRewardedShowErrorEvent._(source: DSAdSource.rewarded));
      } else {
        var processed = false;
        Timer(calcDismissAdAfter(), () {
          if (processed) return;
          processed = true;
          _report(
            '$_tag: showing canceled: not ready after ${calcDismissAdAfter().inSeconds}s',
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
            while (adState == DSAdState.loading || adState == DSAdState.error) {
              await Future.delayed(const Duration(milliseconds: 100));
            }
            if (processed) return;
            processed = true;
            if (_isDisposed) {
              _report(
                '$_tag: showing canceled: manager disposed',
                location: location,
                mediation: mediation,
                attributes: customAttributes,
              );
              then?.call();
              DSAdsManager.I.emitEvent(DSAdsRewardedShowErrorEvent._(source: DSAdSource.rewarded));
              return;
            }
            if (adState == DSAdState.none) {
              // Failed to fetch ad
              then?.call();
              DSAdsManager.I.emitEvent(DSAdsRewardedShowErrorEvent._(source: DSAdSource.rewarded));
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

    final rewardedShowLock = DSAdsManager.I.rewardedShowLockedProc(location);
    if (DateTime.timestamp().difference(_lastShowTime) < (rewardedShowLock)) {
      _report(
        '$_tag: showing canceled: locked for ${rewardedShowLock.inSeconds}s',
        location: location,
        mediation: _mediation,
        attributes: customAttributes,
      );
      onShowLock?.call();
      then?.call();
      DSAdsManager.I.emitEvent(DSAdsRewardedShowLockEvent._(source: DSAdSource.rewarded));
      return;
    }

    final ad = _ad;
    if (ad == null) {
      Fimber.e('ad is null but state: $_adState', stacktrace: StackTrace.current);
      _report(
        '$_tag: showing canceled by error',
        location: location,
        mediation: _mediation,
        attributes: customAttributes,
      );
      then?.call();
      cancelCurrentAd(location: location);
      DSAdsManager.I.emitEvent(DSAdsRewardedShowErrorEvent._(source: DSAdSource.rewarded));
      return;
    }

    final attrs = customAttributes ?? {};

    ad.onAdImpression = (ad) {
      try {
        unawaited(DSMetrica.putErrorEnvironmentValue('ads_last_action', 'rewarded_impression'));
        unawaited(DSMetrica.putErrorEnvironmentValue('ads_rewarded_adapter', ad.mediationAdapterClassName));
        _report('$_tag: impression',
            location: location, mediation: ad.mediation, adapter: ad.mediationAdapterClassName, attributes: attrs);
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onPaidEvent = (ad, valueMicros, precision, currencyCode, appLovinDspName) {
      try {
        DSAdsManager.I.onPaidEvent(ad, ad.mediation, location, valueMicros, precision, currencyCode,
            DSAdSource.rewarded, appLovinDspName, attrs);
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdShown = (ad) {
      try {
        DSAdsAppOpen.lockShowFor(const Duration(hours: 1));

        final eventAttrs = attrs.putShowAdInfo(
          startShowRequest: startTime,
          totalLoadDuration: _totalLoadDuration,
          loadConditions: _loadConditions,
        );
        _totalLoadDuration = Duration.zero;

        _report('$_tag: showed full screen content',
            location: location, mediation: ad.mediation, adapter: ad.mediationAdapterClassName, attributes: eventAttrs);
        if (_isDisposed) {
          Fimber.e('$_tag: showing disposed ad', stacktrace: StackTrace.current);
        }
        _adState = DSAdState.showing;
        onAdShow?.call();
        DSAdsManager.I.emitEvent(DSAdsRewardedShowedEvent._(source: DSAdSource.rewarded, ad: ad));
        then?.call();
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdDismissed = (ad) {
      try {
        DSAdsAppOpen.lockShowFor(const Duration(seconds: 5));
        _report('$_tag: full screen content dismissed',
            location: location, mediation: ad.mediation, adapter: ad.mediationAdapterClassName, attributes: attrs);
        ad.dispose();
        _ad = null;
        _adState = DSAdState.none;
        _mediation = null;
        _finishLoadTime = DateTime(0);
        _lastShowTime = DateTime.timestamp();
        // если перенести then?.call() сюда, возникает краткий показ предыдущего экрана при закрытии интерстишла
        DSAdsManager.I.emitEvent(DSAdsRewardedShowDismissedEvent._(source: DSAdSource.rewarded, ad: ad));
        onAdClosed?.call();
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdFailedToShow = (ad, int errCode, String errText) {
      try {
        DSAdsAppOpen.lockShowFor(const Duration(seconds: 5));
        _report('$_tag: showing canceled by error',
            location: location, mediation: ad.mediation, adapter: ad.mediationAdapterClassName, attributes: attrs);
        Fimber.e('$errText ($errCode)', stacktrace: StackTrace.current);
        ad.dispose();
        _ad = null;
        _adState = DSAdState.none;
        _mediation = null;
        _finishLoadTime = DateTime(0);
        _lastShowTime = DateTime.timestamp();
        onFailedToShow?.call(errCode, errText);
        then?.call();
        DSAdsManager.I.emitEvent(DSAdsRewardedShowErrorEvent._(source: DSAdSource.rewarded));
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdClicked = (ad) {
      try {
        DSAdsAppOpen.lockShowFor(const Duration(hours: 1));
        _report('$_tag: ad clicked',
            location: location, mediation: ad.mediation, adapter: ad.mediationAdapterClassName, attributes: attrs);
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
      _report('$_tag: showing canceled: manager disposed',
          location: location, mediation: _mediation, attributes: attrs);
      then?.call();
      DSAdsManager.I.emitEvent(DSAdsRewardedShowErrorEvent._(source: DSAdSource.rewarded));
      return;
    }

    final res = await beforeAdShow?.call() ?? true;
    if (!res) {
      _report('$_tag: showing canceled by caller', location: location, mediation: _mediation, attributes: attrs);
      then?.call();
      return;
    }

    _adState = DSAdState.preShowing;
    _lastShowTime = DateTime.timestamp();
    DSAdsManager.I.emitEvent(DSAdsRewardedPreShowingEvent._(source: DSAdSource.rewarded, ad: ad));

    _showNum++;
    attrs['rewarded_show_num'] = _showNum;

    _report('$_tag: start showing', location: location, mediation: _mediation, attributes: {
      ...?customAttributes,
      'since_fetched_seconds': _finishLoadTime.year == 0
          ? -1
          : DateTime.timestamp().difference(_finishLoadTime).inSeconds,
    });
    await ad.show();
  }

  void updateLastShowTime() {
    _lastShowTime = DateTime.timestamp();
  }
}
