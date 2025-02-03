## 1.3.3
- fix interstitial exception handling for 3-2-1 counter https://app.asana.com/0/1208203354836323/1209262977876096/f
- try to fix: [E] Null check operator used on a null value
- try to fix: uncatched interstitial showAd recall https://app.asana.com/0/1207987727410001/1209292264154313/f

## 1.3.2
- switch to ds_common DSAdLocker

## 1.3.1
- fix banner and native state update when isPremium flag changes https://app.asana.com/0/1208203354836323/1208203354836326/f

## 1.3.0
- 3-2-1 counter customised by counterIntervals and counterDuration parameters
- dependencies updated

## 1.2.6
- remove Fimber dependency

## 1.2.5
- add environment of last ads to YandexMetrica error report

## 1.2.4
- flag appState.adsDisabledInDebugMode added to DSAppAdsStateMixin for backward capability

## 1.2.3
- fix non-blocked Back hardware button for Flutter 3.24
- flag appState.adsDisabledInDebugMode added to DSAppAdsStateMixin for backward capability

## 1.2.2
- flag appState.adsDisabledInDebugMode added

## 1.2.1
- pub.dev score improved (dart format applied)

## 1.2.0
- add DSAdsManager.disabledInDebugMode flag (makes app debug easier without ads)
- applovin_max and google_mobile_ads updated. For Android tested with this adapters versions:
```groovy
    implementation 'com.applovin.mediation:fyber-adapter:8.3.1.1'
    implementation 'com.applovin.mediation:google-ad-manager-adapter:23.4.0.1'
    implementation 'com.applovin.mediation:google-adapter:23.4.0.1'
    implementation 'com.applovin.mediation:inmobi-adapter:10.7.7.2'
    implementation 'com.squareup.picasso:picasso:2.71828'
    implementation 'androidx.recyclerview:recyclerview:1.2.1'
    implementation 'com.applovin.mediation:ironsource-adapter:8.4.0.0.0'
    implementation 'com.applovin.mediation:vungle-adapter:7.4.1.2'
    implementation 'com.applovin.mediation:facebook-adapter:6.18.0.0'
    implementation 'com.applovin.mediation:mintegral-adapter:16.8.51.2'
    implementation 'com.applovin.mediation:bytedance-adapter:6.2.0.7.0'
    implementation 'com.applovin.mediation:unityads-adapter:4.12.3.0'
    implementation 'com.google.android.gms:play-services-ads-lite:23.4.0'
```

## 1.1.0
- allow to use location in interstitialShowLockedCallback (instead of legacy interstitialShowLockCallback)
- allow to use location in rewardedShowLockedCallback (instead of legacy rewardedShowLockCallback)
- add onShowLock callback for interstitial and rewarded ads
- set Flutter 3.24 as minimum supported version (no any reason to use Flutter 3.22 but no problem with this)

## 1.0.3
- pub.dev score minor improvements

## 1.0.2
- fix external references to pro.altush.ads.ds_ads package

## 1.0.1
- fix Flutter 3.24 release build

## 1.0.0
- update dependencies
- dart format applied

## 0.8.5
- prepare to prohibit direct links to google_mobile_ads and applovin_max from projects
- add "I" property as the alias of "instance"

## 0.8.4
- pinned applovin_max to 3.10.1

## 0.8.3
- add DSConsentStatus type to prevent google_mobile_ads import

## 0.8.2
- downgrade AppLovin max to the last stable version - 3.10.1. 4.0.0 is bugly too

## 0.8.1
- changed 'Advertising in' to 'Ad in'
- updated dependencies
- mark DSAdsBanner.adaptive property as not used

## 0.8.0
- experimental support of AppLovin Flutter natives
- experimental add consent support for iOS
- remove native2 mixin (was in experimental status since version 0.4)
- copy AppOpen block implementation from Interstitial to Rewarded ads (fix app open after rewarded ad issue)
- add optional andLockFor parameter to unlockUntilAppResume
- fix isAdAvailable

## 0.7.0
- add DSAdsManager.splashAppOpen
- fix call DSAdSource.interstitial as source instead of DSAdSource.interstitial2 and DSAdSource.interstitialSplash
- fix recreating splashInterstitial on isAdShowing call
- add duration to event ads_manager: AppLovin initialized
- ads dependencies updated

## 0.6.1
- add optional counter before interstitial

## 0.6.0
- update google_mobile_ads to 5.1.0 
- banner optimizations
- add waitForInit method
- applovin_max updated

## 0.5.2
- add AppLovin 3.6.0 support
- remove appLovinSDKConfiguration property

## 0.5.1
- added consent form support
- google_mobile_ads and applovin_max updated
- ds_common minimum version updated

## 0.5.0
- add different ids support for interstitial ads
- update applovin_max dependency
- fix unclickable native ad after reload
- fix banner bug for premium mode

BREAKING CHANGE
- DSAdsInterstitialType replaced to part of DSAdSource

## 0.4.0
- add banners support
- аdd experimental native2 mixin
- update dependencies: Flutter to 3.10, etc
- fix tryNextMediation availability checks
- remove bloc state management
- fixed app open showing after click on interstitial (rare case)
- optimize AppLovin initialization

## 0.3.2
- fix AppLovin native ads for Yandex adapter (banner and size for video)
- fix app open showing after interstitial
- add adapter attribute in events report

## 0.3.1
- dependencies updated

## 0.3.0
- app open support added
- native add reload allowed
- dynamic mediation selection improved
- added google_mobile_ads v3 and dart v3 support

BREAKING CHANGES
- Flutter prior 3.0 is unsupported
- Yandex mediation removed
- parameters of many methods changed

## 0.2.0
- added beforeAdShow callback to DSAdsInterstitialCubit.showAd
- added events base classes: DSAdsInterstitialEvent and DSAdsNativeEvent
- allowed to dynamically bloc ads loading and showing by DSAdsManager.isAdAllowedCallback
- allowed to use google_mobile_ads 1.3.0 (for experimental purposes)

BREAKING CHANGES
- location attribute is strictly typified
- defaultFetchAdWait renamed to defaultFetchAdDelay and now it's deprecated
- AdState renamed to DSAdState

## 0.1.2
- fixed destroying the displayed interstitial ad
- build fixed

## 0.1.1
- extended support of separated interstitial ad (eg. splash): add parameter allowFetchNext to showAd
- fixed disposeClass exception

## 0.1.0
- dark theme support
- new style NativeAdBannerStyle.style2 added
- native ad preload

BREAKING CHANGES 
- add DS prefix to all classes

## 0.0.3
- fixed interstitial ads showing bugs

## 0.0.2
- fixed AdMob SDK error “Too many recently failed requests”
- debug code removed
- minor improvements

## 0.0.1
- init
