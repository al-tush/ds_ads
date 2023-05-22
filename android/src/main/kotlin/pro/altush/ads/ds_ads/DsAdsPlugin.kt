package pro.altush.ads.ds_ads

import android.os.Looper
import android.util.Log
import com.applovin.applovin_max.AppLovinMAX
import com.applovin.mediation.MaxAd
import com.applovin.mediation.nativeAds.MaxNativeAdView
import com.yandex.mobile.ads.common.AdRequest
import com.yandex.mobile.ads.common.AdRequestError
import com.yandex.mobile.ads.common.ImpressionData
import com.yandex.mobile.ads.common.MobileAds
import com.yandex.mobile.ads.interstitial.InterstitialAd
import com.yandex.mobile.ads.interstitial.InterstitialAdEventListener
import io.flutter.BuildConfig
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import timber.log.Timber

/** DsAdsPlugin */
class DsAdsPlugin: FlutterPlugin, ActivityAware {

  companion object {
    fun registerALNativeAdFactory(engine: FlutterEngine, factoryId: String,
                                  nativeAdFactory: ALNativeAdFactory): Boolean {
      val plugin = engine.plugins[DsAdsPlugin::class.java] as DsAdsPlugin?
      if (plugin == null) {
        val message = String.format(
          "Could not find a %s instance. The plugin may have not been registered.",
          DsAdsPlugin::class.java.simpleName
        )
        throw IllegalStateException(message)
      }
      if (plugin.alInstanceManager!!.alFactories.containsKey(factoryId)) {
        val errorMessage = String.format(
          "A ALNativeAdFactory with the following factoryId already exists: %s", factoryId
        )
        Timber.e(errorMessage)
        return false
      }

      plugin.alInstanceManager!!.alFactories[factoryId] = nativeAdFactory
      return true
    }

    fun unregisterALNativeAdFactory(engine: FlutterEngine, factoryId: String) {
      val plugin = engine.plugins[DsAdsPlugin::class.java] as DsAdsPlugin?
      if (plugin == null) {
        val message = String.format(
          "Could not find a %s instance. The plugin may have not been registered.",
          DsAdsPlugin::class.java.simpleName
        )
        throw IllegalStateException(message)
      }
      plugin.alInstanceManager!!.alFactories.remove(factoryId)
    }
  }

  private var flutterEngine: FlutterEngine? = null
  private val channelYandexName = "pro.altush.ds_ads/yandex_native"
  private lateinit var channel: MethodChannel

  private val yaInterstitials = mutableMapOf<String, InterstitialAd>()

