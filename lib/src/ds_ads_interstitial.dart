import 'dart:async';

import 'package:ds_ads/src/ds_ads_manager.dart';
import 'package:ds_ads/src/generic_ads/export.dart';
import 'package:ds_ads/src/google_ads/export.dart';
import 'package:ds_ads/src/yandex_ads/export.dart';
import 'package:fimber/fimber.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'ds_ads_interstitial_state.dart';
import 'ds_ads_types.dart';

part 'ds_ads_interstitial_types.dart';

class DSAdsInterstitial extends Cubit<DSAdsInterstitialState> {
  static var _lastShowTime = DateTime(0);

  String get adUnitId {
    final mediation = DSAdsManager.instance.currentMediation;
    if (mediation == null) {
      return 'noMediation';
    }
    switch (type) {
      case DSAdsInterstitialType.def:
        switch (mediation) {
          case DSAdMediation.google:
            return DSAdsManager.instance.interstitialGoogleUnitId!;
          case DSAdMediation.yandex:
            return DSAdsManager.instance.interstitialYandexUnitId!;
        }
      case DSAdsInterstitialType.splash:
        switch (mediation) {
          case DSAdMediation.google:
            return DSAdsManager.instance.interstitialSplashGoogleUnitId!;
          case DSAdMediation.yandex:
            return DSAdsManager.instance.interstitialSplashYandexUnitId!;
        }
    }
  }
  final DSAdsInterstitialType type;
  final int loadRetryMaxCount;
  final Duration loadRetryDelay;

  var _isDisposed = false;

  DSAdsInterstitial({
    required this.type,
    this.loadRetryMaxCount = 3,
    this.loadRetryDelay = const Duration(seconds: 1),
  })
      : super(DSAdsInterstitialState(
    ad: null,
    adState: DSAdState.none,
    loadRetryCount: 0,
  ));

  void dispose() {
    _isDisposed = true;
    cancelCurrentAd(location: const DSAdLocation('internal_dispose'));
  }

  void _report(String eventName, {
    required DSAdLocation location,
    String? customAdId,
    Map<String, Object>? attributes,
  }) {
    DSAdsManager.instance.onReportEvent?.call(eventName, {
      'adUnitId': customAdId ?? adUnitId,
      'location': location.val,
      'mediation': '${DSAdsManager.instance.currentMediation}',
      ...?attributes,
    });
  }

  static final _locationErrReports = <DSAdLocation>{};

  static bool _isDisabled(DSAdLocation location) {
    if (!location.isInternal && DSAdsManager.instance.locations?.contains(location) == false) {
      final msg = 'ads_interstitial: location $location not in locations';
      assert(false, msg);
      if (!_locationErrReports.contains(location)) {
        _locationErrReports.add(location);
        Fimber.e(msg, stacktrace: StackTrace.current);
      }
    }
    if (DSAdsManager.instance.isAdAllowedCallback?.call(DSAdSource.interstitial, location) == false) {
      Fimber.i('ads_interstitial: disabled (location: $location)');
      return true;
    }
    if (DSAdsManager.instance.currentMediation == null) {
      Fimber.i('ads_interstitial: disabled (no mediation)');
      return true;
    }
    return false;
  }

