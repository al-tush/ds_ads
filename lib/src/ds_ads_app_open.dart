import 'dart:async';
import 'dart:ui';

import 'package:ds_ads/src/ds_ads_manager.dart';
import 'package:ds_ads/src/generic_ads/export.dart';
import 'package:ds_ads/src/google_ads/export.dart';
import 'package:ds_common/ds_common.dart';
import 'package:fimber/fimber.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'applovin_ads/applovin_ads.dart';
import 'ds_ads_types.dart';
import 'ds_ads_types_internal.dart';

part 'ds_ads_app_open_types.dart';

/// Allows to pre fetch and show Google and AppLovin MAX app open ads
class DSAdsAppOpen {
  static var _showLockedUntil = DateTime(0);
  static var _showLockedUntilAppResumed = false;
  static const _tag = 'ads_app_open';

  static var _showNum = 0;

  var _startLoadTime = DateTime(0);
  var _totalLoadDuration = Duration.zero;
  final _loadConditions = <DSAdsLoadCondition>{};

  /// Maximum duration allowed between loading and showing the ad.
  final maxCacheDuration = const Duration(hours: 4);

  var _lastLoadTime = DateTime(0);

  final DSAdSource source;
  final Duration loadRetryDelay;

  DateTime get lastLoadTime => _lastLoadTime;

  DSAppOpenAd? _ad;
  DSAdMediation? _mediation;
  var _adState = DSAdState.none;
  var _loadRetryCount = 0;

  var _isDisposed = false;

  DSAdState get adState => _adState;

  DSAdsAppOpen({
    required this.source,
    this.loadRetryDelay = const Duration(seconds: 1),
  }) : assert({DSAdSource.appOpen, DSAdSource.appOpenSplash}.contains(source));

  @internal
  void dispose() {
    _isDisposed = true;
    cancelCurrentAd(location: const DSAdLocation('internal_dispose'));
  }

  void cancelCurrentAd({
    required final DSAdLocation location,
  }) {
    _report('$_tag: cancel current ad (adState: $adState)',
        location: location, mediation: _mediation);
    if (adState == DSAdState.showing) return;
    _ad?.dispose();
    _ad = null;
    _mediation = null;
    _adState == DSAdState.none;
  }