  private var alInstanceManager: ALInstanceManager? = null

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    flutterEngine = flutterPluginBinding.flutterEngine
    if (!flutterEngine!!.plugins.has(GoogleMobileAdsPlugin::class.java)) {
      Timber.i("Recommended to reorder plugging: GoogleMobileAdsPlugin should be registered before DsAdsPlugin")
      flutterEngine!!.plugins.add(GoogleMobileAdsPlugin())
    }
    if (!flutterEngine!!.plugins.has(com.applovin.applovin_max.AppLovinMAX::class.java)) {
      Timber.i("Recommended to reorder plugging: AppLovinMAX should be registered before DsAdsPlugin")
      flutterEngine!!.plugins.add(com.applovin.applovin_max.AppLovinMAX())
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
            assert(unitId.startsWith("R-M-"))
            if (yaInterstitials.containsKey(unitId)) {
              result.error("", "$unitId is already loaded", null)
              return@setMethodCallHandler
            }
            val inter = InterstitialAd(context)
            inter.setAdUnitId(unitId)
            val adRequest = AdRequest.Builder()
                    .build()

            inter.setInterstitialAdEventListener(object : InterstitialAdEventListener {
              override fun onAdLoaded() {
                invokeEvent("onAdLoaded", mapOf(
                        "unitId" to unitId,
                ))
              }

              override fun onAdFailedToLoad(error: AdRequestError) {
                yaInterstitials.remove(unitId)
                invokeEvent("onAdFailedToLoad", mapOf(
                        "unitId" to unitId,
                        "errorCode" to error.code,
                        "errorDescription" to error.description,
                ))
              }

              override fun onAdShown() {
                invokeEvent("onAdShown", mapOf(
                        "unitId" to unitId,
                ))
              }

              override fun onAdDismissed() {
                yaInterstitials.remove(unitId)
                invokeEvent("onAdDismissed", mapOf(
                        "unitId" to unitId,
                ))
              }

              override fun onAdClicked() {
                invokeEvent("onAdClicked", mapOf(
                        "unitId" to unitId,
                ))
              }

              override fun onLeftApplication() {
                Timber.i("yandex_ads: onLeftApplication")
              }

              override fun onReturnedToApplication() {
                Timber.i("yandex_ads: onReturnedToApplication")
              }

              override fun onImpression(data: ImpressionData?) {
                invokeEvent("onImpression", mapOf(
                        "unitId" to unitId,
                        "data" to data?.rawData,
                ))
              }
          })
            yaInterstitials[unitId] = inter
            inter.loadAd(adRequest)
            result.success(null)
          }
          "showInterstitial" -> {
            val params = call.arguments as List<*>
            val unitId = params[0] as String
            val inter = yaInterstitials.remove(unitId)!!
            inter.show()
            result.success(null)
          }
          else -> result.notImplemented()
        }
      } catch (e: Throwable) {
        result.error("", "$e", null)
      }
    }

    alInstanceManager = ALInstanceManager(flutterPluginBinding)
  }

  private fun invokeEvent(eventName: String, arguments: Map<String, Any?>) {
    android.os.Handler(Looper.getMainLooper()).post {
      channel.invokeMethod(eventName, arguments)
    }
  }

  interface ALNativeAdFactory {
    fun createNativeAd(): MaxNativeAdView
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    alInstanceManager!!.setActivity(binding.activity)

    val engine = flutterEngine!!
    GoogleMobileAdsPlugin.registerNativeAdFactory(
      engine,
      "adFactory1Light",
      NativeAdFactory1(binding.activity.layoutInflater, R.layout.g_native_ad_1_light),
    )
    GoogleMobileAdsPlugin.registerNativeAdFactory(
      engine,
      "adFactory1Dark",
      NativeAdFactory1(binding.activity.layoutInflater, R.layout.g_native_ad_1_dark),
    )
    GoogleMobileAdsPlugin.registerNativeAdFactory(
      engine,
      "adFactory2Light",
      NativeAdFactory1(binding.activity.layoutInflater, R.layout.g_native_ad_2_light),
    )
    GoogleMobileAdsPlugin.registerNativeAdFactory(
      engine,
      "adFactory2Dark",
      NativeAdFactory1(binding.activity.layoutInflater, R.layout.g_native_ad_2_dark),
    )

    registerALNativeAdFactory(
      engine,
      "adFactory1Light",
      ALNativeAdFactory1(binding.activity, R.layout.al_native_ad_1_light),
    )
    registerALNativeAdFactory(
      engine,
      "adFactory1Dark",
      ALNativeAdFactory1(binding.activity, R.layout.al_native_ad_1_dark),
    )
    registerALNativeAdFactory(
      engine,
      "adFactory2Light",
      ALNativeAdFactory1(binding.activity, R.layout.al_native_ad_2_light),
    )
    registerALNativeAdFactory(
      engine,
      "adFactory2Dark",
      ALNativeAdFactory1(binding.activity, R.layout.al_native_ad_2_dark),
    )
  }

  override fun onDetachedFromActivity() {
    val engine = flutterEngine!!
    GoogleMobileAdsPlugin.unregisterNativeAdFactory(engine, "adFactory1Light")
    GoogleMobileAdsPlugin.unregisterNativeAdFactory(engine, "adFactory1Dark")
    GoogleMobileAdsPlugin.unregisterNativeAdFactory(engine, "adFactory2Light")
    GoogleMobileAdsPlugin.unregisterNativeAdFactory(engine, "adFactory2Dark")

    unregisterALNativeAdFactory(engine, "adFactory1Light")
    unregisterALNativeAdFactory(engine, "adFactory1Dark")
    unregisterALNativeAdFactory(engine, "adFactory2Light")
    unregisterALNativeAdFactory(engine, "adFactory2Dark")

    alInstanceManager?.setActivity(null)
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    onAttachedToActivity(binding)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity()
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    flutterEngine = null
  }
}
