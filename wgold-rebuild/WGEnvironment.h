#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WGEnvironment : NSObject
+ (instancetype)shared;
@property (nonatomic, readonly) NSString *bundleIdentifier;
@property (nonatomic, readonly) NSString *canonicalBundleIdentifier;
@property (nonatomic, readonly) NSString *appGroupIdentifier;
@property (nonatomic, readonly, getter=isSideloaded) BOOL sideloaded;
- (void)refresh;
- (NSDictionary<NSString *, id> *)diagnostics;
@end

NS_ASSUME_NONNULL_END
