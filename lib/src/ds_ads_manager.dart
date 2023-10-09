import 'dart:async';

import 'package:applovin_max/applovin_max.dart';
import 'package:collection/collection.dart';
import 'package:ds_ads/src/ds_ads_app_open.dart';
import 'package:ds_ads/src/ds_ads_interstitial.dart';
import 'package:ds_ads/src/ds_ads_native_loader_mixin.dart';
import 'package:ds_ads/src/ds_ads_rewarded.dart';
import 'package:fimber/fimber.dart';
import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'ds_ads_native2_loader_mixin.dart';
import 'ds_ads_types.dart';

/// [DSAdsManager} is a root point to control ads
/// Call [DSAdsManager.preInit] before create application
/// Call constructor for init ds_ads library
/// Read README.md file for more information
class DSAdsManager {
  static DSAdsManager? _instance;

  static DSAdsManager get instance {
    assert(_instance != null, 'Call AdsManager(...) to initialize ads');
    return _instance!;
  }

  final _nextMediationWait = const Duration(minutes: 1);

  final _adsInterstitial = DSAdsInterstitial(source: DSAdSource.interstitial);
  final _adsInterstitial2 = DSAdsInterstitial(source: DSAdSource.interstitial2);
  final _adsRewarded = DSAdsRewarded();
  final _adsAppOpen = DSAdsAppOpen();
  DSAdsInterstitial? _splashInterstitial;

  @protected
  final appLovinSDKConfiguration = {};

  static bool get isInitialized => _instance != null;

  static DSAdsInterstitial get interstitial => instance._adsInterstitial;
  static DSAdsInterstitial get interstitial2 => instance._adsInterstitial2;

  static DSAdsInterstitial get splashInterstitial {
    if (instance._splashInterstitial == null) {
      Fimber.i('splash interstitial created');
      instance._splashInterstitial = DSAdsInterstitial(source: DSAdSource.interstitialSplash);
    }
    return instance._splashInterstitial!;
  }

  static DSAdsRewarded get rewarded => instance._adsRewarded;

  static DSAdsAppOpen get appOpen => instance._adsAppOpen;

  /// Is any full-screen ad shows
  static bool get isAdShowing =>
      isInitialized &&
          ({DSAdState.preShowing, DSAdState.showing}.contains(interstitial.adState) ||
              {DSAdState.preShowing, DSAdState.showing}.contains(splashInterstitial.adState) ||
              {DSAdState.preShowing, DSAdState.showing}.contains(rewarded.adState) ||
              {DSAdState.preShowing, DSAdState.showing}.contains(appOpen.adState));

  /// Stop loading splash interstitial and dispose [DSAdsManager.splashInterstitial] object
  void disposeSplashInterstitial() {
    _splashInterstitial?.dispose();
    _splashInterstitial = null;
    Fimber.i('splash interstitial disposed');
  }

  var _isAdAvailable = false;
  final _currentMediation = <DSAdSource, DSAdMediation?>{};
  final _mediationInitialized = <DSAdMediation>{};

  /// Was the ad successfully loaded at least once in this session
  bool get isAdAvailable => _isAdAvailable;

  DSAdMediation? currentMediation(DSAdSource source) => _currentMediation[source];

  final _eventController = StreamController<DSAdsEvent>.broadcast();

  Stream<DSAdsEvent> get eventStream => _eventController.stream;

  final List<DSAdMediation> Function(DSAdSource source) mediationPrioritiesCallback;
  final OnPaidEvent onPaidEvent;
  final DSAppAdsState appState;
  final OnReportEvent? onReportEvent;
  final Set<DSAdLocation>? locations;
  final String interstitialGoogleUnitId;
  final String interstitialSplashGoogleUnitId;
  final String interstitial2GoogleUnitId;
  final String nativeGoogleUnitId;
  final String native2GoogleUnitId;
  final String appOpenGoogleUnitId;
  final String rewardedGoogleUnitId;
  final String appLovinSDKKey;
  final String interstitialAppLovinUnitId;
  final String interstitialSplashAppLovinUnitId;
  final String interstitial2AppLovinUnitId;
  final String nativeAppLovinUnitId;
  final String native2AppLovinUnitId;
  final String appOpenAppLovinUnitId;
  final String rewardedAppLovinUnitId;
  final DSDurationCallback? interstitialFetchDelayCallback;
  final DSDurationCallback? interstitialShowLockCallback;
  final DSDurationCallback? rewardedFetchDelayCallback;
  final DSDurationCallback? rewardedShowLockCallback;
  final DSNativeStyle nativeAdBannerDefStyle;
  final List<NativeAdBanner> nativeAdCustomBanners;
  final DSIsAdAllowedCallback? isAdAllowedCallback;
  final DSRetryCountCallback? retryCountCallback;

