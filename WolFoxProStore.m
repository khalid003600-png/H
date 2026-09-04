#import "WFRedactedLogger.h"
// WolFoxProStore.m
#import "WolFoxProStore.h"
#import "WFHookDefaults.h"
#import <sqlite3.h>

NSNotificationName const WFSpoofStateDidChangeNotification = @"WFSpoofStateDidChangeNotification";

@implementation WolFoxProLocation
- (id)copyWithZone:(NSZone *)zone {
    WolFoxProLocation *copy = [[WolFoxProLocation allocWithZone:zone] init];
    copy.ID = self.ID; copy.name = self.name; copy.coordinate = self.coordinate; copy.altitude = self.altitude;
    return copy;
}
@end

@implementation WolFoxLocationHistoryEntry
- (id)copyWithZone:(NSZone *)zone {
    WolFoxLocationHistoryEntry *copy = [[WolFoxLocationHistoryEntry allocWithZone:zone] init];
    copy.ID = self.ID; copy.name = self.name; copy.coordinate = self.coordinate; copy.usedAt = self.usedAt;
    return copy;
}
@end

@implementation WolFoxLocationProfile
- (id)copyWithZone:(NSZone *)zone {
    WolFoxLocationProfile *copy = [[WolFoxLocationProfile allocWithZone:zone] init];
    copy.profileID = self.profileID; copy.name = self.name; copy.coordinate = self.coordinate;
    copy.speed = self.speed; copy.updateIntervalSeconds = self.updateIntervalSeconds;
    copy.jitterEnabled = self.jitterEnabled;
    return copy;
}
@end

@implementation WolFoxProIdentifier
- (id)copyWithZone:(NSZone *)zone {
    WolFoxProIdentifier *copy = [[WolFoxProIdentifier allocWithZone:zone] init];
    copy.uuid = self.uuid; copy.name = self.name; copy.createdAt = self.createdAt;
    return copy;
}
@end

@implementation WolFoxBleProfile
- (id)copyWithZone:(NSZone *)zone {
    WolFoxBleProfile *copy = [[WolFoxBleProfile allocWithZone:zone] init];
    copy.profileID = self.profileID; copy.name = self.name;
    copy.uuid = self.uuid; copy.localName = self.localName; copy.rssi = self.rssi;
    return copy;
}
@end

@interface WolFoxProStore ()
- (void)loadLocationHistory;
- (void)loadLocationProfiles;
- (void)persistLocationProfiles;
@end

@implementation WolFoxProStore {
    sqlite3 *_db;
    NSMutableArray *_mutableLocations;
    NSMutableArray *_mutableLocationHistory;
    NSMutableArray *_mutableLocationProfiles;
    NSMutableArray *_mutableIdentifiers;
}

+ (instancetype)shared {
    static WolFoxProStore *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [WolFoxProStore new]; });
    return s;
}

- (void)setSpoofActive:(BOOL)spoofActive {
    if (_spoofActive == spoofActive) return;
    _spoofActive = spoofActive;
    [[NSNotificationCenter defaultCenter] postNotificationName:WFSpoofStateDidChangeNotification
                                                        object:self
                                                      userInfo:@{ @"active": @(spoofActive) }];
}

- (instancetype)init {
    if (self = [super init]) {
        [self openDB];
        [self loadSettings];
        [self loadLocationProfiles];
    }
    return self;
}

- (void)openDB {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *base = [fm URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject.path;
    if (!base.length) base = [fm URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject.path;
    NSString *directory = [base stringByAppendingPathComponent:@"WolFox"];
    NSError *directoryError = nil;
    if (![fm createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&directoryError]) {
        directory = NSTemporaryDirectory();
        WFLog(@"[WolFox][STORE] persistent_directory_fallback=%@", directoryError.localizedDescription);
    }
    NSString *path = [directory stringByAppendingPathComponent:@"wolfox_pro.db"];
    if (sqlite3_open([path UTF8String], &_db) != SQLITE_OK) {
        if (_db) sqlite3_close(_db);
        sqlite3_open(":memory:", &_db);
    }
    
    const char *schemaStatements[] = {
        "CREATE TABLE IF NOT EXISTS locations (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, lat REAL, lon REAL, alt REAL);",
        "CREATE TABLE IF NOT EXISTS location_history (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, lat REAL, lon REAL, used_at REAL);"
    };
    for (NSUInteger index = 0; index < sizeof(schemaStatements) / sizeof(schemaStatements[0]); index++) {
        char *err = NULL;
        if (sqlite3_exec(_db, schemaStatements[index], NULL, NULL, &err) != SQLITE_OK) {
            WFLog(@"[WolFox][STORE] schema_error=%s", err ?: "unknown");
        }
        if (err) sqlite3_free(err);
    }
    [self loadLocations];
    [self loadLocationHistory];
}

- (void)loadLocations {
    _mutableLocations = [NSMutableArray new];
    const char *sql = "SELECT id, name, lat, lon, alt FROM locations ORDER BY id DESC;";
    sqlite3_stmt *stmt = NULL;
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) == SQLITE_OK) {
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            WolFoxProLocation *l = [WolFoxProLocation new];
            l.ID = sqlite3_column_int64(stmt, 0);
            const char *nameText = (const char *)sqlite3_column_text(stmt, 1);
            l.name = nameText ? [NSString stringWithUTF8String:nameText] : @"موقع غير معروف";
            l.coordinate = CLLocationCoordinate2DMake(sqlite3_column_double(stmt, 2), sqlite3_column_double(stmt, 3));
            l.altitude = sqlite3_column_double(stmt, 4);
            [_mutableLocations addObject:l];
        }
    }
    if (stmt) sqlite3_finalize(stmt);
}

