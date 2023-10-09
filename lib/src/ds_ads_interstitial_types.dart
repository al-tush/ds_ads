part of 'ds_ads_interstitial.dart';

abstract class DSAdsInterstitialEvent extends DSAdsEvent {
  const DSAdsInterstitialEvent();
}

class DSAdsInterstitialLoadedEvent extends DSAdsInterstitialEvent {
  final DSInterstitialAd ad;

  const DSAdsInterstitialLoadedEvent._({
    required this.ad,
  });
}

class DSAdsInterstitialLoadFailedEvent extends DSAdsInterstitialEvent {
  final int errCode;
  final String errText;

  const DSAdsInterstitialLoadFailedEvent._({
    required this.errCode,
    required this.errText,
  });
}

class DSAdsInterstitialPreShowingEvent extends DSAdsInterstitialEvent {
  final DSInterstitialAd ad;

  const DSAdsInterstitialPreShowingEvent._({
    required this.ad,
  });
}

class DSAdsInterstitialShowedEvent extends DSAdsInterstitialEvent {
  final DSInterstitialAd ad;

  const DSAdsInterstitialShowedEvent._({
    required this.ad,
  });
}

/// Error when displaying advertisements
/// This event allows the next advertisement to be loaded immediately after the event occurs
class DSAdsInterstitialShowErrorEvent extends DSAdsInterstitialEvent {
  const DSAdsInterstitialShowErrorEvent._();
}

class DSAdsInterstitialShowDismissedEvent extends DSAdsInterstitialEvent {
  final DSInterstitialAd ad;

  const DSAdsInterstitialShowDismissedEvent._({
    required this.ad,
  });
}
