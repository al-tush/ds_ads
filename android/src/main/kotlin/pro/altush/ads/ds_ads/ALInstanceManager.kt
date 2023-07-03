package pro.altush.ads.ds_ads

import android.app.Activity
import android.content.Context
import android.graphics.Color
import android.os.Looper
import android.view.View
import android.widget.TextView
import io.flutter.BuildConfig
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import timber.log.Timber
import java.util.*

class ALInstanceManager(binding: FlutterPlugin.FlutterPluginBinding) {

    private val channelAppLovinName = "pro.altush.ds_ads/app_lovin_ads"
    private var channel: MethodChannel

    val alFactories = mutableMapOf<String, DsAdsPlugin.ALNativeAdFactory>()
    private val alNatives = mutableMapOf<Int, ALNativeAd>()

    var activity: Activity? = null
        private set

    init {
        channel = MethodChannel(binding.binaryMessenger, channelAppLovinName)
        binding.platformViewRegistry.registerViewFactory(
            "pro.altush.ds_ads/al_widgets",
            ALNativeViewFactory(this))
        channel.setMethodCallHandler {
            // This method is invoked on the main thread.
                call, result ->
            try {
                when (call.method) {
                    "loadNativeAd" -> {
                        val args = call.arguments as Map<*, *>
                        val adId = args["adId"] as Int
                        val adUnitId = args["adUnitId"] as String
                        val factoryId = args["factoryId"] as String

                        if (alNatives.containsKey(adId)) {
                            result.error("", "$$adId is already loaded", null)
                            return@setMethodCallHandler
                        }
                        val ad = ALNativeAd(adId, adUnitId, this, factoryId)
                        alNatives[adId] = ad
                        ad.load(activity!!)
                        result.success(null)
                    }
                    "disposeAd" -> {
                        val args = call.arguments as Map<*, *>
                        val adId = args["adId"] as Int
                        adForId(adId)!!.dispose()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Throwable) {
                result.error("", "$e", null)
            }
        }

    }

    fun adForId(id: Int): ALNativeAd? {
        return alNatives[id]
    }

    fun adIdFor(ad: ALNativeAd): Int? {
        for (adId in alNatives.keys) {
            if (alNatives[adId] === ad) {
                return adId
            }
        }
        return null
    }

    fun invokeMethod(eventName: String, arguments: Map<String, Any?>) {
        android.os.Handler(Looper.getMainLooper()).post {
            channel.invokeMethod(eventName, arguments)
        }
    }

    fun setActivity(newValue: Activity?) {
        if (activity == newValue) return
        activity = newValue
//        alNatives.values.forEach { it.dispose() }
//        alNatives.clear()
    }

}

class ALNativeViewFactory (
    private val manager: ALInstanceManager,
        ) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context?, viewId: Int, args: Any?): PlatformView {
        val adId = args as Int
        val ad = manager.adForId(adId)
        val pv = ad?.getPlatformView()
        return pv ?: getErrorView(context!!, adId)
    }

    private class ErrorTextView(context: Context, message: String) : PlatformView {
        private val textView: TextView

        init {
            textView = TextView(context)
            textView.text = message
            textView.setBackgroundColor(Color.RED)
            textView.setTextColor(Color.YELLOW)
        }

        override fun getView(): View {
            return textView
        }

        override fun dispose() {}
    }

    /**
     * Returns an ErrorView with a debug message for debug builds only. Otherwise just returns an
     * empty PlatformView.
     */
    private fun getErrorView(context: Context, adId: Int): PlatformView {
        val message = String.format(
            Locale.getDefault(), "This ad may have not been loaded or has been disposed. "
                    + "Ad with the following id could not be found: %d.",
            adId
        )
        return if (BuildConfig.DEBUG) {
            ErrorTextView(context, message)
        } else {
            Timber.e(ALNativeViewFactory::class.java.simpleName, message)
            object : PlatformView {
                override fun getView(): View {
                    return View(context)
                }

                override fun dispose() {
                    // Do nothing.
                }
            }
        }
    }

}
