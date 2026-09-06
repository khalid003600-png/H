#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>

static NSString * const WGOfficialBundleID = @"net.whatsapp.WhatsApp";
static NSString * const WGOfficialGroupID = @"group.net.whatsapp.WhatsApp.shared";
static NSString * const WGCompatEnabledKey = @"WGoldCompatBundleAliasEnabled";

static BOOL WGIsWhatsAppCloneBundle(NSString *bundleID) {
    if (bundleID.length == 0) return NO;
    if ([bundleID isEqualToString:WGOfficialBundleID]) return NO;
    return [bundleID hasPrefix:WGOfficialBundleID];
}

static BOOL WGCompatEnabled(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id explicitValue = [defaults objectForKey:WGCompatEnabledKey];
    return explicitValue ? [explicitValue boolValue] : YES;
}

@interface NSBundle (WGoldCompat)
- (NSString *)wg_bundleIdentifier;
@end

@implementation NSBundle (WGoldCompat)
- (NSString *)wg_bundleIdentifier {
    NSString *real = [self wg_bundleIdentifier];
    if (self == NSBundle.mainBundle && WGCompatEnabled() && WGIsWhatsAppCloneBundle(real)) {
        return WGOfficialBundleID;
    }
    return real;
}
@end

@interface NSFileManager (WGoldCompat)
- (NSURL *)wg_containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier;
@end

@implementation NSFileManager (WGoldCompat)
- (NSURL *)wg_containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier {
    NSString *realBundle = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
    if (WGCompatEnabled() && WGIsWhatsAppCloneBundle(realBundle) && [groupIdentifier isEqualToString:WGOfficialGroupID]) {
        NSURL *official = [self wg_containerURLForSecurityApplicationGroupIdentifier:groupIdentifier];
        if (official) return official;

        NSString *suffix = [realBundle substringFromIndex:WGOfficialBundleID.length];
        NSString *cloneGroup = [WGOfficialGroupID stringByAppendingString:suffix ?: @""];
        NSURL *cloneURL = [self wg_containerURLForSecurityApplicationGroupIdentifier:cloneGroup];
        if (cloneURL) return cloneURL;
    }
    return [self wg_containerURLForSecurityApplicationGroupIdentifier:groupIdentifier];
}
@end

static void WGSwizzle(Class cls, SEL original, SEL replacement) {
    Method a = class_getInstanceMethod(cls, original);
    Method b = class_getInstanceMethod(cls, replacement);
    if (a && b) method_exchangeImplementations(a, b);
}

__attribute__((constructor))
static void WGoldCompatInit(void) {
    @autoreleasepool {
        NSString *realBundle = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
        if (!WGIsWhatsAppCloneBundle(realBundle)) return;

        WGSwizzle(NSBundle.class, @selector(bundleIdentifier), @selector(wg_bundleIdentifier));
        WGSwizzle(NSFileManager.class,
                  @selector(containerURLForSecurityApplicationGroupIdentifier:),
                  @selector(wg_containerURLForSecurityApplicationGroupIdentifier:));

        NSLog(@"[WGoldCompat] enabled for %@ -> %@", realBundle, WGOfficialBundleID);
    }
}
