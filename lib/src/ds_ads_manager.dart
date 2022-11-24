import 'dart:async';

import 'package:ds_ads/src/ds_ads_interstitial.dart';
import 'package:ds_ads/src/ds_ads_native_loader_mixin.dart';
import 'package:ds_ads/src/yandex_ads/export.dart';
import 'package:fimber/fimber.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ds_ads_types.dart';

class DSAdsManager {
  static DSAdsManager? _instance;
  static DSAdsManager get instance {
    assert(_instance != null, 'Call AdsManager(...) to initialize ads');
    return _instance!;
  }

  final _nextMediationWait = const Duration(minutes: 1);

  final _adsInterstitialCubit = DSAdsInterstitial(type: DSAdsInterstitialType.def);
  DSAdsInterstitial? _splashInterstitial;

  static bool get isInitialized => _instance != null;

  static DSAdsInterstitial get interstitial => instance._adsInterstitialCubit;
  static DSAdsInterstitial get splashInterstitial {
    if (instance._splashInterstitial == null) {
      Fimber.i('splash interstitial created');
      instance._splashInterstitial = DSAdsInterstitial(type: DSAdsInterstitialType.splash);
    }
    return instance._splashInterstitial!;
  }

  void disposeSplashInterstitial() {
    _splashInterstitial?.dispose();
    _splashInterstitial = null;
    Fimber.i('splash interstitial disposed');
  }

  var _isAdAvailable = false;
  DSAdMediation? _currentMediation;
  final _mediationInitialized = <DSAdMediation>{};
  /// Was the ad successfully loaded at least once in this session
  bool get isAdAvailable => _isAdAvailable;
  DSAdMediation? get currentMediation => _currentMediation;

  final _eventController = StreamController<DSAdsEvent>.broadcast();

  Stream<DSAdsEvent> get eventStream => _eventController.stream;
  
  final List<DSAdMediation> Function() mediationPrioritiesCallback;
  final OnPaidEvent onPaidEvent;
  final DSAppAdsState appState;
  final OnReportEvent? onReportEvent;
  final Set<DSAdLocation>? locations;
  final String? interstitialGoogleUnitId;
  final String? interstitialSplashGoogleUnitId;
  final String? nativeGoogleUnitId;
  final String? interstitialYandexUnitId;
  final String? interstitialSplashYandexUnitId;
  final Duration interstitialFetchDelay;
  final Duration interstitialShowLock;
  final DSNativeAdBannerStyle nativeAdBannerStyle;
  final DSIsAdAllowedCallback? isAdAllowedCallback;

  /// Initializes ads in the app
  /// [onPaidEvent] allows you to know/handle the onPaidEvent event in google_mobile_ads
  /// In [appState] you should pass the [DSAppAdsState] interface implementation, so the ad manager can know the current 
  /// state of the app (whether the subscription is paid, whether the app is in the foreground, etc.).
  /// [nativeAdBannerStyle] defines the appearance of the native ad unit.
  /// If this [locations] set is defined, the nativeAdLocation method and the location parameter can return only one 
  /// of the values listed in [locations].
  /// [onLoadAdError] ToDo: TBD
  /// [onReportEvent] is an event handler for the ability to send events to analytics.
  /// [interstitialUnitId] is the default unitId for the interstitial.
  /// [nativeUnitId] unitId for native block.
  /// [isAdAllowedCallback] allows you to dynamically determine whether an ad can be displayed.
  /// [interstitialFetchDelay] sets the minimum time after displaying an interstitial before the next interstitial is started to load.
  /// [interstitialShowLock] the time from the moment the user closes the interstitial for which the interstitials show are blocked.
  DSAdsManager({
    required this.mediationPrioritiesCallback,
    required this.onPaidEvent,
    required this.appState,
    required this.nativeAdBannerStyle,
    this.locations,
    this.onReportEvent,
    this.interstitialGoogleUnitId,
    this.interstitialSplashGoogleUnitId,
    this.nativeGoogleUnitId,
    this.interstitialYandexUnitId,
    this.interstitialSplashYandexUnitId,
    this.isAdAllowedCallback,

    this.interstitialFetchDelay = const Duration(),
    this.interstitialShowLock = const Duration(),
  }) :
        assert(_instance == null, 'dismiss previous Ads instance before init new'),
        assert(interstitialYandexUnitId == null || interstitialYandexUnitId.startsWith('R-M-'),
        'interstitialYandexUnitId must begin with R-M-')
  {
    _instance = this;
    unawaited(_tryNextMediation());

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
  
  var _lockMediationTill = DateTime(0);
  
  Future<void> _tryNextMediation() async {
    final mediationPriorities = mediationPrioritiesCallback();
    if (mediationPriorities.contains(DSAdMediation.google)) {
      if (interstitialGoogleUnitId?.isNotEmpty != true) {
        mediationPriorities.remove(DSAdMediation.google);
        assert(false, 'setup interstitialGoogleUnitId or remove DSAdMediation.google from mediationPrioritiesCallack');
      }
    }
    if (mediationPriorities.contains(DSAdMediation.yandex)) {
      if (interstitialYandexUnitId?.isNotEmpty != true) {
        mediationPriorities.remove(DSAdMediation.yandex);
        assert(false, 'setup interstitialYandexUnitId or remove DSAdMediation.yandex from mediationPrioritiesCallack');
      }
    }
    if (mediationPriorities.isEmpty) {
      Fimber.e('ads_manager: no mediation', stacktrace: StackTrace.current);
      return;
    }

    final DSAdMediation next;
    if (_currentMediation == null) {
      if (_lockMediationTill.isAfter(DateTime.now())) return;
      next = mediationPriorities.first;
    } else {
      if (_currentMediation == mediationPriorities.last) {
        _lockMediationTill = DateTime.now().add(_nextMediationWait);
        _currentMediation = null;
        onReportEvent?.call('ads_manager: no next mediation, waiting ${_nextMediationWait.inSeconds}s', {});
        Timer(_nextMediationWait, () async {
          if (currentMediation == null) {
            await _tryNextMediation();
          }
        });
        return;
      }
      final curr = mediationPriorities.indexOf(_currentMediation!);
      next = mediationPriorities[curr + 1];
    }
    
    onReportEvent?.call('ads_manager: select mediation', {
      'mediation': '$next',
    });
    _currentMediation = next;
    if (!_mediationInitialized.contains(next)) {
      _mediationInitialized.add(next);
      switch (next) {
        case DSAdMediation.google:
          await MobileAds.instance.initialize();
          break;
        case DSAdMediation.yandex:
          await YandexAds.instance.initialize();
          break;
      }
      onReportEvent?.call('ads_manager: mediation initialized', {
        'mediation': '$next',
      });
    }
  }
  
  @internal
  Future<void> onLoadAdError(int errCode, String errText, DSAdMediation mediation, DSAdSource source) async {
    if (mediationPrioritiesCallback().length <= 1) return;
    switch (mediation) {
      case DSAdMediation.google:
      // https://support.google.com/admob/thread/3494603/admob-error-codes-logs?hl=en
        if (errCode == 3) {
          await _tryNextMediation();
        }
        break;
      case DSAdMediation.yandex:
      // https://yandex.com/dev/mobile-ads/doc/android/ref/constant-values.html#com.yandex.mobile.ads.common.AdRequestError.Code.NO_FILL
        if (errCode == 4) {
          await _tryNextMediation();
        }
        break;
    }
  }

}
