#import "K7GPSEnhancements.h"

@implementation K7GPSEnhancements

+ (NSDictionary *)buildInformationForVariant:(NSString *)variant version:(NSString *)version {
    return @{
        @"product": @"K7GPS",
        @"variant": variant ?: @"standalone",
        @"version": version ?: @"1.0.1",
        @"builtAt": [[NSISO8601DateFormatter new] stringFromDate:[NSDate date]] ?: @""
    };
}

+ (NSDictionary *)coordinateFromText:(NSString *)text {
    NSString *q = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!q.length) return nil;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"^\\s*([+-]?[0-9]+(?:\\.[0-9]+)?)\\s*[, ]\\s*([+-]?[0-9]+(?:\\.[0-9]+)?)\\s*$" options:0 error:nil];
    NSTextCheckingResult *m = [re firstMatchInString:q options:0 range:NSMakeRange(0, q.length)];
    if (!m || m.numberOfRanges < 3) return nil;
    double lat = [[q substringWithRange:[m rangeAtIndex:1]] doubleValue];
    double lon = [[q substringWithRange:[m rangeAtIndex:2]] doubleValue];
    CLLocationCoordinate2D c = CLLocationCoordinate2DMake(lat, lon);
    if (!CLLocationCoordinate2DIsValid(c) || fabs(lat) > 90.0 || fabs(lon) > 180.0) return nil;
    return @{ @"lat": @(lat), @"lon": @(lon) };
}

+ (NSData *)exportSettingsDictionary:(NSDictionary *)settings error:(NSError **)error {
    NSDictionary *root = @{ @"format": @"K7GPS-settings-v1", @"settings": settings ?: @{} };
    return [NSJSONSerialization dataWithJSONObject:root options:NSJSONWritingPrettyPrinted error:error];
}

+ (NSDictionary *)importSettingsData:(NSData *)data error:(NSError **)error {
    if (!data.length) return nil;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (![obj isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *root = (NSDictionary *)obj;
    if (![root[@"format"] isEqual:@"K7GPS-settings-v1"] || ![root[@"settings"] isKindOfClass:NSDictionary.class]) return nil;
    return root[@"settings"];
}

@end
