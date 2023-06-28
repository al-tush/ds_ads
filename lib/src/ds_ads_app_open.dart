import 'dart:async';
import 'dart:ui';

import 'package:ds_ads/src/ds_ads_manager.dart';
import 'package:ds_ads/src/generic_ads/export.dart';
import 'package:ds_ads/src/google_ads/export.dart';
import 'package:ds_common/ds_common.dart';
import 'package:fimber/fimber.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'applovin_ads/applovin_ads.dart';
import 'ds_ads_types.dart';

part 'ds_ads_app_open_types.dart';

class DSAdsAppOpen {
  static var _showLockedUntil = DateTime(0);
  static var _showLockedUntilAppResumed = false;
  static const _tag = 'ads_app_open';

  static var _showNum = 0;

  /// Maximum duration allowed between loading and showing the ad.
  final maxCacheDuration = const Duration(hours: 4);

  var _lastLoadTime = DateTime(0);

  final Duration loadRetryDelay;
  DateTime get lastLoadTime => _lastLoadTime;

  DSAppOpenAd? _ad;
  DSAdMediation? _mediation;
  var _adState = DSAdState.none;
  var _loadRetryCount = 0;

  var _isDisposed = false;

  DSAdState get adState => _adState;

  DSAdsAppOpen({
    this.loadRetryDelay = const Duration(seconds: 1),
  });

  @internal
  void dispose() {
    _isDisposed = true;
    cancelCurrentAd(location: const DSAdLocation('internal_dispose'));
  }

  void cancelCurrentAd({
    required final DSAdLocation location,
  }) {
    _report('$_tag: cancel current ad (adState: $_adState)', location: location, mediation: _mediation);
    if (_adState == DSAdState.showing) return;
    _ad?.dispose();
    _ad = null;
    _mediation = null;
    _adState == DSAdState.none;
  }

