# ds_ads

Ads wrapper components.

Supports interstitial, native and other ads by Google Ads and AppLovin.

## Getting started

Add using it:
### Add `ds_ads` to `pubspec.yaml`
```yaml
dependencies:
  ds_ads: ^1.0.0
```

### Initialize

```dart
    DSAdsManager(
      needConsent: true, // Set to true to enable consent checking before loading ads
      onPaidEvent: (Ad ad, double valueMicros, PrecisionType precision, String currencyCode, String format) async {
        // Process paid event (e.g. send stat)
      },
      appState: // application state (implementation of DSAppAdsState)
      nativeAdBannerStyle: NativeAdBannerStyle.style1,
      onReportEvent: (eventName, attributes) {
        // send stat
      },
      interstitialUnitId: 'ca-app-pub-3940256099942544/7049598008',
      nativeUnitId: 'ca-app-pub-3940256099942544/2247696110',
    );
```

NB! You should process exceptions by Fimber from [ds_common](https://pub.dev/packages/ds_common) library. For example:
```
Fimber.plantTree(DebugTree());
```
See details at root [Fimber](https://pub.dev/packages/fimber) project.

### Handle consent (if needConsent = true)

If you set `needConsent: true` during initialization, you need to request user consent before loading ads.

```dart
// Request and show consent dialog on app start
await DSAdsManager.I.tryShowConsent();

// Option 1: Check consent status manually before loading ads
if (DSAdsManager.I.canRequestAds) {
  DSAdsManager.interstitial.fetchAd(location: myLocation);
}

// Option 2: Subscribe to consent ready event (recommended)
unawaited(() async {
  await for (final event in DSAdsManager.instance.eventStream) {
    if (event is DSAdsConsentReadyEvent && event.canRequestAds) {
      // Consent granted, start loading ads
      DSAdsManager.interstitial.fetchAd(location: const DSAdLocation('internal_after_consent'));
      DSAdsManager.rewarded.fetchAd(location: const DSAdLocation('internal_after_consent'));
      // Load other ad types as needed
    }
  }
}());
```

### Preload ads
```dart
    DSAdsManager.interstitial.fetchAd(then: () async {
      await DSAdsNativeLoaderMixin.fetchAd();
    });
```


### Show interstitial ad
```dart
await AdsManager.interstitial.showAd();
```

### Show native ad
```dart
class SomePageState extends State<SomePage> with DSAdsNativeLoaderMixin {

  @override
  String? get nativeAdLocation => 'some_page'; // Just for stats purposes

  @override
  Widget build(BuildContext context) {
    return ...
      Padding(
        padding: 
        child: nativeAdWidget(),
      ),
      ...
  }
}
```
