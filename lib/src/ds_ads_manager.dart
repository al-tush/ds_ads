import 'dart:async';

import 'package:applovin_max/applovin_max.dart';
import 'package:collection/collection.dart';
import 'package:ds_ads/src/ds_ads_app_open.dart';
import 'package:ds_ads/src/ds_ads_interstitial.dart';
import 'package:ds_ads/src/ds_ads_native_loader_mixin.dart';
import 'package:ds_ads/src/ds_ads_rewarded.dart';
import 'package:fimber/fimber.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'ds_ads_types.dart';

class DSAdsManager {
  static DSAdsManager? _instance;
  static DSAdsManager get instance {
    assert(_instance != null, 'Call AdsManager(...) to initialize ads');
    return _instance!;
  }

  final _nextMediationWait = const Duration(minutes: 1);

  final _adsInterstitial = DSAdsInterstitial(type: DSAdsInterstitialType.def);
  final _adsRewarded = DSAdsRewarded();
  final _adsAppOpen = DSAdsAppOpen();
  DSAdsInterstitial? _splashInterstitial;

  @protected
  final appLovinSDKConfiguration = {};

  static bool get isInitialized => _instance != null;

  static DSAdsInterstitial get interstitial => instance._adsInterstitial;
  static DSAdsInterstitial get splashInterstitial {
    if (instance._splashInterstitial == null) {
      Fimber.i('splash interstitial created');
      instance._splashInterstitial = DSAdsInterstitial(type: DSAdsInterstitialType.splash);
    }
    return instance._splashInterstitial!;
  }

  static DSAdsRewarded get rewarded => instance._adsRewarded;

  static DSAdsAppOpen get appOpen => instance._adsAppOpen;

  void disposeSplashInterstitial() {
    _splashInterstitial?.dispose();
    _splashInterstitial = null;
    Fimber.i('splash interstitial disposed');
  }

  var _isAdAvailable = false;
  final _currentMediation = <DSMediationType, DSAdMediation?>{};
  final _mediationInitialized = <DSAdMediation>{};
  /// Was the ad successfully loaded at least once in this session
  bool get isAdAvailable => _isAdAvailable;
  DSAdMediation? currentMediation(DSMediationType type) => _currentMediation[type];

  final _eventController = StreamController<DSAdsEvent>.broadcast();

  Stream<DSAdsEvent> get eventStream => _eventController.stream;
  
