#import "K7GPSEngine.h"
#import <MapKit/MapKit.h>
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
+ (instancetype)shared { static K7GPSEngine *engine; static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ engine=[K7GPSEngine new]; }); return engine; }
- (instancetype)init { self=[super init]; if(self){ _routePoints=@[]; _currentCoordinate=kCLLocationCoordinate2DInvalid; } return self; }
- (void)notifyState { [[NSNotificationCenter defaultCenter] postNotificationName:K7GPSEngineStateDidChangeNotification object:self]; }
- (void)notifyLocation { [[NSNotificationCenter defaultCenter] postNotificationName:K7GPSEngineLocationDidChangeNotification object:self userInfo:@{@"latitude":@(self.currentCoordinate.latitude),@"longitude":@(self.currentCoordinate.longitude)}]; }
- (void)activateCoordinate:(CLLocationCoordinate2D)coordinate { if(!CLLocationCoordinate2DIsValid(coordinate))return; self.currentCoordinate=coordinate; self.running=YES; [self notifyLocation]; [self notifyState]; }
- (void)stopAll { [self.routeTimer invalidate]; self.routeTimer=nil; [self.randomTimer invalidate]; self.randomTimer=nil; [self.scheduleTimer invalidate]; self.scheduleTimer=nil; self.running=NO; self.routeMode=NO; self.randomMode=NO; self.scheduleMode=NO; [self notifyState]; }
- (void)setRoutePoints:(NSArray<NSValue *> *)points { _routePoints=[points copy]?:@[]; self.routeIndex=0; }
- (void)startRouteWithInterval:(NSTimeInterval)interval loops:(BOOL)loops { [self.routeTimer invalidate]; if(self.routePoints.count==0)return; self.routeLoops=loops; self.routeIndex=0; self.routeMode=YES; self.randomMode=NO; self.running=YES; interval=MAX(.25,interval); __weak typeof(self)w=self; self.routeTimer=[NSTimer scheduledTimerWithTimeInterval:interval repeats:YES block:^(__unused NSTimer*t){ __strong typeof(w)s=w; if(!s||s.routePoints.count==0)return; if(s.routeIndex>=s.routePoints.count){ if(s.routeLoops)s.routeIndex=0; else { [s stopRoute]; return; } } CLLocationCoordinate2D c=[s.routePoints[s.routeIndex] MKCoordinateValue]; s.routeIndex++; [s activateCoordinate:c]; }]; [self notifyState]; }
- (void)stopRoute { [self.routeTimer invalidate]; self.routeTimer=nil; self.routeMode=NO; [self notifyState]; }
- (void)startRandomAround:(CLLocationCoordinate2D)center radiusMeters:(CLLocationDistance)radius interval:(NSTimeInterval)interval { [self.randomTimer invalidate]; if(!CLLocationCoordinate2DIsValid(center))return; self.randomCenter=center; self.randomRadius=MAX(1.0,radius); self.randomMode=YES; self.routeMode=NO; self.running=YES; interval=MAX(.5,interval); __weak typeof(self)w=self; self.randomTimer=[NSTimer scheduledTimerWithTimeInterval:interval repeats:YES block:^(__unused NSTimer*t){ __strong typeof(w)s=w; if(!s)return; double a=((double)arc4random_uniform(100000)/100000.0)*2.0*M_PI; double d=sqrt((double)arc4random_uniform(100000)/100000.0)*s.randomRadius; double dLat=(d*cos(a))/111320.0; double denom=111320.0*MAX(.1,cos(s.randomCenter.latitude*M_PI/180.0)); double dLon=(d*sin(a))/denom; [s activateCoordinate:CLLocationCoordinate2DMake(s.randomCenter.latitude+dLat,s.randomCenter.longitude+dLon)]; }]; [self notifyState]; }
- (void)stopRandom { [self.randomTimer invalidate]; self.randomTimer=nil; self.randomMode=NO; [self notifyState]; }
- (void)scheduleCoordinate:(CLLocationCoordinate2D)coordinate atDate:(NSDate *)date { [self.scheduleTimer invalidate]; if(!CLLocationCoordinate2DIsValid(coordinate)||!date)return; NSTimeInterval delay=[date timeIntervalSinceNow]; if(delay<=0){ [self activateCoordinate:coordinate]; return; } self.scheduleMode=YES; __weak typeof(self)w=self; self.scheduleTimer=[NSTimer scheduledTimerWithTimeInterval:delay repeats:NO block:^(__unused NSTimer*t){ __strong typeof(w)s=w; if(!s)return; s.scheduleMode=NO; [s activateCoordinate:coordinate]; [s notifyState]; }]; [self notifyState]; }
- (void)cancelSchedule { [self.scheduleTimer invalidate]; self.scheduleTimer=nil; self.scheduleMode=NO; [self notifyState]; }
@end
