import 'dart:async';

import 'package:applovin_max/applovin_max.dart';
import 'package:ds_ads/ds_ads.dart';
import 'package:fimber/fimber.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Widget to show Google and AppLovin MAX banner ads
class DSAdsBanner extends StatefulWidget {
  /// Use [builder] to wrap banner widget to another widget. Eg. [Padding]
  final BannerAdBuilder? builder;
  /// Define location. Allows to disable banners by location and see data in statistics ([DSAdsManager.onReportEvent])
  final DSAdLocation location;
  final String googleUnitId;
  final String appLovinUnitId;
  /// Do not use it
  final bool adaptive;

  const DSAdsBanner({
    super.key,
    required this.location,
    this.googleUnitId = '',
    this.appLovinUnitId = '',
    @Deprecated('Used by AppLovin. Now is not supported') this.adaptive = false,
    this.builder,
  }) : assert(googleUnitId != '' || appLovinUnitId != '');

  @override
  State<DSAdsBanner> createState() => _DSAdsBannerState();

  /// Wrapper of [AppLovinMAX.getAdaptiveBannerHeightForWidth]
  static Future<double?> getAdaptiveBannerHeightForWidth(double width) =>
      AppLovinMAX.getAdaptiveBannerHeightForWidth(width);
}

class _DSAdsBannerState extends State<DSAdsBanner> {
  static const _tag = 'ads_banner';

  String _adUnitId(DSAdMediation mediation) {
    var res = '';
    switch (mediation) {
      case DSAdMediation.google:
        res = widget.googleUnitId;
      case DSAdMediation.appLovin:
        res = widget.appLovinUnitId;
    }
    assert(res.isNotEmpty);
    return res;
  }

  void _report(
    String eventName, {
    required DSAdMediation? mediation,
    String? adapter,
    Map<String, Object>? attributes,
  }) {
    DSAdsManager.I.onReportEvent?.call(eventName, {
      if (mediation != null) 'adUnitId': _adUnitId(mediation),
      'location': widget.location.val,
      'mediation': '$mediation',
      if (adapter != null) 'adapter': adapter,
      ...?attributes,
    });
  }

  static final _locationErrReports = <DSAdLocation>{};

  bool _isDisabled(DSAdLocation location) {
    if (DSAdsManager.I.appState.isPremium) return true;
    if (!location.isInternal &&
        DSAdsManager.I.locations?.contains(location) == false) {
      final msg = '$_tag: location $location not in locations';
      assert(false, msg);
      if (!_locationErrReports.contains(location)) {
        _locationErrReports.add(location);
        Fimber.e(msg, stacktrace: StackTrace.current);
      }
    }
    if (DSAdsManager.I.isAdAllowedCallbackProc(DSAdSource.banner, location) ==
        false) {
      Fimber.i('$_tag: disabled (location: $location)');
      return true;
    }
    if (DSAdsManager.I.currentMediation(DSAdSource.banner) == null) {
      _report('$_tag: disabled (no mediation)', mediation: null);
      return true;
    }
    return false;
  }

  var _isStartLoading = false;
  var _isLoaded = false;
  BannerAd? _googleAd;

