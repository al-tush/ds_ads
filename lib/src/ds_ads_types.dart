import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

typedef OnReportEvent = void Function(String eventName, Map<String, Object> attributes);
typedef OnPaidEvent = void Function(Ad ad, double valueMicros, PrecisionType precision,
    String currencyCode, DSAdSource source);

typedef DSIsAdAllowedCallback = bool Function(DSAdSource source, String location);

enum DSAdSource {
  interstitial,
  native
}

enum DSNativeAdBannerStyle {
  style1, // top margin 16dp
  style2, // no margins
}

abstract class DSAppAdsState {
  /// App is in premium mode (no any ads shows)
  bool get isPremium;
  /// App is in foreground (interstitial ads cannot be shown)
  bool get isInForeground;
  // Current brightness for native banners style
  Brightness get brightness;
}

enum DSAdState {
  none,
  loading,
  loaded,
  preShowing,
  showing,
}

@immutable
abstract class DSAdsEvent {
  const DSAdsEvent();
}
