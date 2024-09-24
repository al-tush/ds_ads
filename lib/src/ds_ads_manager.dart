import 'dart:async';
import 'dart:io';

import 'package:applovin_max/applovin_max.dart';
import 'package:collection/collection.dart';
import 'package:ds_ads/src/ds_ads_app_open.dart';
import 'package:ds_ads/src/ds_ads_interstitial.dart';
import 'package:ds_ads/src/ds_ads_native_loader_mixin.dart';
import 'package:ds_ads/src/ds_ads_rewarded.dart';
import 'package:ds_common/core/ds_adjust.dart';
import 'package:ds_common/ds_common.dart';
import 'package:fimber/fimber.dart';
import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ds_ads_types.dart';

/// [DSAdsManager} is a root point to control ads
/// Call [DSAdsManager.preInit] before create application
/// Call constructor for init ds_ads library
/// Read README.md file for more information
class DSAdsManager {
  static DSAdsManager? _instance;

  static DSAdsManager get instance {
    assert(_instance != null, 'Call DSAdsManager(...) to initialize ads');
    return _instance!;
  }

  final _nextMediationWait = const Duration(minutes: 1);

  final _adsInterstitial = DSAdsInterstitial(source: DSAdSource.interstitial);
  final _adsInterstitial2 = DSAdsInterstitial(source: DSAdSource.interstitial2);
  final _adsRewarded = DSAdsRewarded();
  final _adsAppOpen = DSAdsAppOpen(source: DSAdSource.appOpen);
  DSAdsInterstitial? _splashInterstitial;
  DSAdsAppOpen? _splashAppOpen;

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

  static DSAdsAppOpen get splashAppOpen {
    if (instance._splashAppOpen == null) {
      Fimber.i('splash app open created');
      instance._splashAppOpen = DSAdsAppOpen(source: DSAdSource.appOpenSplash);
    }
    return instance._splashAppOpen!;
  }

  /// Is any full-screen ad shows
  static bool get isAdShowing =>
      isInitialized &&
          ({DSAdState.preShowing, DSAdState.showing}.contains(interstitial.adState) ||
              {DSAdState.preShowing, DSAdState.showing}.contains(instance._splashInterstitial?.adState) ||
              {DSAdState.preShowing, DSAdState.showing}.contains(rewarded.adState) ||
              {DSAdState.preShowing, DSAdState.showing}.contains(appOpen.adState) ||
              {DSAdState.preShowing, DSAdState.showing}.contains(instance._splashAppOpen?.adState));

  /// Stop loading splash interstitial and dispose [DSAdsManager.splashInterstitial] object
  void disposeSplashInterstitial() {
    _splashInterstitial?.dispose();
    _splashInterstitial = null;
    Fimber.i('splash interstitial disposed');
  }

  /// Stop loading splash app open and dispose [DSAdsManager.splashAppOpen] object
  void disposeSplashAppOpen() {
    _splashAppOpen?.dispose();
    _splashAppOpen = null;
    Fimber.i('splash app open disposed');
  }

  var _isAdAvailable = false;
  final _currentMediation = <DSAdSource, DSAdMediation?>{};
  final _mediationInitialized = <DSAdMediation>{};

