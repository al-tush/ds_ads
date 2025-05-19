part of 'ds_ads_app_open.dart';

/// Root event for all AppOpen ad events. Do not use directly
abstract class DSAdsAppOpenEvent extends DSAdsEvent {
  const DSAdsAppOpenEvent({
    required super.source,
  });
}

/// Generated when AppOpen ad successfully loaded
class DSAdsAppOpenLoadedEvent extends DSAdsAppOpenEvent {
  final DSAppOpenAd ad;

  const DSAdsAppOpenLoadedEvent._({
    required super.source,
    required this.ad,
  });
}

/// Generated when AppOpen ad ready to show (show method was called)
class DSAdsAppOpenPreShowingEvent extends DSAdsAppOpenEvent {
  final DSAppOpenAd ad;

  const DSAdsAppOpenPreShowingEvent._({
    required super.source,
    required this.ad,
  });
}

/// Generated when AppOpen ad showed
class DSAdsAppOpenShowedEvent extends DSAdsAppOpenEvent {
  final DSAppOpenAd ad;

  const DSAdsAppOpenShowedEvent._({
    required super.source,
    required this.ad,
  });
}

/// Generated when AppOpen ad failed to load
class DSAdsAppOpenLoadFailedEvent extends DSAdsAppOpenEvent {
  final int errCode;
  final String errText;

  const DSAdsAppOpenLoadFailedEvent._({
    required super.source,
    required this.errCode,
    required this.errText,
  });
}

/// Error when displaying advertisements
class DSAdsAppOpenShowErrorEvent extends DSAdsAppOpenEvent {
  const DSAdsAppOpenShowErrorEvent._({
    required super.source,
  });
}

/// Generated when AppOpen ad was closed
class DSAdsAppOpenShowDismissedEvent extends DSAdsAppOpenEvent {
  final DSAppOpenAd ad;

  const DSAdsAppOpenShowDismissedEvent._({
    required super.source,
    required this.ad,
  });
}
