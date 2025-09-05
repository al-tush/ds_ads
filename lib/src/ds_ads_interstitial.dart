import 'dart:async';

import 'package:ds_ads/src/applovin_ads/applovin_ads.dart';
import 'package:ds_ads/src/ds_ads_manager.dart';
import 'package:ds_ads/src/ds_ads_overlay_screen.dart';
import 'package:ds_ads/src/ds_ads_types_internal.dart';
import 'package:ds_ads/src/generic_ads/export.dart';
import 'package:ds_ads/src/google_ads/export.dart';
import 'package:ds_common/ds_common.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'ds_ads_app_open.dart';
import 'ds_ads_types.dart';

part 'ds_ads_interstitial_types.dart';

/// Allows to pre fetch and show Google and AppLovin MAX interstitials
class DSAdsInterstitial {
  static var _lastShowTime = DateTime(0);
  static const _tag = 'ads_interstitial';

  static var _showNum = 0;
  static int get showCount => _showNum;

  var _startLoadTime = DateTime(0);
  var _finishLoadTime = DateTime(0);
  var _totalLoadDuration = Duration.zero;
  final _loadConditions = <DSAdsLoadCondition>{};

  DSAdState get adState => _adState;

  DSAdMediation? _getMediation() {
    final m = DSAdsManager.I.currentMediation(source);
    if (m == null) return null;
    if (_adUnitIdGoogle().isNotEmpty && _adUnitIdAppLovin().isEmpty) {
      return DSAdMediation.google;
    }
    if (_adUnitIdGoogle().isEmpty && _adUnitIdAppLovin().isNotEmpty) {
      return DSAdMediation.appLovin;
    }
    return m;
  }

  String _adUnitIdGoogle() {
    switch (source) {
      case DSAdSource.interstitial:
        return DSAdsManager.I.interstitialGoogleUnitId;
      case DSAdSource.interstitialSplash:
        return DSAdsManager.I.interstitialSplashGoogleUnitId;
      case DSAdSource.interstitial2:
        return DSAdsManager.I.interstitial2GoogleUnitId;
      default:
        throw Exception('Unsupported source $source');
    }
  }

