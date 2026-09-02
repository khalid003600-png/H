// WolFoxProHookManager.h
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

// مفتاح associated object يُميّز CLLocation المزيّف الصادر عن WolFox
// ليمنع hook_CLLocation_coordinate من إعادة تزييفه مرة ثانية.
// مُعرَّف في WolFoxProHookManager.m — يُستخدم بعنوانه (&WFSpoofedLocationAssociationKey).
extern char WFSpoofedLocationAssociationKey;

@interface WolFoxProHookManager : NSObject

+ (instancetype)shared;

/// يثبّت هوك setDelegate: على CLLocationManager (يُنفَّذ مرة واحدة فقط).
- (void)installHooks;

/// يُسلّم تحديثاً فورياً بالإحداثيات الوهمية إلى جميع delegates المسجّلة.
- (void)deliverFakeUpdate;

/// يبدأ محاكاة مسار متعدد النقاط بالسرعة المحددة (كم/س).
- (void)startRouteWithWaypoints:(NSArray<CLLocation *> *)waypoints speedKmh:(double)speed;

/// يوقف المحاكاة ويعيد routeActive إلى NO.
- (void)stopRoute;

/// يعيد إنشاء مؤقت المسار بالقيمة الجديدة المحفوظة من Store.
- (void)restartActiveRouteTimer;

/// آخر إحداثيات حقيقية وردت من CLLocationManager قبل التزييف.
@property (nonatomic, strong, nullable) CLLocation *lastRealLocation;

/// نقطة المسار الحالية (للعرض في الواجهة).
@property (nonatomic, readonly) NSUInteger currentWaypointIndex;

/// إجمالي نقاط المسار.
@property (nonatomic, readonly) NSUInteger totalWaypoints;

@end

NS_ASSUME_NONNULL_END
