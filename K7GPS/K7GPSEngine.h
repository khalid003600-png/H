#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const K7GPSEngineLocationDidChangeNotification;
FOUNDATION_EXPORT NSString * const K7GPSEngineStateDidChangeNotification;

@interface K7GPSEngine : NSObject
+ (instancetype)shared;
@property(nonatomic, assign, readonly) BOOL running;
@property(nonatomic, assign, readonly) BOOL randomMode;
@property(nonatomic, assign, readonly) BOOL routeMode;
@property(nonatomic, assign, readonly) BOOL scheduleMode;
@property(nonatomic, assign, readonly) CLLocationCoordinate2D currentCoordinate;
@property(nonatomic, copy, readonly) NSArray<NSValue *> *routePoints;

- (void)activateCoordinate:(CLLocationCoordinate2D)coordinate;
- (void)stopAll;

- (void)setRoutePoints:(NSArray<NSValue *> *)points;
- (void)startRouteWithInterval:(NSTimeInterval)interval loops:(BOOL)loops;
- (void)stopRoute;

- (void)startRandomAround:(CLLocationCoordinate2D)center radiusMeters:(CLLocationDistance)radius interval:(NSTimeInterval)interval;
- (void)stopRandom;

- (void)scheduleCoordinate:(CLLocationCoordinate2D)coordinate atDate:(NSDate *)date;
- (void)cancelSchedule;
@end

NS_ASSUME_NONNULL_END
