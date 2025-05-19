part of 'ds_ads_native_loader_mixin.dart';

/// Root event for all Native ad events. Do not use directly
abstract class DSAdsNativeEvent extends DSAdsEvent {
  const DSAdsNativeEvent({
    required super.source,
  });
}

/// Generated when Native ad successfully loaded
class DSAdsNativeLoadedEvent extends DSAdsNativeEvent {
  final DSNativeAd ad;

  const DSAdsNativeLoadedEvent._({
    required super.source,
    required this.ad,
  });
}

/// Generated when Native ad failed to load
class DSAdsNativeLoadFailed extends DSAdsNativeEvent {
  const DSAdsNativeLoadFailed._({
    required super.source,
  });
}

/// Generated when Native ad clicked
class DSAdsNativeClickEvent extends DSAdsNativeEvent {
  const DSAdsNativeClickEvent._({
    required super.source,
  });
}

/// Generated when Native ad show content by click
class DSAdsNativeOpenedEvent extends DSAdsNativeEvent {
  const DSAdsNativeOpenedEvent._({
    required super.source,
  });
}

/// Generated when Native ad was closed
class DSAdsNativeClosedEvent extends DSAdsNativeEvent {
  const DSAdsNativeClosedEvent._({
    required super.source,
  });
}
