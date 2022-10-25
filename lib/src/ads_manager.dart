import 'dart:async';
import 'dart:ui';

import 'package:ds_ads/src/ads_interstitial_cubit.dart';
import 'package:ds_ads/src/ads_native_loader_mixin.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

typedef OnReportEvent = void Function(String eventName, Map<String, Object> attributes);
typedef OnPaidEvent = void Function(Ad ad, double valueMicros, PrecisionType precision,
    String currencyCode, String format);

enum NativeAdBannerStyle {
  style1, // top margin 16dp
  style2, // no margins
}

abstract class AppAdState {
  /// App is in premium mode (no any ads shows)
  bool get isPremium;
  /// App is in foreground (interstitial ads cannot be shown)
  bool get isInForeground;
  // Current brightness for native banners style
  Brightness get brightness;
}

@immutable
abstract class AdEvent {
  const AdEvent();
}

class AdsManager {
  static AdsManager? _instance;
  static AdsManager get instance {
    assert(_instance != null, 'Call AdsManager(...) to initialize ads');
    return _instance!;
  }

  static AdsInterstitialCubit get interstitial {
    assert(_instance?._adsInterstitialCubit != null, 'Pass interstitialUnitId to AdsManager(...) on app start');
    return instance._adsInterstitialCubit!;
  }

  final AdsInterstitialCubit? _adsInterstitialCubit;

  var _isAdAvailable = false;
  /// Was the ad successfully loaded at least once in this session
  bool get isAdAvailable => _isAdAvailable;

  final _eventController = StreamController<AdEvent>.broadcast();

  Stream<AdEvent> get eventStream => _eventController.stream;

  final OnPaidEvent onPaidEvent;
  final AppAdState appState;
  final OnReportEvent? onReportEvent;
  final String? interstitialUnitId;
  final String? nativeUnitId;
  final Duration defaultFetchAdWait;
  final bool defaultShowNativeAdProgress;
  final NativeAdBannerStyle nativeAdBannerStyle;

  AdsManager({
    required this.onPaidEvent,
    required this.appState,
    required this.nativeAdBannerStyle,
    this.onReportEvent,
    this.interstitialUnitId,
    this.nativeUnitId,
    this.defaultFetchAdWait = const Duration(seconds: 20),
    this.defaultShowNativeAdProgress = false,
  }) :
    _adsInterstitialCubit = interstitialUnitId != null
        ? AdsInterstitialCubit(adUnitId: interstitialUnitId)
        : null {
    assert(_instance == null, 'dismiss previous Ads instance before init new');
    MobileAds.instance.initialize();
    _instance = this;

    unawaited(() async {
      await for (final event in eventStream) {
        if (event is AdInterstitialLoadedEvent || event is AdNativeLoadedEvent) {
          _isAdAvailable = true;
        }
        if (event is AdInterstitialLoadedEvent) {
          Timer.run(() async {
            await AdsNativeLoaderMixin.tryLoadBanner();
          });
        }
      }
    }());
  }

  void dismiss() {
    _instance = null;
    AdsNativeLoaderMixin.disposeClass();
  }

  @internal
  void emitEvent(AdEvent event) {
    _eventController.sink.add(event);
  }
}