  ConsentForm? _consentForm;
  DSConsentStatus _lastConsentStatus = DSConsentStatus.unknown;

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
  final String appOpenGoogleUnitId;
  final String appOpenSplashGoogleUnitId;
  final String rewardedGoogleUnitId;
  final String appLovinSDKKey;
  final String interstitialAppLovinUnitId;
  final String interstitialSplashAppLovinUnitId;
  final String interstitial2AppLovinUnitId;
  final String nativeAppLovinUnitId;
  final String appOpenAppLovinUnitId;
  final String appOpenSplashAppLovinUnitId;
  final String rewardedAppLovinUnitId;
  final DSDurationCallback? interstitialFetchDelayCallback;
  final DSDurationCallback? interstitialShowLockCallback;
  final DSDurationCallback? rewardedFetchDelayCallback;
  final DSDurationCallback? rewardedShowLockCallback;
  final DSNativeStyle nativeAdBannerDefStyle;
  final List<NativeAdBannerInterface> nativeAdCustomBanners;
  final DSIsAdAllowedCallback? isAdAllowedCallback;
  final DSRetryCountCallback? retryCountCallback;
  final ConsentDebugSettings? consentDebugSettings;

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
  /// [nativeGoogleUnitId], [nativeAppLovinUnitId] unitId for native block.
  /// [isAdAllowedCallback] allows you to dynamically determine whether an ad can be displayed.
  /// [interstitialFetchDelay] sets the minimum time after displaying an interstitial before the next interstitial is started to load.
  /// [interstitialShowLock] the time from the moment the user closes the interstitial for which the interstitials show are blocked.
  /// [consentDebugSettings] settings for UMP Consent for internal app builds (by default debugGeography: DebugGeography.debugGeographyEea)
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
    this.appOpenGoogleUnitId = '',
    this.appOpenSplashGoogleUnitId = '',
    this.appLovinSDKKey = '',
    this.interstitialAppLovinUnitId = '',
    this.interstitialSplashAppLovinUnitId = '',
    this.interstitial2AppLovinUnitId = '',
    this.nativeAppLovinUnitId = '',
    this.appOpenAppLovinUnitId = '',
    this.appOpenSplashAppLovinUnitId = '',
    this.rewardedAppLovinUnitId = '',
    this.isAdAllowedCallback,
    this.nativeAdCustomBanners = const [],
    this.interstitialFetchDelayCallback,
    this.interstitialShowLockCallback,
    this.rewardedFetchDelayCallback,
    this.rewardedShowLockCallback,
    this.retryCountCallback,
    this.consentDebugSettings,
  })  : assert(_instance == null, 'dismiss previous Ads instance before init new'),
        assert(_widgetsObserver != null, 'call DSAdsManager.preInit() before') {
    _instance = this;
    for (final t in DSAdSource.values) {
      _tryNextMediation(t, true);
    }

    unawaited(() async {
      await for (final event in eventStream) {
        if (event is DSAdsInterstitialLoadedEvent
            || event is DSAdsAppOpenLoadedEvent
            || event is DSAdsRewardedLoadedEvent
            || event is DSAdsNativeLoadedEvent) {
          _isAdAvailable = true;
        }
      }
    }());

    unawaited(() async {
      // ANDROID CONSENT
      if (Platform.isAndroid) {
        ConsentDebugSettings? settings;
        if (DSConstants.I.isInternalVersion) {
          settings = consentDebugSettings ?? ConsentDebugSettings(
            debugGeography: DebugGeography.debugGeographyEea,
          );
        }
        final params = ConsentRequestParameters(
          consentDebugSettings: settings,
        );
        ConsentInformation.instance.requestConsentInfoUpdate(
          params, () async {
          _lastConsentStatus = await ConsentInformation.instance.getConsentStatus();
          AppLovinMAX.setHasUserConsent(_lastConsentStatus == DSConsentStatus.obtained);
          DSMetrica.reportEvent('consent status', attributes: {
            'consent_status': '$_lastConsentStatus',
            'position': 'init',
          });
          if ([DSConsentStatus.notRequired, DSConsentStatus.obtained].contains(_lastConsentStatus)) return;
          if (await ConsentInformation.instance.isConsentFormAvailable()) {
            ConsentForm.loadConsentForm((ConsentForm consentForm) async {
              _consentForm = consentForm;
            },
                  (FormError error) =>
                  Fimber.e('Consent error: ${error.message} (${error.errorCode})', stacktrace: StackTrace.current),
            );
          } else {
            DSMetrica.reportEvent('consent status', attributes: {
              'consent_status': 'formUnavailable',
              'position': 'init',
            });
          }
        }, (FormError error) =>
            Fimber.e('Consent error: ${error.message} (${error.errorCode})', stacktrace: StackTrace.current),
        );
      }
      // IOS CONSENT
      if (Platform.isIOS) {
        final status = await DSAdjust.getATTStatus();
        _lastConsentStatus = _convertATTStatus(status);
        AppLovinMAX.setHasUserConsent(_lastConsentStatus == DSConsentStatus.obtained);
        DSMetrica.reportEvent('consent status', attributes: {
          'consent_status': '$_lastConsentStatus',
          'att_status': status,
          'position': 'init',
        });
      }
    }());
  }

  Future<void> dismiss() async {
    _instance = null;
    await DSAdsNativeLoaderMixin.disposeClass();
  }

  /// Wait for initialize lib. [maxWait] define stop wait after this period (default 5 seconds)
  static Future<void> waitForInit({final maxWait = const Duration(seconds: 5)}) async {
    final start = DateTime.now();
    while (true) {
      if (isInitialized) break;
      if (DateTime.now().difference(start) >= maxWait) {
        Fimber.e('Failed to wait DSAdsManager', stacktrace: StackTrace.current);
        break;
      }
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  DSConsentStatus get consentStatus => _lastConsentStatus;

  /// return true if consent available (for Android only)
  bool get isConsentAvailable => (consentStatus != DSConsentStatus.notRequired);

  DSConsentStatus _convertATTStatus(int status) {
    return switch (status) {
    // ToDo: need refactoring
      1 => DSConsentStatus.required,
    // ToDo: need refactoring
      2 => DSConsentStatus.required,
      3 => DSConsentStatus.obtained,
      _ => DSConsentStatus.unknown,
    };
  }
  
  /// Show consent window if consent available
  Future<bool> tryShowConsent() async {
    DSAdsAppOpen.lockUntilAppResume();
    try {
      if (Platform.isAndroid) {
        if (_consentForm == null) {
          final completerForm = Completer<ConsentForm?>();
          ConsentForm.loadConsentForm((ConsentForm consentForm) async {
            completerForm.complete(consentForm);
          }, (FormError error) {
            Fimber.e('Consent error: ${error.message} (${error.errorCode})', stacktrace: StackTrace.current);
            completerForm.complete(null);
          });
          _consentForm = await completerForm.future;
          if (_consentForm == null) {
            return false;
          }
        }
        final completer = Completer<bool>();
        _consentForm!.show(
              (FormError? error) async {
            _consentForm = null;
            if (error == null) {
              _lastConsentStatus = await ConsentInformation.instance.getConsentStatus();
              AppLovinMAX.setHasUserConsent(_lastConsentStatus == DSConsentStatus.obtained);
              DSMetrica.reportEvent('consent status', attributes: {
                'consent_status': '$_lastConsentStatus',
                'position': 'after dialog',
              });
              completer.complete(true);
            } else {
              Fimber.e('Consent error: ${error.message} (${error.errorCode})', stacktrace: StackTrace.current);
              completer.complete(false);
            }
          },
        );
        return await completer.future;
      }

      if (Platform.isIOS) {
        final status = await DSAdjust.requestATT();
        _lastConsentStatus = _convertATTStatus(status.toInt());
        AppLovinMAX.setHasUserConsent(_lastConsentStatus == DSConsentStatus.obtained);
        DSMetrica.reportEvent('consent status', attributes: {
          'consent_status': '$_lastConsentStatus',
          'att_status': status,
          'position': 'dialog',
        });
        return true;
      }
    } finally {
      DSAdsAppOpen.unlockUntilAppResume(andLockFor: const Duration(seconds: 2));
    }

    return false; // other platforms are not implemented yet
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
      case DSAdSource.rewarded:
        googleId = rewardedGoogleUnitId;
        appLovinId = rewardedAppLovinUnitId;
        break;
      case DSAdSource.appOpen:
        googleId = appOpenGoogleUnitId;
        appLovinId = appOpenAppLovinUnitId;
        break;
      case DSAdSource.appOpenSplash:
        googleId = appOpenSplashGoogleUnitId;
        appLovinId = appOpenSplashAppLovinUnitId;
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
              await initAppLovin();
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

  @Deprecated('Use initAppLovin() instead')
  Future<void> initAppLovine() => initAppLovin();

  /// Force init AppLovin dependency
  Future<void> initAppLovin() async {
    if (isMediationInitialized(DSAdMediation.appLovin)) return;

    _appLovinInit ??= () async {
      final start = DateTime.timestamp();
      onReportEvent?.call('ads_manager: AppLovin start initializing', {});
      if (appLovinSDKKey.isEmpty) {
        Fimber.e('AppLovin not initialized. SDKKey is empty', stacktrace: StackTrace.current);
        return;
      }
      await AppLovinMAX.initialize(appLovinSDKKey);
      _mediationInitialized.add(DSAdMediation.appLovin);
      final time = DateTime.timestamp().difference(start);
      onReportEvent?.call('ads_manager: AppLovin initialized', {
        'ads_init_sec': time.inSeconds,
        'ads_init_ms': time.inMilliseconds,
      });
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