  /// App is in foreground
  @internal
  bool get isInForeground => _widgetsObserver!.appLifecycleState! == AppLifecycleState.resumed;

  static _WidgetsObserver? _widgetsObserver;

  /// Must be called before create application
  static void preInit() {
    if (_widgetsObserver != null) return;

    _widgetsObserver = _WidgetsObserver();
    WidgetsBinding.instance.addObserver(_widgetsObserver!);
    _widgetsObserver!.appLifecycleState = WidgetsBinding.instance.lifecycleState;
  }

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
    this.interstitialGoogleUnitId = '',
    this.interstitialSplashGoogleUnitId = '',
    this.interstitial2GoogleUnitId = '',
    this.rewardedGoogleUnitId = '',
    this.nativeGoogleUnitId = '',
    this.native2GoogleUnitId = '',
    this.appOpenGoogleUnitId = '',
    this.appLovinSDKKey = '',
    this.interstitialAppLovinUnitId = '',
    this.interstitialSplashAppLovinUnitId = '',
    this.interstitial2AppLovinUnitId = '',
    this.nativeAppLovinUnitId = '',
    this.native2AppLovinUnitId = '',
    this.appOpenAppLovinUnitId = '',
    this.rewardedAppLovinUnitId = '',
    this.isAdAllowedCallback,
    this.nativeAdCustomBanners = const [],
    this.interstitialFetchDelayCallback,
    this.interstitialShowLockCallback,
    this.rewardedFetchDelayCallback,
    this.rewardedShowLockCallback,
    this.retryCountCallback,
  })  : assert(_instance == null, 'dismiss previous Ads instance before init new'),
        assert(_widgetsObserver != null, 'call DSAdsManager.preInit() before') {
    _instance = this;
    for (final t in DSAdSource.values) {
      _tryNextMediation(t, true);
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
    await DSAdsNative2LoaderMixin.disposeClass();
  }

  @internal
  void emitEvent(DSAdsEvent event) {
    _eventController.sink.add(event);
  }

  var _lockMediationTill = DateTime(0);

  void _tryNextMediation(DSAdSource source, bool isInit) {
    final mediationPriorities = mediationPrioritiesCallback(source);
    _prevMediationPriorities[source] = mediationPriorities.toSet();
    final String googleId;
    final String appLovinId;
    switch (source) {
      case DSAdSource.interstitial:
        googleId = interstitialGoogleUnitId;
        appLovinId = interstitialAppLovinUnitId;
        break;
      case DSAdSource.interstitial2:
        googleId = interstitial2GoogleUnitId;
        appLovinId = interstitial2AppLovinUnitId;
        break;
      case DSAdSource.interstitialSplash:
        googleId = interstitialSplashGoogleUnitId;
        appLovinId = interstitialSplashAppLovinUnitId;
        break;
      case DSAdSource.banner:
        // ToDo: need implement mediations check for banner different approach
        googleId = '-';
        appLovinId = '-';
      case DSAdSource.native:
        googleId = nativeGoogleUnitId;
        appLovinId = nativeAppLovinUnitId;
        break;
      case DSAdSource.native2:
        googleId = native2GoogleUnitId;
        appLovinId = native2AppLovinUnitId;
        break;
      case DSAdSource.rewarded:
        googleId = rewardedGoogleUnitId;
        appLovinId = rewardedAppLovinUnitId;
        break;
      case DSAdSource.appOpen:
        googleId = appOpenGoogleUnitId;
        appLovinId = appOpenAppLovinUnitId;
        break;
    }

    if (mediationPriorities.contains(DSAdMediation.google)) {
      if (googleId.isEmpty) {
        mediationPriorities.remove(DSAdMediation.google);
        assert(false,
            '$source error: setup ...GoogleUnitId field or remove DSAdMediation.google from mediationPrioritiesCallback ($source)');
      }
    }
    if (mediationPriorities.contains(DSAdMediation.appLovin)) {
      if (appLovinSDKKey.isEmpty) {
        mediationPriorities.remove(DSAdMediation.appLovin);
        assert(false, 'setup appLovinSDKKey or remove DSAdMediation.appLovin from mediationPrioritiesCallack ($source)');
      } 
      if (appLovinId.isEmpty) {
        mediationPriorities.remove(DSAdMediation.appLovin);
        assert(false,
            '$source error: setup ...AppLovinUnitId or remove DSAdMediation.appLovin from mediationPrioritiesCallack ($source)');
      }
    }
    if (mediationPriorities.isEmpty) {
      if (!isInit) {
        _lockMediationTill = DateTime.timestamp().add(_nextMediationWait);
        _currentMediation[source] = null;
        Timer(_nextMediationWait, () async {
          if (currentMediation(source) == null) {
            _tryNextMediation(source, false);
          }
        });
        Fimber.e('ads_manager: no mediation', stacktrace: StackTrace.current);
      }
      return;
    }

    final DSAdMediation next;
    if (_currentMediation[source] == null) {
      if (_lockMediationTill.isAfter(DateTime.timestamp())) return;
      next = mediationPriorities.first;
    } else {
      if (_currentMediation[source] == mediationPriorities.last) {
        _lockMediationTill = DateTime.timestamp().add(_nextMediationWait);
        _currentMediation[source] = null;
        onReportEvent?.call('ads_manager: no next mediation, waiting ${_nextMediationWait.inSeconds}s', {});
        Timer(_nextMediationWait, () async {
          if (currentMediation(source) == null) {
            _tryNextMediation(source, false);
          }
        });
        return;
      }
      final curr = mediationPriorities.indexOf(_currentMediation[source]!);
      next = mediationPriorities[curr + 1];
    }

    onReportEvent?.call('ads_manager: select mediation', {
      'mediation': '$next',
      'mediation_type': '$source',
    });
    _currentMediation[source] = next;
    if (!_mediationInitialized.contains(next)) {
      unawaited(() async {
        try {
          switch (next) {
            case DSAdMediation.google:
              // It seems that init just creates competition for other mediations
              //await MobileAds.instance.initialize();
              break;
            case DSAdMediation.appLovin:
              await initAppLovine();
              break;
          }
          _mediationInitialized.add(next);
        } catch (e, stack) {
          Fimber.e('$e', stacktrace: stack);
        }
      }());
    }
  }

  final _prevMediationPriorities = <DSAdSource, Set<DSAdMediation>>{};

  @internal
  bool updateMediations(DSAdSource source) {
    if (currentMediation(source) == null) return false;
    final mediationPriorities = mediationPrioritiesCallback(source);
    try {
      void reloadMediation() {
        Fimber.i('ads_manager: mediations reloaded');
        _lockMediationTill = DateTime(0);
        _currentMediation[source] = null;
        _tryNextMediation(source, false);
      }

      if (!mediationPriorities.contains(currentMediation(source))) {
        reloadMediation();
        return true;
      }
      final isSame = const IterableEquality().equals(mediationPriorities, _prevMediationPriorities[source]);
      if (!isSame) {
        if (mediationPriorities.first != currentMediation(source)) {
          reloadMediation();
          return true;
        }
      }
    } catch (e, stack) {
      Fimber.e('$e', stacktrace: stack);
      _prevMediationPriorities[source] = mediationPriorities.toSet();
    }
    return false;
  }

  @internal
  Future<void> onLoadAdError(int errCode, String errText, DSAdMediation mediation, DSAdSource source) async {
    if (mediation != currentMediation(source)) return;
    if (mediationPrioritiesCallback(source).length <= 1) return;
    switch (mediation) {
      case DSAdMediation.google:
        // https://support.google.com/admob/thread/3494603/admob-error-codes-logs?hl=en
        if (errCode == 3) {
          if (!updateMediations(source)) {
            _tryNextMediation(source, false);
          }
        }
        break;
      case DSAdMediation.appLovin:
        // https://dash.applovin.com/documentation/mediation/flutter/getting-started/errorcodes
        if (errCode == 204 || errCode == -5001) {
          if (!updateMediations(source)) {
            _tryNextMediation(source, false);
          }
        }
        break;
    }
  }

  bool isMediationInitialized(DSAdMediation mediation) => _mediationInitialized.contains(mediation);

  Future<void>? _appLovinInit;

  Future<void> initAppLovine() async {
    if (isMediationInitialized(DSAdMediation.appLovin)) return;

    _appLovinInit ??= () async {
      onReportEvent?.call('ads_manager: AppLovin start initializing', {});
      appLovinSDKConfiguration.clear();
        if (appLovinSDKKey.isEmpty) {
          Fimber.e('AppLovin not initialized. SDKKey is empty', stacktrace: StackTrace.current);
          return;
        }
        final config = await AppLovinMAX.initialize(appLovinSDKKey);
        if (config != null) {
          appLovinSDKConfiguration.addAll(config);
        }
        _mediationInitialized.add(DSAdMediation.appLovin);
        onReportEvent?.call('ads_manager: AppLovin initialized', {});
      } ();

    await _appLovinInit;
  }

  @internal
  int getRetryMaxCount(DSAdSource source) {
    return retryCountCallback?.call(source) ?? 3;
  }
}

class _WidgetsObserver with WidgetsBindingObserver {
  AppLifecycleState? appLifecycleState;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (appLifecycleState == state) return;
    final old = appLifecycleState;
    appLifecycleState = state;
    DSAdsManager._instance?._adsAppOpen.appLifecycleChanged(old, state);
  }
}
