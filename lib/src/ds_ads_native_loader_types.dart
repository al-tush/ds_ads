part of 'ds_ads_native_loader_mixin.dart';

abstract class DSAdsNativeEvent extends DSAdsEvent {
  const DSAdsNativeEvent();
}

class DSAdsNativeLoadedEvent extends DSAdsNativeEvent {
  final DSNativeAd ad;

  const DSAdsNativeLoadedEvent._({
    required this.ad,
  });
}

class DSAdsNativeLoadFailed extends DSAdsNativeEvent {
  const DSAdsNativeLoadFailed._();
}
