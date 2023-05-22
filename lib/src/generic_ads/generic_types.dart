import 'package:google_mobile_ads/google_mobile_ads.dart';

typedef DSOnPaidEventCallback = void Function(
    DSAd ad, double valueMicros, PrecisionType precision, String currencyCode, String? appLovinDspName);
typedef DSOnAdFailedToLoad = void Function(DSAd ad, int errCode, String errDescription);
typedef DSOnRewardEventCallback = void Function(DSAd ad, num amount, String type);

typedef DSPrecisionType = PrecisionType;

abstract class DSAd {
  final String adUnitId;

  String get mediationAdapterClassName;

  const DSAd({
    required this.adUnitId,
  });
}

abstract class DSInterstitialAd extends DSAd {
  const DSInterstitialAd({
    required super.adUnitId,
  });

  Future<void> show();

  Future<void> dispose();

  set onPaidEvent(DSOnPaidEventCallback? value);

//  set onAdLoaded(void Function(DSInterstitialAd ad) value);
//  set onAdFailedToLoad(void Function(DSInterstitialAd ad, int errCode, String errText) value);
  set onAdDismissed(void Function(DSInterstitialAd ad)? value);
  set onAdFailedToShow(void Function(DSInterstitialAd ad, int errCode, String errText) value);
  set onAdShown(void Function(DSInterstitialAd ad)? value);
  set onAdClicked(void Function(DSInterstitialAd ad)? value);
  set onAdImpression(void Function(DSInterstitialAd ad)? value);
}

abstract class DSNativeAd  extends DSAd {
  final String factoryId;
  final created = DateTime.now();

  final void Function(DSNativeAd ad)? onAdLoaded;
  final void Function(DSNativeAd ad, int errCode, String errDescription)? onAdFailedToLoad;
  final void Function(DSNativeAd ad)? onAdClicked;
  final void Function(DSNativeAd ad, double valueMicros, DSPrecisionType precision, String currencyCode) onPaidEvent;

  DSNativeAd({
    required super.adUnitId,
    required this.factoryId,
    required this.onPaidEvent,
    this.onAdLoaded,
    this.onAdFailedToLoad,
    this.onAdClicked,
  });

  bool get isLoaded;

  Future<void> load();

  Future<void> dispose();
}

abstract class DSRewardedAd extends DSAd {
  const DSRewardedAd({
    required super.adUnitId,
  });

  Future<void> show();

  Future<void> dispose();

  set onPaidEvent(DSOnPaidEventCallback? value);
  set onRewardEvent(DSOnRewardEventCallback? value);

//  set onAdLoaded(void Function(DSRewardedAd ad) value);
//  set onAdFailedToLoad(void Function(DSRewardedAd ad, int errCode, String errText) value);
  set onAdDismissed(void Function(DSRewardedAd ad)? value);
  set onAdFailedToShow(void Function(DSRewardedAd ad, int errCode, String errText) value);
  set onAdShown(void Function(DSRewardedAd ad)? value);
  set onAdClicked(void Function(DSRewardedAd ad)? value);
  set onAdImpression(void Function(DSRewardedAd ad)? value);
}

abstract class DSAppOpenAd extends DSAd {
  const DSAppOpenAd({
    required super.adUnitId,
  });

  Future<void> show();

  Future<void> dispose();

  set onPaidEvent(DSOnPaidEventCallback? value);

//  set onAdLoaded(void Function(DSAppOpenAd ad) value);
//  set onAdFailedToLoad(void Function(DSAppOpenAd ad, int errCode, String errText) value);
  set onAdDismissed(void Function(DSAppOpenAd ad)? value);
  set onAdFailedToShow(void Function(DSAppOpenAd ad, int errCode, String errText) value);
  set onAdShown(void Function(DSAppOpenAd ad)? value);
  set onAdClicked(void Function(DSAppOpenAd ad)? value);
  set onAdImpression(void Function(DSAppOpenAd ad)? value);
}