- (void)loadLocationHistory {
    _mutableLocationHistory = [NSMutableArray new];
    const char *sql = "SELECT id, name, lat, lon, used_at FROM location_history ORDER BY used_at DESC, id DESC LIMIT 50;";
    sqlite3_stmt *stmt = NULL;
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) == SQLITE_OK) {
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            WolFoxLocationHistoryEntry *entry = [WolFoxLocationHistoryEntry new];
            entry.ID = sqlite3_column_int64(stmt, 0);
            const char *nameText = (const char *)sqlite3_column_text(stmt, 1);
            entry.name = nameText ? [NSString stringWithUTF8String:nameText] : @"موقع مستخدم";
            entry.coordinate = CLLocationCoordinate2DMake(sqlite3_column_double(stmt, 2), sqlite3_column_double(stmt, 3));
            entry.usedAt = [NSDate dateWithTimeIntervalSince1970:sqlite3_column_double(stmt, 4)];
            [_mutableLocationHistory addObject:entry];
        }
    }
    if (stmt) sqlite3_finalize(stmt);
}

- (long long)saveLocation:(WolFoxProLocation *)l {
    sqlite3_stmt *stmt = NULL;
    const char *sql = "INSERT INTO locations (name, lat, lon, alt) VALUES (?, ?, ?, ?);";
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, [l.name UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_double(stmt, 2, l.coordinate.latitude);
        sqlite3_bind_double(stmt, 3, l.coordinate.longitude);
        sqlite3_bind_double(stmt, 4, l.altitude);
        if (sqlite3_step(stmt) == SQLITE_DONE) {
            l.ID = sqlite3_last_insert_rowid(_db);
            [_mutableLocations insertObject:l atIndex:0];
        }
    }
    if (stmt) sqlite3_finalize(stmt);
    return l.ID;
}

- (BOOL)updateLocation:(WolFoxProLocation *)l {
    if (!l || l.ID <= 0 || !CLLocationCoordinate2DIsValid(l.coordinate)) return NO;
    NSString *safeName = l.name.length ? l.name : @"موقع محفوظ";
    sqlite3_stmt *stmt = NULL;
    BOOL success = NO;
    const char *sql = "UPDATE locations SET name = ?, lat = ?, lon = ?, alt = ? WHERE id = ?;";
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, [safeName UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_double(stmt, 2, l.coordinate.latitude);
        sqlite3_bind_double(stmt, 3, l.coordinate.longitude);
        sqlite3_bind_double(stmt, 4, l.altitude);
        sqlite3_bind_int64(stmt, 5, l.ID);
        success = sqlite3_step(stmt) == SQLITE_DONE && sqlite3_changes(_db) > 0;
    }
    if (stmt) sqlite3_finalize(stmt);
    if (success) {
        NSUInteger index = [_mutableLocations indexOfObjectPassingTest:^BOOL(WolFoxProLocation *saved, NSUInteger idx, BOOL *stop) {
            (void)idx;
            if (saved.ID != l.ID) return NO;
            *stop = YES;
            return YES;
        }];
        if (index != NSNotFound) {
            WolFoxProLocation *updated = [l copy];
            updated.name = safeName;
            [_mutableLocations replaceObjectAtIndex:index withObject:updated];
        }
    }
    return success;
}