  final List<DSAdMediation> Function(DSMediationType type) mediationPrioritiesCallback;
  final OnPaidEvent onPaidEvent;
  final DSAppAdsState appState;
  final OnReportEvent? onReportEvent;
  final Set<DSAdLocation>? locations;
  final String? interstitialGoogleUnitId;
  final String? interstitialSplashGoogleUnitId;
  final String? nativeGoogleUnitId;
  final String? appOpenGoogleUnitId;
  final String? rewardedGoogleUnitId;
  final String? appLovinSDKKey;
  final String? interstitialAppLovinUnitId;
  final String? interstitialSplashAppLovinUnitId;
  final String? nativeAppLovinUnitId;
  final String? rewardedAppLovinUnitId;
  final DSDurationCallback? interstitialFetchDelayCallback;
  final DSDurationCallback? interstitialShowLockCallback;
  final DSDurationCallback? rewardedFetchDelayCallback;
  final DSDurationCallback? rewardedShowLockCallback;
  final DSNativeStyle nativeAdBannerDefStyle;
  final List<NativeAdBanner> nativeAdCustomBanners;
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
  /// [nativeAdHeight] height of custom native ad blocks (not in [DSNativeAdBannerStyle])
  /// [isAdAllowedCallback] allows you to dynamically determine whether an ad can be displayed.
  /// [interstitialFetchDelay] sets the minimum time after displaying an interstitial before the next interstitial is started to load.
  /// [interstitialShowLock] the time from the moment the user closes the interstitial for which the interstitials show are blocked.
  DSAdsManager({
    required this.mediationPrioritiesCallback,
    required this.onPaidEvent,
    required this.appState,
    this.nativeAdBannerDefStyle = DSNativeAdBannerStyle.notDefined,
    this.locations,
    this.onReportEvent,
    this.interstitialGoogleUnitId,
    this.interstitialSplashGoogleUnitId,
    this.rewardedGoogleUnitId,
    this.nativeGoogleUnitId,
    this.appOpenGoogleUnitId,
    this.appLovinSDKKey,
    this.interstitialAppLovinUnitId,
    this.interstitialSplashAppLovinUnitId,
    this.nativeAppLovinUnitId,
    this.rewardedAppLovinUnitId,
    this.isAdAllowedCallback,
    this.nativeAdCustomBanners = const [],

    this.interstitialFetchDelayCallback,
    this.interstitialShowLockCallback,
    this.rewardedFetchDelayCallback,
    this.rewardedShowLockCallback,
  }) :
        assert(_instance == null, 'dismiss previous Ads instance before init new')
  {
    _instance = this;
    for (final t in DSMediationType.values) {
      unawaited(_tryNextMediation(t));
    }

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
  
  Future<void> _tryNextMediation(DSMediationType type) async {
    final mediationPriorities = mediationPrioritiesCallback(type);
    _prevMediationPriorities[type] = mediationPriorities.toSet();
    if (mediationPriorities.contains(DSAdMediation.google)) {
      if (interstitialGoogleUnitId?.isNotEmpty != true) {
        mediationPriorities.remove(DSAdMediation.google);
        assert(false, 'setup interstitialGoogleUnitId or remove DSAdMediation.google from mediationPrioritiesCallack');
      }
    }
    if (mediationPriorities.contains(DSAdMediation.appLovin)) {
      if (appLovinSDKKey?.isNotEmpty != true) {
        mediationPriorities.remove(DSAdMediation.appLovin);
        assert(false, 'setup appLovinSDKKey or remove DSAdMediation.appLovin from mediationPrioritiesCallack');
      }
      if (interstitialAppLovinUnitId?.isNotEmpty != true) {
        mediationPriorities.remove(DSAdMediation.appLovin);
        assert(false, 'setup interstitialAppLovinUnitId or remove DSAdMediation.appLovin from mediationPrioritiesCallack');
      }
    }
    if (mediationPriorities.isEmpty) {
      Fimber.e('ads_manager: no mediation', stacktrace: StackTrace.current);
      return;
    }

    final DSAdMediation next;
    if (_currentMediation[type] == null) {
      if (_lockMediationTill.isAfter(DateTime.now())) return;
      next = mediationPriorities.first;
    } else {
      if (_currentMediation[type] == mediationPriorities.last) {
        _lockMediationTill = DateTime.now().add(_nextMediationWait);
        _currentMediation[type] = null;
        onReportEvent?.call('ads_manager: no next mediation, waiting ${_nextMediationWait.inSeconds}s', {});
        Timer(_nextMediationWait, () async {
          if (currentMediation(type) == null) {
            await _tryNextMediation(type);
          }
        });
        return;
      }
      final curr = mediationPriorities.indexOf(_currentMediation[type]!);
      next = mediationPriorities[curr + 1];
    }
    
    onReportEvent?.call('ads_manager: select mediation', {
      'mediation': '$next',
      'mediation_type': '$type',
    });
    _currentMediation[type] = next;
    if (!_mediationInitialized.contains(next)) {
      _mediationInitialized.add(next);
      switch (next) {
        case DSAdMediation.google:
          // It seems that init just creates competition for other mediations
          //await MobileAds.instance.initialize();
          break;
        case DSAdMediation.appLovin:
          appLovinSDKConfiguration.clear();
          final config = await AppLovinMAX.initialize(appLovinSDKKey!);
          if (config != null) {
            appLovinSDKConfiguration.addAll(config);
          }
      }
      onReportEvent?.call('ads_manager: mediation initialized', {
        'mediation': '$next',
        'mediation_type': '$type',
      });
    }
  }

  final _prevMediationPriorities = <DSMediationType, Set<DSAdMediation>>{};

  @internal
  Future<void> checkMediation(DSMediationType type) async {
    if (currentMediation(type) == null) return;
    final mediationPriorities = mediationPrioritiesCallback(type);
    try {
      if (!mediationPriorities.contains(currentMediation(type))) {
        await _tryNextMediation(type);
        return;
      }
      final isSame = const IterableEquality().equals(mediationPriorities, _prevMediationPriorities[type]);
      if (!isSame) {
        if (mediationPriorities.first != currentMediation(type)) {
          _currentMediation[type] = null;
          await _tryNextMediation(type);
        }
      }
    } catch (e, stack) {
      Fimber.e('$e', stacktrace: stack);
      _prevMediationPriorities[type] = mediationPriorities.toSet();
    }
  }

  @internal
  Future<void> onLoadAdError(int errCode, String errText, DSAdMediation mediation, DSAdSource source) async {
    final type = source == DSAdSource.native ? DSMediationType.native : DSMediationType.main;
    if (mediationPrioritiesCallback(type).length <= 1) return;
    switch (mediation) {
      case DSAdMediation.google:
      // https://support.google.com/admob/thread/3494603/admob-error-codes-logs?hl=en
        if (errCode == 3) {
          await _tryNextMediation(type);
        }
        break;
      case DSAdMediation.appLovin:
      // https://dash.applovin.com/documentation/mediation/flutter/getting-started/errorcodes
        if (errCode == 204 || errCode == -5001) {
          await _tryNextMediation(type);
        }
        break;
    }
  }

}
