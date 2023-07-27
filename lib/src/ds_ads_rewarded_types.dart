part of 'ds_ads_rewarded.dart';

abstract class DSAdsRewardedEvent extends DSAdsEvent {
  const DSAdsRewardedEvent();
}

class DSAdsRewardedLoadedEvent extends DSAdsRewardedEvent {
  final DSRewardedAd ad;

  const DSAdsRewardedLoadedEvent._({
    required this.ad,
  });
}

class DSAdsRewardedLoadFailedEvent extends DSAdsRewardedEvent {
  final int errCode;
  final String errText;

  const DSAdsRewardedLoadFailedEvent._({
    required this.errCode,
    required this.errText,
  });
}

class DSAdsRewardedPreShowingEvent extends DSAdsRewardedEvent {
  final DSRewardedAd ad;

  const DSAdsRewardedPreShowingEvent._({
    required this.ad,
  });
}

class DSAdsRewardedShowedEvent extends DSAdsRewardedEvent {
  final DSRewardedAd ad;

  const DSAdsRewardedShowedEvent._({
    required this.ad,
  });
}

/// Error when displaying advertisements
/// This event allows the next advertisement to be loaded immediately after the event occurs
class DSAdsRewardedShowErrorEvent extends DSAdsRewardedEvent {
  const DSAdsRewardedShowErrorEvent._();
}

class DSAdsRewardedShowDismissedEvent extends DSAdsRewardedEvent {
  final DSRewardedAd ad;

  const DSAdsRewardedShowDismissedEvent._({
    required this.ad,
  });
}