- (void)deleteLocationID:(long long)ID {
    sqlite3_stmt *stmt = NULL;
    const char *sql = "DELETE FROM locations WHERE id = ?;";
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_int64(stmt, 1, ID);
        if (sqlite3_step(stmt) == SQLITE_DONE) {
            NSUInteger index = [_mutableLocations indexOfObjectPassingTest:^BOOL(WolFoxProLocation *l, NSUInteger idx, BOOL *stop) {
                if (l.ID != ID) return NO;
                *stop = YES;
                return YES;
            }];
            if (index != NSNotFound) {
                [_mutableLocations removeObjectAtIndex:index];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"WF_SCHEDULE_LOCATION_DELETED" object:@(ID)];
            }
        }
    }
    if (stmt) sqlite3_finalize(stmt);
}

- (NSArray *)locations { return [_mutableLocations copy]; }

- (NSArray *)locationHistory { return [_mutableLocationHistory copy]; }

- (void)recordLocationHistoryWithName:(NSString *)name coordinate:(CLLocationCoordinate2D)coordinate {
    if (!CLLocationCoordinate2DIsValid(coordinate)) return;
    NSString *safeName = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!safeName.length) safeName = @"موقع مستخدم";
    NSDate *now = [NSDate date];
    sqlite3_stmt *stmt = NULL;
    const char *sql = "INSERT INTO location_history (name, lat, lon, used_at) VALUES (?, ?, ?, ?);";
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, [safeName UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_double(stmt, 2, coordinate.latitude);
        sqlite3_bind_double(stmt, 3, coordinate.longitude);
        sqlite3_bind_double(stmt, 4, now.timeIntervalSince1970);
        if (sqlite3_step(stmt) == SQLITE_DONE) {
            WolFoxLocationHistoryEntry *entry = [WolFoxLocationHistoryEntry new];
            entry.ID = sqlite3_last_insert_rowid(_db);
            entry.name = safeName;
            entry.coordinate = coordinate;
            entry.usedAt = now;
            [_mutableLocationHistory insertObject:entry atIndex:0];
            while (_mutableLocationHistory.count > 50) [_mutableLocationHistory removeLastObject];
        }
    }
    if (stmt) sqlite3_finalize(stmt);
    sqlite3_exec(_db, "DELETE FROM location_history WHERE id NOT IN (SELECT id FROM location_history ORDER BY used_at DESC, id DESC LIMIT 50);", NULL, NULL, NULL);
}

- (void)clearLocationHistory {
    if (sqlite3_exec(_db, "DELETE FROM location_history;", NULL, NULL, NULL) == SQLITE_OK) {
        [_mutableLocationHistory removeAllObjects];
    }
}


- (void)loadLocationProfiles {
    @synchronized(self) {
        _mutableLocationProfiles = [NSMutableArray new];
        id saved = [[NSUserDefaults standardUserDefaults] objectForKey:@"WF_LOCATION_PROFILES_V1"];
        if (![saved isKindOfClass:[NSArray class]]) return;
        for (id rawItem in (NSArray *)saved) {
            if (![rawItem isKindOfClass:[NSDictionary class]]) continue;
            NSDictionary *item = (NSDictionary *)rawItem;
            id latitudeValue = item[@"latitude"];
            id longitudeValue = item[@"longitude"];
            if (![latitudeValue respondsToSelector:@selector(doubleValue)] ||
                ![longitudeValue respondsToSelector:@selector(doubleValue)]) continue;
            CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake([latitudeValue doubleValue], [longitudeValue doubleValue]);
            if (!CLLocationCoordinate2DIsValid(coordinate)) continue;

            WolFoxLocationProfile *profile = [WolFoxLocationProfile new];
            profile.profileID = [item[@"profileID"] isKindOfClass:[NSString class]] ? item[@"profileID"] : [[NSUUID UUID] UUIDString];
            profile.name = [item[@"name"] isKindOfClass:[NSString class]] ? item[@"name"] : @"ملف موقع";
            profile.coordinate = coordinate;
            profile.speed = WFClampSimulationSpeed([item[@"speed"] respondsToSelector:@selector(doubleValue)] ? [item[@"speed"] doubleValue] : WFDefaultSimulationSpeedKmh);
            profile.updateIntervalSeconds = WFClampGPSUpdateInterval([item[@"updateInterval"] respondsToSelector:@selector(doubleValue)] ? [item[@"updateInterval"] doubleValue] : WFDefaultGPSUpdateIntervalSeconds);
            profile.jitterEnabled = [item[@"jitter"] respondsToSelector:@selector(boolValue)] ? [item[@"jitter"] boolValue] : WFDefaultJitterEnabled;
            [_mutableLocationProfiles addObject:profile];
            if (_mutableLocationProfiles.count >= 25) break;
        }
    }
}

