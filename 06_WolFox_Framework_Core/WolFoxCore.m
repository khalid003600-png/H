#import "WolFoxCore.h"
#import "../WFLicenseClient.h"
#import "../WolFoxProStore.h"
#import "../WolFoxProHookManager.h"

#ifndef WOLFOX_CORE_VERSION
#define WOLFOX_CORE_VERSION "1.0.0"
#endif

double WolFoxCoreVersionNumber = 1.0;
const unsigned char WolFoxCoreVersionString[] = WOLFOX_CORE_VERSION;

@implementation WolFoxCore

+ (instancetype)shared {
    static WolFoxCore *core = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        core = [WolFoxCore new];
    });
    return core;
}

- (void)start {
    [[WolFoxProHookManager shared] installHooks];
}

- (BOOL)isLicenseValid {
    return [WFLicenseClient isRuntimeLicenseValid];
}

- (void)setSpoofCoordinate:(CLLocationCoordinate2D)coordinate enabled:(BOOL)enabled {
    WolFoxProStore *store = [WolFoxProStore shared];
    store.currentFakeCoords = coordinate;
    store.spoofActive = enabled;
    [store saveSettings];
    if (enabled) {
        [[WolFoxProHookManager shared] deliverFakeUpdate];
    } else {
        [[WolFoxProHookManager shared] stopRoute];
    }
}

@end
