import 'dart:async';

import 'package:ds_ads/src/ds_ads_interstitial_cubit.dart';
import 'package:ds_ads/src/ds_ads_native_loader_mixin.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ds_ads_types.dart';

class DSAdsManager {
  static DSAdsManager? _instance;
  static DSAdsManager get instance {
    assert(_instance != null, 'Call AdsManager(...) to initialize ads');
    return _instance!;
  }

  static DSAdsInterstitialCubit get interstitial {
    assert(_instance?._adsInterstitialCubit != null, 'Pass interstitialUnitId to AdsManager(...) on app start');
    return instance._adsInterstitialCubit!;
  }

  final DSAdsInterstitialCubit? _adsInterstitialCubit;

  var _isAdAvailable = false;
  /// Was the ad successfully loaded at least once in this session
  bool get isAdAvailable => _isAdAvailable;

  final _eventController = StreamController<DSAdsEvent>.broadcast();

  Stream<DSAdsEvent> get eventStream => _eventController.stream;

  final OnPaidEvent onPaidEvent;
  final DSAppAdsState appState;
  final OnReportEvent? onReportEvent;
  final Set<DSAdLocation>? locations;
  final String? interstitialUnitId;
  final String? nativeUnitId;
  final Duration defaultFetchAdDelay;
  final bool defaultShowNativeAdProgress;
  final DSNativeAdBannerStyle nativeAdBannerStyle;
  final DSIsAdAllowedCallback? isAdAllowedCallback;

  /// Initializes ads in the app
  /// [onPaidEvent] allows you to know/handle the onPaidEvent event in google_mobile_ads
  /// In [appState] you should pass the [DSAppAdsState] interface implementation, so the ad manager can know the current 
  /// state of the app (whether the subscription is paid, whether the app is in the foreground, etc.).
  /// [nativeAdBannerStyle] defines the appearance of the native ad unit.
  /// If this [locations] set is defined, the nativeAdLocation method and the location parameter can return only one 
  /// of the values listed in [locations].
  /// [onReportEvent] is an event handler for the ability to send events to analytics.
  /// [interstitialUnitId] is the default unitId for the interstitial.
  /// [nativeUnitId] unitId for native block.
  /// [isAdAllowedCallback] allows you to dynamically determine whether an ad can be displayed.
  DSAdsManager({
    required this.onPaidEvent,
    required this.appState,
    required this.nativeAdBannerStyle,
    this.locations,
    this.onReportEvent,
    this.interstitialUnitId,
    this.nativeUnitId,
    this.isAdAllowedCallback,

    @Deprecated('looks as useless parameter')
    this.defaultFetchAdDelay = const Duration(),
    @Deprecated('looks as useless parameter')
    this.defaultShowNativeAdProgress = true,
  }) :
    _adsInterstitialCubit = interstitialUnitId != null
        ? DSAdsInterstitialCubit(adUnitId: interstitialUnitId)
        : null {
    assert(_instance == null, 'dismiss previous Ads instance before init new');
    MobileAds.instance.initialize();
    _instance = this;

    unawaited(() async {
      await for (final event in eventStream) {
        if (event is DSAdsInterstitialLoadedEvent || event is DSAdsNativeLoadedEvent) {
          _isAdAvailable = true;
        }
      }
    }());
  }

  Future<void> dismiss() async {
    _instance = null;
    await DSAdsNativeLoaderMixin.disposeClass();
  }

  @internal
  void emitEvent(DSAdsEvent event) {
    _eventController.sink.add(event);
  }
}