import 'package:fimber/fimber.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'generic_ads/export.dart';

typedef OnReportEvent = void Function(String eventName, Map<String, Object> attributes);
typedef OnPaidEvent = void Function(DSAd ad, DSAdMediation mediation, DSAdLocation location, double valueMicros, PrecisionType precision,
    String currencyCode, DSAdSource source, String? appLovinDspName);

typedef DSIsAdAllowedCallback = bool Function(DSAdSource source, DSAdLocation location);

typedef DSDurationCallback = Duration Function();

enum DSAdSource {
  interstitial,
  native,
  rewarded,
  appOpen,
}

enum DSAdMediation {
  google,
  yandex,
  appLovin,
}

enum DSMediationType {
  main,
  native,
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
  error,
}

@immutable
abstract class DSAdsEvent {
  const DSAdsEvent();
}

@Deprecated('Remove TEST calls before release')
void logDeb(String message, {int stackSkip = 0, int stackDeep = 5}) {
  if (!kDebugMode) return;
  Fimber.d(message, stacktrace: LimitedStackTrace(
    stackTrace: StackTrace.current,
    skipFirst: stackSkip + 1,
    deep: stackDeep,
  ));
}

class LimitedStackTrace implements StackTrace {
  final StackTrace stackTrace;
  final int skipFirst;
  final int deep;

  const LimitedStackTrace({
    required this.stackTrace,
    this.skipFirst = 0,
    this.deep = 3,
  });

  @override
  String toString() {
    final list = stackTrace.toString().split('\n');
    return list.getRange(skipFirst, list.length - 1).take(deep).join('\n');
  }
}
