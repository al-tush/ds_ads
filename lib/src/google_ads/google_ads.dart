import 'package:ds_ads/src/generic_ads/export.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class DSGoogleInterstitialAd extends DSInterstitialAd {
  InterstitialAd? _ad;

  DSGoogleInterstitialAd({
    required super.adUnitId,
  });

  Future<void> load({
    required void Function(DSInterstitialAd ad) onAdLoaded,
    required DSOnAdFailedToLoad onAdFailedToLoad,
  }) async {
    await InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) async {
            _ad = ad;
            ad.onPaidEvent = (Ad ad, double valueMicros, PrecisionType precision, String currencyCode) {
              assert(_ad == ad);
              onPaidEvent?.call(this, valueMicros, precision, currencyCode, null);
            };
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdImpression: (ad) {
                assert(_ad == ad);
                onAdImpression?.call(this);
              },
              onAdShowedFullScreenContent: (ad) {
                assert(_ad == ad);
                onAdShown?.call(this);
              },
              onAdDismissedFullScreenContent: (InterstitialAd ad) {
                assert(_ad == ad);
                onAdDismissed?.call(this);
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                assert(_ad == ad);
                onAdFailedToShow?.call(this, error.code, error.message);
              },
              onAdClicked: (ad) {
                assert(_ad == ad);
                onAdClicked?.call(this);
              },
            );
            onAdLoaded(this);
          },
          onAdFailedToLoad: (LoadAdError error) {
            onAdFailedToLoad(this, error.code, error.message);
          },
        ),
    );
  }

  @override
  Future<void> show() async {
    await _ad!.show();
  }

  @override
  Future<void> dispose() async {
    await _ad?.dispose();
    _ad = null;
  }

  @override
  DSOnPaidEventCallback? onPaidEvent;
  @override
  void Function(DSInterstitialAd ad)? onAdDismissed;
  @override
  void Function(DSInterstitialAd ad, int errCode, String errText)? onAdFailedToShow;
  @override
  void Function(DSInterstitialAd ad)? onAdShown;
  @override
  void Function(DSInterstitialAd ad)? onAdClicked;
  @override
  void Function(DSInterstitialAd ad)? onAdImpression;

  @override
  String get mediationAdapterClassName => '${_ad!.responseInfo?.mediationAdapterClassName}';

}

class DSGoogleRewardedAd extends DSRewardedAd {
  RewardedAd? _ad;

  DSGoogleRewardedAd({
    required super.adUnitId,
  });

  Future<void> load({
    required void Function(DSRewardedAd ad) onAdLoaded,
    required DSOnAdFailedToLoad onAdFailedToLoad,
  }) async {
    await RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) async {
          _ad = ad;
          ad.onPaidEvent = (Ad ad, double valueMicros, PrecisionType precision, String currencyCode) {
            assert(_ad == ad);
            onPaidEvent?.call(this, valueMicros, precision, currencyCode, null);
          };
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdImpression: (ad) {
              assert(_ad == ad);
              onAdImpression?.call(this);
            },
            onAdShowedFullScreenContent: (ad) {
              assert(_ad == ad);
              onAdShown?.call(this);
            },
            onAdDismissedFullScreenContent: (RewardedAd ad) {
              assert(_ad == ad);
              onAdDismissed?.call(this);
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              assert(_ad == ad);
              onAdFailedToShow?.call(this, error.code, error.message);
            },
            onAdClicked: (ad) {
              assert(_ad == ad);
              onAdClicked?.call(this);
            },
          );
          onAdLoaded(this);
        },
        onAdFailedToLoad: (LoadAdError error) {
          onAdFailedToLoad(this, error.code, error.message);
        },
      ),
    );
  }

  @override
  Future<void> show() async {
    await _ad!.setImmersiveMode(true);
    await _ad!.show(
        onUserEarnedReward: (ad, reward) {
          assert(ad == _ad);
          onRewardEvent?.call(this, reward.amount, reward.type);
        }
    );
  }

  @override
  Future<void> dispose() async {
    await _ad?.dispose();
    _ad = null;
  }

  @override
  DSOnPaidEventCallback? onPaidEvent;
  @override
  DSOnRewardEventCallback? onRewardEvent;
  @override
  void Function(DSRewardedAd ad)? onAdDismissed;
  @override
  void Function(DSRewardedAd ad, int errCode, String errText)? onAdFailedToShow;
  @override
  void Function(DSRewardedAd ad)? onAdShown;
  @override
  void Function(DSRewardedAd ad)? onAdClicked;
  @override
  void Function(DSRewardedAd ad)? onAdImpression;

  @override
  String get mediationAdapterClassName => '${_ad!.responseInfo?.mediationAdapterClassName}';

}

// ToDo: replace wrapper to full implementation
class DSNativeAd extends DSAd {
  final NativeAd ad;

  DSNativeAd({
    required this.ad,
  }) : super(adUnitId: ad.adUnitId);

  @override
  String get mediationAdapterClassName => '${ad.responseInfo?.mediationAdapterClassName}';

}