  @internal
  void appLifecycleChanged(
      AppLifecycleState? oldState, AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_showLockedUntilAppResumed) {
        _showLockedUntilAppResumed = false;
        lockShowFor(const Duration(seconds: 1));
      }
    }
  }

  String _adUnitIdGoogle() {
    switch (source) {
      case DSAdSource.appOpen:
        return DSAdsManager.I.appOpenGoogleUnitId;
      case DSAdSource.appOpenSplash:
        return DSAdsManager.I.appOpenSplashGoogleUnitId;
      default:
        throw Exception('Unsupported source $source');
    }
  }

  String _adUnitIdAppLovin() {
    switch (source) {
      case DSAdSource.appOpen:
        return DSAdsManager.I.appOpenAppLovinUnitId;
      case DSAdSource.appOpenSplash:
        return DSAdsManager.I.appOpenSplashAppLovinUnitId;
      default:
        throw Exception('Unsupported source $source');
    }
  }

  String _adUnitId(DSAdMediation mediation) {
    final String id;
    switch (mediation) {
      case DSAdMediation.google:
        id = _adUnitIdGoogle();
      case DSAdMediation.appLovin:
        id = _adUnitIdAppLovin();
    }
    assert(
        id.isNotEmpty, 'empty adsId for mediation=$mediation source=$source');
    return id;
  }

  void _report(
    String eventName, {
    required DSAdLocation location,
    required DSAdMediation? mediation,
    String? adapter,
    Map<String, Object>? attributes,
  }) {
    DSAdsManager.I.onReportEvent?.call(eventName, {
      if (mediation != null) 'adUnitId': _adUnitId(mediation),
      'location': location.val,
      'mediation': '$mediation',
      if (adapter != null) 'adapter': adapter,
      ...?attributes,
    });
  }

  static final _locationErrReports = <DSAdLocation>{};

  bool _isDisabled(DSAdLocation location) {
    if (!location.isInternal &&
        DSAdsManager.I.locations?.contains(location) == false) {
      final msg = '$_tag: location $location not in locations';
      assert(false, msg);
      if (!_locationErrReports.contains(location)) {
        _locationErrReports.add(location);
        Fimber.e(msg, stacktrace: StackTrace.current);
      }
    }
    if (DSAdsManager.I.isAdAllowedCallbackProc(source, location) == false) {
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
    @internal final Function()? then,
  }) {
    assert(_checkCustomAttributes(customAttributes),
        'custom attributes must have custom_attr_ prefix');

    if (DSAdsManager.I.appState.isPremium || _isDisposed) {
      then?.call();
      return;
    }

    DSAdsManager.I.updateMediations(source);

    if (_isDisabled(location)) {
      then?.call();
      return;
    }

    if (DateTime.timestamp().difference(_lastLoadTime) > maxCacheDuration) {
      unawaited(_ad?.dispose());
      _ad = null;
      _adState = DSAdState.none;
    }

    if ([DSAdState.loading, DSAdState.loaded].contains(adState)) {
      then?.call();
      return;
    }
    if ([DSAdState.preShowing, DSAdState.showing].contains(adState)) {
      Fimber.w(
        '$_tag: fetching is prohibited when ad is showing',
        stacktrace: LimitedStackTrace(stackTrace: StackTrace.current),
      );
      then?.call();
      return;
    }

    final mediation = DSAdsManager.I.currentMediation(source);
    _mediation = mediation;
    if (mediation == null) {
      _report('$_tag: no mediation',
          location: location,
          mediation: mediation,
          attributes: customAttributes);
      return;
    }

    _report('$_tag: start loading',
        location: location, mediation: mediation, attributes: customAttributes);
    if (_startLoadTime.year == 0) {
      _startLoadTime = DateTime.timestamp();
    }

    Future<void> onAdLoaded(DSAppOpenAd ad) async {
      try {
        _totalLoadDuration = DateTime.timestamp().difference(_startLoadTime);
        _startLoadTime = DateTime(0);
        _report(
          '$_tag: loaded',
          location: location,
          mediation: mediation,
          adapter: ad.mediationAdapterClassName,
          attributes: {
            ...ad.getReportAttributes(),
            ...?customAttributes,
          },
        );
        await _ad?.dispose();
        _ad = ad;
        _adState = DSAdState.loaded;
        _lastLoadTime = DateTime.timestamp();
        _loadRetryCount = 0;

        then?.call();
        DSAdsManager.I.emitEvent(DSAdsAppOpenLoadedEvent._(ad: ad));
      } catch (e, stack) {
        then?.call();
        Fimber.e('$e', stacktrace: stack);
      }
    }

    Future<void> onAdFailedToLoad(
        DSAd ad, int errCode, String errDescription) async {
      try {
        final attrs = ad.getReportAttributes();
        unawaited(_ad?.dispose());
        _ad = null;
        _lastLoadTime = DateTime(0);
        _adState = DSAdState.error;
        _loadRetryCount++;
        _report('$_tag: failed to load',
            location: location,
            mediation: mediation,
            attributes: {
              'error_text': errDescription,
              'error_code': '$errCode ($mediation)',
              ...attrs,
              ...?customAttributes,
            });
        final oldMediation = DSAdsManager.I.currentMediation(source);
        await DSAdsManager.I
            .onLoadAdError(errCode, errDescription, mediation, source);
        _loadConditions.add(DSAdsLoadCondition.error);
        final newMediation = DSAdsManager.I.currentMediation(source);
        if (newMediation != oldMediation) {
          _loadRetryCount = 0;
          if (newMediation == null) {
            _loadConditions.add(DSAdsLoadCondition.mediationTimeout);
          } else {
            _loadConditions.add(DSAdsLoadCondition.mediationChanged);
          }
        }
        if (_loadRetryCount < DSAdsManager.I.getRetryMaxCount(source)) {
          await Future.delayed(loadRetryDelay);
          if ({DSAdState.none, DSAdState.error}.contains(adState) &&
              !_isDisposed) {
            _report('$_tag: retry loading',
                location: location,
                mediation: mediation,
                attributes: customAttributes);
            fetchAd(
                location: location,
                then: then,
                customAttributes: customAttributes);
          }
        } else {
          Fimber.w('$errDescription ($errCode)',
              stacktrace: StackTrace.current);
          _adState = DSAdState.none;
          then?.call();
          DSAdsManager.I.emitEvent(DSAdsAppOpenLoadFailedEvent._(
            errCode: errCode,
            errText: errDescription,
          ));
          _startLoadTime = DateTime(0);
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
    assert(_checkCustomAttributes(customAttributes),
        'custom attributes must have custom_attr_ prefix');

    if (DSAdsManager.I.appState.isPremium || _isDisposed) {
      then?.call();
      return;
    }

    if (_isDisabled(location)) {
      then?.call();
      return;
    }

    final startTime = DateTime.timestamp();

    if (_showLockedUntilAppResumed ||
        DateTime.timestamp().compareTo(_showLockedUntil) < 0) {
      then?.call();
      _report('$_tag: showing locked',
          location: location,
          mediation: _mediation,
          attributes: customAttributes);
      return;
    }

    if (!DSAdsManager.I.isInForeground) {
      _report('$_tag: app in background',
          location: location,
          mediation: _mediation,
          attributes: customAttributes);
      then?.call();
      // https://support.google.com/admob/answer/6201362#zippy=%2Cdisallowed-example-user-launches-app
      return;
    }

    if ([DSAdState.preShowing, DSAdState.showing].contains(adState)) {
      Fimber.e('showAd recall (adState: $adState)',
          stacktrace: StackTrace.current);
      _report('$_tag: showing canceled by error',
          location: location,
          mediation: _mediation,
          attributes: customAttributes);
      then?.call();
      return;
    }

    if ([DSAdState.none, DSAdState.loading, DSAdState.error]
        .contains(adState)) {
      _report(
        '$_tag: ad was not ready',
        location: location,
        mediation: _mediation,
        attributes: customAttributes,
      );
      then?.call();
      return;
    }

    if (DateTime.timestamp().difference(_lastLoadTime) > maxCacheDuration) {
      _report(
        '$_tag: loaded ad is too old',
        location: location,
        mediation: _mediation,
        adapter: _ad?.mediationAdapterClassName,
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
      Fimber.e('app open ad is null but state: $_adState',
          stacktrace: StackTrace.current);
      _report('$_tag: showing canceled by error',
          location: location,
          mediation: _mediation,
          attributes: customAttributes);
      then?.call();
      cancelCurrentAd(location: location);
      return;
    }

    final attrs = customAttributes ?? {};

    ad.onAdImpression = (ad) {
      try {
        _report('$_tag: impression',
            location: location,
            mediation: ad.mediation,
            adapter: ad.mediationAdapterClassName,
            attributes: attrs);
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onPaidEvent =
        (ad, valueMicros, precision, currencyCode, appLovinDspName) {
      try {
        DSAdsManager.I.onPaidEvent(ad, ad.mediation, location, valueMicros,
            precision, currencyCode, source, appLovinDspName, attrs);
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdShown = (ad) {
      try {
        final eventAttrs = attrs.putShowAdInfo(
          startShowRequest: startTime,
          totalLoadDuration: _totalLoadDuration,
          loadConditions: _loadConditions,
        );
        _totalLoadDuration = Duration.zero;

        _report('$_tag: showed full screen content',
            location: location,
            mediation: ad.mediation,
            adapter: ad.mediationAdapterClassName,
            attributes: eventAttrs);
        if (_isDisposed) {
          Fimber.e('showing disposed ad', stacktrace: StackTrace.current);
        }
        _adState = DSAdState.showing;
        onAdShow?.call();
        DSAdsManager.I.emitEvent(DSAdsAppOpenShowedEvent._(ad: ad));
        then?.call();
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdDismissed = (ad) {
      try {
        _report('$_tag: full screen content dismissed',
            location: location,
            mediation: ad.mediation,
            adapter: ad.mediationAdapterClassName,
            attributes: attrs);
        ad.dispose();
        _ad = null;
        _mediation = null;
        _adState = DSAdState.none;
        _lastLoadTime = DateTime(0);
        DSAdsManager.I.emitEvent(DSAdsAppOpenShowDismissedEvent._(ad: ad));
        onAdClosed?.call();
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdFailedToShow = (ad, int errCode, String errText) {
      try {
        _report('$_tag: showing canceled by error',
            location: location,
            mediation: _mediation,
            adapter: ad.mediationAdapterClassName,
            attributes: {
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
        DSAdsManager.I.emitEvent(const DSAdsAppOpenShowErrorEvent._());
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdClicked = (ad) {
      try {
        _report('$_tag: ad clicked',
            location: location,
            mediation: ad.mediation,
            adapter: ad.mediationAdapterClassName,
            attributes: attrs);
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };

    if (_isDisposed) {
      _report('$_tag: showing canceled: manager disposed',
          location: location, mediation: _mediation, attributes: attrs);
      then?.call();
      DSAdsManager.I.emitEvent(const DSAdsAppOpenShowErrorEvent._());
      return;
    }

    final res = await beforeAdShow?.call() ?? true;
    if (!res) {
      _report('$_tag: showing canceled by caller',
          location: location, mediation: _mediation, attributes: attrs);
      then?.call();
      DSAdsManager.I.emitEvent(const DSAdsAppOpenShowErrorEvent._());
      return;
    }

    _adState = DSAdState.preShowing;
    DSAdsManager.I.emitEvent(DSAdsAppOpenPreShowingEvent._(ad: ad));

    _showNum++;
    attrs['app_open_show_num'] = _showNum;

    _report('$_tag: start showing',
        location: location, mediation: _mediation, attributes: attrs);
    await ad.show();
  }

  static void lockUntilAppResume() {
    _showLockedUntilAppResumed = true;
  }

  static void unlockUntilAppResume({Duration? andLockFor}) {
    _showLockedUntilAppResumed = false;
    andLockFor?.let((it) => lockShowFor(it));
  }

  static void lockShowFor(Duration duration) {
    _showLockedUntil = DateTime.timestamp().add(duration);
  }
}
