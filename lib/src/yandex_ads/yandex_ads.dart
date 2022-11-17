import 'dart:async';

import 'package:ds_ads/src/ds_ads_manager.dart';
import 'package:fimber/fimber.dart';
import 'package:flutter/services.dart';

import 'yandex_types.dart';

class YandexAds {
  static final instance = YandexAds._();
  static var _lastAdId = 0;

  final _interstitials = <String, AdInterstitialInfo>{};

  final _channel = const MethodChannel('pro.altush.ds_ads/yandex_native');
  YandexAds._() {
    _channel.setMethodCallHandler((call) async {
      try {
        final args = call.arguments;
        final adUnitId = args['unitId'] as String?;
        final inter = _interstitials[adUnitId];
        final ad = inter?.ad;
        switch (call.method) {
          case 'onAdLoaded':
            inter!.onAdLoaded(ad!);
            break;
          case 'onAdFailedToLoad':
            inter!.onAdFailedToLoad(ad!, args['errorCode'] as int, args['errorDescription'] as String);
            break;
          case 'onAdShown':
            ad!.onAdShown?.call(ad);
            break;
          case 'onAdDismissed':
            inter!.onAdDismissed?.call(ad!);
            ad!.onAdDismissed?.call(ad);
            break;
          case 'onAdClicked':
            ad!.onAdClicked?.call(ad);
            break;
          case 'onImpression':
            final data = args['data'] as String?;
            DSAdsManager.instance.onReportEvent?.call('yandex_ads: onImpression', {
              'adUnitId': '${ad?.adUnitId}',
              'data': '$data',
            });
            ad!.onAdImpression?.call(ad);
            break;
        }
      } catch (e, stack) {
        Fimber.e('$e', stacktrace: stack);
      }
    });
  }

  Future<void> initialize() async {
    await _channel.invokeMethod('init');
    DSAdsManager.instance.onReportEvent?.call('yandex_ads: initialized', {});
  }

  Future<void> loadInterstitial({
    required String adUnitId,
    required void Function(YandexInterstitialAd ad)? onAdLoaded,
    required OnAdFailedToLoad? onAdFailedToLoad,
  }) async {
    assert(adUnitId.startsWith('R-M-'));
    final prevState = _interstitials[adUnitId]?.state;
    if (prevState != null) {
      switch (prevState) {
        case YandexAdState.none:
          assert(false);
          return;
        case YandexAdState.loading:
        case YandexAdState.loaded:
          return;
        case YandexAdState.showing:
          throw Exception('Yandex ad $adUnitId is showing');
      }
    }
    final adId = ++_lastAdId;
    final ad = YandexInterstitialAd(
      id: adId,
      adUnitId: adUnitId,
    );
    bool validateId() {
      if (_interstitials[adUnitId]?.ad.id != adId) {
        onAdFailedToLoad?.call(ad, -1, 'ds_ads: interstitial ad info replaced');
        return false;
      }
      return true;
    }
    final inter = AdInterstitialInfo(
      ad: ad,
      onAdLoaded: (YandexInterstitialAd ad) {
        if (validateId()) {
          ad.setState(YandexAdState.loaded);
          onAdLoaded?.call(ad);
        }
      },
      onAdFailedToLoad: (YandexInterstitialAd ad, int errCode, String errDescription) {
        if (validateId()) {
          _interstitials.remove(ad.adUnitId);
          onAdFailedToLoad?.call(ad, errCode, errDescription);
        }
      },
    );
    ad.setState(YandexAdState.loading);
    _interstitials[adUnitId] = inter;
    try {
      await _channel.invokeMethod('loadInterstitial', [adUnitId]);
    } catch (e, stack) {
      Fimber.e('$e', stacktrace: stack);
      _interstitials.remove(adUnitId);
      onAdFailedToLoad?.call(ad, -2, 'ds_ads: $e');
    }
  }

  Future<void> showInterstitial({
    required YandexInterstitialAd ad,
  }) async {
    final inter = _interstitials[ad.adUnitId];
    if (inter == null || inter.state != YandexAdState.loaded) {
      throw Exception('Interstitial ${ad.adUnitId} is not ready (${inter?.state}');
    }
    if (inter.ad.id != ad.id) {
      Fimber.w('ds_ads: interstitial was replaced', stacktrace: StackTrace.current);
    }
    inter.onAdDismissed = (YandexInterstitialAd ad) {
      _interstitials.remove(ad.adUnitId);
    };
    inter.ad.setState(YandexAdState.showing);
    await _channel.invokeMethod('showInterstitial', [ad.adUnitId]);
  }
  
}
