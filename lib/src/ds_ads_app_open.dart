import 'dart:async';

import 'package:ds_ads/src/ds_ads_manager.dart';
import 'package:ds_ads/src/generic_ads/export.dart';
import 'package:ds_ads/src/google_ads/export.dart';
import 'package:fimber/fimber.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'applovin_ads/applovin_ads.dart';
import 'ds_ads_types.dart';

part 'ds_ads_app_open_types.dart';

class DSAdsAppOpen {
  static var _showLockedUntil = DateTime(0);

  /// Maximum duration allowed between loading and showing the ad.
  final maxCacheDuration = const Duration(hours: 4);

  var _lastLoadTime = DateTime(0);

  final int loadRetryMaxCount;
  final Duration loadRetryDelay;
  DateTime get lastLoadTime => _lastLoadTime;

  DSAppOpenAd? _ad;
  var _adState = DSAdState.none;
  var _loadRetryCount = 0;

  var _isDisposed = false;

  DSAdState get adState => _adState;

  DSAdsAppOpen({
    this.loadRetryMaxCount = 3,
    this.loadRetryDelay = const Duration(seconds: 1),
  });

  void dispose() {
    _isDisposed = true;
    cancelCurrentAd(location: const DSAdLocation('internal_dispose'));
  }

  void cancelCurrentAd({
    required final DSAdLocation location,
  }) {
    _report('ads_app_open: cancel current ad (adState: $_adState)', location: location);
    if (_adState == DSAdState.showing) return;
    _ad?.dispose();
    _ad = null;
    _adState == DSAdState.none;
  }

  static String get adUnitId {
    final mediation = DSAdsManager.instance.currentMediation(DSMediationType.main);
    if (mediation == null) {
      return 'noMediation';
    }
    switch (mediation) {
      case DSAdMediation.google:
        return DSAdsManager.instance.appOpenGoogleUnitId!;
      case DSAdMediation.appLovin:
        return DSAdsManager.instance.appOpenAppLovinUnitId!;
    }
  }

  void _report(String eventName, {
    required DSAdLocation location,
    Map<String, Object>? attributes,
  }) {
    DSAdsManager.instance.onReportEvent?.call(eventName, {
      'adUnitId': adUnitId,
      'location': location.val,
      'mediation': '${DSAdsManager.instance.currentMediation(DSMediationType.main)}',
      ...?attributes,
    });
  }

  static final _locationErrReports = <DSAdLocation>{};

  static bool _isDisabled(DSAdLocation location) {
    if (!location.isInternal && DSAdsManager.instance.locations?.contains(location) == false) {
      final msg = 'ads_app_open: location $location not in locations';
      assert(false, msg);
      if (!_locationErrReports.contains(location)) {
        _locationErrReports.add(location);
        Fimber.e(msg, stacktrace: StackTrace.current);
      }
    }
    if (DSAdsManager.instance.isAdAllowedCallback?.call(DSAdSource.appOpen, location) == false) {
      Fimber.i('ads_app_open: disabled (location: $location)');
      return true;
    }
    return false;
  }

  bool _checkCustomAttributes(Map<String, Object>? attrs) {
    if (attrs == null) return true;
    return attrs.keys.every((e) => e.startsWith('custom_attr_'));
  }

