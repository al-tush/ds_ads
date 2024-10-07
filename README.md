# ds_ads

Ads components for sect.dev (https://sect.dev/)

Supports interstitial and native ads on Android.

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

NB! You should process exceptions by Fimber. For example:
```
Fimber.plantTree(DebugTree());
```
See details at [Fimber](https://pub.dev/packages/fimber).

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
