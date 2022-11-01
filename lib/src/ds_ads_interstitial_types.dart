part of 'ds_ads_interstitial_cubit.dart';

class DSAdsInterstitialLoadedEvent extends DSAdsEvent {
  final Ad ad;

  const DSAdsInterstitialLoadedEvent._({
    required this.ad,
  });
}

class DSAdsInterstitialLoadFailedEvent extends DSAdsEvent {
  final LoadAdError err;

  const DSAdsInterstitialLoadFailedEvent._({
    required this.err,
  });
}

class DSAdsInterstitialShowedEvent extends DSAdsEvent {
  final Ad ad;

  const DSAdsInterstitialShowedEvent._({
    required this.ad,
  });
}


/// Error when displaying advertisements
/// This event allows the next advertisement to be loaded immediately after the event occurs
class DSAdsInterstitialShowErrorEvent extends DSAdsEvent {
  const DSAdsInterstitialShowErrorEvent._();
}

class DSAdsInterstitialShowDismissedEvent extends DSAdsEvent {
  final Ad ad;

  const DSAdsInterstitialShowDismissedEvent._({
    required this.ad,
  });
}
