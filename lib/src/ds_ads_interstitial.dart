import 'dart:async';

import 'package:ds_ads/src/applovin_ads/applovin_ads.dart';
import 'package:ds_ads/src/ds_ads_manager.dart';
import 'package:ds_ads/src/generic_ads/export.dart';
import 'package:ds_ads/src/google_ads/export.dart';
import 'package:ds_common/ds_common.dart';
import 'package:fimber/fimber.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'ds_ads_app_open.dart';
import 'ds_ads_interstitial_state.dart';
import 'ds_ads_types.dart';

part 'ds_ads_interstitial_types.dart';

class DSAdsInterstitial extends Cubit<DSAdsInterstitialState> {
  static var _lastShowTime = DateTime(0);
  static const _tag = 'ads_interstitial';

  static var _showNum = 0;

  String _adUnitId(DSAdMediation mediation) {
    switch (type) {
      case DSAdsInterstitialType.def:
        switch (mediation) {
          case DSAdMediation.google:
            return DSAdsManager.instance.interstitialGoogleUnitId;
          case DSAdMediation.appLovin:
            return DSAdsManager.instance.interstitialAppLovinUnitId;
        }
      case DSAdsInterstitialType.splash:
        switch (mediation) {
          case DSAdMediation.google:
            return DSAdsManager.instance.interstitialSplashGoogleUnitId;
          case DSAdMediation.appLovin:
            return DSAdsManager.instance.interstitialSplashAppLovinUnitId;
        }
    }
  }

  final DSAdsInterstitialType type;
  final Duration loadRetryDelay;

  var _isDisposed = false;
  DSAdMediation? _mediation;

