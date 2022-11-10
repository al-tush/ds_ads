import 'dart:async';

import 'package:ds_ads/ds_ads.dart';
import 'package:fimber/fimber.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

part 'ds_ads_native_loader_types.dart';

mixin DSAdsNativeLoaderMixin<T extends StatefulWidget> on State<T> {
  final _adKey = GlobalKey();
  bool get isLoaded => _loadedAds[this] != null;

  DSAdLocation get nativeAdLocation;

  static final _loadedAds = <DSAdsNativeLoaderMixin?, NativeAd>{};
  static bool get hasPreloadedAd => _loadedAds[null] != null;

  static double get nativeAdHeight {
    // the same as in res/layout/native_ad_X_light.xml and res/layout/native_ad_X_dark.xml
    switch (DSAdsManager.instance.nativeAdBannerStyle) {
      case DSNativeAdBannerStyle.style1:
        return 260;
      case DSNativeAdBannerStyle.style2:
        return 280;
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(() async {
      await for (final event in DSAdsManager.instance.eventStream) {
        if (!mounted) return;
        if (event is DSAdsNativeLoadedEvent) {
          final res = _assignAdToMe();
          if (res) {
            setState(() {});
          }
        }
      }
    } ());
    _isDisabled(nativeAdLocation);
    unawaited(fetchAd(location: nativeAdLocation));
    _assignAdToMe();
  }

  @override
  void dispose() {
    final ad = _loadedAds.remove(this);
    _report('ads_native: dispose (isLoaded: ${ad != null})', location: nativeAdLocation);
    ad?.dispose();
    unawaited(fetchAd(location: const DSAdLocation('internal_dispose')));
    super.dispose();
  }

  @internal
  static Future<void> disposeClass() async {
    while (_loadedAds.isNotEmpty) {
      await _loadedAds.remove(_loadedAds.keys.first)?.dispose();
    }
  }

  static void _report(String eventName, {
    required final DSAdLocation location,
  }) {
    final adUnitId = DSAdsManager.instance.nativeUnitId;
    DSAdsManager.instance.onReportEvent?.call(eventName, {
      'location': location.val,
      'adUnitId': adUnitId ?? 'unknown',
    });
  }

  static DSAdLocation _getLocationByAd(Ad ad) {
    final obj = _loadedAds.entries.firstWhere((e) => e.value == ad).key;
    return obj?.nativeAdLocation ?? const DSAdLocation('internal_unassigned');
  }

  static String _getFactoryId() {
    final String group;
    switch (DSAdsManager.instance.nativeAdBannerStyle) {
      case DSNativeAdBannerStyle.style1:
        group = 'adFactory1';
        break;
      case DSNativeAdBannerStyle.style2:
        group = 'adFactory2';
        break;
    }
    switch (DSAdsManager.instance.appState.brightness) {
      case Brightness.light:
        return '${group}Light';
      case Brightness.dark:
        return '${group}Dark';
    }
  }

  static final _locationErrReports = <DSAdLocation>{};

  static bool _isDisabled(DSAdLocation location) {
    if (!location.isInternal && DSAdsManager.instance.locations?.contains(location) == false) {
      final msg = 'ads_native: location $location not in locations';
      assert(false, msg);
      if (!_locationErrReports.contains(location)) {
        _locationErrReports.add(location);
        Fimber.e(msg, stacktrace: StackTrace.current);
      }
    }
    if (DSAdsManager.instance.isAdAllowedCallback?.call(DSAdSource.native, location) == false) {
      Fimber.i('ads_native: disabled (location: $location)');
      return true;
    }
    return false;
  }

  static var _isBannerLoading = false;

  static Future<void> fetchAd({
    required final DSAdLocation location,
  }) async {
    if (_isDisabled(location)) return;

    final adUnitId = DSAdsManager.instance.nativeUnitId;
    assert(adUnitId != null, 'Pass nativeUnitId to DSAdsManager(...) on app start');
    if (hasPreloadedAd) {
      Fimber.i('ads_native: banner already loaded (location: $location)');
      return;
    }
    if (_isBannerLoading) {
      Fimber.i('ads_native: banner is already loading (location: $location)');
      return;
    }
    _report('ads_native: start loading', location: location);
    _isBannerLoading = true;
    await NativeAd(
      factoryId: _getFactoryId(),
      adUnitId: adUnitId!,
      listener: NativeAdListener(
        onAdImpression: (ad) {
          try {
            _report('ads_native: impression', location: location);
          } catch (e, stack) {
            Fimber.e('$e', stacktrace: stack);
          }
        },
        onAdLoaded: (ad) {
          try {
            _isBannerLoading = false;
            _loadedAds[null] = ad as NativeAd;
            _report('ads_native: loaded', location: location);
            DSAdsManager.instance.emitEvent(DSAdsNativeLoadedEvent._(ad: ad));
          } catch (e, stack) {
            Fimber.e('$e', stacktrace: stack);
          }
        },
        onAdFailedToLoad: (ad, err) {
          try {
            _isBannerLoading = false;
            _report('ads_native: failed to load', location: location);
            DSAdsManager.instance.emitEvent(const DSAdsNativeLoadFailed._());
            ad.dispose();
          } catch (e, stack) {
            Fimber.e('$e', stacktrace: stack);
          }
        },
        onPaidEvent: (ad, valueMicros, precision, currencyCode) {
          try {
            DSAdsManager.instance.onPaidEvent(ad, valueMicros, precision, currencyCode, DSAdSource.native);
          } catch (e, stack) {
            Fimber.e('$e', stacktrace: stack);
          }
        },
        onAdOpened: (ad) {
          try {
            _report('ads_native: ad opened', location: _getLocationByAd(ad));
          } catch (e, stack) {
            Fimber.e('$e', stacktrace: stack);
          }
        },
        onAdClicked: (ad) {
          try {
            _report('ads_native: ad clicked', location: _getLocationByAd(ad));
          } catch (e, stack) {
            Fimber.e('$e', stacktrace: stack);
          }
        },
        onAdClosed: (ad) {
          try {
            _report('ads_native: ad closed', location: _getLocationByAd(ad));
          } catch (e, stack) {
            Fimber.e('$e', stacktrace: stack);
          }
        },
      ),
      request: const AdRequest(),
    ).load();
  }

  bool _assignAdToMe() {
    final readyAd = _loadedAds[null];
    if (readyAd == null) return false; // No ads ready
    if (isLoaded) return false; // Already assigned
    _loadedAds[this] = readyAd;
    _loadedAds.remove(null);
    return true;
  }

  Widget nativeAdWidget({
    final NativeAdBuilder? builder,
    final bool? showProgress,
  }) {
    assert(!nativeAdLocation.isInternal);
    if (!DSAdsManager.instance.isAdAvailable) return const SizedBox();
    if (DSAdsManager.instance.appState.isPremium) return const SizedBox();
    if (_isDisabled(nativeAdLocation)) return const SizedBox();

    final child = SizedBox(
      height: nativeAdHeight,
      child: isLoaded
          ? AdWidget(key: _adKey, ad: _loadedAds[this]!)
          : (showProgress ?? DSAdsManager.instance.defaultShowNativeAdProgress) ? const Center(child: CircularProgressIndicator()) : const SizedBox(),
    );
    if (builder != null) {
      return builder(context, isLoaded, child);
    } else {
      return child;
    }
  }

}