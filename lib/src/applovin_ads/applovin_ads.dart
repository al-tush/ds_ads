import 'package:applovin_max/applovin_max.dart';
import 'package:ds_ads/src/generic_ads/export.dart';
import 'package:fimber/fimber.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class DSAppLovinInterstitialAd extends DSInterstitialAd {
  MaxAd? _ad;

  DSAppLovinInterstitialAd({
    required super.adUnitId,
  });

  Future<void> load({
    required void Function(DSInterstitialAd ad) onAdLoaded,
    required DSOnAdFailedToLoad onAdFailedToLoad,
  }) async {
    AppLovinMAX.setInterstitialListener(InterstitialListener(
      onAdLoadedCallback: (ad) {
        _ad = ad;
        onAdLoaded(this);
      },
      onAdLoadFailedCallback: (adUnitId, error) {
        onAdFailedToLoad(this, error.code, error.message);
      },
      onAdDisplayedCallback: (ad) {
        onAdShown?.call(this);
      },
      onAdRevenuePaidCallback: (ad) {
        onAdImpression?.call(this);
        // https://dash.applovin.com/documentation/mediation/android/getting-started/advanced-settings#impression-level-user-revenue-api
        if (ad.revenue < 0) {
          Fimber.w('AppLovin revenue error');
          return;
        }
        onPaidEvent?.call(this, ad.revenue * 1000000, PrecisionType.unknown, 'USD',  ad.dspName);
      },
      onAdDisplayFailedCallback: (ad, error) {
        onAdFailedToShow?.call(this, error.code, error.message);
      },
      onAdClickedCallback: (ad) {
        onAdClicked?.call(this);
      },
      onAdHiddenCallback: (ad) {
        onAdDismissed?.call(this);
      },
    ));

    AppLovinMAX.loadInterstitial(adUnitId);
  }

  @override
  Future<void> show() async {
    final isReady = await AppLovinMAX.isInterstitialReady(adUnitId);
    if (isReady != true) {
      Fimber.e('AppLovin interstitial not ready: $adUnitId');
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
  void Function(DSInterstitialAd ad, int errCode, String errText)? onAdFailedToShow;
  @override
  void Function(DSInterstitialAd ad)? onAdShown;
  @override
  void Function(DSInterstitialAd ad)? onAdClicked;
  @override
  void Function(DSInterstitialAd ad)? onAdImpression;

  @override
  String get mediationAdapterClassName => _ad!.networkName;

}

class DSAppLovinRewardedAd extends DSRewardedAd {
  MaxAd? _ad;

  DSAppLovinRewardedAd({
    required super.adUnitId,
  });

  Future<void> load({
    required void Function(DSRewardedAd ad) onAdLoaded,
    required DSOnAdFailedToLoad onAdFailedToLoad,
  }) async {
    AppLovinMAX.setRewardedAdListener(RewardedAdListener(
      onAdLoadedCallback: (ad) {
        _ad = ad;
        onAdLoaded(this);
      },
      onAdLoadFailedCallback: (adUnitId, error) {
        onAdFailedToLoad(this, error.code, error.message);
      },
      onAdDisplayedCallback: (ad) {
        onAdShown?.call(this);
      },
      onAdRevenuePaidCallback: (ad) {
        onAdImpression?.call(this);
        onPaidEvent?.call(this, ad.revenue * 1000000, PrecisionType.unknown, 'USD',  ad.dspName);
      },
      onAdDisplayFailedCallback: (ad, error) {
        onAdFailedToShow?.call(this, error.code, error.message);
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

    AppLovinMAX.loadRewardedAd(adUnitId);
  }

  @override
  Future<void> show() async {
    final isReady = await AppLovinMAX.isRewardedAdReady(adUnitId);
    if (isReady != true) {
      Fimber.e('AppLovin rewarded not ready: $adUnitId');
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