  DSAdsInterstitial({
    required this.type,
    this.loadRetryDelay = const Duration(seconds: 1),
  }) : super(DSAdsInterstitialState(
          ad: null,
          adState: DSAdState.none,
          loadRetryCount: 0,
        ));

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
    DSAdsManager.instance.onReportEvent?.call(eventName, {
      if (mediation != null) 'adUnitId': customAdId ?? _adUnitId(mediation),
      'location': location.val,
      'mediation': '$mediation',
      if (adapter != null) 'adapter': adapter,
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
    if (DSAdsManager.instance.isAdAllowedCallback?.call(DSAdSource.interstitial, location) == false) {
      Fimber.i('$_tag: disabled (location: $location)');
      return true;
    }
    if (DSAdsManager.instance.currentMediation(DSAdSource.interstitial) == null) {
      Fimber.i('$_tag: disabled (no mediation)');
      return true;
    }
    return false;
  }

  bool _checkCustomAttributes(Map<String, Object>? attrs) {
    if (attrs == null) return true;
    return attrs.keys.every((e) => e.startsWith('custom_attr_'));
  }

  /// Fetch interstitial ad
  void fetchAd({
    required final DSAdLocation location,
    Map<String, Object>? customAttributes,
    @internal final Function()? then,
  }) {
    assert(_checkCustomAttributes(customAttributes), 'custom attributes must have custom_attr_ prefix');

    if (DSAdsManager.instance.appState.isPremium || _isDisposed) {
      then?.call();
      return;
    }

    DSAdsManager.instance.updateMediations(DSAdSource.interstitial);

    if (_isDisabled(location)) {
      then?.call();
      return;
    }

    if ([DSAdState.loading, DSAdState.loaded].contains(state.adState)) {
      then?.call();
      return;
    }
    if ([DSAdState.preShowing, DSAdState.showing].contains(state.adState)) {
      Fimber.i(
        '$_tag: fetching is prohibited when ad is showing',
        stacktrace: LimitedStackTrace(stackTrace: StackTrace.current),
      );
      then?.call();
      return;
    }

    final interstitialFetchDelay = DSAdsManager.instance.interstitialFetchDelayCallback?.call() ?? const Duration();
    if (DateTime.now().difference(_lastShowTime) < interstitialFetchDelay) {
      then?.call();
      unawaited(() async {
        final spent = DateTime.now().difference(_lastShowTime);
        final delay = interstitialFetchDelay - spent;
        await Future.delayed(delay);
        fetchAd(location: const DSAdLocation('internal_fetch_delayed'), customAttributes: customAttributes);
      }());
      return;
    }

    final mediation = DSAdsManager.instance.currentMediation(DSAdSource.interstitial);
    _mediation = mediation;
    if (mediation == null) {
      _report('$_tag: no mediation', location: location, mediation: mediation, attributes: customAttributes);
      return;
    }
    _report('$_tag: start loading', location: location, mediation: mediation, attributes: customAttributes);
    switch (mediation) {
      case DSAdMediation.google:
        DSGoogleInterstitialAd(adUnitId: _adUnitId(mediation)).load(
          onAdLoaded: (ad) async {
            try {
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
              await state.ad?.dispose();
              emit(state.copyWith(
                ad: ad,
                adState: DSAdState.loaded,
                loadRetryCount: 0,
              ));

              then?.call();
              DSAdsManager.instance.emitEvent(DSAdsInterstitialLoadedEvent._(ad: ad));
            } catch (e, stack) {
              Fimber.e('$e', stacktrace: stack);
            }
          },
          onAdFailedToLoad: (DSAd ad, int errCode, String errDescription) async {
            try {
              final attrs = ad.getReportAttributes();
              await state.ad?.dispose();
              emit(state.copyWith(
                ad: null,
                adState: DSAdState.error,
                loadRetryCount: state.loadRetryCount + 1,
              ));
              _report(
                '$_tag: failed to load',
                location: location,
                mediation: mediation,
                adapter: ad.mediationAdapterClassName,
                attributes: {
                  'error_text': errDescription,
                  'error_code': '$errCode ($mediation)',
                  ...attrs,
                  ...?customAttributes,
                },
              );
              await DSAdsManager.instance.onLoadAdError(errCode, errDescription, mediation, DSAdSource.interstitial);
              if (DSAdsManager.instance.currentMediation(DSAdSource.interstitial) != _mediation) {
                emit(state.copyWith(
                  loadRetryCount: 0,
                ));
              }
              _mediation = null;
              if (state.loadRetryCount < DSAdsManager.instance.getRetryMaxCount(DSAdSource.interstitial)) {
                await Future.delayed(loadRetryDelay);
                if ({DSAdState.none, DSAdState.error}.contains(state.adState) && !_isDisposed) {
                  _report('$_tag: retry loading',
                      location: location, mediation: _mediation, attributes: customAttributes);
                  fetchAd(location: location, then: then, customAttributes: customAttributes);
                }
              } else {
                Fimber.w('$errDescription ($errCode)', stacktrace: StackTrace.current);
                emit(state.copyWith(
                  ad: null,
                  adState: DSAdState.none,
                ));
                then?.call();
                DSAdsManager.instance.emitEvent(DSAdsInterstitialLoadFailedEvent._(
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
        DSAppLovinInterstitialAd(adUnitId: _adUnitId(mediation)).load(
          onAdLoaded: (ad) async {
            try {
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
              await state.ad?.dispose();
              emit(state.copyWith(
                ad: ad,
                adState: DSAdState.loaded,
                loadRetryCount: 0,
              ));

              then?.call();
              DSAdsManager.instance.emitEvent(DSAdsInterstitialLoadedEvent._(ad: ad));
            } catch (e, stack) {
              Fimber.e('$e', stacktrace: stack);
            }
          },
          onAdFailedToLoad: (DSAd ad, int errCode, String errDescription) async {
            try {
              final attrs = ad.getReportAttributes();
              await state.ad?.dispose();
              emit(state.copyWith(
                ad: null,
                adState: DSAdState.error,
                loadRetryCount: state.loadRetryCount + 1,
              ));
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
              final oldMediation = DSAdsManager.instance.currentMediation(DSAdSource.interstitial);
              await DSAdsManager.instance.onLoadAdError(errCode, errDescription, mediation, DSAdSource.interstitial);
              if (DSAdsManager.instance.currentMediation(DSAdSource.interstitial) != oldMediation) {
                emit(state.copyWith(
                  loadRetryCount: 0,
                ));
              }
              if (state.loadRetryCount < DSAdsManager.instance.getRetryMaxCount(DSAdSource.interstitial)) {
                await Future.delayed(loadRetryDelay);
                if ({DSAdState.none, DSAdState.error}.contains(state.adState) && !_isDisposed) {
                  _report('$_tag: retry loading',
                      location: location, mediation: mediation, attributes: customAttributes);
                  fetchAd(location: location, then: then, customAttributes: customAttributes);
                }
              } else {
                Fimber.w('$errDescription ($errCode)', stacktrace: StackTrace.current);
                emit(state.copyWith(
                  ad: null,
                  adState: DSAdState.none,
                ));
                then?.call();
                DSAdsManager.instance.emitEvent(DSAdsInterstitialLoadFailedEvent._(
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

    emit(state.copyWith(
      adState: DSAdState.loading,
    ));
  }

  void cancelCurrentAd({
    required final DSAdLocation location,
  }) {
    _report('$_tag: cancel current ad (adState: ${state.adState})', location: location, mediation: _mediation);
    if (state.adState == DSAdState.showing) return;
    state.ad?.dispose();
    _mediation = null;
    emit(state.copyWith(
      ad: null,
      adState: DSAdState.none,
    ));
  }

  /// Show interstitial ad. Can wait fetching if [dismissAdAfter] (or [dismissAdAfterCallback]) more than zero.
  /// [allowFetchNext] allows start fetching after show interstitial ad.
  /// [location] sets location attribute to report (any string allowed)
  /// [beforeAdShow] allows to cancel ad by return false
  Future<void> showAd({
    required final DSAdLocation location,
    final Duration dismissAdAfter = const Duration(),
    final Duration Function()? dismissAdAfterCallback,
    final Future<bool> Function()? beforeAdShow,
    final Function()? onAdShow,
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

    if (!DSAdsManager.instance.isInForeground) {
      _report('$_tag: app in background', location: location, mediation: _mediation, attributes: customAttributes);
      then?.call();
      fetchAd(location: location, customAttributes: customAttributes);
      // https://support.google.com/admob/answer/6201362#zippy=%2Cdisallowed-example-user-launches-app
      return;
    }

    if ([DSAdState.preShowing, DSAdState.showing].contains(state.adState)) {
      Fimber.e('showAd recall (state: $state)', stacktrace: StackTrace.current);
      _report('$_tag: showing canceled by error',
          location: location, mediation: _mediation, attributes: customAttributes);
      then?.call();
      return;
    }

    Duration calcDismissAdAfter() {
      if (dismissAdAfterCallback != null) {
        return dismissAdAfterCallback();
      }
      return dismissAdAfter;
    }

    if ([DSAdState.none, DSAdState.loading, DSAdState.error].contains(state.adState)) {
      if (calcDismissAdAfter().inSeconds <= 0) {
        _report(
          '$_tag: showing canceled: not ready immediately (dismiss ad after ${calcDismissAdAfter().inSeconds}s, state: ${state.adState})',
          location: location,
          mediation: _mediation,
          attributes: customAttributes,
        );
        then?.call();
        DSAdsManager.instance.emitEvent(const DSAdsInterstitialShowErrorEvent._());
      } else {
        var processed = false;
        Timer(calcDismissAdAfter(), () {
          if (processed) return;
          processed = true;
          _report(
            '$_tag: showing canceled: not ready after ${calcDismissAdAfter().inSeconds}s, state: ${state.adState}',
            location: location,
            mediation: _mediation,
            attributes: customAttributes,
          );
          then?.call();
        });
        fetchAd(
          location: location,
          customAttributes: customAttributes,
          then: () async {
            while (state.adState == DSAdState.loading || state.adState == DSAdState.error) {
              await Future.delayed(const Duration(milliseconds: 100));
            }
            if (processed) return;
            processed = true;
            if (_isDisposed) {
              _report(
                '$_tag: showing canceled: manager disposed',
                location: location,
                mediation: _mediation,
                attributes: customAttributes,
              );
              then?.call();
              DSAdsManager.instance.emitEvent(const DSAdsInterstitialShowErrorEvent._());
              return;
            }
            if (state.adState == DSAdState.none) {
              // Failed to fetch ad
              then?.call();
              DSAdsManager.instance.emitEvent(const DSAdsInterstitialShowErrorEvent._());
              return;
            }
            await showAd(
              location: location,
              beforeAdShow: beforeAdShow,
              onAdShow: onAdShow,
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

    final interstitialShowLock = DSAdsManager.instance.interstitialShowLockCallback?.call() ?? const Duration();
    if (DateTime.now().difference(_lastShowTime) < interstitialShowLock) {
      _report(
        '$_tag: showing canceled: locked for ${interstitialShowLock.inSeconds}s',
        location: location,
        mediation: _mediation,
        attributes: customAttributes,
      );
      then?.call();
      return;
    }

    final ad = state.ad;
    if (ad == null) {
      Fimber.e('ad is null but state: ${state.adState}', stacktrace: StackTrace.current);
      _report('$_tag: showing canceled by error',
          location: location, mediation: _mediation, attributes: customAttributes);
      then?.call();
      cancelCurrentAd(location: location);
      DSAdsManager.instance.emitEvent(const DSAdsInterstitialShowErrorEvent._());
      return;
    }

    final attrs = customAttributes ?? {};

    ad.onAdImpression = (ad) {
      try {
        _report('$_tag: impression',
            location: location, mediation: _mediation, adapter: ad.mediationAdapterClassName, attributes: attrs);
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onPaidEvent = (ad, valueMicros, precision, currencyCode, appLovinDspName) {
      try {
        DSAdsManager.instance.onPaidEvent(ad, _mediation!, location, valueMicros, precision, currencyCode,
            DSAdSource.interstitial, appLovinDspName, attrs);
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdShown = (ad) {
      try {
        DSAdsAppOpen.lockShowFor(const Duration(hours: 1));
        _report('$_tag: showed full screen content',
            location: location, mediation: _mediation, adapter: ad.mediationAdapterClassName, attributes: attrs);
        if (_isDisposed) {
          Fimber.e('$_tag: showing disposed ad', stacktrace: StackTrace.current);
        }
        emit(state.copyWith(
          adState: DSAdState.showing,
        ));
        onAdShow?.call();
        DSAdsManager.instance.emitEvent(DSAdsInterstitialShowedEvent._(ad: ad));
        then?.call();
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdDismissed = (ad) {
      try {
        DSAdsAppOpen.lockShowFor(const Duration(seconds: 5));
        _report('$_tag: full screen content dismissed',
            location: location, mediation: _mediation, adapter: ad.mediationAdapterClassName, attributes: attrs);
        ad.dispose();
        updateLastShowTime();
        _mediation = null;
        emit(state.copyWith(
          ad: null,
          adState: DSAdState.none,
        ));
        // если перенести then?.call() сюда, возникает краткий показ предыдущего экрана при закрытии интерстишла
        DSAdsManager.instance.emitEvent(DSAdsInterstitialShowDismissedEvent._(ad: ad));
        onAdClosed?.call();
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdFailedToShow = (ad, int errCode, String errText) {
      try {
        DSAdsAppOpen.lockShowFor(const Duration(seconds: 5));
        _report('$_tag: showing canceled by error',
            location: location, mediation: _mediation, adapter: ad.mediationAdapterClassName, attributes: attrs);
        Fimber.e('$errText ($errCode)', stacktrace: StackTrace.current);
        ad.dispose();
        updateLastShowTime();
        _mediation = null;
        emit(state.copyWith(
          ad: null,
          adState: DSAdState.none,
        ));
        onFailedToShow?.call(errCode, errText);
        then?.call();
        DSAdsManager.instance.emitEvent(const DSAdsInterstitialShowErrorEvent._());
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdClicked = (ad) {
      try {
        _report('$_tag: ad clicked',
            location: location, mediation: _mediation, adapter: ad.mediationAdapterClassName, attributes: attrs);
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };

    if (_isDisposed) {
      _report('$_tag: showing canceled: manager disposed',
          location: location, mediation: _mediation, attributes: attrs);
      then?.call();
      DSAdsManager.instance.emitEvent(const DSAdsInterstitialShowErrorEvent._());
      return;
    }

    final res = await beforeAdShow?.call() ?? true;
    if (!res) {
      _report('$_tag: showing canceled by caller', location: location, mediation: _mediation, attributes: attrs);
      then?.call();
      return;
    }

    updateLastShowTime();
    emit(state.copyWith(
      adState: DSAdState.preShowing,
    ));
    DSAdsManager.instance.emitEvent(DSAdsInterstitialPreShowingEvent._(ad: ad));

    _showNum++;
    attrs['interstitial_show_num'] = _showNum;

    _report('$_tag: start showing', location: location, mediation: _mediation, attributes: attrs);
    await ad.show();
  }

  DateTime getLastShowTime() => _lastShowTime;

  void updateLastShowTime() {
    _lastShowTime = DateTime.now();
  }
}
