#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT double WolFoxCoreVersionNumber;
FOUNDATION_EXPORT const unsigned char WolFoxCoreVersionString[];

@interface WolFoxCore : NSObject
+ (instancetype)shared;
- (void)start;
- (BOOL)isLicenseValid;
- (void)setSpoofCoordinate:(CLLocationCoordinate2D)coordinate enabled:(BOOL)enabled;
@end

NS_ASSUME_NONNULL_END