  @internal
  void appLifecycleChanged(AppLifecycleState? oldState, AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_showLockedUntilAppResumed) {
        _showLockedUntilAppResumed = false;
        lockShowFor(const Duration(seconds: 1));
      }
    }
  }

  static String _adUnitId(DSAdMediation mediation) {
    switch (mediation) {
      case DSAdMediation.google:
        return DSAdsManager.instance.appOpenGoogleUnitId!;
      case DSAdMediation.appLovin:
        return DSAdsManager.instance.appOpenAppLovinUnitId!;
    }
  }

  void _report(String eventName, {
    required DSAdLocation location,
    required DSAdMediation? mediation,
    Map<String, Object>? attributes,
  }) {
    DSAdsManager.instance.onReportEvent?.call(eventName, {
      if (mediation != null)
        'adUnitId': _adUnitId(mediation),
      'location': location.val,
      'mediation': '$mediation',
      ...?attributes,
    });
  }

  static final _locationErrReports = <DSAdLocation>{};

  static bool _isDisabled(DSAdLocation location) {
    if (!location.isInternal && DSAdsManager.instance.locations?.contains(location) == false) {
      final msg = '$_tag: location $location not in locations';
      assert(false, msg);
      if (!_locationErrReports.contains(location)) {
        _locationErrReports.add(location);
        Fimber.e(msg, stacktrace: StackTrace.current);
      }
    }
    if (DSAdsManager.instance.isAdAllowedCallback?.call(DSAdSource.appOpen, location) == false) {
      Fimber.i('$_tag: disabled (location: $location)');
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

    DSAdsManager.instance.updateMediations(DSAdSource.appOpen);

    if (_isDisabled(location)) {
      then?.call();
      return;
    }

    if (DateTime.now().difference(_lastLoadTime) > maxCacheDuration) {
      unawaited(_ad?.dispose());
      _ad = null;
      _adState = DSAdState.none;
    }

    if ([DSAdState.loading, DSAdState.loaded].contains(_adState)) {
      then?.call();
      return;
    }
    if ([DSAdState.preShowing, DSAdState.showing].contains(_adState)) {
      Fimber.w('$_tag: fetching is prohibited when ad is showing',
        stacktrace: LimitedStackTrace(stackTrace: StackTrace.current),
      );
      then?.call();
      return;
    }

    final startTime = DateTime.now();
    final mediation = DSAdsManager.instance.currentMediation(DSAdSource.appOpen);
    _mediation = mediation;
    if (mediation == null) {
      _report('$_tag: no mediation', location: location, mediation: mediation, attributes: customAttributes);
      return;
    }

    _report('$_tag: start loading', location: location, mediation: mediation, attributes: customAttributes);

    Future<void> onAdLoaded(DSAppOpenAd ad) async {
      try {
        final duration = DateTime.now().difference(startTime);
        _report('$_tag: loaded', location: location, mediation: mediation, attributes: {
          'ad_loaded_seconds': duration.inSeconds,
          'ad_loaded_milliseconds': duration.inMilliseconds,
          ...?customAttributes,
        });
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
        _report('$_tag: failed to load', location: location, mediation: mediation, attributes: {
          'error_text': errDescription,
          'error_code': '$errCode ($mediation)',
          'ad_load_error_seconds': duration.inSeconds,
          'ad_load_error_milliseconds': duration.inMilliseconds,
          ...?customAttributes,
        });
        final oldMediation = DSAdsManager.instance.currentMediation(DSAdSource.appOpen);
        await DSAdsManager.instance.onLoadAdError(errCode, errDescription, mediation, DSAdSource.appOpen);
        if (DSAdsManager.instance.currentMediation(DSAdSource.appOpen) != oldMediation) {
          _loadRetryCount = 0;
        }
        if (_loadRetryCount < DSAdsManager.instance.getRetryMaxCount(DSAdSource.appOpen)) {
          await Future.delayed(loadRetryDelay);
          if ({DSAdState.none, DSAdState.error}.contains(_adState) && !_isDisposed) {
            _report('$_tag: retry loading', location: location, mediation: mediation, attributes: customAttributes);
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
          DSGoogleAppOpenAd(adUnitId: _adUnitId(mediation)).load(
            orientation: AppOpenAd.orientationPortrait,
            onAdLoaded: onAdLoaded,
            onAdFailedToLoad: onAdFailedToLoad,
          );
          break;
        case DSAdMediation.appLovin:
          DSAppLovinAppOpenAd(adUnitId: _adUnitId(mediation)).load(
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

    if (_showLockedUntilAppResumed || DateTime.now().compareTo(_showLockedUntil) < 0) {
      then?.call();
      _report('$_tag: showing locked', location: location, mediation: _mediation, attributes: customAttributes);
      return;
    }

    if (!DSAdsManager.instance.isInForeground) {
      _report('$_tag: app in background', location: location, mediation: _mediation, attributes: customAttributes);
      then?.call();
      // https://support.google.com/admob/answer/6201362#zippy=%2Cdisallowed-example-user-launches-app
      return;
    }

    if ([DSAdState.preShowing, DSAdState.showing].contains(_adState)) {
      Fimber.e('showAd recall (adState: $_adState)', stacktrace: StackTrace.current);
      _report('$_tag: showing canceled by error', location: location, mediation: _mediation, attributes: customAttributes);
      then?.call();
      return;
    }

    if ([DSAdState.none, DSAdState.loading, DSAdState.error].contains(_adState)) {
      _report('$_tag: ad was not ready',
        location: location,
        mediation: _mediation,
        attributes: customAttributes,
      );
      then?.call();
      return;
    }

    if (DateTime.now().difference(_lastLoadTime) > maxCacheDuration) {
      _report('$_tag: loaded ad is too old',
        location: location,
        mediation: _mediation,
        attributes: customAttributes,
      );
      await _ad?.dispose();
      _ad = null;
      _mediation = null;
      _adState = DSAdState.none;
      then?.call();
      return;
    }

    final ad = _ad;
    if (ad == null) {
      Fimber.e('app open ad is null but state: $_adState', stacktrace: StackTrace.current);
      _report('$_tag: showing canceled by error', location: location, mediation: _mediation, attributes: customAttributes);
      then?.call();
      cancelCurrentAd(location: location);
      return;
    }

    final attrs = customAttributes ?? {};

    ad.onAdImpression = (ad) {
      try {
        _report('$_tag: impression', location: location, mediation: _mediation, attributes: attrs);
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onPaidEvent = (ad, valueMicros, precision, currencyCode, appLovinDspName) {
      try {
        DSAdsManager.instance.onPaidEvent(ad, _mediation!, location, valueMicros, precision, currencyCode,
            DSAdSource.appOpen, appLovinDspName, attrs);
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdShown = (ad) {
      try {
        _report('$_tag: showed full screen content', location: location, mediation: _mediation, attributes: attrs);
        if (_isDisposed) {
          Fimber.e('showing disposed ad', stacktrace: StackTrace.current);
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
        _report('$_tag: full screen content dismissed', location: location, mediation: _mediation, attributes: attrs);
        ad.dispose();
        _ad = null;
        _mediation = null;
        _adState = DSAdState.none;
        _lastLoadTime = DateTime(0);
        DSAdsManager.instance.emitEvent(DSAdsAppOpenShowDismissedEvent._(ad: ad));
        onAdClosed?.call();
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdFailedToShow = (ad, int errCode, String errText) {
      try {
        _report('$_tag: showing canceled by error', location: location, mediation: _mediation, attributes: {
          'app_open_error_code': errCode,
          'app_open_error_text': errText,
          ...attrs
        });
        Fimber.e('$errText ($errCode)', stacktrace: StackTrace.current);
        ad.dispose();
        _ad = null;
        _mediation = null;
        _adState = DSAdState.none;
        onFailedToShow?.call(errCode, errText);
        then?.call();
        DSAdsManager.instance.emitEvent(const DSAdsAppOpenShowErrorEvent._());
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdClicked = (ad) {
      try {
        _report('$_tag: ad clicked', location: location, mediation: _mediation, attributes: attrs);
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };

    if (_isDisposed) {
      _report('$_tag: showing canceled: manager disposed', location: location, mediation: _mediation, attributes: attrs);
      then?.call();
      DSAdsManager.instance.emitEvent(const DSAdsAppOpenShowErrorEvent._());
      return;
    }

    final res = await beforeAdShow?.call() ?? true;
    if (!res) {
      _report('$_tag: showing canceled by caller', location: location, mediation: _mediation, attributes: attrs);
      then?.call();
      DSAdsManager.instance.emitEvent(const DSAdsAppOpenShowErrorEvent._());
      return;
    }

    _adState = DSAdState.preShowing;
    DSAdsManager.instance.emitEvent(DSAdsAppOpenPreShowingEvent._(ad: ad));

    _showNum++;
    attrs['app_open_show_num'] = _showNum;

    _report('$_tag: start showing', location: location, mediation: _mediation, attributes: attrs);
    await ad.show();
  }

  static void lockUntilAppResume() {
    _showLockedUntilAppResumed = true;
  }

  static void unlockUntilAppResume() {
    _showLockedUntilAppResumed = false;
  }

  static void lockShowFor(Duration duration) {
    _showLockedUntil = DateTime.now().add(duration);
  }

}
