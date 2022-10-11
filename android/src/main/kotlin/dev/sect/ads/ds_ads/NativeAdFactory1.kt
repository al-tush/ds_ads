package dev.sect.ads.ds_ads

import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

internal class NativeAdFactory1(val layoutInflater: LayoutInflater) : NativeAdFactory {
    override fun createNativeAd(nativeAd: NativeAd, customOptions: Map<String, Any>?): NativeAdView  {

        val adView = layoutInflater.inflate(R.layout.native_ad_1, null) as NativeAdView

        // Set the media view.
        adView.setMediaView(adView.findViewById(R.id.ad_media) as MediaView)

        // Set other ad assets.
        adView.setHeadlineView(adView.findViewById(R.id.ad_headline))
        adView.setBodyView(adView.findViewById(R.id.ad_body))
        adView.setCallToActionView(adView.findViewById(R.id.ad_call_to_action))
        adView.setIconView(adView.findViewById(R.id.ad_app_icon))

        // The headline and mediaContent are guaranteed to be in every NativeAd.
        (adView.getHeadlineView() as TextView).setText(nativeAd.getHeadline())
        adView.getMediaView()?.setMediaContent(nativeAd.mediaContent!!)

        // These assets aren't guaranteed to be in every NativeAd, so it's important to
        // check before trying to display them.
        if (nativeAd.getBody() == null) {
            adView.bodyView!!.setVisibility(View.INVISIBLE)
        } else {
            adView.bodyView!!.setVisibility(View.VISIBLE)
            (adView.bodyView as TextView).text = nativeAd.body
        }
        if (nativeAd.getCallToAction() == null) {
            adView.callToActionView!!.setVisibility(View.INVISIBLE)
        } else {
            adView.callToActionView!!.setVisibility(View.VISIBLE)
            (adView.callToActionView as Button).text = nativeAd.callToAction
        }
        if (nativeAd.getIcon() == null) {
            adView.iconView!!.setVisibility(View.GONE)
        } else {
            (adView.iconView!! as ImageView).setImageDrawable(nativeAd.icon!!.drawable)
            adView.iconView!!.visibility = View.VISIBLE
        }

        // This method tells the Google Mobile Ads SDK that you have finished populating your
        // native ad view with this native ad.
        adView.setNativeAd(nativeAd)
        return adView
    }
}