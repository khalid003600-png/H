#import "WGEnvironment.h"
#import <UIKit/UIKit.h>

@interface WGEnvironment ()
@property (nonatomic, copy, readwrite) NSString *bundleIdentifier;
@property (nonatomic, copy, readwrite) NSString *canonicalBundleIdentifier;
@property (nonatomic, copy, readwrite) NSString *appGroupIdentifier;
@property (nonatomic, readwrite, getter=isSideloaded) BOOL sideloaded;
@end

@implementation WGEnvironment

+ (instancetype)shared {
    static WGEnvironment *obj;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ obj = [WGEnvironment new]; [obj refresh]; });
    return obj;
}

- (void)refresh {
    NSString *bundle = NSBundle.mainBundle.bundleIdentifier ?: @"";
    self.bundleIdentifier = bundle;
    self.canonicalBundleIdentifier = @"net.whatsapp.WhatsApp";
    self.sideloaded = ![bundle isEqualToString:self.canonicalBundleIdentifier] && [bundle hasPrefix:@"net.whatsapp.WhatsApp"];

    if (self.sideloaded && bundle.length > self.canonicalBundleIdentifier.length) {
        NSString *suffix = [bundle substringFromIndex:self.canonicalBundleIdentifier.length];
        self.appGroupIdentifier = [@"group.net.whatsapp.WhatsApp.shared" stringByAppendingString:suffix];
    } else {
        self.appGroupIdentifier = @"group.net.whatsapp.WhatsApp.shared";
    }
}

- (NSDictionary<NSString *,id> *)diagnostics {
    return @{
        @"bundleIdentifier": self.bundleIdentifier ?: @"",
        @"canonicalBundleIdentifier": self.canonicalBundleIdentifier ?: @"",
        @"appGroupIdentifier": self.appGroupIdentifier ?: @"",
        @"sideloaded": @(self.sideloaded),
        @"osVersion": UIDevice.currentDevice.systemVersion ?: @""
    };
}

@end