- (void)persistLocationProfiles {
    @synchronized(self) {
        NSMutableArray *rawProfiles = [NSMutableArray new];
        for (WolFoxLocationProfile *profile in _mutableLocationProfiles) {
            [rawProfiles addObject:@{
                @"profileID": profile.profileID ?: @"",
                @"name": profile.name ?: @"ملف موقع",
                @"latitude": @(profile.coordinate.latitude),
                @"longitude": @(profile.coordinate.longitude),
                @"speed": @(profile.speed),
                @"updateInterval": @(WFClampGPSUpdateInterval(profile.updateIntervalSeconds)),
                @"jitter": @(profile.jitterEnabled)
            }];
        }
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:rawProfiles forKey:@"WF_LOCATION_PROFILES_V1"];
        [defaults synchronize];
    }
}

- (NSArray<WolFoxLocationProfile *> *)locationProfiles {
    @synchronized(self) {
        return [[NSArray alloc] initWithArray:_mutableLocationProfiles ?: @[] copyItems:YES];
    }
}

- (void)saveLocationProfile:(WolFoxLocationProfile *)profile {
    if (!profile || !CLLocationCoordinate2DIsValid(profile.coordinate)) return;
    WolFoxLocationProfile *safeProfile = [profile copy];
    NSString *name = [safeProfile.name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    safeProfile.name = name.length ? name : @"ملف موقع";
    safeProfile.profileID = safeProfile.profileID.length ? safeProfile.profileID : [[NSUUID UUID] UUIDString];
    safeProfile.speed = WFClampSimulationSpeed(safeProfile.speed);
    safeProfile.updateIntervalSeconds = WFClampGPSUpdateInterval(safeProfile.updateIntervalSeconds);
    @synchronized(self) {
        if (!_mutableLocationProfiles) _mutableLocationProfiles = [NSMutableArray new];
        NSUInteger index = [_mutableLocationProfiles indexOfObjectPassingTest:^BOOL(WolFoxLocationProfile *saved, NSUInteger idx, BOOL *stop) {
            (void)idx;
            if (![saved.profileID isEqualToString:safeProfile.profileID]) return NO;
            *stop = YES;
            return YES;
        }];
        if (index != NSNotFound) [_mutableLocationProfiles removeObjectAtIndex:index];
        [_mutableLocationProfiles insertObject:safeProfile atIndex:0];
        while (_mutableLocationProfiles.count > 25) [_mutableLocationProfiles removeLastObject];
        [self persistLocationProfiles];
    }
}

- (void)deleteLocationProfileID:(NSString *)profileID {
    if (!profileID.length) return;
    @synchronized(self) {
        NSIndexSet *matches = [_mutableLocationProfiles indexesOfObjectsPassingTest:^BOOL(WolFoxLocationProfile *profile, NSUInteger idx, BOOL *stop) {
            (void)idx; (void)stop;
            return [profile.profileID isEqualToString:profileID];
        }];
        if (matches.count == 0) return;
        [_mutableLocationProfiles removeObjectsAtIndexes:matches];
        [self persistLocationProfiles];
    }
}

- (void)clearLocationProfiles {
    @synchronized(self) {
        [_mutableLocationProfiles removeAllObjects];
        [self persistLocationProfiles];
    }
}

- (void)loadSettings {
    @synchronized(self) {
    NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
    if ([u objectForKey:@"WF_PRO_SPOOF_ACT"] == nil) { self.spoofActive = NO; [u setBool:NO forKey:@"WF_PRO_SPOOF_ACT"]; } else { self.spoofActive = [u boolForKey:@"WF_PRO_SPOOF_ACT"]; }
    // FIXED: routeActive لا يُحفظ بين الجلسات — الـ timer ينتهي مع العملية
    self.routeActive = NO;
    if ([u objectForKey:@"WF_PRO_JITTER_ACT"] == nil) {
        self.jitterActive = WFDefaultJitterEnabled;
        [u setBool:self.jitterActive forKey:@"WF_PRO_JITTER_ACT"];
    } else {
        self.jitterActive = [u boolForKey:@"WF_PRO_JITTER_ACT"];
    }
    self.volumeGestureEnabled = [u objectForKey:@"WF_PRO_VOLUME_GESTURE"] == nil ? YES : [u boolForKey:@"WF_PRO_VOLUME_GESTURE"];
    self.themeIndex = [u integerForKey:@"WF_PRO_THEME_IDX"];
    self.mapStyle = [u integerForKey:@"WF_PRO_MAP_STYLE"];
    double savedSpeed = [u objectForKey:@"WF_PRO_SIM_SPEED"] ? [u doubleForKey:@"WF_PRO_SIM_SPEED"] : WFDefaultSimulationSpeedKmh;
    self.simSpeed = WFClampSimulationSpeed(savedSpeed);
    double savedInterval = [u objectForKey:@"WF_PRO_UPDATE_INTERVAL"] ? [u doubleForKey:@"WF_PRO_UPDATE_INTERVAL"] : WFDefaultGPSUpdateIntervalSeconds;
    self.updateIntervalSeconds = WFClampGPSUpdateInterval(savedInterval);
    NSNumber *savedLatitude = [u objectForKey:@"WF_PRO_LAT"];
    NSNumber *savedLongitude = [u objectForKey:@"WF_PRO_LON"];
    if ([savedLatitude isKindOfClass:NSNumber.class] && [savedLongitude isKindOfClass:NSNumber.class]) {
        self.currentFakeCoords = CLLocationCoordinate2DMake(savedLatitude.doubleValue, savedLongitude.doubleValue);
    } else {
        self.currentFakeCoords = CLLocationCoordinate2DMake(24.7136, 46.6753);
    }
    if (!CLLocationCoordinate2DIsValid(self.currentFakeCoords)) {
        self.currentFakeCoords = CLLocationCoordinate2DMake(24.7136, 46.6753);
    }
    // targetRouteCoords persistence
    NSNumber *savedTargetLat = [u objectForKey:@"WF_PRO_TARGET_LAT"];
    NSNumber *savedTargetLon = [u objectForKey:@"WF_PRO_TARGET_LON"];
    if ([savedTargetLat isKindOfClass:NSNumber.class] && [savedTargetLon isKindOfClass:NSNumber.class]) {
        self.targetRouteCoords = CLLocationCoordinate2DMake(savedTargetLat.doubleValue, savedTargetLon.doubleValue);
    }
    self.spoofedImagePath = [u stringForKey:@"WF_PRO_CAM_IMG"];
    self.mediaUploadActive = [u boolForKey:@"WF_PRO_MEDIA_UPLOAD_ACTIVE"];
    id rememberCameraValue = [u objectForKey:@"WF_PRO_CAM_REMEMBER"];
    // ترحيل آمن للإصدارات السابقة: الصورة الموجودة كانت تُحفظ دائماً، فنحافظ عليها مرة واحدة.
    self.rememberCameraImage = rememberCameraValue ? [u boolForKey:@"WF_PRO_CAM_REMEMBER"]
                                                   : self.spoofedImagePath.length > 0;
    if (!rememberCameraValue) [u setBool:self.rememberCameraImage forKey:@"WF_PRO_CAM_REMEMBER"];
    self.scheduleEnabled = [u boolForKey:@"WF_PRO_SCHEDULE_ENABLED"];
    NSArray *rawDays = [u arrayForKey:@"WF_PRO_SCHEDULE_DAYS"] ?: @[];
    NSMutableArray<NSNumber *> *validDays = [NSMutableArray new];
    for (id value in rawDays) {
        NSInteger day = [value integerValue];
        if (day >= 1 && day <= 7 && ![validDays containsObject:@(day)]) [validDays addObject:@(day)];
    }
    self.scheduleWeekdays = validDays;
    NSInteger startMinutes = [u integerForKey:@"WF_PRO_SCHEDULE_START"];
    NSInteger endMinutes = [u integerForKey:@"WF_PRO_SCHEDULE_END"];
    self.scheduleStartMinutes = (startMinutes >= 0 && startMinutes < 1440) ? startMinutes : 540;
    self.scheduleEndMinutes = (endMinutes >= 0 && endMinutes < 1440) ? endMinutes : 1020;
    self.scheduleLocationID = [[u objectForKey:@"WF_PRO_SCHEDULE_LOCATION_ID"] longLongValue];
    self.scheduleApplied = [u boolForKey:@"WF_PRO_SCHEDULE_APPLIED"];
    self.scheduleDraftDirty = [u boolForKey:@"WF_PRO_SCHEDULE_DRAFT_DIRTY"];
    BOOL hasCommittedSchedule = [u boolForKey:@"WF_PRO_SCHEDULE_COMMITTED_V1"];
    if (hasCommittedSchedule) {
        self.committedScheduleEnabled = [u boolForKey:@"WF_PRO_SCHEDULE_COMMITTED_ENABLED"];
        self.committedScheduleWeekdays = [u arrayForKey:@"WF_PRO_SCHEDULE_COMMITTED_DAYS"] ?: @[];
        NSInteger committedStart = [u integerForKey:@"WF_PRO_SCHEDULE_COMMITTED_START"];
        NSInteger committedEnd = [u integerForKey:@"WF_PRO_SCHEDULE_COMMITTED_END"];
        self.committedScheduleStartMinutes = (committedStart >= 0 && committedStart < 1440) ? committedStart : 540;
        self.committedScheduleEndMinutes = (committedEnd >= 0 && committedEnd < 1440) ? committedEnd : 1020;
        self.committedScheduleLocationID = [[u objectForKey:@"WF_PRO_SCHEDULE_COMMITTED_LOCATION_ID"] longLongValue];
    } else {
        self.committedScheduleEnabled = self.scheduleEnabled;
        self.committedScheduleWeekdays = self.scheduleWeekdays ?: @[];
        self.committedScheduleStartMinutes = self.scheduleStartMinutes;
        self.committedScheduleEndMinutes = self.scheduleEndMinutes;
        self.committedScheduleLocationID = self.scheduleLocationID;
        self.scheduleDraftDirty = NO;
    }
    if (self.spoofedImagePath.length && ![[NSFileManager defaultManager] fileExistsAtPath:self.spoofedImagePath]) {
        self.spoofedImagePath = nil;
        self.mediaUploadActive = NO;
        [u removeObjectForKey:@"WF_PRO_CAM_IMG"];
        [u setBool:NO forKey:@"WF_PRO_MEDIA_UPLOAD_ACTIVE"];
    }
    
    // Load Identifiers from Defaults (simulated structured store)
    _mutableIdentifiers = [NSMutableArray new];
    NSArray *ids = [u arrayForKey:@"WF_PRO_IDS"] ?: @[];
    for (NSDictionary *d in ids) {
        NSUUID *savedUUID = [[NSUUID alloc] initWithUUIDString:d[@"uuid"]];
        if (!savedUUID) continue;
        WolFoxProIdentifier *i = [WolFoxProIdentifier new];
        i.uuid = savedUUID.UUIDString; i.name = d[@"name"];
        NSString *dateStr = d[@"date"];
        i.createdAt = dateStr ? [NSDate dateWithTimeIntervalSince1970:[dateStr doubleValue]] : [NSDate date];
        [_mutableIdentifiers addObject:i];
    }
    NSUUID *activeUUID = [[NSUUID alloc] initWithUUIDString:[u stringForKey:@"WF_PRO_ACTIVE_ID"]];
    self.activeIdentifierUUID = activeUUID.UUIDString;
    if (!activeUUID) [u removeObjectForKey:@"WF_PRO_ACTIVE_ID"];
    
    self.bluetoothActive = [u boolForKey:@"WF_PRO_BT_ACT"];
    self.activeBleProfileID = [u stringForKey:@"WF_PRO_BT_ACTIVE_ID"];
    NSArray *rawProfiles = [u arrayForKey:@"WF_PRO_BT_PROFILES"] ?: @[];
    self.savedBleProfiles = [NSMutableArray new];
    for (NSDictionary *d in rawProfiles) {
        if (![d isKindOfClass:[NSDictionary class]]) continue;
        WolFoxBleProfile *p = [WolFoxBleProfile new];
        p.profileID = d[@"profileID"] ?: [[NSUUID UUID] UUIDString];
        p.name      = d[@"name"] ?: @"جهاز غير معروف";
        p.uuid      = d[@"uuid"] ?: @"";
        p.localName = d[@"localName"] ?: @"";
        p.rssi      = [d[@"rssi"] integerValue];
        [self.savedBleProfiles addObject:p];
    }
    } // @synchronized
}

- (void)saveSettings {
    @synchronized(self) {
        NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
        [u setBool:self.spoofActive forKey:@"WF_PRO_SPOOF_ACT"];
        [u setBool:self.jitterActive forKey:@"WF_PRO_JITTER_ACT"];
        [u setBool:self.volumeGestureEnabled forKey:@"WF_PRO_VOLUME_GESTURE"];
        [u setInteger:self.themeIndex forKey:@"WF_PRO_THEME_IDX"];
        [u setInteger:self.mapStyle forKey:@"WF_PRO_MAP_STYLE"];
        [u setDouble:self.simSpeed forKey:@"WF_PRO_SIM_SPEED"];
        [u setDouble:WFClampGPSUpdateInterval(self.updateIntervalSeconds) forKey:@"WF_PRO_UPDATE_INTERVAL"];
        [u setDouble:self.currentFakeCoords.latitude forKey:@"WF_PRO_LAT"];
        [u setDouble:self.currentFakeCoords.longitude forKey:@"WF_PRO_LON"];
        [u setDouble:self.targetRouteCoords.latitude forKey:@"WF_PRO_TARGET_LAT"];
        [u setDouble:self.targetRouteCoords.longitude forKey:@"WF_PRO_TARGET_LON"];
        if (self.spoofedImagePath) [u setObject:self.spoofedImagePath forKey:@"WF_PRO_CAM_IMG"];
        else [u removeObjectForKey:@"WF_PRO_CAM_IMG"];
        [u setBool:self.mediaUploadActive forKey:@"WF_PRO_MEDIA_UPLOAD_ACTIVE"];
        [u setBool:self.rememberCameraImage forKey:@"WF_PRO_CAM_REMEMBER"];
        [u setBool:self.scheduleEnabled forKey:@"WF_PRO_SCHEDULE_ENABLED"];
        [u setObject:self.scheduleWeekdays ?: @[] forKey:@"WF_PRO_SCHEDULE_DAYS"];
        [u setInteger:MAX(0, MIN(1439, self.scheduleStartMinutes)) forKey:@"WF_PRO_SCHEDULE_START"];
        [u setInteger:MAX(0, MIN(1439, self.scheduleEndMinutes)) forKey:@"WF_PRO_SCHEDULE_END"];
        [u setObject:@(self.scheduleLocationID) forKey:@"WF_PRO_SCHEDULE_LOCATION_ID"];
        [u setBool:self.scheduleApplied forKey:@"WF_PRO_SCHEDULE_APPLIED"];
        [u setBool:self.scheduleDraftDirty forKey:@"WF_PRO_SCHEDULE_DRAFT_DIRTY"];
        [u setBool:YES forKey:@"WF_PRO_SCHEDULE_COMMITTED_V1"];
        [u setBool:self.committedScheduleEnabled forKey:@"WF_PRO_SCHEDULE_COMMITTED_ENABLED"];
        [u setObject:self.committedScheduleWeekdays ?: @[] forKey:@"WF_PRO_SCHEDULE_COMMITTED_DAYS"];
        [u setInteger:MAX(0, MIN(1439, self.committedScheduleStartMinutes)) forKey:@"WF_PRO_SCHEDULE_COMMITTED_START"];
        [u setInteger:MAX(0, MIN(1439, self.committedScheduleEndMinutes)) forKey:@"WF_PRO_SCHEDULE_COMMITTED_END"];
        [u setObject:@(self.committedScheduleLocationID) forKey:@"WF_PRO_SCHEDULE_COMMITTED_LOCATION_ID"];
        
        NSMutableArray *ids = [NSMutableArray new];
        for (WolFoxProIdentifier *i in _mutableIdentifiers) {
            NSString *dateStr = i.createdAt ? [NSString stringWithFormat:@"%.0f", [(NSDate*)i.createdAt timeIntervalSince1970]] : [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]];
            [ids addObject:@{@"uuid": i.uuid ?: @"", @"name": i.name ?: @"", @"date": dateStr}];
        }
        [u setObject:ids forKey:@"WF_PRO_IDS"];
        if (self.activeIdentifierUUID) [u setObject:self.activeIdentifierUUID forKey:@"WF_PRO_ACTIVE_ID"];
        else [u removeObjectForKey:@"WF_PRO_ACTIVE_ID"];
        
        [u setBool:self.bluetoothActive forKey:@"WF_PRO_BT_ACT"];
        if (self.activeBleProfileID) [u setObject:self.activeBleProfileID forKey:@"WF_PRO_BT_ACTIVE_ID"];
        else [u removeObjectForKey:@"WF_PRO_BT_ACTIVE_ID"];
        NSMutableArray *rawProfiles = [NSMutableArray new];
        for (WolFoxBleProfile *p in self.savedBleProfiles) {
            [rawProfiles addObject:@{
                @"profileID": p.profileID ?: @"",
                @"name":      p.name ?: @"",
                @"uuid":      p.uuid ?: @"",
                @"localName": p.localName ?: @"",
                @"rssi":      @(p.rssi)
            }];
        }
        [u setObject:rawProfiles forKey:@"WF_PRO_BT_PROFILES"];
        
        [u synchronize];
    }
}

