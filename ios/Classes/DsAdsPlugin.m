#import "DsAdsPlugin.h"
#if __has_include(<ds_ads/ds_ads-Swift.h>)
#import <ds_ads/ds_ads-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "ds_ads-Swift.h"
#endif

@implementation DsAdsPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftDsAdsPlugin registerWithRegistrar:registrar];
}
@end
