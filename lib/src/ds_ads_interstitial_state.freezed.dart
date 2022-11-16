// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target

part of 'ds_ads_interstitial_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$AdsInterstitialState {
  DSInterstitialAd? get ad => throw _privateConstructorUsedError;
  DSAdState get adState => throw _privateConstructorUsedError;
  DateTime get loadedTime => throw _privateConstructorUsedError;
  DateTime get lastShowedTime => throw _privateConstructorUsedError;
  int get loadRetryCount => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $AdsInterstitialStateCopyWith<DSAdsInterstitialState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AdsInterstitialStateCopyWith<$Res> {
  factory $AdsInterstitialStateCopyWith(DSAdsInterstitialState value,
          $Res Function(DSAdsInterstitialState) then) =
      _$AdsInterstitialStateCopyWithImpl<$Res>;
  $Res call(
      {DSInterstitialAd? ad,
      DSAdState adState,
      DateTime loadedTime,
      DateTime lastShowedTime,
      int loadRetryCount});
}

/// @nodoc
class _$AdsInterstitialStateCopyWithImpl<$Res>
    implements $AdsInterstitialStateCopyWith<$Res> {
  _$AdsInterstitialStateCopyWithImpl(this._value, this._then);

  final DSAdsInterstitialState _value;
  // ignore: unused_field
  final $Res Function(DSAdsInterstitialState) _then;

  @override
  $Res call({
    Object? ad = freezed,
    Object? adState = freezed,
    Object? loadedTime = freezed,
    Object? lastShowedTime = freezed,
    Object? loadRetryCount = freezed,
  }) {
    return _then(_value.copyWith(
      ad: ad == freezed
          ? _value.ad
          : ad // ignore: cast_nullable_to_non_nullable
              as DSInterstitialAd?,
      adState: adState == freezed
          ? _value.adState
          : adState // ignore: cast_nullable_to_non_nullable
              as DSAdState,
      loadedTime: loadedTime == freezed
          ? _value.loadedTime
          : loadedTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lastShowedTime: lastShowedTime == freezed
          ? _value.lastShowedTime
          : lastShowedTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      loadRetryCount: loadRetryCount == freezed
          ? _value.loadRetryCount
          : loadRetryCount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
abstract class _$$_AdsInterstitialStateDataCopyWith<$Res>
    implements $AdsInterstitialStateCopyWith<$Res> {
  factory _$$_AdsInterstitialStateDataCopyWith(
          _$_AdsInterstitialStateData value,
          $Res Function(_$_AdsInterstitialStateData) then) =
      __$$_AdsInterstitialStateDataCopyWithImpl<$Res>;
  @override
  $Res call(
      {DSInterstitialAd? ad,
      DSAdState adState,
      DateTime loadedTime,
      DateTime lastShowedTime,
      int loadRetryCount});
}

/// @nodoc
class __$$_AdsInterstitialStateDataCopyWithImpl<$Res>
    extends _$AdsInterstitialStateCopyWithImpl<$Res>
    implements _$$_AdsInterstitialStateDataCopyWith<$Res> {
  __$$_AdsInterstitialStateDataCopyWithImpl(_$_AdsInterstitialStateData _value,
      $Res Function(_$_AdsInterstitialStateData) _then)
      : super(_value, (v) => _then(v as _$_AdsInterstitialStateData));

  @override
  _$_AdsInterstitialStateData get _value =>
      super._value as _$_AdsInterstitialStateData;

  @override
  $Res call({
    Object? ad = freezed,
    Object? adState = freezed,
    Object? loadedTime = freezed,
    Object? lastShowedTime = freezed,
    Object? loadRetryCount = freezed,
  }) {
    return _then(_$_AdsInterstitialStateData(
      ad: ad == freezed
          ? _value.ad
          : ad // ignore: cast_nullable_to_non_nullable
              as DSInterstitialAd?,
      adState: adState == freezed
          ? _value.adState
          : adState // ignore: cast_nullable_to_non_nullable
              as DSAdState,
      loadedTime: loadedTime == freezed
          ? _value.loadedTime
          : loadedTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lastShowedTime: lastShowedTime == freezed
          ? _value.lastShowedTime
          : lastShowedTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      loadRetryCount: loadRetryCount == freezed
          ? _value.loadRetryCount
          : loadRetryCount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$_AdsInterstitialStateData implements _AdsInterstitialStateData {
  _$_AdsInterstitialStateData(
      {required this.ad,
      required this.adState,
      required this.loadedTime,
      required this.lastShowedTime,
      required this.loadRetryCount});

  @override
  final DSInterstitialAd? ad;
  @override
  final DSAdState adState;
  @override
  final DateTime loadedTime;
  @override
  final DateTime lastShowedTime;
  @override
  final int loadRetryCount;

  @override
  String toString() {
    return 'AdsInterstitialState(ad: $ad, adState: $adState, loadedTime: $loadedTime, lastShowedTime: $lastShowedTime, loadRetryCount: $loadRetryCount)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_AdsInterstitialStateData &&
            const DeepCollectionEquality().equals(other.ad, ad) &&
            const DeepCollectionEquality().equals(other.adState, adState) &&
            const DeepCollectionEquality()
                .equals(other.loadedTime, loadedTime) &&
            const DeepCollectionEquality()
                .equals(other.lastShowedTime, lastShowedTime) &&
            const DeepCollectionEquality()
                .equals(other.loadRetryCount, loadRetryCount));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(ad),
      const DeepCollectionEquality().hash(adState),
      const DeepCollectionEquality().hash(loadedTime),
      const DeepCollectionEquality().hash(lastShowedTime),
      const DeepCollectionEquality().hash(loadRetryCount));

  @JsonKey(ignore: true)
  @override
  _$$_AdsInterstitialStateDataCopyWith<_$_AdsInterstitialStateData>
      get copyWith => __$$_AdsInterstitialStateDataCopyWithImpl<
          _$_AdsInterstitialStateData>(this, _$identity);
}

abstract class _AdsInterstitialStateData implements DSAdsInterstitialState {
  factory _AdsInterstitialStateData(
      {required final DSInterstitialAd? ad,
      required final DSAdState adState,
      required final DateTime loadedTime,
      required final DateTime lastShowedTime,
      required final int loadRetryCount}) = _$_AdsInterstitialStateData;

  @override
  DSInterstitialAd? get ad => throw _privateConstructorUsedError;
  @override
  DSAdState get adState => throw _privateConstructorUsedError;
  @override
  DateTime get loadedTime => throw _privateConstructorUsedError;
  @override
  DateTime get lastShowedTime => throw _privateConstructorUsedError;
  @override
  int get loadRetryCount => throw _privateConstructorUsedError;
  @override
  @JsonKey(ignore: true)
  _$$_AdsInterstitialStateDataCopyWith<_$_AdsInterstitialStateData>
      get copyWith => throw _privateConstructorUsedError;
}
