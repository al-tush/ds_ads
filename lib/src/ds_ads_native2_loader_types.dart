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

class DSAdsNative2ClickEvent extends DSAdsNativeEvent {
  const DSAdsNative2ClickEvent._();
}

class DSAdsNative2OpenedEvent extends DSAdsNativeEvent {
  const DSAdsNative2OpenedEvent._();
}

class DSAdsNative2ClosedEvent extends DSAdsNativeEvent {
  const DSAdsNative2ClosedEvent._();
}
