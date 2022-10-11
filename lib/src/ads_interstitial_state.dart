import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

part 'ads_interstitial_state.freezed.dart';

enum AdState {
  none,
  loading,
  loaded,
  preShowing,
  showing,
}

@freezed
class AdsInterstitialState with _$AdsInterstitialState {
  factory AdsInterstitialState({
    required InterstitialAd? ad,
    required AdState adState,
    required DateTime loadedTime,
    required DateTime lastShowedTime,
    required int loadRetryCount,
  }) = _AdsInterstitialStateData;
}
