import 'package:ds_ads/src/generic_ads/export.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'yandex_ads.dart';

enum YandexAdState {
  none,
  loading,
  loaded,
  showing,
}

class YandexInterstitialAd extends DSInterstitialAd {
  final int id;
  var _state = YandexAdState.none;
  YandexAdState get state => _state;

  YandexInterstitialAd({
    required this.id,
    required super.adUnitId,
  }) : assert(adUnitId.startsWith('R-M-'));

  @internal
  void setState(YandexAdState value) {
    _state = value;
  }

  @override
  DSOnPaidEventCallback? onPaidEvent; // ToDo: implement
  @override
  void Function(DSInterstitialAd ad)? onAdDismissed;
  @override
  set onAdFailedToShow(void Function(DSInterstitialAd ad, int errCode, String errText) value) {
    // never calls
  }
  @override
  void Function(DSInterstitialAd ad)? onAdShown;
  @override
  void Function(DSInterstitialAd ad)? onAdClicked;
  @override
  void Function(DSInterstitialAd ad)? onAdImpression;

  @override
  Future<void> show() async {
    await YandexAds.instance.showInterstitial(ad: this);
  }

  @override
  Future<void> dispose() async {
    // do nothing
  }

  @override
  String get mediationAdapterClassName => ''; // ToDo: implement
}

@internal
class AdInterstitialInfo {
  final YandexInterstitialAd ad;

  YandexAdState get state => ad.state;

  void Function(YandexInterstitialAd ad) onAdLoaded;
  OnAdFailedToLoad onAdFailedToLoad;
  void Function(YandexInterstitialAd ad)? onAdDismissed;

  AdInterstitialInfo({
    required this.ad,
    required this.onAdLoaded,
    required this.onAdFailedToLoad,
  });

}
