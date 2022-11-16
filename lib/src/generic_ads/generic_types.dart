import 'package:google_mobile_ads/google_mobile_ads.dart';

typedef DSOnPaidEventCallback = void Function(
    DSInterstitialAd ad, double valueMicros, PrecisionType precision, String currencyCode);

abstract class DSInterstitialAd {
  Future<void> show();

  Future<void> dispose();

  String get adUnitId;

  set onPaidEvent(DSOnPaidEventCallback? value);

//  set onAdLoaded(void Function(DSInterstitialAd ad) value);
//  set onAdFailedToLoad(void Function(DSInterstitialAd ad, int errCode, String errText) value);
  set onAdDismissed(void Function(DSInterstitialAd ad)? value);
  set onAdFailedToShow(void Function(DSInterstitialAd ad, int errCode, String errText) value);
  set onAdShown(void Function(DSInterstitialAd ad)? value);
  set onAdClicked(void Function(DSInterstitialAd ad)? value);
  set onAdImpression(void Function(DSInterstitialAd ad)? value);
}