part of 'ds_ads_interstitial.dart';

/// Root event for all Interstitial ad events. Do not use directly
abstract class DSAdsInterstitialEvent extends DSAdsEvent {
  const DSAdsInterstitialEvent({
    required super.source,
  });
}

/// Generated when Interstitial ad successfully loaded
class DSAdsInterstitialLoadedEvent extends DSAdsInterstitialEvent {
  final DSInterstitialAd ad;

  const DSAdsInterstitialLoadedEvent._({
    required super.source,
    required this.ad,
  });
}

/// Generated when Interstitial ad failed to load
class DSAdsInterstitialLoadFailedEvent extends DSAdsInterstitialEvent {
  final int errCode;
  final String errText;

  const DSAdsInterstitialLoadFailedEvent._({
    required super.source,
    required this.errCode,
    required this.errText,
  });
}

/// Generated when Interstitial ad ready to show (show method was called)
class DSAdsInterstitialPreShowingEvent extends DSAdsInterstitialEvent {
  final DSInterstitialAd ad;

  const DSAdsInterstitialPreShowingEvent._({
    required super.source,
    required this.ad,
  });
}

/// Generated when Interstitial ad showed
class DSAdsInterstitialShowedEvent extends DSAdsInterstitialEvent {
  final DSInterstitialAd ad;

  const DSAdsInterstitialShowedEvent._({
    required super.source,
    required this.ad,
  });
}

/// Error when displaying advertisements
/// This event allows the next advertisement to be loaded immediately after the event occurs
class DSAdsInterstitialShowErrorEvent extends DSAdsInterstitialEvent {
  const DSAdsInterstitialShowErrorEvent._({
    required super.source,
  });
}

/// The ad was not displayed due to a timer lock
class DSAdsInterstitialShowLockEvent extends DSAdsInterstitialEvent {
  const DSAdsInterstitialShowLockEvent._({
    required super.source,
  });
}

/// Generated when Interstitial ad was closed
class DSAdsInterstitialShowDismissedEvent extends DSAdsInterstitialEvent {
  final DSInterstitialAd ad;

  const DSAdsInterstitialShowDismissedEvent._({
    required super.source,
    required this.ad,
  });
}