  @override
  void initState() {
    super.initState();
    if (widget.appLovinUnitId.isNotEmpty) {
      // https://dash.applovin.com/documentation/mediation/flutter/ad-formats/banners#adaptive-banners
      AppLovinMAX.setBannerExtraParameter(
          widget.appLovinUnitId, 'adaptive_banner', 'false');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _isStartLoading = false;
    _isLoaded = false;
    final mediation = DSAdsManager.I.currentMediation(DSAdSource.banner);
    if (mediation == DSAdMediation.google) {
      unawaited(_loadGoogleAd());
    }
  }

  Future<void> _onAdImpression(DSAdMediation mediation, String? adapter) async {
    try {
      _report(
        '$_tag: impression',
        mediation: mediation,
        adapter: '$adapter',
      );
    } catch (e, stack) {
      Fimber.e('$e', stacktrace: stack);
    }
  }

  Future<void> _onAdLoaded(DSAdMediation mediation, String? adapter) async {
    try {
      _report(
        '$_tag: loaded',
        mediation: mediation,
        adapter: '$adapter',
      );
      _isLoaded = true;
    } catch (e, stack) {
      Fimber.e('$e', stacktrace: stack);
    }
  }

  Future<void> _onAdFailedToLoad(int code, String message,
      DSAdMediation mediation, String? adapter) async {
    try {
      _report(
        '$_tag: failed to load',
        mediation: mediation,
        adapter: '$adapter',
        attributes: {
          'error_text': message,
          'error_code': '$code ($mediation)',
        },
      );
      await DSAdsManager.I
          .onLoadAdError(code, message, mediation, DSAdSource.banner);
      final newMediation = DSAdsManager.I.currentMediation(DSAdSource.banner);
      if (newMediation != mediation) {
        setState(() {});
      }
    } catch (e, stack) {
      Fimber.e('$e', stacktrace: stack);
    }
  }

  Future<void> _onPaidEvent(
      DSAdMediation mediation,
      String? adapter,
      double valueMicros,
      DSPrecisionType precision,
      String currencyCode,
      String? appLovinDspName) async {
    try {
      final ad = _DSBannerAdStub(
        adUnitId: _adUnitId(mediation),
        adapter: adapter,
        mediation: mediation,
      );
      DSAdsManager.I.onPaidEvent(ad, mediation, widget.location, valueMicros,
          precision, currencyCode, DSAdSource.banner, appLovinDspName, {});
    } catch (e, stack) {
      Fimber.e('$e', stacktrace: stack);
    }
  }

  Future<void> _onAdOpened(DSAdMediation mediation, String? adapter) async {
    try {
      _report('$_tag: ad opened', mediation: mediation, adapter: adapter);
    } catch (e, stack) {
      Fimber.e('$e', stacktrace: stack);
    }
  }

  Future<void> _onAdClicked(DSAdMediation mediation, String? adapter) async {
    try {
      _report(
        '$_tag: ad clicked',
        mediation: mediation,
        adapter: '$adapter',
      );
    } catch (e, stack) {
      Fimber.e('$e', stacktrace: stack);
    }
  }

  Future<void> _onAdWillDismiss(
      DSAdMediation mediation, String? adapter) async {
    try {
      _report(
        '$_tag: ad will dismiss screen',
        mediation: mediation,
        adapter: '$adapter',
      );
    } catch (e, stack) {
      Fimber.e('$e', stacktrace: stack);
    }
  }

  Future<void> _onAdClosed(DSAdMediation mediation, String? adapter) async {
    try {
      _report(
        '$_tag: ad closed',
        mediation: mediation,
        adapter: '$adapter',
      );
    } catch (e, stack) {
      Fimber.e('$e', stacktrace: stack);
    }
  }

  Future<void> _loadGoogleAd() async {
    if (_isDisabled(widget.location)) return;

    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
        MediaQuery.of(context).size.width.truncate());
    if (size == null) {
      Fimber.e('Unable to get height of ads_banner (${widget.location})');
      return;
    }
    _googleAd = BannerAd(
      adUnitId: _adUnitId(DSAdMediation.google),
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdImpression: (Ad ad) {
          _onAdImpression(
              DSAdMediation.google, ad.responseInfo?.mediationAdapterClassName);
        },
        onAdLoaded: (Ad ad) {
          _onAdLoaded(
              DSAdMediation.google, ad.responseInfo?.mediationAdapterClassName);
          _googleAd = ad as BannerAd;
          setState(() {});
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          _onAdFailedToLoad(error.code, error.message, DSAdMediation.google,
              ad.responseInfo?.mediationAdapterClassName);
          ad.dispose();
        },
        onAdOpened: (Ad ad) {
          _onAdOpened(
              DSAdMediation.google, ad.responseInfo?.mediationAdapterClassName);
        },
        onAdClicked: (Ad ad) {
          _onAdClicked(
              DSAdMediation.google, ad.responseInfo?.mediationAdapterClassName);
        },
        onAdClosed: (Ad ad) {
          _onAdClosed(
              DSAdMediation.google, ad.responseInfo?.mediationAdapterClassName);
        },
        onPaidEvent: (Ad ad, double valueMicros, PrecisionType precision,
            String currencyCode) {
          _onPaidEvent(
              DSAdMediation.google,
              ad.responseInfo?.mediationAdapterClassName,
              valueMicros,
              precision,
              currencyCode,
              null);
        },
        onAdWillDismissScreen: (Ad ad) {
          _onAdWillDismiss(
              DSAdMediation.google, ad.responseInfo?.mediationAdapterClassName);
        },
      ),
    );
    _report('$_tag: start loading', mediation: DSAdMediation.google);
    _isStartLoading = true;
    await _googleAd!.load();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisabled(widget.location)) return const SizedBox();

    final mediation = DSAdsManager.I.currentMediation(DSAdSource.banner)!;

    final Widget child;
    switch (mediation) {
      case DSAdMediation.google:
        if (_googleAd == null || !_isLoaded) return const SizedBox();
        child = Container(
          color: switch (DSAdsManager.I.appState.brightness) {
            Brightness.light => Colors.white,
            Brightness.dark => Colors.black,
          },
          width: _googleAd!.size.width.toDouble(),
          height: _googleAd!.size.height.toDouble(),
          child: AdWidget(ad: _googleAd!),
        );
        break;
      case DSAdMediation.appLovin:
        if (!_isStartLoading) {
          _isStartLoading = true;
          _report('$_tag: start loading', mediation: DSAdMediation.appLovin);
        }
        child = MaxAdView(
          adUnitId: _adUnitId(DSAdMediation.appLovin),
          adFormat: AdFormat.banner,
          listener: AdViewAdListener(
            onAdLoadedCallback: (ad) {
              _isLoaded = true;
              _onAdLoaded(mediation, ad.networkName);
            },
            onAdLoadFailedCallback: (adUnitId, error) {
              _onAdFailedToLoad(error.code.value, error.message, mediation, null);
            },
            onAdClickedCallback: (ad) {
              _onAdClicked(mediation, ad.networkName);
            },
            onAdExpandedCallback: (ad) {
              Fimber.i('ad expanded', stacktrace: StackTrace.current);
            },
            onAdCollapsedCallback: (ad) {
              Fimber.i('ad collapsed', stacktrace: StackTrace.current);
            },
            onAdRevenuePaidCallback: (ad) {
              _onAdImpression(mediation, ad.networkName);
              // https://dash.applovin.com/documentation/mediation/android/getting-started/advanced-settings#impression-level-user-revenue-api
              if (ad.revenue < 0) {
                Fimber.w('AppLovin revenue error',
                    stacktrace: StackTrace.current);
                return;
              }
              _onPaidEvent(mediation, ad.networkName, ad.revenue * 1000000,
                  DSPrecisionType.unknown, 'USD', ad.dspName);
            },
          ),
        );
        break;
    }

    // ToDo: переделать на вызов билдера и для случая, когда isShowed == false
    Widget res;
    if (widget.builder != null) {
      res = widget.builder!(context, true, child);
    } else {
      res = child;
    }
    return res;
  }
}

class _DSBannerAdStub extends DSAd {
  final String? adapter;

  @override
  final DSAdMediation mediation;

  _DSBannerAdStub({
    required super.adUnitId,
    required this.adapter,
    required this.mediation,
  });

  @override
  String get mediationAdapterClassName => '$adapter';
}
