part of 'ds_ads_native_loader_mixin.dart';

/// Root event for all Native ad events. Do not use directly
abstract class DSAdsNativeEvent extends DSAdsEvent {
  const DSAdsNativeEvent();
}

/// Generated when Native ad successfully loaded
class DSAdsNativeLoadedEvent extends DSAdsNativeEvent {
  final DSNativeAd ad;

  const DSAdsNativeLoadedEvent._({
    required this.ad,
  });
}

/// Generated when Native ad failed to load
class DSAdsNativeLoadFailed extends DSAdsNativeEvent {
  const DSAdsNativeLoadFailed._();
}

/// Generated when Native ad clicked
class DSAdsNativeClickEvent extends DSAdsNativeEvent {
  const DSAdsNativeClickEvent._();
}

/// Generated when Native ad show content by click
class DSAdsNativeOpenedEvent extends DSAdsNativeEvent {
  const DSAdsNativeOpenedEvent._();
}

/// Generated when Native ad was closed
class DSAdsNativeClosedEvent extends DSAdsNativeEvent {
  const DSAdsNativeClosedEvent._();
}
