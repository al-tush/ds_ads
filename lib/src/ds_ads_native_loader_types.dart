part of 'ds_ads_native_loader_mixin.dart';

typedef NativeAdBuilder = Widget Function(BuildContext context, bool isLoaded, Widget child);

abstract class DSAdsNativeEvent extends DSAdsEvent {
  const DSAdsNativeEvent();
}

class DSAdsNativeLoadedEvent extends DSAdsNativeEvent {
  final Ad ad;

  const DSAdsNativeLoadedEvent._({
    required this.ad,
  });
}

class DSAdsNativeLoadFailed extends DSAdsNativeEvent {
  const DSAdsNativeLoadFailed._();
}
