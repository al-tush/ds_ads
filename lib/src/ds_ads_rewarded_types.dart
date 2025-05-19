part of 'ds_ads_rewarded.dart';

abstract class DSAdsRewardedEvent extends DSAdsEvent {
  const DSAdsRewardedEvent({
    required super.source,
  });
}

class DSAdsRewardedLoadedEvent extends DSAdsRewardedEvent {
  final DSRewardedAd ad;

  const DSAdsRewardedLoadedEvent._({
    required super.source,
    required this.ad,
  });
}

class DSAdsRewardedLoadFailedEvent extends DSAdsRewardedEvent {
  final int errCode;
  final String errText;

  const DSAdsRewardedLoadFailedEvent._({
    required super.source,
    required this.errCode,
    required this.errText,
  });
}

class DSAdsRewardedPreShowingEvent extends DSAdsRewardedEvent {
  final DSRewardedAd ad;

  const DSAdsRewardedPreShowingEvent._({
    required super.source,
    required this.ad,
  });
}

class DSAdsRewardedShowedEvent extends DSAdsRewardedEvent {
  final DSRewardedAd ad;

  const DSAdsRewardedShowedEvent._({
    required super.source,
    required this.ad,
  });
}

/// Error when displaying advertisements
/// This event allows the next advertisement to be loaded immediately after the event occurs
class DSAdsRewardedShowErrorEvent extends DSAdsRewardedEvent {
  const DSAdsRewardedShowErrorEvent._({
    required super.source,
  });
}

/// The ad was not displayed due to a timer lock
class DSAdsRewardedShowLockEvent extends DSAdsRewardedEvent {
  const DSAdsRewardedShowLockEvent._({
    required super.source,
  });
}

class DSAdsRewardedShowDismissedEvent extends DSAdsRewardedEvent {
  final DSRewardedAd ad;

  const DSAdsRewardedShowDismissedEvent._({
    required super.source,
    required this.ad,
  });
}
