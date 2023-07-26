part of 'ds_ads_native2_loader_mixin.dart';

abstract class DSAdsNative2Event extends DSAdsEvent {
  const DSAdsNative2Event();
}

class DSAdsNative2LoadedEvent extends DSAdsNative2Event {
  final DSNativeAd ad;

  const DSAdsNative2LoadedEvent._({
    required this.ad,
  });
}

class DSAdsNative2LoadFailed extends DSAdsNative2Event {
  const DSAdsNative2LoadFailed._();
}
