#import "K7GPSEngine.h"
#import <math.h>

NSString * const K7GPSEngineLocationDidChangeNotification = @"K7GPSEngineLocationDidChangeNotification";
NSString * const K7GPSEngineStateDidChangeNotification = @"K7GPSEngineStateDidChangeNotification";

@interface K7GPSEngine ()
@property(nonatomic, assign, readwrite) BOOL running;
@property(nonatomic, assign, readwrite) BOOL randomMode;
@property(nonatomic, assign, readwrite) BOOL routeMode;
@property(nonatomic, assign, readwrite) BOOL scheduleMode;
@property(nonatomic, assign, readwrite) CLLocationCoordinate2D currentCoordinate;
@property(nonatomic, copy, readwrite) NSArray<NSValue *> *routePoints;
@property(nonatomic, strong) NSTimer *routeTimer;
@property(nonatomic, strong) NSTimer *randomTimer;
@property(nonatomic, strong) NSTimer *scheduleTimer;
@property(nonatomic, assign) NSUInteger routeIndex;
@property(nonatomic, assign) BOOL routeLoops;
@property(nonatomic, assign) CLLocationCoordinate2D randomCenter;
@property(nonatomic, assign) CLLocationDistance randomRadius;
@end

@implementation K7GPSEngine

+ (instancetype)shared {
    static K7GPSEngine *engine;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ engine = [K7GPSEngine new]; });
    return engine;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _routePoints = @[];
        _currentCoordinate = kCLLocationCoordinate2DInvalid;
    }
    return self;
}

- (void)notifyState {
    [[NSNotificationCenter defaultCenter] postNotificationName:K7GPSEngineStateDidChangeNotification object:self];
}

- (void)notifyLocation {
    [[NSNotificationCenter defaultCenter] postNotificationName:K7GPSEngineLocationDidChangeNotification object:self userInfo:@{
        @"latitude": @(self.currentCoordinate.latitude),
        @"longitude": @(self.currentCoordinate.longitude)
    }];
}

- (void)activateCoordinate:(CLLocationCoordinate2D)coordinate {
    if (!CLLocationCoordinate2DIsValid(coordinate)) return;
    self.currentCoordinate = coordinate;
    self.running = YES;
    [self notifyLocation];
    [self notifyState];
}

- (void)stopAll {
    [self.routeTimer invalidate]; self.routeTimer = nil;
    [self.randomTimer invalidate]; self.randomTimer = nil;
    [self.scheduleTimer invalidate]; self.scheduleTimer = nil;
    self.running = NO;
    self.routeMode = NO;
    self.randomMode = NO;
    self.scheduleMode = NO;
    [self notifyState];
}

- (void)setRoutePoints:(NSArray<NSValue *> *)points {
    _routePoints = [points copy] ?: @[];
    self.routeIndex = 0;
}

- (void)startRouteWithInterval:(NSTimeInterval)interval loops:(BOOL)loops {
    [self.routeTimer invalidate];
    if (self.routePoints.count == 0) return;
    self.routeLoops = loops;
    self.routeIndex = 0;
    self.routeMode = YES;
    self.randomMode = NO;
    self.running = YES;
    interval = MAX(0.25, interval);
    __weak typeof(self) weakSelf = self;
    self.routeTimer = [NSTimer scheduledTimerWithTimeInterval:interval repeats:YES block:^(__unused NSTimer *timer) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.routePoints.count == 0) return;
        if (self.routeIndex >= self.routePoints.count) {
            if (self.routeLoops) self.routeIndex = 0;
            else { [self stopRoute]; return; }
        }
        CLLocationCoordinate2D c = [self.routePoints[self.routeIndex] MKCoordinateValue];
        self.routeIndex += 1;
        [self activateCoordinate:c];
    }];
    [self notifyState];
}

- (void)stopRoute {
    [self.routeTimer invalidate]; self.routeTimer = nil;
    self.routeMode = NO;
    [self notifyState];
}

- (void)startRandomAround:(CLLocationCoordinate2D)center radiusMeters:(CLLocationDistance)radius interval:(NSTimeInterval)interval {
    [self.randomTimer invalidate];
    if (!CLLocationCoordinate2DIsValid(center)) return;
    self.randomCenter = center;
    self.randomRadius = MAX(1.0, radius);
    self.randomMode = YES;
    self.routeMode = NO;
    self.running = YES;
    interval = MAX(0.5, interval);
    __weak typeof(self) weakSelf = self;
    self.randomTimer = [NSTimer scheduledTimerWithTimeInterval:interval repeats:YES block:^(__unused NSTimer *timer) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        double angle = ((double)arc4random_uniform(100000) / 100000.0) * 2.0 * M_PI;
        double dist = sqrt((double)arc4random_uniform(100000) / 100000.0) * self.randomRadius;
        double dLat = (dist * cos(angle)) / 111320.0;
        double denom = 111320.0 * MAX(0.1, cos(self.randomCenter.latitude * M_PI / 180.0));
        double dLon = (dist * sin(angle)) / denom;
        CLLocationCoordinate2D c = CLLocationCoordinate2DMake(self.randomCenter.latitude + dLat, self.randomCenter.longitude + dLon);
        [self activateCoordinate:c];
    }];
    [self notifyState];
}

- (void)stopRandom {
    [self.randomTimer invalidate]; self.randomTimer = nil;
    self.randomMode = NO;
    [self notifyState];
}

- (void)scheduleCoordinate:(CLLocationCoordinate2D)coordinate atDate:(NSDate *)date {
    [self.scheduleTimer invalidate];
    if (!CLLocationCoordinate2DIsValid(coordinate) || !date) return;
    NSTimeInterval delay = [date timeIntervalSinceNow];
    if (delay <= 0) { [self activateCoordinate:coordinate]; return; }
    self.scheduleMode = YES;
    __weak typeof(self) weakSelf = self;
    self.scheduleTimer = [NSTimer scheduledTimerWithTimeInterval:delay repeats:NO block:^(__unused NSTimer *timer) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.scheduleMode = NO;
        [self activateCoordinate:coordinate];
        [self notifyState];
    }];
    [self notifyState];
}

- (void)cancelSchedule {
    [self.scheduleTimer invalidate]; self.scheduleTimer = nil;
    self.scheduleMode = NO;
    [self notifyState];
}

@end
