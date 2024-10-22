import 'package:applovin_max/applovin_max.dart';
import 'package:ds_ads/ds_ads.dart';
import 'package:fimber/fimber.dart';

class DSAppLovinInterstitialAd extends DSInterstitialAd {
  MaxAd? _ad;

  @override
  DSAdMediation get mediation => DSAdMediation.appLovin;

  DSAppLovinInterstitialAd({
    required super.adUnitId,
  });

  Future<void> load({
    required void Function(DSInterstitialAd ad) onAdLoaded,
    required DSOnAdFailedToLoad onAdFailedToLoad,
  }) async {
    if (!DSAdsManager.I.isMediationInitialized(DSAdMediation.appLovin)) {
      Fimber.e('AppLovin was not initialized', stacktrace: StackTrace.current);
    }
    AppLovinMAX.setInterstitialListener(InterstitialListener(
      onAdLoadedCallback: (ad) {
        _ad = ad;
        setLoaded();
        onAdLoaded(this);
      },
      onAdLoadFailedCallback: (adUnitId, error) {
        setLoadFailed();
        onAdFailedToLoad(this, error.code.value, error.message);
      },
      onAdDisplayedCallback: (ad) {
        onAdShown?.call(this);
      },
      onAdRevenuePaidCallback: (ad) {
        onAdImpression?.call(this);
        // https://dash.applovin.com/documentation/mediation/android/getting-started/advanced-settings#impression-level-user-revenue-api
        if (ad.revenue < 0) {
          Fimber.w('AppLovin revenue error', stacktrace: StackTrace.current);
          return;
        }
        onPaidEvent?.call(this, ad.revenue * 1000000, DSPrecisionType.unknown,
            'USD', ad.dspName);
      },
      onAdDisplayFailedCallback: (ad, error) {
        onAdFailedToShow?.call(this, error.code.value, error.message);
      },
      onAdClickedCallback: (ad) {
        onAdClicked?.call(this);
      },
      onAdHiddenCallback: (ad) {
        onAdDismissed?.call(this);
      },
    ));

    startLoading();
    AppLovinMAX.loadInterstitial(adUnitId);
  }

  @override
  Future<void> show() async {
    final isReady = await AppLovinMAX.isInterstitialReady(adUnitId);
    if (isReady != true) {
      Fimber.e('AppLovin interstitial not ready: $adUnitId',
          stacktrace: StackTrace.current);
      return;
    }
    AppLovinMAX.showInterstitial(adUnitId);
  }

  @override
  Future<void> dispose() async {
    _ad = null;
  }

  @override
  DSOnPaidEventCallback? onPaidEvent;
  @override
  void Function(DSInterstitialAd ad)? onAdDismissed;
  @override
  void Function(DSInterstitialAd ad, int errCode, String errText)?
      onAdFailedToShow;
  @override
  void Function(DSInterstitialAd ad)? onAdShown;
  @override
  void Function(DSInterstitialAd ad)? onAdClicked;
  @override
  void Function(DSInterstitialAd ad)? onAdImpression;

  @override
  String get mediationAdapterClassName => '${_ad?.networkName}';
}

class DSAppLovinRewardedAd extends DSRewardedAd {
  MaxAd? _ad;

  @override
  DSAdMediation get mediation => DSAdMediation.appLovin;

  DSAppLovinRewardedAd({
    required super.adUnitId,
  });

  Future<void> load({
    required void Function(DSRewardedAd ad) onAdLoaded,
    required DSOnAdFailedToLoad onAdFailedToLoad,
  }) async {
    if (!DSAdsManager.I.isMediationInitialized(DSAdMediation.appLovin)) {
      Fimber.e('AppLovin was not initialized', stacktrace: StackTrace.current);
    }
    AppLovinMAX.setRewardedAdListener(RewardedAdListener(
      onAdLoadedCallback: (ad) {
        _ad = ad;
        setLoaded();
        onAdLoaded(this);
      },
      onAdLoadFailedCallback: (adUnitId, error) {
        setLoadFailed();
        onAdFailedToLoad(this, error.code.value, error.message);
      },
      onAdDisplayedCallback: (ad) {
        onAdShown?.call(this);
      },
      onAdRevenuePaidCallback: (ad) {
        onAdImpression?.call(this);
        onPaidEvent?.call(this, ad.revenue * 1000000, DSPrecisionType.unknown,
            'USD', ad.dspName);
      },
      onAdDisplayFailedCallback: (ad, error) {
        onAdFailedToShow?.call(this, error.code.value, error.message);
      },
      onAdClickedCallback: (ad) {
        onAdClicked?.call(this);
      },
      onAdHiddenCallback: (ad) {
        onAdDismissed?.call(this);
      },
      onAdReceivedRewardCallback: (MaxAd ad, MaxReward reward) {
        onRewardEvent?.call(this, reward.amount, reward.label);
      },
    ));
    startLoading();
    AppLovinMAX.loadRewardedAd(adUnitId);
  }

