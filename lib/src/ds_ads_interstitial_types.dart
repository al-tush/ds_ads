part of 'ds_ads_interstitial_cubit.dart';

abstract class DSAdsInterstitialEvent extends DSAdsEvent {
  const DSAdsInterstitialEvent();
}

class DSAdsInterstitialLoadedEvent extends DSAdsInterstitialEvent {
  final Ad ad;

  const DSAdsInterstitialLoadedEvent._({
    required this.ad,
  });
}

class DSAdsInterstitialLoadFailedEvent extends DSAdsInterstitialEvent {
  final LoadAdError err;

  const DSAdsInterstitialLoadFailedEvent._({
    required this.err,
  });
}

class DSAdsInterstitialShowedEvent extends DSAdsInterstitialEvent {
  final Ad ad;

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
  final Ad ad;

  const DSAdsInterstitialShowDismissedEvent._({
    required this.ad,
  });
}
