#import <Foundation/Foundation.h>

@interface WFSpoofScheduleManager : NSObject
+ (instancetype)shared;
- (void)start;
- (void)updateTimerState;
- (void)evaluateNow;
- (BOOL)isScheduleActiveNow;
- (NSString *)statusDescription;
@end
