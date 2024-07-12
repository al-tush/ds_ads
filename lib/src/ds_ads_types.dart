import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'generic_ads/export.dart';

typedef OnReportEvent = void Function(String eventName, Map<String, Object> attributes);
typedef OnPaidEvent = void Function(
    DSAd ad,
    DSAdMediation mediation,
    DSAdLocation location,
    double valueMicros,
    PrecisionType precision,
    String currencyCode,
    DSAdSource source,
    String? appLovinDspName,
    Map<String, Object> metricaAttrs);

typedef DSIsAdAllowedCallback = bool Function(DSAdSource source, DSAdLocation location);
typedef DSRetryCountCallback = int Function(DSAdSource source);

typedef DSDurationCallback = Duration Function();

enum DSAdSource {
  interstitial,
  interstitial2,
  interstitialSplash,
  banner,
  native,
  rewarded,
  appOpen,
  appOpenSplash,
}

enum DSAdMediation {
  google,
  appLovin,
}

@immutable
class DSAdLocation {
  final String val;

  const DSAdLocation(this.val);

  bool get isInternal => val.startsWith('internal_');

  @override
  int get hashCode => val.hashCode;

  @override
  bool operator ==(other) => other is DSAdLocation && val == other.val;

  @override
  String toString() => val;
}

typedef DSNativeStyle = String;
typedef NativeAdBuilder = Widget Function(BuildContext context, bool isLoaded, Widget child);

typedef BannerAdBuilder = Widget Function(BuildContext context, bool isLoaded, Widget child);

class NativeAdBanner {
  final DSAdLocation location;
  final DSNativeStyle style;
  final double height;

  NativeAdBanner({
    required this.location,
    required this.style,
    required this.height,
  });
}

abstract class DSNativeAdBannerStyle {
  static const DSNativeStyle notDefined = '';
  static const DSNativeStyle style1 = 'adFactory1'; // top margin 16dp
  static const DSNativeStyle style2 = 'adFactory2'; // no margins
}

abstract class DSAppAdsState {
  /// App is in premium mode (no any ads shows)
  bool get isPremium;

  // Current brightness for native banners style
  Brightness get brightness;
}

enum DSAdState {
  none,
  loading,
  loaded,
  preShowing,
  showing,
  error,
}

@immutable
abstract class DSAdsEvent {
  const DSAdsEvent();
}
