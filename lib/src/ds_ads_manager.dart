import 'dart:async';

import 'package:ds_ads/src/ds_ads_interstitial_cubit.dart';
import 'package:ds_ads/src/ds_ads_native_loader_mixin.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
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
  final String? interstitialUnitId;
  final String? nativeUnitId;
  final Duration defaultFetchAdDelay;
  final bool defaultShowNativeAdProgress;
  final DSNativeAdBannerStyle nativeAdBannerStyle;
  final FirebaseRemoteConfig? remoteConfig;

  DSAdsManager({
    required this.onPaidEvent,
    required this.appState,
    required this.nativeAdBannerStyle,
    this.onReportEvent,
    this.interstitialUnitId,
    this.nativeUnitId,
    this.defaultFetchAdDelay = const Duration(),
    this.defaultShowNativeAdProgress = false,
    this.remoteConfig,
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