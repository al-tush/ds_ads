import 'package:freezed_annotation/freezed_annotation.dart';

import 'ds_ads_types.dart';
import 'generic_ads/export.dart';

part 'ds_ads_interstitial_state.freezed.dart';

@freezed
class DSAdsInterstitialState with _$AdsInterstitialState {
  factory DSAdsInterstitialState({
    required DSInterstitialAd? ad,
    required DSAdState adState,
    required DateTime loadedTime,
    required DateTime lastShowedTime,
    required int loadRetryCount,
  }) = _AdsInterstitialStateData;
}
