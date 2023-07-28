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

class DSAdsNativeClickEvent extends DSAdsNativeEvent {
  const DSAdsNativeClickEvent._();
}

class DSAdsNativeOpenedEvent extends DSAdsNativeEvent {
  const DSAdsNativeOpenedEvent._();
}

class DSAdsNativeClosedEvent extends DSAdsNativeEvent {
  const DSAdsNativeClosedEvent._();
}
