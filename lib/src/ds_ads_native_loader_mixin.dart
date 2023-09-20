import 'dart:async';

import 'package:collection/collection.dart';
import 'package:ds_ads/ds_ads.dart';
import 'package:ds_ads/src/applovin_ads/ds_applovin_ad_widget.dart';
import 'package:ds_ads/src/applovin_ads/ds_applovin_native_ad.dart';
import 'package:fimber/fimber.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'google_ads/export.dart';

part 'ds_ads_native_loader_types.dart';

/// Widget mixin to show Google and AppLovin MAX native ads with different ad id
mixin DSAdsNativeLoaderMixin<T extends StatefulWidget> on State<T> {
  static const _tag = 'ads_native';

  var _adKey = GlobalKey();

  bool get isShowed => _showedAds[this] != null;

  DSAdLocation get nativeAdLocation;

  static final _loadingAds = <DSNativeStyle, DSNativeAd>{};
  static final _showedAds = <DSAdsNativeLoaderMixin, DSNativeAd>{};

  static const _loadingTimeout = Duration(minutes: 1);
  static const _loadedTimeout = Duration(hours: 4);

  /// Реклама уже предзагружена или сейчас загружается
  static bool hasPreloadedAd(DSAdLocation location) {
    final style = _getStyleByLocation(location);
    return _loadingAds.containsKey(style);
  }

  static String _adUnitId(DSAdMediation mediation) {
    switch (mediation) {
      case DSAdMediation.google:
        return DSAdsManager.instance.nativeGoogleUnitId;
      case DSAdMediation.appLovin:
        return DSAdsManager.instance.nativeAppLovinUnitId;
    }
  }

  double get nativeAdHeight {
    var height =
        DSAdsManager.instance.nativeAdCustomBanners.firstWhereOrNull((e) => e.location == nativeAdLocation)?.height;
    if (height != null) return height;
    // the same as in res/layout/native_ad_X_light.xml and res/layout/native_ad_X_dark.xml
    switch (DSAdsManager.instance.nativeAdBannerDefStyle) {
      case DSNativeAdBannerStyle.style1:
        return 260;
      case DSNativeAdBannerStyle.style2:
        return 290;
      default:
        assert(false, 'nativeAdBannerDefStyle or nativeAdCustomBanners should be defined');
        return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    reloadAd();
  }

  @override
  void dispose() {
    final ad = _showedAds.remove(this);
    _report('$_tag: dispose (isShowed: ${ad != null})', location: nativeAdLocation, mediation: ad?.mediation);
    ad?.dispose();
    unawaited(fetchAd(location: const DSAdLocation('internal_dispose')));
    super.dispose();
  }

  @internal
  static Future<void> disposeClass() async {
    while (_loadingAds.isNotEmpty) {
      await _loadingAds.remove(_loadingAds.keys.first)?.dispose();
    }
  }

  static Future<void> _disposeOtherMediation() async {
    final Type currentClass;
    switch (DSAdsManager.instance.currentMediation(DSAdSource.native)) {
      case DSAdMediation.google:
        currentClass = DSGoogleNativeAd;
        break;
      case DSAdMediation.appLovin:
        currentClass = DSAppLovinNativeAd;
        break;
      default:
        currentClass = Object;
        break;
    }
    _loadingAds.removeWhere((key, value) {
      final del = value.runtimeType != currentClass;
      if (del) {
        unawaited(value.dispose());
      }
      return del;
    });
    _showedAds.removeWhere((key, value) {
      final del = value.runtimeType != currentClass;
      if (del) {
        value.dispose();
      }
      return del;
    });
  }

  static void _report(
    String eventName, {
    required final DSAdLocation location,
    required DSAdMediation? mediation,
    String? adapter,
    Map<String, Object>? attributes,
  }) {
    DSAdsManager.instance.onReportEvent?.call(eventName, {
      if (mediation != null) 'adUnitId': _adUnitId(mediation),
      'location': location.val,
      'mediation': '$mediation',
      if (adapter != null) 'adapter': adapter,
      ...?attributes,
    });
  }

  static DSAdLocation _getLocationByAd(DSNativeAd ad) {
    final obj = _showedAds.entries.firstWhereOrNull((e) => e.value == ad)?.key;
    return obj?.nativeAdLocation ?? const DSAdLocation('internal_unassigned');
  }

  static DSNativeStyle _getStyleByLocation(DSAdLocation location) {
    String? style;
    if (!location.isInternal) {
      style = DSAdsManager.instance.nativeAdCustomBanners.firstWhereOrNull((e) => e.location == location)?.style;
    }
    style ??= DSAdsManager.instance.nativeAdBannerDefStyle;
    return style;
  }

  static String _getFactoryId({
    required final DSAdLocation location,
  }) {
    final style = _getStyleByLocation(location);
    switch (DSAdsManager.instance.appState.brightness) {
      case Brightness.light:
        return '${style}Light';
      case Brightness.dark:
        return '${style}Dark';
    }
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
    if (DSAdsManager.instance.isAdAllowedCallback?.call(DSAdSource.native, location) == false) {
      Fimber.i('$_tag: disabled (location: $location)');
      return true;
    }
    if (DSAdsManager.instance.currentMediation(DSAdSource.native) == null) {
      _report('$_tag: disabled (no mediation)', location: location, mediation: null);
      return true;
    }
    return false;
  }

  static Future<void> fetchAd({
    required final DSAdLocation location,
  }) async {
    DSAdsManager.instance.updateMediations(DSAdSource.native);

    if (_isDisabled(location)) return;

    await _disposeOtherMediation();

    final style = _getStyleByLocation(location);
    if (_loadingAds.containsKey(style)) {
      if (_loadingAds[style]?.isLoaded == true) {
        if (_loadingAds[style]!.created.add(_loadedTimeout).isAfter(DateTime.timestamp())) {
          Fimber.i('$_tag: banner already loaded (location: $location)');
          return;
        }
      } else {
        if (_loadingAds[style]?.created.add(_loadingTimeout).isAfter(DateTime.timestamp()) == true) {
          Fimber.i('$_tag: banner is already loading (location: $location)');
          return;
        }
      }
      await _loadingAds[style]?.dispose();
      _loadingAds.remove(style);
    }
    final factoryId = _getFactoryId(location: location);
    if (style.isEmpty) {
      assert(location.isInternal, 'DSAdsManager.instance.nativeAd... should be defined');
      return;
    }

    final mediation = DSAdsManager.instance.currentMediation(DSAdSource.native);
    if (mediation == null) {
      _report('$_tag: no mediation', location: location, mediation: mediation);
      return;
    }

    Future<void> onAdImpression(DSNativeAd ad) async {
      try {
        _report('$_tag: impression',
            location: _getLocationByAd(ad), mediation: ad.mediation, adapter: ad.mediationAdapterClassName);
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    }

    Future<void> onAdLoaded(DSNativeAd ad) async {
      try {
        _loadingAds[style] = ad;
        _report(
          '$_tag: loaded',
          location: location,
          mediation: ad.mediation,
          adapter: ad.mediationAdapterClassName,
          attributes: ad.getReportAttributes(),
        );
        DSAdsManager.instance.emitEvent(DSAdsNativeLoadedEvent._(ad: ad));
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    }

    Future<void> onAdFailedToLoad(DSNativeAd ad, int code, String message) async {
      try {
        _loadingAds.remove(style);
        _report(
          '$_tag: failed to load',
          location: location,
          mediation: ad.mediation,
          adapter: ad.mediationAdapterClassName,
          attributes: {
            ...ad.getReportAttributes(),
            'error_text': message,
            'error_code': '$code ($mediation)',
          },
        );
        DSAdsManager.instance.emitEvent(const DSAdsNativeLoadFailed._());
        await ad.dispose();
        await DSAdsManager.instance.onLoadAdError(code, message, mediation, DSAdSource.native);
        final newMediation = DSAdsManager.instance.currentMediation(DSAdSource.native);
        if (newMediation != mediation) {
          await fetchAd(location: location);
        }
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    }

    Future<void> onPaidEvent(DSNativeAd ad, double valueMicros, DSPrecisionType precision, String currencyCode) async {
      try {
        DSAdsManager.instance.onPaidEvent(
            ad, mediation, _getLocationByAd(ad), valueMicros, precision, currencyCode, DSAdSource.native, null, {});
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    }

    Future<void> onAdOpened(DSNativeAd ad) async {
      try {
        DSAdsManager.instance.emitEvent(const DSAdsNativeOpenedEvent._());
        _report('$_tag: ad opened',
            location: _getLocationByAd(ad), mediation: ad.mediation, adapter: ad.mediationAdapterClassName);
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    }

    Future<void> onAdClicked(DSNativeAd ad) async {
      try {
        DSAdsManager.instance.emitEvent(const DSAdsNativeClickEvent._());
        _report('$_tag: ad clicked',
            location: _getLocationByAd(ad), mediation: ad.mediation, adapter: ad.mediationAdapterClassName);
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    }

    Future<void> onAdClosed(DSNativeAd ad) async {
      try {
        DSAdsManager.instance.emitEvent(const DSAdsNativeClosedEvent._());
        _report('$_tag: ad closed',
            location: _getLocationByAd(ad), mediation: ad.mediation, adapter: ad.mediationAdapterClassName);
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    }

    Future<void> onAdExpired(DSNativeAd ad) async {
      try {
        _report('$_tag: ad expired',
            location: _getLocationByAd(ad), mediation: ad.mediation, adapter: ad.mediationAdapterClassName);
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    }

    final DSNativeAd nativeAd;
    switch (mediation) {
      case DSAdMediation.google:
        nativeAd = DSGoogleNativeAd(
          adUnitId: _adUnitId(mediation),
          factoryId: factoryId,
          onPaidEvent: onPaidEvent,
          onAdImpression: onAdImpression,
          onAdClicked: onAdClicked,
          onAdClosed: onAdClosed,
          onAdOpened: onAdOpened,
          onAdLoaded: onAdLoaded,
          onAdFailedToLoad: onAdFailedToLoad,
        );
        break;
      case DSAdMediation.appLovin:
        nativeAd = DSAppLovinNativeAd(
          adUnitId: _adUnitId(mediation),
          factoryId: factoryId,
          onPaidEvent: onPaidEvent,
          onAdClicked: onAdClicked,
          onAdLoaded: onAdLoaded,
          onAdFailedToLoad: onAdFailedToLoad,
          onAdExpired: onAdExpired,
        );
        break;
    }
    _loadingAds[style] = nativeAd;
    _report('$_tag: start loading', location: location, mediation: mediation);
    await nativeAd.load();
  }

  bool _assignAdToMe() {
    if (isShowed) return false;
    final style = _getStyleByLocation(nativeAdLocation);
    final readyAd = _loadingAds[style];
    if (readyAd == null || !readyAd.isLoaded) return false;
    _showedAds[this] = readyAd;
    _loadingAds.remove(style);
    final mediation = DSAdsManager.instance.currentMediation(DSAdSource.native);
    _report('$_tag: assigned', location: nativeAdLocation, mediation: mediation);
    unawaited(() async {
      // to prevent empty transparent rect instead banner
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {});
    }());
    return true;
  }

  void reloadAd() {
    if (isShowed) {
      final mediation = DSAdsManager.instance.currentMediation(DSAdSource.native);
      _report(
        '$_tag: reloading',
        location: nativeAdLocation,
        mediation: mediation,
        attributes: _showedAds[this]?.getReportAttributes(),
      );
      _showedAds[this]?.dispose();
      _showedAds.remove(this);
      _adKey = GlobalKey();
    }
    unawaited(() async {
      await for (final event in DSAdsManager.instance.eventStream) {
        if (!mounted) return;
        if (event is DSAdsNativeLoadedEvent) {
          _assignAdToMe();
          break;
        }
      }
    }());
    _isDisabled(nativeAdLocation);
    _assignAdToMe();
    unawaited(fetchAd(location: nativeAdLocation));
  }

  @protected
  Widget nativeAdWidget({
    final NativeAdBuilder? builder,
  }) {
    assert(!nativeAdLocation.isInternal);
    if (!DSAdsManager.instance.isAdAvailable) return const SizedBox();
    if (DSAdsManager.instance.appState.isPremium) return const SizedBox();
    if (_isDisabled(nativeAdLocation)) return const SizedBox();

    Widget child;
    final ad = _showedAds[this];
    if (ad == null) {
      child = const Center(child: CircularProgressIndicator());
    } else if (ad is DSGoogleNativeAd) {
      child = DSGoogleAdWidget(key: _adKey, ad: ad);
    } else if (ad is DSAppLovinNativeAd) {
      child = DSAppLovinAdWidget(ad: ad);
    } else {
      assert(false, 'No implementation for ${ad.runtimeType}');
      return const SizedBox();
    }

    child = SizedBox(
      height: nativeAdHeight,
      child: child,
    );
    if (builder != null) {
      return builder(context, isShowed, child);
    } else {
      return child;
    }
  }
}
