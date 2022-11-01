part of 'ds_ads_native_loader_mixin.dart';

typedef NativeAdBuilder = Widget Function(BuildContext context, bool isLoaded, Widget child);

class DSAdsNativeLoadedEvent extends DSAdsEvent {
  final Ad ad;

  const DSAdsNativeLoadedEvent._({
    required this.ad,
  });
}

class DSAdsNativeLoadFailed extends DSAdsEvent {
  const DSAdsNativeLoadFailed._();
}
