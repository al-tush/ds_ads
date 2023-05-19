import 'package:ds_ads/src/generic_ads/export.dart';
import 'package:fimber/fimber.dart';
import 'package:flutter/cupertino.dart';
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
              if (ad != _ad) Fimber.e('ds_ads: assert error', stacktrace: StackTrace.current);
              onAdImpression?.call(this);
            },
            onAdShowedFullScreenContent: (ad) {
              if (ad != _ad) Fimber.e('ds_ads: assert error', stacktrace: StackTrace.current);
              onAdShown?.call(this);
            },
            onAdDismissedFullScreenContent: (RewardedAd ad) {
              if (ad != _ad) Fimber.e('ds_ads: assert error', stacktrace: StackTrace.current);
              onAdDismissed?.call(this);
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              if (ad != _ad) Fimber.e('ds_ads: assert error', stacktrace: StackTrace.current);
              onAdFailedToShow?.call(this, error.code, error.message);
            },
            onAdClicked: (ad) {
              if (ad != _ad) Fimber.e('ds_ads: assert error', stacktrace: StackTrace.current);
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
          if (ad != _ad) Fimber.e('ds_ads: assert error', stacktrace: StackTrace.current);
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

class DSGoogleNativeAd extends DSNativeAd {
  NativeAd? _ad;
  var _isLoaded = false;

  final void Function(DSNativeAd ad)? onAdOpened;
  final void Function(DSNativeAd ad)? onAdClosed;
  final void Function(DSNativeAd ad)? onAdImpression;

  DSGoogleNativeAd({
    required super.adUnitId,
    required super.factoryId,
    required super.onPaidEvent,
    super.onAdLoaded,
    super.onAdFailedToLoad,
    super.onAdClicked,
    this.onAdOpened,
    this.onAdClosed,
    this.onAdImpression,
  }) {
    _ad = NativeAd(
      adUnitId: adUnitId,
      factoryId: factoryId,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          _isLoaded = true;
          onAdLoaded?.call(this);
        },
        onAdFailedToLoad: (ad, error) {
          onAdFailedToLoad?.call(this, error.code, error.message);
        },
        onAdOpened: (ad) {
          onAdOpened?.call(this);
        },
        onAdClosed: (ad) {
          onAdClosed?.call(this);
        },
        onAdClicked: (ad) {
          onAdClicked?.call(this);
        },
        onAdImpression: (ad) {
          onAdImpression?.call(this);
        },
        onPaidEvent: (Ad ad, double valueMicros, PrecisionType precision, String currencyCode) {
          onPaidEvent(this, valueMicros, precision, currencyCode);
        },
      ),
      request: const AdRequest(),
    );
  }

  @override
  String get mediationAdapterClassName => '${_ad?.responseInfo?.mediationAdapterClassName}';

  @override
  bool get isLoaded => _isLoaded;

  @override
  Future<void> load() {
    return _ad!.load();
  }

  @override
  Future<void> dispose() async {
    await _ad?.dispose();
  }

}

class DSGoogleAdWidget extends StatelessWidget {
  final DSGoogleNativeAd ad;

  const DSGoogleAdWidget({
    super.key,
    required this.ad,
  });

  @override
  Widget build(BuildContext context) {
    return AdWidget(ad: ad._ad!);
  }

}

class DSGoogleAppOpenAd extends DSAppOpenAd
{
  AppOpenAd? _ad;

  DSGoogleAppOpenAd({
    required super.adUnitId,
  });

  Future<void> load({
    required int orientation,
    required void Function(DSGoogleAppOpenAd ad) onAdLoaded,
    required DSOnAdFailedToLoad onAdFailedToLoad,
  }) async {
    await AppOpenAd.load(
      adUnitId: adUnitId,
      orientation: orientation,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
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
            onAdDismissedFullScreenContent: (AppOpenAd ad) {
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
  void Function(DSAppOpenAd ad)? onAdDismissed;
  @override
  void Function(DSAppOpenAd ad, int errCode, String errText)? onAdFailedToShow;
  @override
  void Function(DSAppOpenAd ad)? onAdShown;
  @override
  void Function(DSAppOpenAd ad)? onAdClicked;
  @override
  void Function(DSAppOpenAd ad)? onAdImpression;

  @override
  String get mediationAdapterClassName => '${_ad!.responseInfo?.mediationAdapterClassName}';

}
