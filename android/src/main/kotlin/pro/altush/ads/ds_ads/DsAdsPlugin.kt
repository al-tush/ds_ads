package pro.altush.ads.ds_ads

import android.os.Looper
import androidx.annotation.NonNull
import com.google.android.exoplayer2.ui.BuildConfig
import com.yandex.mobile.ads.common.AdRequest
import com.yandex.mobile.ads.common.AdRequestError
import com.yandex.mobile.ads.common.ImpressionData
import com.yandex.mobile.ads.common.MobileAds
import com.yandex.mobile.ads.interstitial.InterstitialAd
import com.yandex.mobile.ads.interstitial.InterstitialAdEventListener
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import timber.log.Timber

/** DsAdsPlugin */
class DsAdsPlugin: FlutterPlugin, ActivityAware {
  private var flutterEngine: FlutterEngine? = null
  private val channelYandexName = "pro.altush.ds_ads/yandex_native"
  private lateinit var channel: MethodChannel

  private val interstitials = mutableMapOf<String, InterstitialAd>()

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    flutterEngine = flutterPluginBinding.flutterEngine
    if (!flutterEngine!!.plugins.has(GoogleMobileAdsPlugin::class.java)) {
      Timber.i("Recommended to reorder plugging: GoogleMobileAdsPlugin should be registered before DsAdsPlugin")
      flutterEngine!!.plugins.add(GoogleMobileAdsPlugin())
    }
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, channelYandexName)
    channel.setMethodCallHandler {
      // This method is invoked on the main thread.
      call, result ->
      try {
        val context = flutterPluginBinding.applicationContext
        when (call.method) {
          "init" -> {
            MobileAds.enableDebugErrorIndicator(BuildConfig.DEBUG)
            MobileAds.initialize(context) {
              Timber.i("yandex_ads: initialized")
              result.success(null)
            }
          }
          "loadInterstitial" -> {
            val params = call.arguments as List<*>
            val unitId = params[0] as String
            Timber.i("TEST: loadInterstitial $unitId")
            assert(unitId.startsWith("R-M-"))
            if (interstitials.containsKey(unitId)) {
              result.error("", "$unitId is already loaded", null)
              return@setMethodCallHandler
            }
            val inter = InterstitialAd(context)
            inter.setAdUnitId(unitId)
            val adRequest = AdRequest.Builder()
                    .build()

            inter.setInterstitialAdEventListener(object : InterstitialAdEventListener {
              override fun onAdLoaded() {
                Timber.i("TEST: onAdLoaded")
                invokeEvent("onAdLoaded", mapOf(
                        "unitId" to unitId,
                ))
              }

              override fun onAdFailedToLoad(error: AdRequestError) {
                Timber.i("TEST: onAdFailedToLoad")
                interstitials.remove(unitId)
                invokeEvent("onAdFailedToLoad", mapOf(
                        "unitId" to unitId,
                        "errorCode" to error.code,
                        "errorDescription" to error.description,
                ))
              }

              override fun onAdShown() {
                Timber.i("TEST: onAdShown")
                invokeEvent("onAdShown", mapOf(
                        "unitId" to unitId,
                ))
              }

              override fun onAdDismissed() {
                Timber.i("TEST: onAdDismissed")
                interstitials.remove(unitId)
                invokeEvent("onAdDismissed", mapOf(
                        "unitId" to unitId,
                ))
              }

              override fun onAdClicked() {
                Timber.i("TEST: onAdClicked")
                invokeEvent("onAdClicked", mapOf(
                        "unitId" to unitId,
                ))
              }

              override fun onLeftApplication() {
                Timber.i("TEST: onLeftApplication")
              }

              override fun onReturnedToApplication() {
                Timber.i("TEST: onReturnedToApplication")
              }

              override fun onImpression(data: ImpressionData?) {
                Timber.i("TEST: onImpression")
                invokeEvent("onImpression", mapOf(
                        "unitId" to unitId,
                        "data" to data?.rawData,
                ))
              }
          })
            interstitials[unitId] = inter
            inter.loadAd(adRequest)
            result.success(null)
          }
          "showInterstitial" -> {
            val params = call.arguments as List<*>
            val unitId = params[0] as String
            val inter = interstitials.remove(unitId)!!
            inter.show()
            result.success(null)
          }
          else -> result.notImplemented()
        }
      } catch (e: Throwable) {
        result.error("", "$e", null)
      }
    }
  }

  private fun invokeEvent(eventName: String, arguments: Map<String, Any?>) {
    android.os.Handler(Looper.getMainLooper()).post {
      channel.invokeMethod(eventName, arguments)
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