- (void)commitScheduleDraft {
    @synchronized(self) {
        self.committedScheduleEnabled = self.scheduleEnabled;
        self.committedScheduleWeekdays = self.scheduleWeekdays ?: @[];
        self.committedScheduleStartMinutes = self.scheduleStartMinutes;
        self.committedScheduleEndMinutes = self.scheduleEndMinutes;
        self.committedScheduleLocationID = self.scheduleLocationID;
        self.scheduleDraftDirty = NO;
    }
}

- (void)saveIdentifier:(WolFoxProIdentifier *)i {
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:i.uuid];
    if (!uuid) return;
    i.uuid = uuid.UUIDString;
    for (WolFoxProIdentifier *existing in [_mutableIdentifiers copy]) {
        if ([existing.uuid isEqualToString:i.uuid]) [_mutableIdentifiers removeObject:existing];
    }
    [_mutableIdentifiers addObject:i];
    [self saveSettings];
}

- (NSUUID *)validatedActiveIdentifier {
    NSString *value = self.activeIdentifierUUID;
    return value.length ? [[NSUUID alloc] initWithUUIDString:value] : nil;
}

- (BOOL)activateIdentifierString:(NSString *)value {
    NSString *trimmed = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:trimmed];
    if (!uuid) return NO;
    self.activeIdentifierUUID = uuid.UUIDString;
    BOOL alreadySaved = NO;
    for (WolFoxProIdentifier *identifier in _mutableIdentifiers) {
        if ([identifier.uuid isEqualToString:self.activeIdentifierUUID]) {
            alreadySaved = YES;
            break;
        }
    }
    if (!alreadySaved) {
        WolFoxProIdentifier *identifier = [WolFoxProIdentifier new];
        identifier.uuid = self.activeIdentifierUUID;
        identifier.name = @"هوية موحدة";
        identifier.createdAt = [NSDate date];
        [_mutableIdentifiers addObject:identifier];
    }
    [self saveSettings];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WF_IDENTIFIER_CHANGED" object:self.activeIdentifierUUID];
    return YES;
}

