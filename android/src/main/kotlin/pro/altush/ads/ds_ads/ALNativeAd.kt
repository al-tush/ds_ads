package pro.altush.ads.ds_ads

import android.content.Context
import android.view.View
import com.applovin.mediation.MaxAd
import com.applovin.mediation.MaxAdRevenueListener
import com.applovin.mediation.MaxError
import com.applovin.mediation.nativeAds.MaxNativeAdListener
import com.applovin.mediation.nativeAds.MaxNativeAdLoader
import com.applovin.mediation.nativeAds.MaxNativeAdView
import io.flutter.plugin.platform.PlatformView

class ALNativeAd(
    val id: Int,
    private val adUnitId: String,
    private val manager: ALInstanceManager,
    private val factoryId: String,
) {
    private var nativeAdLoader: MaxNativeAdLoader? = null
    private var nativeAdView: MaxNativeAdView? = null

    private var nativeAd: MaxAd? = null


    fun getPlatformView(): PlatformView? {
        return nativeAdView?.let { FlutterPlatformView(it) }
    }

    fun load(context: Context) {
        val factory = manager.alFactories[factoryId]
            ?: throw Exception("Can't find NativeAdFactory with id: $factoryId")

        nativeAdLoader = MaxNativeAdLoader(adUnitId, context)
        nativeAdLoader!!.setRevenueListener(object : MaxAdRevenueListener {
            override fun onAdRevenuePaid(ad: MaxAd?) {
                manager.invokeMethod("onPaidEvent",
                mapOf(
                    "adId" to id,
                    "revenue" to ad?.revenue,
                    "precision" to ad?.revenuePrecision,
                ))
            }
        })
        nativeAdLoader!!.setNativeAdListener(object : MaxNativeAdListener() {
            override fun onNativeAdLoaded(view: MaxNativeAdView?, ad: MaxAd) {
                nativeAd = ad
                nativeAdView = factory.createNativeAd()
                manager.invokeMethod("onAdLoaded", mapOf("adId" to id))
                nativeAdLoader!!.render(nativeAdView!!, ad)
            }

            override fun onNativeAdLoadFailed(adUnitId: String, error: MaxError) {
                manager.invokeMethod("onAdLoadFailed",
                    mapOf("adId" to id, "error_code" to error.code, "error_message" to error.message))
            }

            override fun onNativeAdClicked(ad: MaxAd) {
                manager.invokeMethod("onAdClicked", mapOf("adId" to id))
            }

            override fun onNativeAdExpired(nativeAd: MaxAd?) {
                manager.invokeMethod("onAdExpired", mapOf("adId" to id))
            }
        })

        nativeAdLoader!!.loadAd()
    }

    fun dispose() {
        if (nativeAd != null) {
            // Call destroy on the native ad from any native ad loader.
            nativeAdLoader?.destroy(nativeAd)
            nativeAd = null
        }

        // Destroy the actual loader itself
        nativeAdLoader?.destroy()
        nativeAdLoader = null
    }
}

/** A simple PlatformView that wraps a View and sets its reference to null on dispose().  */
internal class FlutterPlatformView(view: View) : PlatformView {
    private var view: View?

    init {
        this.view = view
    }

    override fun getView(): View? {
        return view
    }

    override fun dispose() {
        view = null
    }
}
