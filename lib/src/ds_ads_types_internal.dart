import 'package:freezed_annotation/freezed_annotation.dart';

@internal
enum DSAdsLoadCondition {
  error,
  mediationChanged,
  mediationTimeout,
}

extension Attrs on Map<String, Object> {
  Map<String, Object> putShowAdInfo({
    required DateTime startShowRequest,
    required Duration totalLoadDuration,
    required Set<DSAdsLoadCondition> loadConditions,
  }) {
    final showDelay = DateTime.timestamp().difference(startShowRequest);
    String loadType;
    if (loadConditions.isEmpty) {
      loadType = 'easy_load';
    } else {
      loadType = loadConditions.map((e) => switch (e) {
        DSAdsLoadCondition.error => 'error',
        DSAdsLoadCondition.mediationChanged => 'mediation_changed',
        DSAdsLoadCondition.mediationTimeout => 'mediation_timeout',
      }).join(',');
    }
    return {
      ...this,
      'ads_show_delay_seconds': showDelay.inSeconds,
      'ads_show_delay_milliseconds': showDelay.inMilliseconds,
      'ads_total_load_seconds': totalLoadDuration.inSeconds,
      'ads_total_load_milliseconds': totalLoadDuration.inMilliseconds,
      'ads_total_load_type': loadType,
    };
  }
}