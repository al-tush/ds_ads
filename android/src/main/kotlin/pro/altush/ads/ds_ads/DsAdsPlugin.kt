package pro.altush.ads.ds_ads

import androidx.annotation.NonNull

import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import timber.log.Timber

/** DsAdsPlugin */
class DsAdsPlugin: FlutterPlugin, ActivityAware {
  private var flutterEngine: FlutterEngine? = null

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    flutterEngine = flutterPluginBinding.flutterEngine
    if (!flutterEngine!!.plugins.has(GoogleMobileAdsPlugin::class.java)) {
      Timber.i("Recommended to reorder plugging: GoogleMobileAdsPlugin should be registered before DsAdsPlugin")
      flutterEngine!!.plugins.add(GoogleMobileAdsPlugin())
    }
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine!!,
            "adFactory1Light",
            NativeAdFactory1(binding.activity.layoutInflater, R.layout.native_ad_1_light),
    )
    GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine!!,
            "adFactory1Dark",
            NativeAdFactory1(binding.activity.layoutInflater, R.layout.native_ad_1_dark),
    )
    GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine!!,
            "adFactory2Light",
            NativeAdFactory1(binding.activity.layoutInflater, R.layout.native_ad_2_light),
    )
    GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine!!,
            "adFactory2Dark",
            NativeAdFactory1(binding.activity.layoutInflater, R.layout.native_ad_2_dark),
    )
  }

  override fun onDetachedFromActivity() {
    GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine!!, "adFactory1Light")
    GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine!!, "adFactory1Dark")
    GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine!!, "adFactory2Light")
    GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine!!, "adFactory2Dark")
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    onAttachedToActivity(binding)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity()
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    flutterEngine = null
  }
}
