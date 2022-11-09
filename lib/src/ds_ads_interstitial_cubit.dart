import 'dart:async';

import 'package:ds_ads/src/ds_ads_manager.dart';
import 'package:fimber/fimber.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ds_ads_interstitial_state.dart';
import 'ds_ads_types.dart';

part 'ds_ads_interstitial_types.dart';

class DSAdsInterstitialCubit extends Cubit<DSAdsInterstitialState> {
  final String adUnitId;
  final int loadRetryMaxCount;
  final Duration loadRetryDelay;

  var _isDisposed = false;

  DSAdsInterstitialCubit({
    required this.adUnitId,
    this.loadRetryMaxCount = 3,
    this.loadRetryDelay = const Duration(seconds: 1),
  })
      : super(DSAdsInterstitialState(
    ad: null,
    adState: DSAdState.none,
    loadedTime: DateTime(0),
    lastShowedTime: DateTime(0),
    loadRetryCount: 0,
  ));

  void dispose() {
    _isDisposed = true;
    cancelCurrentAd(location: 'internal_dispose');
  }

  void _report(String eventName, {
    required String location,
    String? customAdId,
  }) {
    DSAdsManager.instance.onReportEvent?.call(eventName, {
      'adUnitId': customAdId ?? adUnitId,
      'location': location,
    });
  }

  static bool _isDisabled(String location) {
    if (DSAdsManager.instance.isAdAllowedCallback?.call(DSAdSource.interstitial, location) == false) {
      Fimber.i('ads_interstitial: disabled (location: $location)');
      return true;
    }
    return false;
  }

  /// Fetch interstitial ad
  void fetchAd({
    required final String location,
    final Duration? fetchDelay,
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
    if (DateTime.now().difference(state.loadedTime) < (fetchDelay ?? DSAdsManager.instance.defaultFetchAdDelay)) {
      then?.call();
      return;
    }

    _report('ads_interstitial: start loading', location: location);
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) async {
          try {
            _report('ads_interstitial: loaded', location: location, customAdId: ad.adUnitId);
            ad.onPaidEvent = (ad, valueMicros, precision, currencyCode) {
              DSAdsManager.instance.onPaidEvent(ad, valueMicros, precision, currencyCode, DSAdSource.interstitial);
            };

            await state.ad?.dispose();
            emit(state.copyWith(
              ad: ad,
              adState: DSAdState.loaded,
              loadedTime: DateTime.now(),
              loadRetryCount: 0,
            ));

            then?.call();
            DSAdsManager.instance.emitEvent(DSAdsInterstitialLoadedEvent._(ad: ad));
          } catch (e, stack) {
            Fimber.e('$e', stacktrace: stack);
          }
        },
        onAdFailedToLoad: (err) async {
          try {
            await state.ad?.dispose();
            emit(state.copyWith(
              ad: null,
              adState: DSAdState.none,
              loadRetryCount: state.loadRetryCount + 1,
            ));
            if (state.loadRetryCount < loadRetryMaxCount) {
              await Future.delayed(loadRetryDelay);
              if (state.adState == DSAdState.none && !_isDisposed) {
                _report('ads_interstitial: retry loading', location: location);
                fetchAd(location: location, fetchDelay: fetchDelay, then: then);
              }
            } else {
              _report('ads_interstitial: failed to load', location: location);
              Fimber.w('$err', stacktrace: StackTrace.current);
              emit(state.copyWith(
                ad: null,
                loadedTime: DateTime.now(),
              ));
              then?.call();
              DSAdsManager.instance.emitEvent(DSAdsInterstitialLoadFailedEvent._(err: err));
            }
          } catch (e, stack) {
            Fimber.e('$e', stacktrace: stack);
          }
        },
      ),
    );

    emit(state.copyWith(
      adState: DSAdState.loading,
    ));
  }

  void cancelCurrentAd({
    required final String location,
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
    required final String location,
    final Duration dismissAdAfter = const Duration(),
    final Future<bool> Function()? beforeAdShow,
    final Function()? onAdShow,
    final Function()? then,
  }) async {
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

    if ([DSAdState.none, DSAdState.loading].contains(state.adState)) {
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
            while (state.adState == DSAdState.loading) {
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

    final ad = state.ad;
    if (ad == null) {
      Fimber.e('ad $adUnitId is null but state: ${state.adState}', stacktrace: StackTrace.current);
      _report('ads_interstitial: showing canceled by error', location: location);
      then?.call();
      cancelCurrentAd(location: location);
      DSAdsManager.instance.emitEvent(const DSAdsInterstitialShowErrorEvent._());
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdImpression: (ad) {
          try {
            _report('ads_interstitial: impression', location: location);
          } catch (e, stack) {
            Fimber.e('$e', stacktrace: stack);
          }
        },
        onAdShowedFullScreenContent: (ad) {
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
          } catch (e, stack) {
            Fimber.e('$e', stacktrace: stack);
          }
          then?.call();
        },
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          try {
            _report('ads_interstitial: full screen content dismissed', location: location);
            ad.dispose();
            emit(state.copyWith(
              ad: null,
              adState: DSAdState.none,
              lastShowedTime: DateTime.now(),
            ));
            // если перенести then?.call() сюда, возникает краткий показ предыдущего экрана при закрытии интерстишла
            DSAdsManager.instance.emitEvent(DSAdsInterstitialShowDismissedEvent._(ad: ad));
          } catch (e, stack) {
            Fimber.e('$e', stacktrace: stack);
          }
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          try {
            _report('ads_interstitial: showing canceled by error', location: location);
            Fimber.e('$error', stacktrace: StackTrace.current);
            ad.dispose();
            emit(state.copyWith(
              ad: null,
              adState: DSAdState.none,
              lastShowedTime: DateTime.now(),
            ));
          } catch (e, stack) {
            Fimber.e('$e', stacktrace: stack);
          }
          then?.call();
          DSAdsManager.instance.emitEvent(const DSAdsInterstitialShowErrorEvent._());
        },
        onAdClicked: (ad) {
          try {
            _report('ads_interstitial: ad clicked', location: location);
          } catch (e, stack) {
            Fimber.e('$e', stacktrace: stack);
          }
        }
    );

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

    emit(state.copyWith(
      adState: DSAdState.preShowing,
      lastShowedTime: DateTime.now(),
    ));
    DSAdsManager.instance.emitEvent(DSAdsInterstitialPreShowingEvent._(ad: ad));

    _report('ads_interstitial: start showing', location: location);
    await ad.show();
  }

  void updateLastShowedTime() {
    emit(state.copyWith(
      lastShowedTime: DateTime.now(),
    ));
  }

}
