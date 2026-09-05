#import "WFRedactedLogger.h"
// WolFoxProHookManager.m
#import "WolFoxProHookManager.h"
#import "WolFoxProStore.h"
#import "WFLicenseClient.h"
#import "WFHookDefaults.h"
#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <math.h>

static const char kWFManagerProxyKey = 0;
char WFSpoofedLocationAssociationKey = 0;

@interface WolFoxProDelegateProxy : NSObject <CLLocationManagerDelegate>
@property (nonatomic, weak) id originalDelegate;
@property (nonatomic, weak) CLLocationManager *manager;
- (BOOL)beginForwarding;
- (void)endForwarding;
@end

@implementation WolFoxProDelegateProxy
- (BOOL)respondsToSelector:(SEL)s { return [super respondsToSelector:s] || [self.originalDelegate respondsToSelector:s]; }
- (id)forwardingTargetForSelector:(SEL)s { return [self.originalDelegate respondsToSelector:s] ? self.originalDelegate : [super forwardingTargetForSelector:s]; }

- (BOOL)beginForwarding {
    @synchronized(self) {
        NSNumber *isForwarding = objc_getAssociatedObject(self, @selector(beginForwarding));
        if (isForwarding.boolValue) return NO;
        objc_setAssociatedObject(self, @selector(beginForwarding), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return YES;
    }
}

- (void)endForwarding {
    @synchronized(self) {
        objc_setAssociatedObject(self, @selector(beginForwarding), @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (void)locationManager:(CLLocationManager *)m didUpdateLocations:(NSArray<CLLocation *> *)l {
    if (![self beginForwarding]) return;
    self.manager = m;
    id strongDelegate = self.originalDelegate;
    @try {
        CLLocation *orig = l.lastObject;
        if (orig) [WolFoxProHookManager shared].lastRealLocation = orig;
        WolFoxProStore *store = [WolFoxProStore shared];
        CLLocationCoordinate2D fake = store.currentFakeCoords;
        BOOL shouldSpoof = store.spoofActive &&
                           [WFLicenseClient isRuntimeLicenseValid] &&
                           CLLocationCoordinate2DIsValid(fake);
        if (shouldSpoof) {
            if (store.jitterActive) {
                fake.latitude  += ((double)arc4random_uniform(100) - 50.0) / 2000000.0;
                fake.longitude += ((double)arc4random_uniform(100) - 50.0) / 2000000.0;
            }

            double fakeAltitude = orig ? orig.altitude : WFDefaultAltitudeMeters;
            if (store.jitterActive && WFDefaultAltitudeJitterEnabled) {
                fakeAltitude = WFApplyAltitudeJitter(fakeAltitude);
            }
            CLLocation *spoofed = [[CLLocation alloc] initWithCoordinate:fake altitude:fakeAltitude horizontalAccuracy:5.0 verticalAccuracy:5.0 timestamp:[NSDate date]];
            objc_setAssociatedObject(spoofed, &WFSpoofedLocationAssociationKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (strongDelegate && [strongDelegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
                [strongDelegate locationManager:m didUpdateLocations:@[spoofed]];
            } else if (strongDelegate && [strongDelegate respondsToSelector:@selector(locationManager:didUpdateToLocation:fromLocation:)]) {
                [strongDelegate locationManager:m didUpdateToLocation:spoofed fromLocation:orig];
            }
        } else {
            if (strongDelegate && [strongDelegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
                [strongDelegate locationManager:m didUpdateLocations:l];
            } else if (strongDelegate && [strongDelegate respondsToSelector:@selector(locationManager:didUpdateToLocation:fromLocation:)]) {
                CLLocation *newLocation = l.lastObject;
                CLLocation *oldLocation = l.count > 1 ? l[l.count - 2] : nil;
                [strongDelegate locationManager:m didUpdateToLocation:newLocation fromLocation:oldLocation];
            }
        }
    } @catch (NSException *e) {
#ifdef DEBUG
        WFLog(@"[WolFox][GPS] delegate_forward_exception=%@", e.name);
#endif
    } @finally {
        [self endForwarding];
    }
}
@end

@implementation WolFoxProHookManager {
    NSHashTable *_proxies;
    NSArray<CLLocation *> *_routeWaypoints;
    NSUInteger _waypointIndex;
    double _routeSpeedKmh;
    NSTimer *_routeTimer;
    NSUInteger _routeGeneration;
}

@synthesize currentWaypointIndex = _waypointIndex;

- (NSUInteger)totalWaypoints { return _routeWaypoints.count; }

+ (instancetype)shared {
    static WolFoxProHookManager *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [WolFoxProHookManager new]; });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        _proxies = [NSHashTable weakObjectsHashTable];
    }
    return self;
}

- (void)installHooks {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
#ifdef DEBUG
        WFLog(@"[WolFox][GPS] install_hooks_begin");
#endif
        Method m1 = class_getInstanceMethod([CLLocationManager class], @selector(setDelegate:));
        if (!m1) {
#ifdef DEBUG
            WFLog(@"[WolFox][GPS] install_hooks_failed missing=setDelegate:");
#endif
            return;
        }
        IMP orig = method_getImplementation(m1);
        const char *types = method_getTypeEncoding(m1);
        IMP replacement = imp_implementationWithBlock(^(CLLocationManager *mgr, id delegate) {
            if (!mgr) {
                ((void(*)(id, SEL, id))orig)(mgr, @selector(setDelegate:), delegate);
                return;
            }

            WolFoxProDelegateProxy *existing = objc_getAssociatedObject(mgr, &kWFManagerProxyKey);
            if (!delegate) {
                if (existing) existing.originalDelegate = nil;
                objc_setAssociatedObject(mgr, &kWFManagerProxyKey, nil, OBJC_ASSOCIATION_ASSIGN);
            } else if ([delegate isKindOfClass:[WolFoxProDelegateProxy class]]) {
                existing = (WolFoxProDelegateProxy *)delegate;
            } else if (existing && existing.originalDelegate == delegate) {
                delegate = existing;
            } else {
                WolFoxProDelegateProxy *proxy = [WolFoxProDelegateProxy new];
                proxy.originalDelegate = delegate;
                proxy.manager = mgr;
                [[WolFoxProHookManager shared] addProxy:proxy];
                objc_setAssociatedObject(mgr, &kWFManagerProxyKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
#ifdef DEBUG
                WFLog(@"[WolFox][GPS] delegate_proxy_attached_once");
#endif
                delegate = proxy;
            }
            ((void(*)(id, SEL, id))orig)(mgr, @selector(setDelegate:), delegate);
        });

        // Add an override when setDelegate: is inherited; otherwise replace the
        // CLLocationManager implementation itself. This avoids changing a
        // superclass implementation shared by unrelated objects.
        if (!class_addMethod([CLLocationManager class], @selector(setDelegate:), replacement, types)) {
            Method ownedMethod = class_getInstanceMethod([CLLocationManager class], @selector(setDelegate:));
            if (ownedMethod) {
                method_setImplementation(ownedMethod, replacement);
            }
        }

#ifdef DEBUG
        WFLog(@"[WolFox][GPS] install_hooks_complete");
#endif
    });
}

- (void)addProxy:(id)p {
    if (!p) return;
    @synchronized(_proxies) {
        if (![_proxies containsObject:p]) [_proxies addObject:p];
        // نظّف المداخل الميتة (manager أو delegate أصبح nil) عند كل إضافة
        // NSHashTable weak لا تُزيل القيم nil تلقائياً قبل استدعاء allObjects
        NSMutableArray *dead = [NSMutableArray new];
        for (id obj in _proxies) {
            WolFoxProDelegateProxy *proxy = obj;
            if (!proxy || !proxy.manager || !proxy.originalDelegate) [dead addObject:proxy];
        }
        for (id d in dead) [_proxies removeObject:d];
    }
}

- (void)deliverFakeUpdate {
    WolFoxProStore *store = [WolFoxProStore shared];
    if (!store.spoofActive || ![WFLicenseClient isRuntimeLicenseValid]) {
        return;
    }

    CLLocationCoordinate2D fake = store.currentFakeCoords;
    if (!CLLocationCoordinate2DIsValid(fake)) {
#ifdef DEBUG
        WFLog(@"[WolFox][GPS] fake_update_skipped invalid_coordinate lat=%.6f lon=%.6f", fake.latitude, fake.longitude);
#endif
        return;
    }
    double fakeAltitude = WFDefaultAltitudeMeters;
    if (store.jitterActive && WFDefaultAltitudeJitterEnabled) {
        fakeAltitude = WFApplyAltitudeJitter(fakeAltitude);
    }
    CLLocation *spoofed = [[CLLocation alloc] initWithCoordinate:fake altitude:fakeAltitude horizontalAccuracy:5.0 verticalAccuracy:5.0 timestamp:[NSDate date]];
    // Prevent hook_CLLocation_coordinate from re-spoofing this object
    objc_setAssociatedObject(spoofed, &WFSpoofedLocationAssociationKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    NSArray *snapshot;
    @synchronized(_proxies) {
        snapshot = [_proxies.allObjects copy];
    }
    for (id obj in snapshot) {
        WolFoxProDelegateProxy *proxy = obj;
        if (!proxy || !proxy.manager || !proxy.originalDelegate) continue;
        if (![proxy beginForwarding]) continue;
        {
            @try {
                if ([proxy.originalDelegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
                    [proxy.originalDelegate locationManager:proxy.manager didUpdateLocations:@[spoofed]];
                } else if ([proxy.originalDelegate respondsToSelector:@selector(locationManager:didUpdateToLocation:fromLocation:)]) {
                    [proxy.originalDelegate locationManager:proxy.manager didUpdateToLocation:spoofed fromLocation:self.lastRealLocation];
                }
            } @catch (NSException *e) {
#ifdef DEBUG
                WFLog(@"[WolFox][GPS] fake_update_exception=%@", e.name);
#endif
            } @finally {
                [proxy endForwarding];
            }
        }
    }
}

- (void)startRouteWithWaypoints:(NSArray<CLLocation *> *)waypoints speedKmh:(double)speed {
    [self stopRoute];
    if (waypoints.count < 2 || ![WFLicenseClient isRuntimeLicenseValid]) return;
    // Route points are WolFox-internal CLLocation objects. Mark them so the
    // global coordinate hook returns their original coordinates while route
    // math is being calculated.
    for (CLLocation *waypoint in waypoints) {
        objc_setAssociatedObject(waypoint, &WFSpoofedLocationAssociationKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    _routeWaypoints = [waypoints copy];
    _routeSpeedKmh  = speed > 0 ? speed : 5.0;
    _waypointIndex  = 0;
    [WolFoxProStore shared].routeActive = YES;
    // Set starting position
    [WolFoxProStore shared].currentFakeCoords = waypoints[0].coordinate;
    NSUInteger generation = ++_routeGeneration;
    __weak typeof(self) weakSelf = self;
    void (^scheduleTimer)(void) = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || generation != strongSelf->_routeGeneration || ![WolFoxProStore shared].routeActive || ![WFLicenseClient isRuntimeLicenseValid]) return;
        // استخدام block-based timer بدلاً من target:self لتجنب retain cycle
        strongSelf->_routeTimer = [NSTimer scheduledTimerWithTimeInterval:WFClampGPSUpdateInterval([WolFoxProStore shared].updateIntervalSeconds)
                                                                   repeats:YES
                                                                     block:^(NSTimer * __unused t) {
            __strong typeof(weakSelf) s = weakSelf;
            if (s) [s updateRouteStep];
        }];
    };
    if ([NSThread isMainThread]) scheduleTimer();
    else dispatch_async(dispatch_get_main_queue(), scheduleTimer);
}

- (void)restartActiveRouteTimer {
    dispatch_async(dispatch_get_main_queue(), ^{
        WolFoxProStore *store = [WolFoxProStore shared];
        if (!store.routeActive || ![WFLicenseClient isRuntimeLicenseValid] || self->_routeWaypoints.count < 2) return;
        [self->_routeTimer invalidate];
        self->_routeTimer = nil;
        NSUInteger generation = self->_routeGeneration;
        __weak typeof(self) weakSelf = self;
        self->_routeTimer = [NSTimer scheduledTimerWithTimeInterval:WFClampGPSUpdateInterval(store.updateIntervalSeconds)
                                                              repeats:YES
                                                                block:^(NSTimer * __unused timer) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || generation != strongSelf->_routeGeneration) return;
            [strongSelf updateRouteStep];
        }];
    });
}

- (void)stopRoute {
    _routeGeneration++;
    [_routeTimer invalidate]; _routeTimer = nil;
    _routeWaypoints = nil; _waypointIndex = 0;
    WolFoxProStore *store = [WolFoxProStore shared];
    // FIXED: دائماً احفظ الإعدادات عند الإيقاف حتى تُحفظ إحداثية التوقف
    store.routeActive = NO;
    [store saveSettings];
}

- (void)updateRouteStep {
    if (![WFLicenseClient isRuntimeLicenseValid]) {
        [self stopRoute];
        return;
    }
    WolFoxProStore *store = [WolFoxProStore shared];

    // Legacy single-target mode (from WolFoxMaster toggleRouteSimulation)
    if (!_routeWaypoints) {
        CLLocationCoordinate2D current = store.currentFakeCoords;
        CLLocationCoordinate2D target  = store.targetRouteCoords;
        CLLocation *currentLocation = [[CLLocation alloc] initWithLatitude:current.latitude longitude:current.longitude];
        CLLocation *targetLocation = [[CLLocation alloc] initWithLatitude:target.latitude longitude:target.longitude];
        CLLocationDistance distanceMeters = [currentLocation distanceFromLocation:targetLocation];
        NSTimeInterval interval = WFClampGPSUpdateInterval(store.updateIntervalSeconds);
        CLLocationDistance stepMeters = MAX(0.1, (store.simSpeed / 3.6) * interval);
        if (distanceMeters <= stepMeters || distanceMeters < 0.01) {
            // وصلنا للهدف — أوقف الـ timer وأرسل WF_ROUTE_FINISHED.
            store.currentFakeCoords = target;
            [self deliverFakeUpdate];
            [self stopRoute];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"WF_ROUTE_FINISHED" object:nil];
        } else {
            double fraction = MIN(1.0, stepMeters / distanceMeters);
            current.latitude += (target.latitude - current.latitude) * fraction;
            current.longitude += (target.longitude - current.longitude) * fraction;
            store.currentFakeCoords = current;
            [self deliverFakeUpdate];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"WF_ROUTE_STEP_UPDATED" object:nil];
        }
        return;
    }
    // Multi-waypoint mode
    if (_waypointIndex >= _routeWaypoints.count - 1) {
        [self stopRoute];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"WF_ROUTE_FINISHED" object:nil];
        return;
    }

    CLLocation *current = [[CLLocation alloc] initWithLatitude:store.currentFakeCoords.latitude longitude:store.currentFakeCoords.longitude];
    objc_setAssociatedObject(current, &WFSpoofedLocationAssociationKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    CLLocation *target  = _routeWaypoints[_waypointIndex + 1];

    CLLocationDistance distanceMeters = [current distanceFromLocation:target];
    NSTimeInterval interval = WFClampGPSUpdateInterval(store.updateIntervalSeconds);
    CLLocationDistance stepMeters = MAX(0.1, (_routeSpeedKmh / 3.6) * interval);

    if (distanceMeters <= stepMeters || distanceMeters < 0.01) {
        // Reached this waypoint, move to next.
        store.currentFakeCoords = target.coordinate;
        _waypointIndex++;
    } else {
        double fraction = MIN(1.0, stepMeters / distanceMeters);
        CLLocationCoordinate2D next;
        next.latitude = current.coordinate.latitude + (target.coordinate.latitude - current.coordinate.latitude) * fraction;
        next.longitude = current.coordinate.longitude + (target.coordinate.longitude - current.coordinate.longitude) * fraction;
        store.currentFakeCoords = next;
    }

    if (store.jitterActive) {
        CLLocationCoordinate2D jittered = store.currentFakeCoords;
        jittered.latitude  += ((double)arc4random_uniform(100) - 50.0) / 2000000.0;
        jittered.longitude += ((double)arc4random_uniform(100) - 50.0) / 2000000.0;
        store.currentFakeCoords = jittered;
    }

        [self deliverFakeUpdate];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WF_ROUTE_STEP_UPDATED" object:nil];
}
@end
