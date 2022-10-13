import 'package:ds_ads/src/ads_interstitial_cubit.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

typedef OnReportEvent = void Function(String eventName, Map<String, Object> attributes);
typedef OnPaidEvent = void Function(Ad ad, double valueMicros, PrecisionType precision,
    String currencyCode, String format);

abstract class AppAdState {
  /// App is in premium mode (no any ads shows)
  bool get isPremium;
  /// App is in foreground (interstitial ads cannot be shown)
  bool get isInForeground;
}

class AdsManager {
  static AdsManager? _instance;
  static AdsManager get instance {
    assert(_instance != null, 'Call AdsManager(...) to initialize ads');
    return _instance!;
  }

  static AdsInterstitialCubit get interstitial {
    assert(_instance?._adsInterstitialCubit != null, 'Pass interstitialUnitId to AdsManager(...) on app start');
    return instance._adsInterstitialCubit!;
  }

  final AdsInterstitialCubit? _adsInterstitialCubit;

  var _isAdAvailable = false;
  /// Was the ad successfully loaded at least once in this session
  bool get isAdAvailable => _isAdAvailable;

  final OnPaidEvent onPaidEvent;
  final AppAdState appState;
  final OnReportEvent? onReportEvent;
  final String? interstitialUnitId;
  final String? nativeUnitId;

  AdsManager({
    required this.onPaidEvent,
    required this.appState,
    this.onReportEvent,
    this.interstitialUnitId,
    this.nativeUnitId,
  }) :
    _adsInterstitialCubit = interstitialUnitId != null
        ? AdsInterstitialCubit(adUnitId: interstitialUnitId)
        : null {
    assert(_instance == null, 'dismiss previous Ads instance before init new');
    MobileAds.instance.initialize();
    _instance = this;
  }

  void adsLoaded() {
    _isAdAvailable = true;
  }

  void dismiss() {
    _instance = null;
  }
}