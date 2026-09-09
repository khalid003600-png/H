#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <Security/Security.h>
#import <objc/runtime.h>
#import "WFLicenseClient.h"
#import "WolFoxProStore.h"

static NSString * const WFFavoritesBackupKey = @"WF_PRO_FAVORITES_BACKUP_V1";
static NSString * const WFLicenseService = @"fun.p3nd.wolfox.license";
static NSString * const WFLicenseCodeAccount = @"wf_license_code";

static NSString *WFTrimOnly(NSString *value) {
    return [value ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static BOOL WFWriteLicenseCodeExactly(NSString *code) {
    NSString *clean = WFTrimOnly(code);
    if (!clean.length) return NO;
    NSData *data = [clean dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *query = @{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
                            (__bridge id)kSecAttrService:WFLicenseService,
                            (__bridge id)kSecAttrAccount:WFLicenseCodeAccount};
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query,
                                    (__bridge CFDictionaryRef)@{(__bridge id)kSecValueData:data});
    if (status == errSecItemNotFound) {
        NSMutableDictionary *add = [query mutableCopy];
        add[(__bridge id)kSecValueData] = data;
        add[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
        status = SecItemAdd((__bridge CFDictionaryRef)add, NULL);
    }
    return status == errSecSuccess;
}

static NSArray *WFFavoritesSnapshot(WolFoxProStore *store) {
    NSMutableArray *out = [NSMutableArray array];
    for (WolFoxProLocation *loc in store.locations ?: @[]) {
        if (!CLLocationCoordinate2DIsValid(loc.coordinate)) continue;
        [out addObject:@{@"name": loc.name ?: @"موقع محفوظ",
                         @"lat": @(loc.coordinate.latitude),
                         @"lon": @(loc.coordinate.longitude),
                         @"alt": @(loc.altitude)}];
    }
    return out;
}

static void WFBackupFavorites(WolFoxProStore *store) {
    NSArray *snapshot = WFFavoritesSnapshot(store);
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setObject:snapshot forKey:WFFavoritesBackupKey];
    [defaults synchronize];
}

static void WFRestoreFavoritesIfNeeded(WolFoxProStore *store) {
    if ((store.locations ?: @[]).count > 0) {
        WFBackupFavorites(store);
        return;
    }
    NSArray *saved = [NSUserDefaults.standardUserDefaults arrayForKey:WFFavoritesBackupKey];
    if (![saved isKindOfClass:NSArray.class] || saved.count == 0) return;
    for (NSDictionary *item in [saved copy]) {
        if (![item isKindOfClass:NSDictionary.class]) continue;
        CLLocationDegrees lat = [item[@"lat"] doubleValue];
        CLLocationDegrees lon = [item[@"lon"] doubleValue];
        CLLocationCoordinate2D c = CLLocationCoordinate2DMake(lat, lon);
        if (!CLLocationCoordinate2DIsValid(c)) continue;
        WolFoxProLocation *loc = [WolFoxProLocation new];
        loc.name = [item[@"name"] isKindOfClass:NSString.class] ? item[@"name"] : @"موقع محفوظ";
        loc.coordinate = c;
        loc.altitude = [item[@"alt"] doubleValue];
        [store saveLocation:loc];
    }
    WFBackupFavorites(store);
}

@interface WFLicenseClient (WFPersistenceFixes)
+ (void)wf_activateCodeKeepingExactValue:(NSString *)code completion:(void(^)(WFLicenseResult *result))completion;
@end

@implementation WFLicenseClient (WFPersistenceFixes)
+ (void)wf_activateCodeKeepingExactValue:(NSString *)code completion:(void(^)(WFLicenseResult *result))completion {
    NSString *original = WFTrimOnly(code);
    [self wf_activateCodeKeepingExactValue:original completion:^(WFLicenseResult *result) {
        if (result.success && original.length) WFWriteLicenseCodeExactly(original);
        if (completion) completion(result);
    }];
}
@end

@interface WolFoxProStore (WFPersistenceFixes)
- (instancetype)wf_initKeepingFavorites;
- (long long)wf_saveLocationKeepingFavorites:(WolFoxProLocation *)location;
- (BOOL)wf_updateLocationKeepingFavorites:(WolFoxProLocation *)location;
- (void)wf_deleteLocationKeepingFavorites:(long long)locationID;
@end

@implementation WolFoxProStore (WFPersistenceFixes)
- (instancetype)wf_initKeepingFavorites {
    id obj = [self wf_initKeepingFavorites];
    if (obj) WFRestoreFavoritesIfNeeded(obj);
    return obj;
}
- (long long)wf_saveLocationKeepingFavorites:(WolFoxProLocation *)location {
    long long value = [self wf_saveLocationKeepingFavorites:location];
    if (value > 0) WFBackupFavorites(self);
    return value;
}
- (BOOL)wf_updateLocationKeepingFavorites:(WolFoxProLocation *)location {
    BOOL ok = [self wf_updateLocationKeepingFavorites:location];
    if (ok) WFBackupFavorites(self);
    return ok;
}
- (void)wf_deleteLocationKeepingFavorites:(long long)locationID {
    [self wf_deleteLocationKeepingFavorites:locationID];
    WFBackupFavorites(self);
}
@end

static void WFSwapInstanceMethod(Class cls, SEL a, SEL b) {
    Method ma = class_getInstanceMethod(cls, a);
    Method mb = class_getInstanceMethod(cls, b);
    if (ma && mb) method_exchangeImplementations(ma, mb);
}

static void WFSwapClassMethod(Class cls, SEL a, SEL b) {
    Method ma = class_getClassMethod(cls, a);
    Method mb = class_getClassMethod(cls, b);
    if (ma && mb) method_exchangeImplementations(ma, mb);
}

__attribute__((constructor))
static void WFInstallPersistenceFixes(void) {
    @autoreleasepool {
        WFSwapClassMethod(WFLicenseClient.class,
                          @selector(activateCode:completion:),
                          @selector(wf_activateCodeKeepingExactValue:completion:));
        WFSwapInstanceMethod(WolFoxProStore.class, @selector(init), @selector(wf_initKeepingFavorites));
        WFSwapInstanceMethod(WolFoxProStore.class, @selector(saveLocation:), @selector(wf_saveLocationKeepingFavorites:));
        WFSwapInstanceMethod(WolFoxProStore.class, @selector(updateLocation:), @selector(wf_updateLocationKeepingFavorites:));
        WFSwapInstanceMethod(WolFoxProStore.class, @selector(deleteLocationID:), @selector(wf_deleteLocationKeepingFavorites:));

        if ([WFLicenseClient hasStoredLicense] && [WFLicenseClient storedCode].length) {
            [WFLicenseClient verifySavedLicenseWithCompletion:^(__unused WFLicenseResult *result) {}];
        }
    }
}