- (void)deactivateIdentifier {
    self.activeIdentifierUUID = nil;
    [self saveSettings];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WF_IDENTIFIER_CHANGED" object:nil];
}

- (void)deleteIdentifierUUID:(NSString *)uuid {
    NSUInteger index = [_mutableIdentifiers indexOfObjectPassingTest:^BOOL(WolFoxProIdentifier *i, NSUInteger idx, BOOL *stop) {
        if (![i.uuid isEqualToString:uuid]) return NO;
        *stop = YES;
        return YES;
    }];
    if (index != NSNotFound) [_mutableIdentifiers removeObjectAtIndex:index];
    BOOL removedActive = self.activeIdentifierUUID.length && uuid.length &&
                         [self.activeIdentifierUUID caseInsensitiveCompare:uuid] == NSOrderedSame;
    if (removedActive) {
        self.activeIdentifierUUID = nil;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"WF_IDENTIFIER_CHANGED" object:nil];
    }
    [self saveSettings];
}

- (NSArray *)identifiers { return [_mutableIdentifiers copy]; }

- (void)saveBleProfile:(WolFoxBleProfile *)profile {
    if (!profile.profileID) profile.profileID = [[NSUUID UUID] UUIDString];
    @synchronized(self.savedBleProfiles) {
        for (WolFoxBleProfile *p in [self.savedBleProfiles copy]) {
            if ([p.profileID isEqualToString:profile.profileID]) {
                [self.savedBleProfiles removeObject:p]; break;
            }
        }
        [self.savedBleProfiles insertObject:profile atIndex:0];
    }
    [self saveSettings];
}

