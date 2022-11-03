import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ds_ads_types.dart';

part 'ds_ads_interstitial_state.freezed.dart';

@freezed
class DSAdsInterstitialState with _$AdsInterstitialState {
  factory DSAdsInterstitialState({
    required InterstitialAd? ad,
    required DSAdState adState,
    required DateTime loadedTime,
    required DateTime lastShowedTime,
    required int loadRetryCount,
  }) = _AdsInterstitialStateData;
}
