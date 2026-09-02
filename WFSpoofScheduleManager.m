#import "WFRedactedLogger.h"
#import "WFSpoofScheduleManager.h"
#import <UIKit/UIKit.h>
#import <math.h>
#import "WolFoxProStore.h"
#import "WolFoxProHookManager.h"
#import "WFLicenseClient.h"

@implementation WFSpoofScheduleManager {
    NSTimer *_timer;
}

+ (instancetype)shared {
    static WFSpoofScheduleManager *manager = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ manager = [WFSpoofScheduleManager new]; });
    return manager;
}

- (instancetype)init {
    if (self = [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationBecameActive:)
                                                     name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(licenseStateChanged:)
                                                     name:@"WF_LICENSE_STATE_CHANGED" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(scheduledLocationDeleted:)
                                                     name:@"WF_SCHEDULE_LOCATION_DELETED" object:nil];
    }
    return self;
}

- (void)dealloc {
    [_timer invalidate];
    _timer = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)start { [self updateTimerState]; }

- (BOOL)hasCommittedSchedule {
    WolFoxProStore *store = [WolFoxProStore shared];
    return store.committedScheduleEnabled &&
           store.committedScheduleLocationID > 0 &&
           store.committedScheduleWeekdays.count > 0 &&
           store.committedScheduleStartMinutes >= 0 && store.committedScheduleStartMinutes < 1440 &&
           store.committedScheduleEndMinutes >= 0 && store.committedScheduleEndMinutes < 1440 &&
           store.committedScheduleStartMinutes != store.committedScheduleEndMinutes;
}

- (void)updateTimerState {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self updateTimerState]; });
        return;
    }
    if (![self hasCommittedSchedule]) {
        [_timer invalidate];
        _timer = nil;
        [self evaluateNow];
        return;
    }
    if (_timer) {
        [self evaluateNow];
        return;
    }
    _timer = [NSTimer scheduledTimerWithTimeInterval:30.0
                                               target:self
                                             selector:@selector(evaluateNow)
                                             userInfo:nil
                                              repeats:YES];
    _timer.tolerance = 5.0;
    [self evaluateNow];
}

- (void)applicationBecameActive:(__unused NSNotification *)notification { [self updateTimerState]; }

- (void)licenseStateChanged:(__unused NSNotification *)notification { [self updateTimerState]; }

- (void)scheduledLocationDeleted:(NSNotification *)notification {
    NSNumber *identifier = [notification.object isKindOfClass:NSNumber.class] ? notification.object : nil;
    if (identifier.longLongValue > 0) [self handleMissingScheduledLocationID:identifier.longLongValue];
}

- (BOOL)isScheduleActiveNow {
    WolFoxProStore *store = [WolFoxProStore shared];
    if (![self hasCommittedSchedule]) return NO;
    NSInteger start = store.committedScheduleStartMinutes;
    NSInteger end = store.committedScheduleEndMinutes;
    if (start < 0 || start >= 1440 || end < 0 || end >= 1440 || start == end) return NO;

    // يتبع تغير الساعة والمنطقة الزمنية في الجهاز أثناء بقاء التطبيق مفتوحاً.
    NSCalendar *calendar = [NSCalendar autoupdatingCurrentCalendar];
    NSDate *now = [NSDate date];
    NSDateComponents *components = [calendar components:(NSCalendarUnitWeekday | NSCalendarUnitHour | NSCalendarUnitMinute) fromDate:now];
    NSInteger minutes = components.hour * 60 + components.minute;
    NSInteger weekday = components.weekday;
    if (start < end) {
        return minutes >= start && minutes < end && [store.committedScheduleWeekdays containsObject:@(weekday)];
    }
    if (minutes >= start) return [store.committedScheduleWeekdays containsObject:@(weekday)];
    if (minutes < end) {
        NSDate *previous = [calendar dateByAddingUnit:NSCalendarUnitDay value:-1 toDate:now options:0];
        NSInteger previousWeekday = [calendar component:NSCalendarUnitWeekday fromDate:previous];
        return [store.committedScheduleWeekdays containsObject:@(previousWeekday)];
    }
    return NO;
}