  /// Fetch app open ad
  void fetchAd({
    required final DSAdLocation location,
    Map<String, Object>? customAttributes,
    @internal
    final Function()? then,
  }) {
    assert(_checkCustomAttributes(customAttributes), 'custom attributes must have custom_attr_ prefix');

    if (DSAdsManager.instance.appState.isPremium || _isDisposed) {
      then?.call();
      return;
    }

    unawaited(DSAdsManager.instance.checkMediation(DSMediationType.main)); // ToDo: fix to await?

    if (_isDisabled(location)) {
      then?.call();
      return;
    }

    if (DateTime.now().difference(_lastLoadTime) > maxCacheDuration) {
      _ad = null;
      _adState = DSAdState.none;
    }

    if ([DSAdState.loading, DSAdState.loaded].contains(_adState)) {
      then?.call();
      return;
    }
    if ([DSAdState.preShowing, DSAdState.showing].contains(_adState)) {
      Fimber.i('ads_app_open: fetching is prohibited when ad is showing',
        stacktrace: LimitedStackTrace(stackTrace: StackTrace.current),
      );
      then?.call();
      return;
    }

    final startTime = DateTime.now();
    _report('ads_app_open: start loading', location: location, attributes: customAttributes);
    final mediation = DSAdsManager.instance.currentMediation(DSMediationType.main)!;

    Future<void> onAdLoaded(DSAppOpenAd ad) async {
      try {
        final duration = DateTime.now().difference(startTime);
        _report('ads_app_open: loaded', location: location, attributes: {
          'mediation': '$mediation', // override
          'google_ads_loaded_seconds': duration.inSeconds,
          'google_ads_loaded_milliseconds': duration.inMilliseconds,
          ...?customAttributes,
        });
        ad.onPaidEvent = (ad, valueMicros, precision, currencyCode, appLovinDspName) {
          DSAdsManager.instance.onPaidEvent(ad, mediation, location, valueMicros, precision, currencyCode, DSAdSource.appOpen, appLovinDspName);
        };

        await _ad?.dispose();
        _ad = ad;
        _adState = DSAdState.loaded;
        _lastLoadTime = DateTime.now();
        _loadRetryCount = 0;

        then?.call();
        DSAdsManager.instance.emitEvent(DSAdsAppOpenLoadedEvent._(ad: ad));
      } catch (e, stack) {
        then?.call();
        Fimber.e('$e', stacktrace: stack);
      }
    }
    Future<void> onAdFailedToLoad(DSAd ad, int errCode, String errDescription) async {
      try {
        final duration = DateTime.now().difference(startTime);
        unawaited(_ad?.dispose());
        _ad = null;
        _lastLoadTime = DateTime(0);
        _adState = DSAdState.error;
        _loadRetryCount++;
        _report('ads_app_open: failed to load', location: location, attributes: {
          'error_text': errDescription,
          'error_code': '$errCode ($mediation)',
          'mediation': '$mediation', // override
          'google_ads_load_error_seconds': duration.inSeconds,
          'google_ads_load_error_milliseconds': duration.inMilliseconds,
          ...?customAttributes,
        });
        final oldMediation = DSAdsManager.instance.currentMediation(DSMediationType.main);
        await DSAdsManager.instance.onLoadAdError(errCode, errDescription, mediation, DSAdSource.appOpen);
        if (DSAdsManager.instance.currentMediation(DSMediationType.main) != oldMediation) {
          _loadRetryCount = 0;
        }
        if (_loadRetryCount < loadRetryMaxCount) {
          await Future.delayed(loadRetryDelay);
          if ({DSAdState.none, DSAdState.error}.contains(_adState) && !_isDisposed) {
            _report('ads_app_open: retry loading', location: location, attributes: {
              'mediation': '$mediation', // override
              ...?customAttributes,
            });
            fetchAd(location: location, then: then, customAttributes: customAttributes);
          }
        } else {
          Fimber.w('$errDescription ($errCode)', stacktrace: StackTrace.current);
          _adState = DSAdState.none;
          then?.call();
          DSAdsManager.instance.emitEvent(DSAdsAppOpenLoadFailedEvent._(
            errCode: errCode,
            errText: errDescription,
          ));
        }
      } catch (e, stack) {
        then?.call();
        Fimber.e('$e', stacktrace: stack);
      }
    }

    try {
      switch (mediation) {
        case DSAdMediation.google:
          DSGoogleAppOpenAd(adUnitId: adUnitId).load(
            orientation: AppOpenAd.orientationPortrait,
            onAdLoaded: onAdLoaded,
            onAdFailedToLoad: onAdFailedToLoad,
          );
          break;
        case DSAdMediation.appLovin:
          DSAppLovinAppOpenAd(adUnitId: adUnitId).load(
            onAdLoaded: onAdLoaded,
            onAdFailedToLoad: onAdFailedToLoad,
          );
          break;
      }
    } catch (e, stack) {
      then?.call();
      Fimber.e('$e', stacktrace: stack);
    }

    _adState = DSAdState.loading;
  }

