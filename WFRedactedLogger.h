#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *WFRedactString(NSString * _Nullable input);
FOUNDATION_EXPORT void WFLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
FOUNDATION_EXPORT void WFLogEvent(NSString *event, NSDictionary<NSString *, id> * _Nullable fields);

NS_ASSUME_NONNULL_END
