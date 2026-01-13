import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'applovin_ads/ds_applovin_native_ad.dart';
import 'generic_ads/export.dart';

typedef OnReportEvent = void Function(
    String eventName, Map<String, Object> attributes);
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

typedef DSIsAdAllowedCallback = bool Function(
    DSAdSource source, DSAdLocation location);
typedef DSRetryCountCallback = int Function(DSAdSource source);

typedef DSConsentStatus = ConsentStatus;

typedef DSDurationCallback = Duration Function();

typedef DSLocatedDurationCallback = Duration Function(DSAdLocation location);

enum DSAdSource {
  interstitial,
  interstitial2,
  interstitialSplash,
  interstitialPremium,
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
typedef NativeAdBuilder = Widget Function(
    BuildContext context, bool isLoaded, Widget child);
typedef NativeAdBuilderFlutter = Widget Function(
    BuildContext context, DSAppLovinNativeAdFlutter ad);

typedef BannerAdBuilder = Widget Function(
    BuildContext context, bool isLoaded, Widget child);

sealed class NativeAdBannerInterface {
  DSAdLocation get location;
}

/// Platform-specific native banner description
class NativeAdBannerPlatform implements NativeAdBannerInterface {
  @override
  final DSAdLocation location;
  final DSNativeStyle style;
  final double height;

  NativeAdBannerPlatform({
    required this.location,
    required this.style,
    required this.height,
  });
}

/// Flutter defined native banner description (currently supported by AppLovin)
/// Use DS-widgets to prevent direct access to applovin_max lib.
/// For example DSMaxNativeAdIconView instead of MaxNativeAdIconView
class NativeAdBannerFlutter implements NativeAdBannerInterface {
  @override
  final DSAdLocation location;
  final double Function(DSAppLovinNativeAdFlutter ad) heightCallback;
  final NativeAdBuilderFlutter builder;

  NativeAdBannerFlutter({
    required this.location,
    required this.heightCallback,
    required this.builder,
  });
}

/// Legacy
@Deprecated(
    'Use NativeAdBannerPlatform for Google or legacy natives or NativeAdBannerFlutter for AppLovin (https://developers.applovin.com/en/flutter/ad-formats/native-ads/)')
class NativeAdBanner extends NativeAdBannerPlatform {
  NativeAdBanner({
    required super.location,
    required super.style,
    required super.height,
  });
}

abstract class DSNativeAdBannerStyle {
  /// not defined style
  static const DSNativeStyle notDefined = '';

  /// top margin 16dp
  static const DSNativeStyle style1 = 'adFactory1';

  /// no margins
  static const DSNativeStyle style2 = 'adFactory2'; // no margins
}

abstract class DSAppAdsState {
  /// App is in premium mode (no any ads shows)
  bool get isPremium;

  // Current brightness for native banners style
  Brightness get brightness;
}

mixin DSAppAdsStateMixin {
  // if true for [kDebugMode] all ads disabled (this location makes switch easier in hot reload)
  bool get adsDisabledInDebugMode => false;
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
  final DSAdSource source;

  const DSAdsEvent({
    required this.source,
  });
}

/// Generated when consent status changes and ads can be requested
class DSAdsConsentReadyEvent extends DSAdsEvent {
  final DSConsentStatus consentStatus;

  const DSAdsConsentReadyEvent({required this.consentStatus})
      : super(source: DSAdSource.native);
}
