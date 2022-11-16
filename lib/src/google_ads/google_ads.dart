import 'package:ds_ads/src/generic_ads/export.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class DSGoogleInterstitialAd extends DSInterstitialAd {
  final InterstitialAd _ad;

  DSGoogleInterstitialAd(this._ad) {
    _ad.onPaidEvent = (Ad ad, double valueMicros, PrecisionType precision, String currencyCode) {
      assert(_ad == ad);
      onPaidEvent?.call(this, valueMicros, precision, currencyCode);
    };
    _ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdImpression: (ad) {
          assert(_ad == ad);
          onAdImpression?.call(this);
        },
        onAdShowedFullScreenContent: (ad) {
          assert(_ad == ad);
          onAdShown?.call(this);
        },
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          assert(_ad == ad);
          onAdDismissed?.call(this);
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          assert(_ad == ad);
          onAdFailedToShow?.call(this, error.code, error.message);
        },
        onAdClicked: (ad) {
          assert(_ad == ad);
          onAdClicked?.call(this);
        }
    );

  }

  @override
  String get adUnitId => _ad.adUnitId;

  @override
  Future<void> show() async {
    await _ad.show();
  }

  @override
  Future<void> dispose() async {
    await _ad.dispose();
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

}