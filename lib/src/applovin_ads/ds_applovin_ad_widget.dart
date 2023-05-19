import 'package:ds_ads/src/applovin_ads/export.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class DSAppLovinAdWidget extends StatefulWidget {
  /// Default constructor for [DSAppLovinAdWidget].
  ///
  /// [ad] must be loaded before this is added to the widget tree.
  const DSAppLovinAdWidget({
    super.key,
    required this.ad,
  });

  final DSAppLovinNativeAd ad;

  @override
  State<DSAppLovinAdWidget> createState() => _DSAppLovinAdWidgetState();
}

class _DSAppLovinAdWidgetState extends State<DSAppLovinAdWidget> {
  bool _adIdAlreadyMounted = false;
  bool _adLoadNotCalled = false;

  @override
  void initState() {
    super.initState();
    final adId = ALInstanceManager.instance.adIdFor(widget.ad);
    if (adId != null) {
      if (ALInstanceManager.instance.isWidgetAdIdMounted(adId)) {
        _adIdAlreadyMounted = true;
      }
      ALInstanceManager.instance.mountWidgetAdId(adId);
    } else {
      _adLoadNotCalled = true;
    }
  }

  @override
  void dispose() {
    super.dispose();
    final adId = ALInstanceManager.instance.adIdFor(widget.ad);
    if (adId != null) {
      ALInstanceManager.instance.unmountWidgetAdId(adId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_adIdAlreadyMounted) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('This AdWidget is already in the Widget tree'),
        ErrorHint(
            'If you placed this AdWidget in a list, make sure you create a new instance '
                'in the builder function with a unique ad object.'),
        ErrorHint(
            'Make sure you are not using the same ad object in more than one AdWidget.'),
      ]);
    }
    if (_adLoadNotCalled) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary(
            'AdWidget requires Ad.load to be called before AdWidget is inserted into the tree'),
        ErrorHint(
            'Parameter ad is not loaded. Call Ad.load before AdWidget is inserted into the tree.'),
      ]);
    }
    const viewType = 'pro.altush.ds_ads/al_widgets';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return PlatformViewLink(
        viewType: viewType,
        surfaceFactory:
            (BuildContext context, PlatformViewController controller) {
          return AndroidViewSurface(
            controller: controller as AndroidViewController,
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          );
        },
        onCreatePlatformView: (PlatformViewCreationParams params) {
          return PlatformViewsService.initSurfaceAndroidView(
            id: params.id,
            viewType: viewType,
            layoutDirection: TextDirection.ltr,
            creationParams: ALInstanceManager.instance.adIdFor(widget.ad),
            creationParamsCodec: const StandardMessageCodec(),
          )
            ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
            ..create();
        },
      );
    }

    // ToDo: implement for iOS
    return UiKitView(
      viewType: viewType,
      creationParams: ALInstanceManager.instance.adIdFor(widget.ad),
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}
