import 'dart:async';

import 'package:ds_ads/src/ads_manager.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

mixin AdsNativeLoaderMixin<T extends StatefulWidget> on State<T> {
  final _adKey = GlobalKey();
  NativeAd? _nativeAd;
  var _canShowAd = false;

  bool get canShowAd => _canShowAd;
  NativeAd? get nativeAd => _nativeAd;

  String? get nativeAdLocation;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBanner());
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    _report('ads_native: dispose (isLoaded: $_canShowAd)');
    super.dispose();
  }

  void _report(String eventName, {String? customAdId}) {
    AdsManager.instance.onReportEvent?.call(eventName, {
      if (nativeAdLocation != null)
        'location': nativeAdLocation!,
      'adUnitId': customAdId ?? AdsManager.instance.nativeUnitId!,
    });
  }

  Future<void> _loadBanner() async {
    final adUnitId = AdsManager.instance.nativeUnitId;
    assert(adUnitId != null, 'Pass nativeUnitId to AdsManager(...) on app start');
    _nativeAd = NativeAd(
      factoryId: 'adFactory1',
      adUnitId: adUnitId!,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          _report('ads_native: loaded');
          if (_canShowAd != true || AdsManager.instance.isAdAvailable != true) {
            setState(() {
              AdsManager.instance.adsLoaded();
              _canShowAd = true;
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          _report('ads_native: failed to load');
          if (_canShowAd != false) {
            setState(() {
              _canShowAd = false;
            });
          }
          ad.dispose();
        },
        onPaidEvent: (ad, valueMicros, precision, currencyCode) {
          AdsManager.instance.onPaidEvent(ad, valueMicros, precision, currencyCode, 'nativeAd');
        },
        onAdOpened: (ad) {
          _report('ads_native: ad opened');
        },
        onAdClicked: (ad) {
          _report('ads_native: ad clicked');
        },
      ),
      request: const AdRequest(),
    );
    await _nativeAd!.load();
  }

  Widget nativeAdWidget() {
    if (!AdsManager.instance.isAdAvailable) return const SizedBox();
    return SizedBox(
      height: 260, // the same as in res/layout/native_ad_1.xml
      child: canShowAd
          ? AdWidget(key: _adKey, ad: nativeAd!)
          : const SizedBox(),
    );
  }

}