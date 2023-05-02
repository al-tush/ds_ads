part of 'ds_ads_app_open.dart';

abstract class DSAdsAppOpenEvent extends DSAdsEvent {
  const DSAdsAppOpenEvent();
}

class DSAdsAppOpenLoadedEvent extends DSAdsAppOpenEvent {
  final DSAppOpenAd ad;

  const DSAdsAppOpenLoadedEvent._({
    required this.ad,
  });
}

class DSAdsAppOpenShowedEvent extends DSAdsAppOpenEvent {
  final DSAppOpenAd ad;

  const DSAdsAppOpenShowedEvent._({
    required this.ad,
  });
}

class DSAdsAppOpenLoadFailedEvent extends DSAdsAppOpenEvent {
  final int errCode;
  final String errText;

  const DSAdsAppOpenLoadFailedEvent._({
    required this.errCode,
    required this.errText,
  });
}
