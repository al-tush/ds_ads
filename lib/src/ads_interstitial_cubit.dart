import 'package:ds_ads/src/ads_manager.dart';
import 'package:fimber/fimber.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_interstitial_state.dart';

class AdsInterstitialCubit extends Cubit<AdsInterstitialState> {
  final String adUnitId;
  final int loadRetryMaxCount;
  final Duration loadRetryDuration;

  var _isDisposed = false;

  AdsInterstitialCubit({
    required this.adUnitId,
    this.loadRetryMaxCount = 5,
    this.loadRetryDuration = const Duration(seconds: 1),
  })
      : super(AdsInterstitialState(
          ad: null,
          adState: AdState.none,
          loadedTime: DateTime(0),
          lastShowedTime: DateTime(0),
          loadRetryCount: 0,
        ));

  void dispose() {
    _isDisposed = true;
    cancelCurrentAd();
  }

  void _report(String eventName, {String? customAdId}) {
    AdsManager.instance.onReportEvent?.call(eventName, {
      'adUnitId': customAdId ?? adUnitId,
    });
  }

  void fetchAd({
    Duration minWait = const Duration(seconds: 20),
    Function()? then,
  }) {
    if (AdsManager.instance.appState.isPremium || _isDisposed) {
      then?.call();
      return;
    }

    if ([AdState.loading, AdState.loaded].contains(state.adState)) {
      then?.call();
      return;
    }
    if (DateTime.now().difference(state.loadedTime) < minWait) {
      then?.call();
      return;
    }

    _report('ads_interstitial: start loading');
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) async {
          try {
            _report('ads_interstitial: loaded', customAdId: ad.adUnitId);
            AdsManager.instance.adsLoaded();
            ad.onPaidEvent = (ad, valueMicros, precision, currencyCode) {
               AdsManager.instance.onPaidEvent(ad, valueMicros, precision, currencyCode, 'interstitialAd');
             };

            await state.ad?.dispose();
            emit(state.copyWith(
              ad: ad,
              adState: AdState.loaded,
              loadedTime: DateTime.now(),
              loadRetryCount: 0,
            ));
          } finally {
            then?.call();
          }
        },
        onAdFailedToLoad: (err) async {
          await state.ad?.dispose();
          emit(state.copyWith(
            ad: null,
            adState: AdState.none,
            loadRetryCount: state.loadRetryCount + 1,
          ));
          if (state.loadRetryCount < loadRetryMaxCount) {
            await Future.delayed(loadRetryDuration);
            if (state.adState == AdState.none) {
              _report('ads_interstitial: retry loading');
              fetchAd(minWait: minWait, then: then);
            }
          } else {
            _report('ads_interstitial: failed to load');
            Fimber.w('$err', stacktrace: StackTrace.current);
            emit(state.copyWith(
              ad: null,
              loadedTime: DateTime.now(),
            ));
            then?.call();
          }
        },
      ),
    );

    emit(state.copyWith(
      adState: AdState.loading,
    ));
  }

  void cancelCurrentAd() {
    _report('ads_interstitial: cancel current ad');
    state.ad?.dispose();
    emit(state.copyWith(
      ad: null,
      adState: AdState.none,
    ));
  }

  Future<void> showAd({
    // dismissAdAfter - время, по прошествии которого показывать рекламу уже ни в коем случае не нужно
    final Duration dismissAdAfter = const Duration(),
    Function()? onAdShow,
    Function()? then,
  }) async {
    final startTime = DateTime.now();

    if (AdsManager.instance.appState.isPremium || _isDisposed) {
      then?.call();
      return;
    }

    if (!AdsManager.instance.appState.isInForeground) {
      then?.call();
      fetchAd();
      // https://support.google.com/admob/answer/6201362#zippy=%2Cdisallowed-example-user-launches-app
      return;
    }

    if ([AdState.preShowing, AdState.showing].contains(state.adState)) {
      Fimber.e('showAd recall (state: $state)', stacktrace: StackTrace.current);
      _report('ads_interstitial: showing canceled by error');
      then?.call();
      return;
    }

    if ([AdState.none, AdState.loading].contains(state.adState)) {
      Fimber.i('TEST5 ${dismissAdAfter.inSeconds} $dismissAdAfter');
      if (dismissAdAfter.inSeconds <= 0) {
        _report('ads_interstitial: showing canceled: not ready immediately (dismiss ad after ${dismissAdAfter.inSeconds}s)');
        fetchAd();
        then?.call();
      } else {
        fetchAd(
          then: () {
            if (_isDisposed) {
              _report('ads_interstitial: showing canceled: manager disposed');
              then?.call();
              return;
            }
            if (DateTime.now().difference(startTime) > dismissAdAfter) {
              _report('ads_interstitial: showing canceled: not ready after ${dismissAdAfter.inSeconds}s');
              then?.call();
              return;
            }
            if (state.adState == AdState.none) {
              // Failed to fetch ad
              then?.call();
              return;
            }
            showAd(onAdShow: onAdShow, then: then);
          },
        );
      }
      return;
    }

    final ad = state.ad;
    if (ad == null) {
      Fimber.e('ad $adUnitId is null but state: ${state.adState}', stacktrace: StackTrace.current);
      _report('ads_interstitial: showing canceled by error');
      then?.call();
      cancelCurrentAd();
      fetchAd();
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (InterstitialAd ad) {
        _report('ads_interstitial: showed full screen content');
        emit(state.copyWith(
          adState: AdState.showing,
        ));
        onAdShow?.call();
        then?.call();
      },
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        _report('ads_interstitial: full screen content dismissed');
        ad.dispose();
        emit(state.copyWith(
          ad: null,
          adState: AdState.none,
          lastShowedTime: DateTime.now(),
        ));
        fetchAd(minWait: const Duration());
        // если перенести then?.call() сюда, возникает краткий показ предыдущего экрана при закрытии интерстишла
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _report('ads_interstitial: showing canceled by error');
        Fimber.e('$error', stacktrace: StackTrace.current);
        ad.dispose();
        emit(state.copyWith(
          ad: null,
          adState: AdState.none,
          lastShowedTime: DateTime.now(),
        ));
        then?.call();
        fetchAd(minWait: const Duration());
      },
      onAdClicked: (ad) {
        _report('ads_interstitial: ad clicked');
      }
    );
    emit(state.copyWith(
      adState: AdState.preShowing,
      lastShowedTime: DateTime.now(),
    ));

    if (_isDisposed) {
      _report('ads_interstitial: showing canceled: manager disposed');
      then?.call();
      return;
    }

    _report('ads_interstitial: start showing');
    await ad.show();
  }

  void updateLastShowedTime() {
    emit(state.copyWith(
      lastShowedTime: DateTime.now(),
    ));
  }
}