- (WolFoxProLocation *)scheduledLocation {
    long long identifier = [WolFoxProStore shared].committedScheduleLocationID;
    for (WolFoxProLocation *location in [WolFoxProStore shared].locations) {
        if (location.ID == identifier) return location;
    }
    return nil;
}

- (void)handleMissingScheduledLocationID:(long long)locationID {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self handleMissingScheduledLocationID:locationID]; });
        return;
    }
    WolFoxProStore *store = [WolFoxProStore shared];
    if (locationID <= 0 || store.committedScheduleLocationID != locationID) return;
#ifdef DEBUG
    WFLog(@"[WolFox][SCHEDULE] location_id=%lld not found in favorites", locationID);
#endif
    if (store.scheduleApplied) {
        [[WolFoxProHookManager shared] stopRoute];
        store.spoofActive = NO;
    }
    store.scheduleApplied = NO;
    store.scheduleEnabled = NO;
    store.scheduleLocationID = 0;
    store.committedScheduleEnabled = NO;
    store.committedScheduleLocationID = 0;
    store.scheduleDraftDirty = NO;
    [store saveSettings];
    [self updateTimerState];
    NSDictionary *info = @{ @"locationID": @(locationID) };
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WF_SCHEDULE_STATE_CHANGED" object:@NO userInfo:info];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WF_SCHEDULE_LOCATION_MISSING" object:nil userInfo:info];
}

- (void)evaluateNow {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self evaluateNow]; });
        return;
    }
    WolFoxProStore *store = [WolFoxProStore shared];
    BOOL shouldApply = [self isScheduleActiveNow] && [WFLicenseClient isRuntimeLicenseValid];
    WolFoxProLocation *location = shouldApply ? [self scheduledLocation] : nil;
    if (shouldApply && !location) {
        [self handleMissingScheduledLocationID:store.committedScheduleLocationID];
        return;
    }

    if (shouldApply) {
        BOOL locationChanged = fabs(store.currentFakeCoords.latitude - location.coordinate.latitude) > 0.000001 ||
                               fabs(store.currentFakeCoords.longitude - location.coordinate.longitude) > 0.000001;
        BOOL needsApply = !store.scheduleApplied || !store.spoofActive || locationChanged;
        if (needsApply) {
            [[WolFoxProHookManager shared] stopRoute];
            store.currentFakeCoords = location.coordinate;
            store.spoofActive = YES;
            store.scheduleApplied = YES;
            [store saveSettings];
            [[WolFoxProHookManager shared] deliverFakeUpdate];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"WF_SCHEDULE_STATE_CHANGED" object:@YES];
#ifdef DEBUG
            WFLog(@"[WolFox][SCHEDULE] applied location_id=%lld", location.ID);
#endif
        }
        return;
    }

    if (store.scheduleApplied) {
        [[WolFoxProHookManager shared] stopRoute];
        store.spoofActive = NO;
        store.scheduleApplied = NO;
        [store saveSettings];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"WF_SCHEDULE_STATE_CHANGED" object:@NO];
#ifdef DEBUG
        WFLog(@"[WolFox][SCHEDULE] stopped");
#endif
    }
}

- (NSString *)statusDescription {
    WolFoxProStore *store = [WolFoxProStore shared];
    if (store.scheduleDraftDirty) return @"تعديلات محفوظة — اضغط حفظ وتطبيق";
    if (!store.committedScheduleEnabled) return @"الجدولة متوقفة";
    if (store.committedScheduleLocationID <= 0) return @"اختر موقعاً من المفضلة";
    if (store.committedScheduleWeekdays.count == 0) return @"اختر يوم تشغيل واحداً على الأقل";
    if (store.committedScheduleStartMinutes == store.committedScheduleEndMinutes) return @"حدّد وقتي بداية ونهاية مختلفين";
    if (![WFLicenseClient isRuntimeLicenseValid]) return @"بانتظار تحقق التفعيل";
    return [self isScheduleActiveNow] ? @"الجدول نشط الآن" : @"الجدول محفوظ — في انتظار الموعد";
}

@end