- (void)deleteBleProfileID:(NSString *)profileID {
    @synchronized(self.savedBleProfiles) {
        for (WolFoxBleProfile *p in [self.savedBleProfiles copy]) {
            if ([p.profileID isEqualToString:profileID]) {
                [self.savedBleProfiles removeObject:p]; break;
            }
        }
    }
    // FIXED: إذا حُذف الملف النشط، أوقف تزييف البلوتوث تلقائياً
    if (profileID.length && self.activeBleProfileID.length &&
        [self.activeBleProfileID isEqualToString:profileID]) {
        self.activeBleProfileID = nil;
        self.bluetoothActive = NO;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"WF_BT_PROFILE_DEACTIVATED" object:nil];
    }
    [self saveSettings];
}

- (WolFoxBleProfile *)activeBleProfile {
    NSString *activeID = self.activeBleProfileID;
    if (!activeID.length) return nil;
    @synchronized(self.savedBleProfiles) {
        for (WolFoxBleProfile *profile in self.savedBleProfiles) {
            if ([profile.profileID isEqualToString:activeID]) return [profile copy];
        }
    }
    return nil;
}

- (NSString *)mediaStoragePath {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *base = [fm URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject.path;
    if (!base.length) base = [fm URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject.path;
    NSString *directory = [base stringByAppendingPathComponent:@"WolFox/Media"];
    NSError *error = nil;
    if (![fm createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error]) {
        directory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"WolFoxMedia"];
        [fm createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    // استخدم bundleID لعزل ملفات الوسائط بين التطبيقات المختلفة
    NSString *bundleSuffix = [NSBundle mainBundle].bundleIdentifier ?: @"default";
    NSString *safeBundle = [[bundleSuffix componentsSeparatedByCharactersInSet:
        [[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@"_"];
    return [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"wf_spoof_%@.jpg", safeBundle]];
}

@end