  @override
  Future<void> show() async {
    final isReady = await AppLovinMAX.isRewardedAdReady(adUnitId);
    if (isReady != true) {
      Fimber.e('AppLovin rewarded not ready: $adUnitId',
          stacktrace: StackTrace.current);
      return;
    }
    AppLovinMAX.showRewardedAd(adUnitId);
  }

  @override
  Future<void> dispose() async {
    _ad = null;
  }

  @override
  DSOnPaidEventCallback? onPaidEvent;
  @override
  DSOnRewardEventCallback? onRewardEvent;
  @override
  void Function(DSRewardedAd ad)? onAdDismissed;
  @override
  void Function(DSRewardedAd ad, int errCode, String errText)? onAdFailedToShow;
  @override
  void Function(DSRewardedAd ad)? onAdShown;
  @override
  void Function(DSRewardedAd ad)? onAdClicked;
  @override
  void Function(DSRewardedAd ad)? onAdImpression;

  @override
  String get mediationAdapterClassName => _ad!.networkName;
}

class DSAppLovinAppOpenAd extends DSAppOpenAd {
  MaxAd? _ad;

  @override
  DSAdMediation get mediation => DSAdMediation.appLovin;

  DSAppLovinAppOpenAd({
    required super.adUnitId,
  });

  Future<void> load({
    required void Function(DSAppOpenAd ad) onAdLoaded,
    required DSOnAdFailedToLoad onAdFailedToLoad,
  }) async {
    if (!DSAdsManager.I.isMediationInitialized(DSAdMediation.appLovin)) {
      Fimber.e('AppLovin was not initialized', stacktrace: StackTrace.current);
    }
    AppLovinMAX.setAppOpenAdListener(AppOpenAdListener(
      onAdLoadedCallback: (ad) {
        _ad = ad;
        setLoaded();
        onAdLoaded(this);
      },
      onAdLoadFailedCallback: (adUnitId, error) {
        setLoadFailed();
        onAdFailedToLoad(this, error.code.value, error.message);
      },
      onAdDisplayedCallback: (ad) {
        onAdShown?.call(this);
      },
      onAdDisplayFailedCallback: (ad, error) {
        onAdFailedToShow?.call(this, error.code.value, error.message);
      },
      onAdClickedCallback: (ad) {
        onAdClicked?.call(this);
      },
      onAdHiddenCallback: (ad) {
        onAdDismissed?.call(this);
      },
      onAdRevenuePaidCallback: (ad) {
        onAdImpression?.call(this);
        // https://dash.applovin.com/documentation/mediation/android/getting-started/advanced-settings#impression-level-user-revenue-api
        if (ad.revenue < 0) {
          Fimber.w('AppLovin revenue error', stacktrace: StackTrace.current);
          return;
        }
        onPaidEvent?.call(this, ad.revenue * 1000000, DSPrecisionType.unknown,
            'USD', ad.dspName);
      },
    ));
    startLoading();
    AppLovinMAX.loadAppOpenAd(adUnitId);
  }

  @override
  Future<void> show() async {
    final isReady = await AppLovinMAX.isAppOpenAdReady(adUnitId);
    if (isReady != true) {
      Fimber.e('AppLovin app open not ready: $adUnitId',
          stacktrace: StackTrace.current);
      return;
    }
    AppLovinMAX.showAppOpenAd(adUnitId);
  }

  @override
  Future<void> dispose() async {
    _ad = null;
  }

  @override
  DSOnPaidEventCallback? onPaidEvent;
  @override
  void Function(DSAppOpenAd ad)? onAdDismissed;
  @override
  void Function(DSAppOpenAd ad, int errCode, String errText)? onAdFailedToShow;
  @override
  void Function(DSAppOpenAd ad)? onAdShown;
  @override
  void Function(DSAppOpenAd ad)? onAdClicked;
  @override
  void Function(DSAppOpenAd ad)? onAdImpression;

  @override
  String get mediationAdapterClassName => _ad!.networkName;
}