  String _adUnitIdAppLovin() {
    switch (source) {
      case DSAdSource.interstitial:
        return DSAdsManager.I.interstitialAppLovinUnitId;
      case DSAdSource.interstitialSplash:
        return DSAdsManager.I.interstitialSplashAppLovinUnitId;
      case DSAdSource.interstitial2:
        return DSAdsManager.I.interstitial2AppLovinUnitId;
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
    assert(id.isNotEmpty, 'empty adsId for mediation=$mediation source=$source');
    return id;
  }

  final DSAdSource source;
  final Duration loadRetryDelay;

  DSInterstitialAd? _ad;
  var _adState = DSAdState.none;
  var _loadRetryCount = 0;
  var _isDisposed = false;
  DSAdMediation? _mediation;

  late final state = DSStateStub(owner: this);

  DSAdsInterstitial({
    required this.source,
    this.loadRetryDelay = const Duration(seconds: 1),
  }) : assert({DSAdSource.interstitial, DSAdSource.interstitial2, DSAdSource.interstitialSplash}.contains(source));

  @internal
  void dispose() {
    _isDisposed = true;
    cancelCurrentAd(location: const DSAdLocation('internal_dispose'));
  }

  void _report(
    String eventName, {
    required DSAdLocation location,
    required DSAdMediation? mediation,
    String? customAdId,
    String? adapter,
    Map<String, Object>? attributes,
  }) {
    DSAdsManager.I.onReportEvent?.call(eventName, {
      if (mediation != null) 'adUnitId': customAdId ?? _adUnitId(mediation),
      'location_source': source.name,
      'location': location.val,
      'mediation': '$mediation',
      if (adapter != null) 'adapter': adapter,
      ...?attributes,
    });
  }

  static final _locationErrReports = <DSAdLocation>{};

  bool _isDisabled(DSAdLocation location) {
    if (!location.isInternal && DSAdsManager.I.locations?.contains(location) == false) {
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
    if (_getMediation() == null) {
      _report('$_tag: disabled (no mediation)', location: location, mediation: null);
      return true;
    }
    return false;
  }

  bool _checkCustomAttributes(Map<String, Object>? attrs) {
    if (attrs == null) return true;
    return attrs.keys.every((e) => e.startsWith('custom_attr_'));
  }

  /// Fetch interstitial ad
  void fetchAd({
    required final DSAdLocation location,
    Map<String, Object>? customAttributes,
    @internal final Function()? then,
  }) {
    assert(_checkCustomAttributes(customAttributes), 'custom attributes must have custom_attr_ prefix');

    if (DSAdsManager.I.isPremium || _isDisposed) {
      then?.call();
      return;
    }

    DSAdsManager.I.updateMediations(source);

    if (_isDisabled(location)) {
      then?.call();
      return;
    }

    if ([DSAdState.loading, DSAdState.loaded].contains(adState)) {
      then?.call();
      return;
    }
    if ([DSAdState.preShowing, DSAdState.showing].contains(adState)) {
      Fimber.i(
        '$_tag: fetching is prohibited when ad is showing',
        stacktrace: LimitedStackTrace(stackTrace: StackTrace.current),
      );
      then?.call();
      return;
    }

    final interstitialFetchDelay = DSAdsManager.I.interstitialFetchDelayCallback?.call() ?? const Duration();
    if (DateTime.timestamp().difference(_lastShowTime) < interstitialFetchDelay) {
      then?.call();
      unawaited(() async {
        final spent = DateTime.timestamp().difference(_lastShowTime);
        final delay = interstitialFetchDelay - spent;
        await Future.delayed(delay);
        fetchAd(location: const DSAdLocation('internal_fetch_delayed'), customAttributes: customAttributes);
      }());
      return;
    }

    final mediation = _getMediation();
    _mediation = mediation;
    if (mediation == null) {
      _report('$_tag: no mediation', location: location, mediation: mediation, attributes: customAttributes);
      return;
    }
    _report('$_tag: start loading', location: location, mediation: mediation, attributes: customAttributes);
    if (_startLoadTime.year == 0) {
      _startLoadTime = DateTime.timestamp();
      _finishLoadTime = DateTime(0);
    }

    Future<void> onAdLoaded(DSInterstitialAd ad) async {
      try {
        _totalLoadDuration = DateTime.timestamp().difference(_startLoadTime);
        _startLoadTime = DateTime(0);
        _finishLoadTime = DateTime.timestamp();
        unawaited(DSMetrica.putErrorEnvironmentValue('ads_last_action', 'inter_loaded'));
        unawaited(DSMetrica.putErrorEnvironmentValue('ads_inter_adapter', ad.mediationAdapterClassName));
        _report(
          '$_tag: loaded',
          location: location,
          mediation: mediation,
          customAdId: ad.adUnitId,
          adapter: ad.mediationAdapterClassName,
          attributes: {
            ...ad.getReportAttributes(),
            ...?customAttributes,
          },
        );
        await _ad?.dispose();
        _adState = DSAdState.loaded;
        _ad = ad;
        _loadRetryCount = 0;
        then?.call();
        DSAdsManager.I.emitEvent(DSAdsInterstitialLoadedEvent._(source: source, ad: ad));
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    }

    Future<void> onAdFailedToLoad(DSAd ad, int errCode, String errDescription) async {
      try {
        final attrs = ad.getReportAttributes();
        await _ad?.dispose();
        _ad = null;
        _adState = DSAdState.error;
        _loadRetryCount++;
        unawaited(DSMetrica.putErrorEnvironmentValue('ads_last_action', 'inter_loading_failed'));
        unawaited(DSMetrica.putErrorEnvironmentValue('ads_inter_adapter', ad.mediationAdapterClassName));

        _report(
          '$_tag: failed to load',
          location: location,
          mediation: mediation,
          adapter: ad.mediationAdapterClassName,
          attributes: {
            'error_text': errDescription,
            'error_code': '$errCode ($mediation)',
            ...attrs,
            ...?customAttributes,
          },
        );
        await DSAdsManager.I.onLoadAdError(errCode, errDescription, mediation, source);
        _loadConditions.add(DSAdsLoadCondition.error);
        final newMediation = _getMediation();
        if (newMediation != _mediation) {
          _loadRetryCount = 0;
          if (newMediation == null) {
            _loadConditions.add(DSAdsLoadCondition.mediationTimeout);
          } else {
            _loadConditions.add(DSAdsLoadCondition.mediationChanged);
          }
        }
        _mediation = null;
        if (_loadRetryCount < DSAdsManager.I.getRetryMaxCount(source)) {
          await Future.delayed(loadRetryDelay);
          if ({DSAdState.none, DSAdState.error}.contains(adState) && !_isDisposed) {
            _report('$_tag: retry loading', location: location, mediation: _mediation, attributes: customAttributes);
            fetchAd(location: location, then: then, customAttributes: customAttributes);
          }
        } else {
          Fimber.w('$errDescription ($errCode)', stacktrace: StackTrace.current);
          _adState = DSAdState.none;
          then?.call();
          DSAdsManager.I.emitEvent(DSAdsInterstitialLoadFailedEvent._(
            source: source,
            errCode: errCode,
            errText: errDescription,
          ));
          _startLoadTime = DateTime(0);
        }
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    }

    switch (mediation) {
      case DSAdMediation.google:
        DSGoogleInterstitialAd(adUnitId: _adUnitId(mediation)).load(
          onAdLoaded: onAdLoaded,
          onAdFailedToLoad: onAdFailedToLoad,
        );
        break;
      case DSAdMediation.appLovin:
        DSAppLovinInterstitialAd(adUnitId: _adUnitId(mediation)).load(
          onAdLoaded: onAdLoaded,
          onAdFailedToLoad: onAdFailedToLoad,
        );
        break;
    }

    _adState = DSAdState.loading;
  }

  void cancelCurrentAd({
    required final DSAdLocation location,
  }) {
    _report('$_tag: cancel current ad (adState: $adState)', location: location, mediation: _mediation);
    if (adState == DSAdState.showing) return;
    _ad?.dispose();
    _ad = null;
    _adState = DSAdState.none;
    _mediation = null;
  }

  /// Show interstitial ad. Can wait fetching if [dismissAdAfter] (or [dismissAdAfterCallback]) more than zero.
  /// [allowFetchNext] allows start fetching after show interstitial ad.
  /// [location] sets location attribute to report (any string allowed)
  /// [beforeAdShow] allows to cancel ad by return false
  /// [counterIntervals] show counter before ad (0 if hide counter, [counterDuration] is interval of counter). If positive [context] must be assigned
  Future<void> showAd({
    required final DSAdLocation location,
    BuildContext? context,
    final Duration dismissAdAfter = const Duration(),
    final Duration Function()? dismissAdAfterCallback,
    @Deprecated('Use counterDuration instead')
    final int counterDelaySec = 0,
    final int counterIntervals = 0,
    final Duration counterDuration = const Duration(milliseconds: 670),
    final Future<bool> Function()? beforeAdShow,
    final Function()? onAdShow,
    final Function(int errCode, String errText)? onFailedToShow,
    final Function()? onAdClosed,
    final Function()? then,
    final Function()? onShowLock,
    Map<String, Object>? customAttributes,
  }) async {
    assert(!location.isInternal);
    assert(counterDelaySec == 0 || context != null, 'context must be assigned to show counter dialog before ad');
    assert(counterIntervals == 0 || context != null, 'context must be assigned to show counter dialog before ad');
    // assert(_checkCustomAttributes(customAttributes), 'custom attributes must have custom_attr_ prefix');

    if (DSAdsManager.I.isPremium || _isDisposed) {
      then?.call();
      return;
    }

    if (_isDisabled(location)) {
      then?.call();
      return;
    }

    final startTime = DateTime.timestamp();

    if (!DSAdsManager.I.isInForeground) {
      _report('$_tag: app in background', location: location, mediation: _mediation, attributes: customAttributes);
      then?.call();
      fetchAd(location: location, customAttributes: customAttributes);
      // https://support.google.com/admob/answer/6201362#zippy=%2Cdisallowed-example-user-launches-app
      return;
    }

    if ([DSAdState.preShowing, DSAdState.showing].contains(adState)) {
      Fimber.e('showAd recall (adState: $adState)', stacktrace: StackTrace.current);
      _report('$_tag: showing canceled by error',
          location: location, mediation: _mediation, attributes: customAttributes);
      then?.call();
      return;
    }

    Duration calcDismissAdAfter() {
      if (dismissAdAfterCallback != null) {
        return dismissAdAfterCallback();
      }
      return dismissAdAfter;
    }

    if ([DSAdState.none, DSAdState.loading, DSAdState.error].contains(adState)) {
      if (calcDismissAdAfter().inSeconds <= 0) {
        _report(
          '$_tag: showing canceled: not ready immediately (dismiss ad after ${calcDismissAdAfter().inSeconds}s, state: $adState)',
          location: location,
          mediation: _mediation,
          attributes: customAttributes,
        );
        then?.call();
        DSAdsManager.I.emitEvent(DSAdsInterstitialShowErrorEvent._(source: source));
      } else {
        var processed = false;
        final timeout = calcDismissAdAfter();
        Timer(timeout, () {
          if (processed) return;
          processed = true;
          _report(
            '$_tag: showing canceled: not ready after ${timeout.inSeconds}s, state: $adState',
            location: location,
            mediation: _mediation,
            attributes: customAttributes,
          );
          then?.call();
        });
        fetchAd(
          location: location,
          customAttributes: customAttributes,
          then: () async {
            while (adState == DSAdState.loading || adState == DSAdState.error) {
              await Future.delayed(const Duration(milliseconds: 100));
            }
            if (processed) return;
            processed = true;
            if (_isDisposed) {
              _report(
                '$_tag: showing canceled: manager disposed',
                location: location,
                mediation: _mediation,
                attributes: customAttributes,
              );
              then?.call();
              DSAdsManager.I.emitEvent(DSAdsInterstitialShowErrorEvent._(source: source));
              return;
            }
            if (adState == DSAdState.none) {
              // Failed to fetch ad
              then?.call();
              DSAdsManager.I.emitEvent(DSAdsInterstitialShowErrorEvent._(source: source));
              return;
            }
            await showAd(
              location: location,
              beforeAdShow: beforeAdShow,
              onAdShow: onAdShow,
              onFailedToShow: onFailedToShow,
              onAdClosed: onAdClosed,
              then: then,
              customAttributes: customAttributes,
            );
          },
        );
      }
      return;
    }

    final interstitialShowLock = DSAdsManager.I.interstitialShowLockedProc(location);
    if (DateTime.timestamp().difference(_lastShowTime) < interstitialShowLock) {
      _report(
        '$_tag: showing canceled: locked for ${interstitialShowLock.inSeconds}s',
        location: location,
        mediation: _mediation,
        attributes: customAttributes,
      );
      onShowLock?.call();
      then?.call();
      DSAdsManager.I.emitEvent(DSAdsInterstitialShowLockEvent._(source: source));
      return;
    }

    final ad = _ad;
    if (ad == null) {
      Fimber.e('ad is null but state: $adState', stacktrace: StackTrace.current);
      _report('$_tag: showing canceled by error',
          location: location, mediation: _mediation, attributes: customAttributes);
      then?.call();
      cancelCurrentAd(location: location);
      DSAdsManager.I.emitEvent(DSAdsInterstitialShowErrorEvent._(source: source));
      return;
    }

    final attrs = customAttributes ?? {};

    ad.onAdImpression = (ad) {
      try {
        unawaited(DSMetrica.putErrorEnvironmentValue('ads_last_action', 'inter_impression'));
        unawaited(DSMetrica.putErrorEnvironmentValue('ads_inter_adapter', ad.mediationAdapterClassName));
        _report('$_tag: impression',
            location: location, mediation: ad.mediation, adapter: ad.mediationAdapterClassName, attributes: attrs);
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onPaidEvent = (ad, valueMicros, precision, currencyCode, appLovinDspName) {
      try {
        DSAdsManager.I.onPaidEvent(
            ad, ad.mediation, location, valueMicros, precision, currencyCode, source, appLovinDspName, attrs);
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdShown = (ad) {
      try {
        DSAdsAppOpen.lockShowFor(const Duration(hours: 1));

        final eventAttrs = attrs.putShowAdInfo(
          startShowRequest: startTime,
          totalLoadDuration: _totalLoadDuration,
          loadConditions: _loadConditions,
        );
        _totalLoadDuration = Duration.zero;

        _report('$_tag: showed full screen content',
            location: location, mediation: ad.mediation, adapter: ad.mediationAdapterClassName, attributes: eventAttrs);
        if (_isDisposed) {
          Fimber.e('$_tag: showing disposed ad', stacktrace: StackTrace.current);
        }
        _adState = DSAdState.showing;
        onAdShow?.call();
        DSAdsManager.I.emitEvent(DSAdsInterstitialShowedEvent._(source: source, ad: ad));
        then?.call();
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdDismissed = (ad) {
      try {
        DSAdsAppOpen.lockShowFor(const Duration(seconds: 5));
        _report('$_tag: full screen content dismissed',
            location: location, mediation: ad.mediation, adapter: ad.mediationAdapterClassName, attributes: attrs);
        ad.dispose();
        updateLastShowTime();
        _mediation = null;
        _ad = null;
        _adState = DSAdState.none;
        _finishLoadTime = DateTime(0);
        // если перенести then?.call() сюда, возникает краткий показ предыдущего экрана при закрытии интерстишла
        DSAdsManager.I.emitEvent(DSAdsInterstitialShowDismissedEvent._(source: source, ad: ad));
        onAdClosed?.call();
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdFailedToShow = (ad, int errCode, String errText) {
      try {
        DSAdsAppOpen.lockShowFor(const Duration(seconds: 5));
        _report('$_tag: showing canceled by error',
            location: location, mediation: ad.mediation, adapter: ad.mediationAdapterClassName, attributes: attrs);
        Fimber.e('$errText ($errCode, adState: $adState)', stacktrace: StackTrace.current);
        ad.dispose();
        updateLastShowTime();
        _mediation = null;
        _ad = null;
        _adState = DSAdState.none;
        _finishLoadTime = DateTime(0);
        onFailedToShow?.call(errCode, errText);
        then?.call();
        DSAdsManager.I.emitEvent(DSAdsInterstitialShowErrorEvent._(source: source));
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };
    ad.onAdClicked = (ad) {
      try {
        DSAdsAppOpen.lockShowFor(const Duration(hours: 1));
        _report('$_tag: ad clicked',
            location: location, mediation: ad.mediation, adapter: ad.mediationAdapterClassName, attributes: attrs);
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    };

    StreamController? streamController;
    if (counterDelaySec > 0 || counterIntervals > 0) {
      streamController = StreamController();
      unawaitedCatch(() async {
        await showDialog(
          context: context!,
          builder: (context) => DSAdsOverlayScreen(
            counterDoneCallback: () => streamController!.add(null),
            delayIntervals: counterDelaySec > 0 ? counterDelaySec : counterIntervals,
            intervalDuration: counterDelaySec > 0 ? const Duration(seconds: 1) : counterDuration,
          ),
        );
        await streamController!.close();
      });
      await streamController.stream.first;
    }

    if (_isDisposed) {
      _report('$_tag: showing canceled: manager disposed',
          location: location, mediation: _mediation, attributes: attrs);
      then?.call();
      DSAdsManager.I.emitEvent(DSAdsInterstitialShowErrorEvent._(source: source));
      return;
    }

    final res = await beforeAdShow?.call() ?? true;
    if (!res) {
      _report('$_tag: showing canceled by caller', location: location, mediation: _mediation, attributes: attrs);
      then?.call();
      return;
    }

    if ([DSAdState.preShowing, DSAdState.showing].contains(adState)) {
      Fimber.e('showAd recall (adState: $adState)', stacktrace: StackTrace.current);
      _report('$_tag: showing canceled by error',
          location: location, mediation: _mediation, attributes: customAttributes);
      then?.call();
      return;
    }

    updateLastShowTime();
    _adState = DSAdState.preShowing;
    DSAdsManager.I.emitEvent(DSAdsInterstitialPreShowingEvent._(source: source, ad: ad));

    _showNum++;
    attrs['interstitial_show_num'] = _showNum;
    attrs['since_fetched_seconds'] = _finishLoadTime.year == 0
        ? -1
        : DateTime.timestamp().difference(_finishLoadTime).inSeconds;

    _report('$_tag: start showing', location: location, mediation: _mediation, attributes: attrs);
    try {
      try {
        await ad.show();
      } finally {
        await streamController?.done;
      }
    } catch (e, stack) {
      Fimber.e('$e', stacktrace: stack);
    }
  }

  DateTime getLastShowTime() => _lastShowTime;

  void updateLastShowTime() {
    _lastShowTime = DateTime.timestamp();
  }
}

class DSStateStub {
  DSAdsInterstitial owner;
  DSStateStub({
    required this.owner,
  });

  @Deprecated('Use adState instead of state.adState')
  DSAdState get adState => owner.adState;
}