  /// Show app open ad
  /// [location] sets location attribute to report (any string allowed)
  /// [beforeAdShow] allows to cancel ad by return false
  Future<void> showAd({
    required final DSAdLocation location,
    final Future<bool> Function()? beforeAdShow,
    final Function()? onAdShow,
    final Function(int errCode, String errText)? onFailedToShow,
    final Function()? onAdClosed,
    final Function()? then,
    Map<String, Object>? customAttributes,
  }) async {
    assert(!location.isInternal);
    assert(_checkCustomAttributes(customAttributes), 'custom attributes must have custom_attr_ prefix');

    if (DSAdsManager.instance.appState.isPremium || _isDisposed) {
      then?.call();
      return;
    }

    if (_isDisabled(location)) {
      then?.call();
      return;
    }

    if (DateTime.now().compareTo(_showLockedUntil) < 0) {
      then?.call();
      _report('ads_app_open: showing locked', location: location, attributes: customAttributes);
      return;
    }

    if (!DSAdsManager.instance.appState.isInForeground) {
      then?.call();
      // https://support.google.com/admob/answer/6201362#zippy=%2Cdisallowed-example-user-launches-app
      return;
    }

    if ([DSAdState.preShowing, DSAdState.showing].contains(_adState)) {
      Fimber.e('showAd recall (adState: $_adState)', stacktrace: StackTrace.current);
      _report('ads_app_open: showing canceled by error', location: location, attributes: customAttributes);
      then?.call();
      return;
    }

    if ([DSAdState.none, DSAdState.loading, DSAdState.error].contains(_adState)) {
      _report('ads_app_open: ad was not ready',
        location: location,
        attributes: customAttributes,
      );
      then?.call();
      return;
    }

    if (DateTime.now().difference(_lastLoadTime) > maxCacheDuration) {
      _report('ads_app_open: loaded ad is too old',
        location: location,
        attributes: customAttributes,
      );
      await _ad?.dispose();
      _ad = null;
      _adState = DSAdState.none;
      then?.call();
      return;
    }

    final ad = _ad;
    if (ad == null) {
      Fimber.e('app open ad is null but state: $_adState', stacktrace: StackTrace.current);
      _report('ads_app_open: showing canceled by error', location: location, attributes: customAttributes);
      then?.call();
      cancelCurrentAd(location: location);
      return;
    }

    ad.onAdImpression = (ad) {
      try {
        _report('ads_app_open: impression', location: location, attributes: customAttributes);
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdShown = (ad) {
      try {
        _report('ads_app_open: showed full screen content', location: location, attributes: customAttributes);
        if (_isDisposed) {
          Fimber.e('ads_app_open: showing disposed ad', stacktrace: StackTrace.current);
        }
        _adState = DSAdState.showing;
        onAdShow?.call();
        DSAdsManager.instance.emitEvent(DSAdsAppOpenShowedEvent._(ad: ad));
        then?.call();
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdDismissed = (ad) {
      try {
        _report('ads_app_open: full screen content dismissed', location: location, attributes: customAttributes);
        ad.dispose();
        _ad = null;
        _adState = DSAdState.none;
        _lastLoadTime = DateTime(0);
        onAdClosed?.call();
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdFailedToShow = (ad, int errCode, String errText) {
      try {
        _report('ads_app_open: showing canceled by error', location: location, attributes: customAttributes);
        Fimber.e('$errText ($errCode)', stacktrace: StackTrace.current);
        ad.dispose();
        _ad = null;
        _adState = DSAdState.none;
        onFailedToShow?.call(errCode, errText);
        then?.call();
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdClicked = (ad) {
      try {
        _report('ads_app_open: ad clicked', location: location, attributes: customAttributes);
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };

    if (_isDisposed) {
      _report('ads_app_open: showing canceled: manager disposed', location: location, attributes: customAttributes);
      then?.call();
      return;
    }

    final res = await beforeAdShow?.call() ?? true;
    if (!res) {
      _report('ads_app_open: showing canceled by caller', location: location, attributes: customAttributes);
      then?.call();
      return;
    }

    _adState = DSAdState.preShowing;

    _report('ads_app_open: start showing', location: location, attributes: customAttributes);
    await ad.show();
  }

  static void lockShowFor(Duration duration) {
    _showLockedUntil = DateTime.now().add(duration);
  }

}
