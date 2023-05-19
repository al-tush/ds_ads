import 'package:ds_ads/src/ds_ads_manager.dart';
import 'package:ds_ads/src/generic_ads/export.dart';
import 'package:fimber/fimber.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class DSAppLovinNativeAd  extends DSNativeAd {
  var _isLoaded = false;

  final void Function(DSNativeAd ad)? onAdExpired;

  DSAppLovinNativeAd({
    required super.adUnitId,
    required super.factoryId,
    required super.onPaidEvent,
    super.onAdLoaded,
    super.onAdFailedToLoad,
    super.onAdClicked,
    this.onAdExpired,
  });

  @override
  // TODO: implement mediationAdapterClassName
  String get mediationAdapterClassName => '';


  @override
  bool get isLoaded => _isLoaded;

  @override
  Future<void> load() {
    return ALInstanceManager.instance.loadNativeAd(this);
  }

  @override
  Future<void> dispose() {
    return ALInstanceManager.instance.disposeAd(this);
  }
}

/// Maintains access to loaded [Ad] instances and handles sending/receiving
/// messages to platform code.
class ALInstanceManager {

  static final instance = ALInstanceManager(
    'pro.altush.ds_ads/app_lovin_ads',
  );

  ALInstanceManager(String channelName)
      : channel = MethodChannel(
    channelName,
    const StandardMethodCodec(),
  ) {
    channel.setMethodCallHandler((MethodCall call) async {
      final int adId = call.arguments['adId'];

      final ad = adFor(adId);
      if (ad != null) {
        _onAdEvent(ad, call.method, call.arguments);
      } else {
        Fimber.e('ALNativeAd with id `$adId` is not available for ${call.method}.');
      }
    });
  }

  int _nextAdId = 1;
  final _loadedAds = <int, DSAppLovinNativeAd>{};

  /// Invokes load and dispose calls.
  final MethodChannel channel;

  void _onAdEvent(DSAppLovinNativeAd ad, String eventName, Map<dynamic, dynamic> arguments) {
    switch (eventName) {
      case 'onAdLoaded':
        ad._isLoaded = true;
        ad.onAdLoaded?.call(ad);
        break;
      case 'onAdFailedToLoad':
        final code = arguments['error_code'];
        final message = arguments['error_message'];
        ad.onAdFailedToLoad?.call(ad, code, message);
        break;
      case 'onPaidEvent':
        final value = arguments['revenue'] as double;
        final precision = arguments['precision'] as String;
        final DSPrecisionType pType;
        switch (precision) {
          case 'publisher_defined':
            pType = DSPrecisionType.publisherProvided;
            break;
          case 'exact':
            pType = DSPrecisionType.precise;
            break;
          case 'estimated':
            pType = DSPrecisionType.estimated;
            break;
          case 'undefined':
            pType = DSPrecisionType.unknown;
            break;
          default:
            pType = PrecisionType.unknown;
            DSAdsManager.instance.onReportEvent?.call('AppLovin (ds_ads) unknown prcision type: $precision', {});
            break;
        }
        ad.onPaidEvent(ad, value * 1000000, pType, 'USD');
        break;
      case 'onAdClicked':
        ad.onAdClicked?.call(ad);
        break;
      case 'onAdExpired':
        ad.onAdExpired?.call(ad);
        break;
      default:
        Fimber.e('invalid ad event name: $eventName', stacktrace: StackTrace.current);
    }
  }

  DSAppLovinNativeAd? adFor(int adId) => _loadedAds[adId];

  int? adIdFor(DSAd ad) {
    int? res;
    _loadedAds.forEach((key, value) {
      if (value == ad) res = key;
    });
    return res;
  }

    final Set<int> _mountedWidgetAdIds = <int>{};

    /// Returns true if the [adId] is already mounted in a [WidgetAd].
    bool isWidgetAdIdMounted(int adId) => _mountedWidgetAdIds.contains(adId);

    /// Indicates that [adId] is mounted in widget tree.
    void mountWidgetAdId(int adId) => _mountedWidgetAdIds.add(adId);

    /// Indicates that [adId] is unmounted from the widget tree.
    void unmountWidgetAdId(int adId) => _mountedWidgetAdIds.remove(adId);

    /// Starts loading the ad if not previously loaded.
    ///
    /// Loading also terminates if ad is already in the process of loading.
    Future<void> loadNativeAd(DSAppLovinNativeAd ad) {
      if (adIdFor(ad) != null) {
        return Future<void>.value();
      }

      final int adId = _nextAdId++;
      _loadedAds[adId] = ad;
      return channel.invokeMethod('loadNativeAd', {
        'adId': adId,
        'adUnitId': ad.adUnitId,
        'factoryId': ad.factoryId,
      });
    }

    /// Free the plugin resources associated with this ad.
    ///
    /// Disposing a banner ad that's been shown removes it from the screen.
    /// Interstitial ads can't be programmatically removed from view.
    Future<void> disposeAd(DSAd ad) {
      final int? adId = adIdFor(ad);
      final DSAd? disposedAd = _loadedAds.remove(adId);
      if (disposedAd == null) {
        return Future<void>.value();
      }
      return channel.invokeMethod('disposeAd', {'adId': adId});
    }

}
