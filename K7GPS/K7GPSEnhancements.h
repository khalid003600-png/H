#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

@interface K7GPSEnhancements : NSObject
+ (NSDictionary *)buildInformationForVariant:(NSString *)variant version:(NSString *)version;
+ (nullable NSDictionary *)coordinateFromText:(NSString *)text;
+ (NSData *)exportSettingsDictionary:(NSDictionary *)settings error:(NSError **)error;
+ (nullable NSDictionary *)importSettingsData:(NSData *)data error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
