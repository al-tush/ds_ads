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