  /// Fetch interstitial ad
  void fetchAd({
    required final DSAdLocation location,
    @internal
    final Function()? then,
  }) {
    if (DSAdsManager.instance.appState.isPremium || _isDisposed) {
      then?.call();
      return;
    }

    if (_isDisabled(location)) {
      then?.call();
      return;
    }

    if ([DSAdState.loading, DSAdState.loaded].contains(state.adState)) {
      then?.call();
      return;
    }
    if ([DSAdState.preShowing, DSAdState.showing].contains(state.adState)) {
      Fimber.i('ads_interstitial: fetching is prohibited when ad is showing',
        stacktrace: LimitedStackTrace(stackTrace: StackTrace.current),
      );
      then?.call();
      return;
    }


    if (DateTime.now().difference(_lastShowTime) < (DSAdsManager.instance.interstitialFetchDelay)) {
      then?.call();
      unawaited(() async {
        final spent = DateTime.now().difference(_lastShowTime);
        final delay = DSAdsManager.instance.interstitialFetchDelay - spent;
        await Future.delayed(delay);
        fetchAd(location: const DSAdLocation('internal_fetch_delayed'));
      }());
      return;
    }

    final startTime = DateTime.now();
    _report('ads_interstitial: start loading', location: location);
    final mediation = DSAdsManager.instance.currentMediation!;
    switch (mediation) {
      case DSAdMediation.google:
        DSGoogleInterstitialAd(adUnitId: adUnitId).load(
          onAdLoaded: (ad) async {
            try {
              final duration = DateTime.now().difference(startTime);
              _report('ads_interstitial: loaded', location: location, customAdId: ad.adUnitId, attributes: {
                'mediation': '$mediation', // override
                'google_ads_loaded_seconds': duration.inSeconds,
                'google_ads_loaded_milliseconds': duration.inMilliseconds,
              });
              ad.onPaidEvent = (ad, valueMicros, precision, currencyCode) {
                DSAdsManager.instance.onPaidEvent(ad, valueMicros, precision, currencyCode, DSAdSource.interstitial);
              };

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
          onAdFailedToLoad: (DSInterstitialAd ad, int errCode, String errDescription) async {
            try {
              final duration = DateTime.now().difference(startTime);
              await state.ad?.dispose();
              emit(state.copyWith(
                ad: null,
                adState: DSAdState.error,
                loadRetryCount: state.loadRetryCount + 1,
              ));
              _report('ads_interstitial: failed to load', location: location, attributes: {
                'error_text': errDescription,
                'error_code': '$errCode ($mediation)',
                'mediation': '$mediation', // override
                'google_ads_load_error_seconds': duration.inSeconds,
                'google_ads_load_error_milliseconds': duration.inMilliseconds,
              });
              final oldMediation = DSAdsManager.instance.currentMediation;
              await DSAdsManager.instance.onLoadAdError(errCode, errDescription, mediation, DSAdSource.interstitial);
              if (DSAdsManager.instance.currentMediation != oldMediation) {
                emit(state.copyWith(
                  loadRetryCount: 0,
                ));
              }
              if (state.loadRetryCount < loadRetryMaxCount) {
                await Future.delayed(loadRetryDelay);
                if ({DSAdState.none, DSAdState.error}.contains(state.adState) && !_isDisposed) {
                  _report('ads_interstitial: retry loading', location: location, attributes: {
                    'mediation': '$mediation', // override
                  });
                  fetchAd(location: location, then: then);
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
      case DSAdMediation.yandex:
      // ToDo: deduplicate with DSAdMediation.google case
        YandexAds.instance.loadInterstitial(
          adUnitId: adUnitId,
          onAdLoaded: (DSInterstitialAd ad) async {
            try {
              final duration = DateTime.now().difference(startTime);
              _report('ads_interstitial: loaded', location: location, customAdId: ad.adUnitId, attributes: {
                'mediation': '$mediation', // override
                'yandex_ads_loaded_seconds': duration.inSeconds,
                'yandex_ads_loaded_milliseconds': duration.inMilliseconds,
              });
              // ToDo: implement
              // ad.onPaidEvent = (ad, valueMicros, precision, currencyCode) {
              //   DSAdsManager.instance.onPaidEvent(ad, valueMicros, precision, currencyCode, DSAdSource.interstitial);
              // };

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
          onAdFailedToLoad: (DSInterstitialAd ad, int errCode, String errDescription) async {
            try {
              final duration = DateTime.now().difference(startTime);
              emit(state.copyWith(
                ad: null,
                adState: DSAdState.error,
                loadRetryCount: state.loadRetryCount + 1,
              ));
              _report('ads_interstitial: failed to load', location: location, attributes: {
                'error_text': errDescription,
                'error_code': '$errCode ($mediation)',
                'mediation': '$mediation', // override
                'yandex_ads_load_error_seconds': duration.inSeconds,
                'yandex_ads_load_error_milliseconds': duration.inMilliseconds,
              });
              final oldMediation = DSAdsManager.instance.currentMediation;
              await DSAdsManager.instance.onLoadAdError(errCode, errDescription, mediation, DSAdSource.interstitial);
              if (DSAdsManager.instance.currentMediation != oldMediation) {
                emit(state.copyWith(
                  loadRetryCount: 0,
                ));
              }
              if (state.loadRetryCount < loadRetryMaxCount) {
                await Future.delayed(loadRetryDelay);
                if ({DSAdState.none, DSAdState.error}.contains(state.adState) && !_isDisposed) {
                  _report('ads_interstitial: retry loading', location: location, attributes: {
                    'mediation': '$mediation', // override
                  });
                  fetchAd(location: location, then: then);
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
    }

    emit(state.copyWith(
      adState: DSAdState.loading,
    ));
  }

  void cancelCurrentAd({
    required final DSAdLocation location,
  }) {
    _report('ads_interstitial: cancel current ad (adState: ${state.adState})', location: location);
    if (state.adState == DSAdState.showing) return;
    state.ad?.dispose();
    emit(state.copyWith(
      ad: null,
      adState: DSAdState.none,
    ));
  }

  /// Show interstitial ad. Can wait fetching if [dismissAdAfter] more than zero.
  /// [allowFetchNext] allows start fetching after show interstitial ad.
  /// [location] sets location attribute to report (any string allowed)
  /// [beforeAdShow] allows to cancel ad by return false
  Future<void> showAd({
    required final DSAdLocation location,
    final Duration dismissAdAfter = const Duration(),
    final Future<bool> Function()? beforeAdShow,
    final Function()? onAdShow,
    final Function()? then,
  }) async {
    assert(!location.isInternal);

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
      fetchAd(location: location);
      // https://support.google.com/admob/answer/6201362#zippy=%2Cdisallowed-example-user-launches-app
      return;
    }

    if ([DSAdState.preShowing, DSAdState.showing].contains(state.adState)) {
      Fimber.e('showAd recall (state: $state)', stacktrace: StackTrace.current);
      _report('ads_interstitial: showing canceled by error', location: location);
      then?.call();
      return;
    }

    if ([DSAdState.none, DSAdState.loading, DSAdState.error].contains(state.adState)) {
      if (dismissAdAfter.inSeconds <= 0) {
        _report('ads_interstitial: showing canceled: not ready immediately (dismiss ad after ${dismissAdAfter.inSeconds}s)',
          location: location,
        );
        then?.call();
        DSAdsManager.instance.emitEvent(const DSAdsInterstitialShowErrorEvent._());
      } else {
        var processed = false;
        Timer(dismissAdAfter, () {
          if (processed) return;
          processed = true;
          _report('ads_interstitial: showing canceled: not ready after ${dismissAdAfter.inSeconds}s',
            location: location,
          );
          then?.call();
        });
        fetchAd(
          location: location,
          then: () async {
            while (state.adState == DSAdState.loading || state.adState == DSAdState.error) {
              await Future.delayed(const Duration(milliseconds: 100));
            }
            if (processed) return;
            processed = true;
            if (_isDisposed) {
              _report('ads_interstitial: showing canceled: manager disposed',
                location: location,
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
            await showAd(onAdShow: onAdShow, then: then, location: location);
          },
        );
      }
      return;
    }

    if (DateTime.now().difference(_lastShowTime) < (DSAdsManager.instance.interstitialShowLock)) {
      _report('ads_interstitial: showing canceled: locked for ${DSAdsManager.instance.interstitialShowLock.inSeconds}s',
        location: location,
      );
      then?.call();
      return;
    }

    final ad = state.ad;
    if (ad == null) {
      Fimber.e('ad $adUnitId is null but state: ${state.adState}', stacktrace: StackTrace.current);
      _report('ads_interstitial: showing canceled by error', location: location);
      then?.call();
      cancelCurrentAd(location: location);
      DSAdsManager.instance.emitEvent(const DSAdsInterstitialShowErrorEvent._());
      return;
    }

    ad.onAdImpression = (ad) {
      try {
        _report('ads_interstitial: impression', location: location);
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdShown = (ad) {
      try {
        _report('ads_interstitial: showed full screen content', location: location);
        if (_isDisposed) {
          Fimber.e('ads_interstitial: showing disposed ad', stacktrace: StackTrace.current);
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
        _report('ads_interstitial: full screen content dismissed', location: location);
        ad.dispose();
        _lastShowTime = DateTime.now();
        emit(state.copyWith(
          ad: null,
          adState: DSAdState.none,
        ));
        // если перенести then?.call() сюда, возникает краткий показ предыдущего экрана при закрытии интерстишла
        DSAdsManager.instance.emitEvent(DSAdsInterstitialShowDismissedEvent._(ad: ad));
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdFailedToShow = (ad, int errCode, String errText) {
      try {
        _report('ads_interstitial: showing canceled by error', location: location);
        Fimber.e('$errText ($errCode)', stacktrace: StackTrace.current);
        ad.dispose();
        _lastShowTime = DateTime.now();
        emit(state.copyWith(
          ad: null,
          adState: DSAdState.none,
        ));
        then?.call();
        DSAdsManager.instance.emitEvent(const DSAdsInterstitialShowErrorEvent._());
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdClicked = (ad) {
      try {
        _report('ads_interstitial: ad clicked', location: location);
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };

    if (_isDisposed) {
      _report('ads_interstitial: showing canceled: manager disposed', location: location);
      then?.call();
      DSAdsManager.instance.emitEvent(const DSAdsInterstitialShowErrorEvent._());
      return;
    }

    final res = await beforeAdShow?.call() ?? true;
    if (!res) {
      _report('ads_interstitial: showing canceled by caller', location: location);
      then?.call();
      return;
    }

    _lastShowTime = DateTime.now();
    emit(state.copyWith(
      adState: DSAdState.preShowing,
    ));
    DSAdsManager.instance.emitEvent(DSAdsInterstitialPreShowingEvent._(ad: ad));

    _report('ads_interstitial: start showing', location: location);
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
