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
      Timber.i("Recommended to reorder pluging: GoogleMobileAdsPlugin should register before DsAdsPlugin")
      flutterEngine!!.plugins.add(GoogleMobileAdsPlugin())
    }
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    GoogleMobileAdsPlugin.registerNativeAdFactory(flutterEngine!!, "adFactory1", NativeAdFactory1(binding.activity.layoutInflater))
  }

  override fun onDetachedFromActivity() {
    GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine!!, "adFactory1")
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
