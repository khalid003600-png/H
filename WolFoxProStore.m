#import "WFRedactedLogger.h"
// WolFoxProStore.m
#import "WolFoxProStore.h"
#import "WFHookDefaults.h"
#import <sqlite3.h>

NSNotificationName const WFSpoofStateDidChangeNotification = @"WFSpoofStateDidChangeNotification";

static NSString *WFNormalizedIdentifierUUIDString(NSString *value) {
    if (![value isKindOfClass:[NSString class]]) return nil;
    NSString *raw = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if ([raw.lowercaseString hasPrefix:@"urn:uuid:"]) raw = [raw substringFromIndex:9];
    if ([raw hasPrefix:@"{"] && [raw hasSuffix:@"}"] && raw.length > 2) {
        raw = [raw substringWithRange:NSMakeRange(1, raw.length - 2)];
    }
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:raw];
    return uuid.UUIDString;
}

@implementation WolFoxProLocation
- (id)copyWithZone:(NSZone *)zone {
    WolFoxProLocation *copy = [[WolFoxProLocation allocWithZone:zone] init];
    copy.ID = self.ID; copy.name = self.name; copy.coordinate = self.coordinate; copy.altitude = self.altitude;
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

@implementation WolFoxProStore {
    sqlite3 *_db;
    NSMutableArray *_mutableLocations;
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
    char *err = NULL;
    const char *sql = "CREATE TABLE IF NOT EXISTS locations (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, lat REAL, lon REAL, alt REAL);";
    if (sqlite3_exec(_db, sql, NULL, NULL, &err) != SQLITE_OK) {
        WFLog(@"[WolFox][STORE] schema_error=%s", err ?: "unknown");
    }
    if (err) sqlite3_free(err);
    [self loadLocations];
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
    if (l.ID <= 0 || !l.name.length || !CLLocationCoordinate2DIsValid(l.coordinate)) return NO;
    sqlite3_stmt *stmt = NULL;
    const char *sql = "UPDATE locations SET name = ?, lat = ?, lon = ?, alt = ? WHERE id = ?;";
    BOOL updated = NO;
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, [l.name UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_double(stmt, 2, l.coordinate.latitude);
        sqlite3_bind_double(stmt, 3, l.coordinate.longitude);
        sqlite3_bind_double(stmt, 4, l.altitude);
        sqlite3_bind_int64(stmt, 5, l.ID);
        updated = sqlite3_step(stmt) == SQLITE_DONE && sqlite3_changes(_db) > 0;
    }
    if (stmt) sqlite3_finalize(stmt);
    if (!updated) return NO;
    for (WolFoxProLocation *item in _mutableLocations) {
        if (item.ID == l.ID) {
            item.name = l.name; item.coordinate = l.coordinate; item.altitude = l.altitude;
            break;
        }
    }
    return YES;
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

- (void)loadSettings {
    @synchronized(self) {
        NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
        if ([u objectForKey:@"WF_PRO_SPOOF_ACT"] == nil) { self.spoofActive = NO; [u setBool:NO forKey:@"WF_PRO_SPOOF_ACT"]; } else { self.spoofActive = [u boolForKey:@"WF_PRO_SPOOF_ACT"]; }
        self.routeActive = NO;
        if ([u objectForKey:@"WF_PRO_JITTER_ACT"] == nil) {
            self.jitterActive = WFDefaultJitterEnabled;
            [u setBool:self.jitterActive forKey:@"WF_PRO_JITTER_ACT"];
        } else self.jitterActive = [u boolForKey:@"WF_PRO_JITTER_ACT"];
        self.volumeGestureEnabled = [u objectForKey:@"WF_PRO_VOLUME_GESTURE"] == nil ? YES : [u boolForKey:@"WF_PRO_VOLUME_GESTURE"];
        self.themeIndex = 0; [u setInteger:0 forKey:@"WF_PRO_THEME_IDX"];
        self.mapStyle = [u integerForKey:@"WF_PRO_MAP_STYLE"];
        double savedSpeed = [u objectForKey:@"WF_PRO_SIM_SPEED"] ? [u doubleForKey:@"WF_PRO_SIM_SPEED"] : WFDefaultSimulationSpeedKmh;
        self.simSpeed = WFClampSimulationSpeed(savedSpeed);
        double savedInterval = [u objectForKey:@"WF_PRO_UPDATE_INTERVAL"] ? [u doubleForKey:@"WF_PRO_UPDATE_INTERVAL"] : WFDefaultGPSUpdateIntervalSeconds;
        self.updateIntervalSeconds = WFClampGPSUpdateInterval(savedInterval);
        NSNumber *savedLatitude = [u objectForKey:@"WF_PRO_LAT"];
        NSNumber *savedLongitude = [u objectForKey:@"WF_PRO_LON"];
        if ([savedLatitude isKindOfClass:NSNumber.class] && [savedLongitude isKindOfClass:NSNumber.class]) self.currentFakeCoords = CLLocationCoordinate2DMake(savedLatitude.doubleValue, savedLongitude.doubleValue);
        else self.currentFakeCoords = CLLocationCoordinate2DMake(24.7136, 46.6753);
        if (!CLLocationCoordinate2DIsValid(self.currentFakeCoords)) self.currentFakeCoords = CLLocationCoordinate2DMake(24.7136, 46.6753);
        NSNumber *savedTargetLat = [u objectForKey:@"WF_PRO_TARGET_LAT"];
        NSNumber *savedTargetLon = [u objectForKey:@"WF_PRO_TARGET_LON"];
        if ([savedTargetLat isKindOfClass:NSNumber.class] && [savedTargetLon isKindOfClass:NSNumber.class]) self.targetRouteCoords = CLLocationCoordinate2DMake(savedTargetLat.doubleValue, savedTargetLon.doubleValue);
        self.spoofedImagePath = [u stringForKey:@"WF_PRO_CAM_IMG"];
        self.mediaUploadActive = [u boolForKey:@"WF_PRO_MEDIA_UPLOAD_ACTIVE"];
        id rememberCameraValue = [u objectForKey:@"WF_PRO_CAM_REMEMBER"];
        self.rememberCameraImage = rememberCameraValue ? [u boolForKey:@"WF_PRO_CAM_REMEMBER"] : self.spoofedImagePath.length > 0;
        if (!rememberCameraValue) [u setBool:self.rememberCameraImage forKey:@"WF_PRO_CAM_REMEMBER"];
        self.scheduleEnabled = [u boolForKey:@"WF_PRO_SCHEDULE_ENABLED"];
        NSArray *rawDays = [u arrayForKey:@"WF_PRO_SCHEDULE_DAYS"] ?: @[];
        NSMutableArray<NSNumber *> *validDays = [NSMutableArray new];
        for (id value in rawDays) { NSInteger day = [value integerValue]; if (day >= 1 && day <= 7 && ![validDays containsObject:@(day)]) [validDays addObject:@(day)]; }
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
            self.spoofedImagePath = nil; self.mediaUploadActive = NO; [u removeObjectForKey:@"WF_PRO_CAM_IMG"]; [u setBool:NO forKey:@"WF_PRO_MEDIA_UPLOAD_ACTIVE"];
        }

        _mutableIdentifiers = [NSMutableArray new];
        NSMutableSet<NSString *> *seenIdentifierUUIDs = [NSMutableSet set];
        NSArray *ids = [u arrayForKey:@"WF_PRO_IDS"] ?: @[];
        for (id rawIdentifier in ids) {
            if (![rawIdentifier isKindOfClass:[NSDictionary class]]) continue;
            NSDictionary *d = (NSDictionary *)rawIdentifier;
            NSString *uuidValue = [d[@"uuid"] isKindOfClass:[NSString class]] ? d[@"uuid"] : nil;
            NSString *normalizedUUID = WFNormalizedIdentifierUUIDString(uuidValue);
            if (!normalizedUUID || [seenIdentifierUUIDs containsObject:normalizedUUID.lowercaseString]) continue;
            WolFoxProIdentifier *i = [WolFoxProIdentifier new];
            i.uuid = normalizedUUID;
            NSString *rawName = [d[@"name"] isKindOfClass:[NSString class]] ? d[@"name"] : @"";
            NSString *trimmedName = [rawName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            i.name = trimmedName.length ? trimmedName : @"هوية محفوظة";
            id dateValue = d[@"date"];
            NSTimeInterval timestamp = [dateValue respondsToSelector:@selector(doubleValue)] ? [dateValue doubleValue] : NSDate.date.timeIntervalSince1970;
            i.createdAt = [NSDate dateWithTimeIntervalSince1970:timestamp];
            [seenIdentifierUUIDs addObject:i.uuid.lowercaseString];
            [_mutableIdentifiers addObject:i];
            if (_mutableIdentifiers.count >= 50) break;
        }
        NSString *normalizedActiveUUID = WFNormalizedIdentifierUUIDString([u stringForKey:@"WF_PRO_ACTIVE_ID"]);
        self.activeIdentifierUUID = normalizedActiveUUID;
        if (normalizedActiveUUID && ![seenIdentifierUUIDs containsObject:normalizedActiveUUID.lowercaseString]) self.activeIdentifierUUID = nil;
        if (!self.activeIdentifierUUID.length) [u removeObjectForKey:@"WF_PRO_ACTIVE_ID"];

        self.bluetoothActive = [u boolForKey:@"WF_PRO_BT_ACT"];
        self.activeBleProfileID = [u stringForKey:@"WF_PRO_BT_ACTIVE_ID"];
        NSArray *rawProfiles = [u arrayForKey:@"WF_PRO_BT_PROFILES"] ?: @[];
        self.savedBleProfiles = [NSMutableArray new];
        for (NSDictionary *d in rawProfiles) {
            if (![d isKindOfClass:[NSDictionary class]]) continue;
            WolFoxBleProfile *p = [WolFoxBleProfile new];
            p.profileID = d[@"profileID"] ?: [[NSUUID UUID] UUIDString];
            p.name = d[@"name"] ?: @"جهاز غير معروف";
            p.uuid = d[@"uuid"] ?: @"";
            p.localName = d[@"localName"] ?: @"";
            p.rssi = [d[@"rssi"] integerValue];
            [self.savedBleProfiles addObject:p];
        }
    }
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
        [u setDouble:self.updateIntervalSeconds forKey:@"WF_PRO_UPDATE_INTERVAL"];
        [u setDouble:self.currentFakeCoords.latitude forKey:@"WF_PRO_LAT"];
        [u setDouble:self.currentFakeCoords.longitude forKey:@"WF_PRO_LON"];
        if (CLLocationCoordinate2DIsValid(self.targetRouteCoords)) { [u setDouble:self.targetRouteCoords.latitude forKey:@"WF_PRO_TARGET_LAT"]; [u setDouble:self.targetRouteCoords.longitude forKey:@"WF_PRO_TARGET_LON"]; }
        [u setBool:self.mediaUploadActive forKey:@"WF_PRO_MEDIA_UPLOAD_ACTIVE"];
        [u setBool:self.rememberCameraImage forKey:@"WF_PRO_CAM_REMEMBER"];
        if (self.spoofedImagePath) [u setObject:self.spoofedImagePath forKey:@"WF_PRO_CAM_IMG"]; else [u removeObjectForKey:@"WF_PRO_CAM_IMG"];
        [u setBool:self.scheduleEnabled forKey:@"WF_PRO_SCHEDULE_ENABLED"];
        [u setObject:self.scheduleWeekdays ?: @[] forKey:@"WF_PRO_SCHEDULE_DAYS"];
        [u setInteger:self.scheduleStartMinutes forKey:@"WF_PRO_SCHEDULE_START"];
        [u setInteger:self.scheduleEndMinutes forKey:@"WF_PRO_SCHEDULE_END"];
        [u setObject:@(self.scheduleLocationID) forKey:@"WF_PRO_SCHEDULE_LOCATION_ID"];
        [u setBool:self.scheduleApplied forKey:@"WF_PRO_SCHEDULE_APPLIED"];
        [u setBool:self.scheduleDraftDirty forKey:@"WF_PRO_SCHEDULE_DRAFT_DIRTY"];
        [u setBool:YES forKey:@"WF_PRO_SCHEDULE_COMMITTED_V1"];
        [u setBool:self.committedScheduleEnabled forKey:@"WF_PRO_SCHEDULE_COMMITTED_ENABLED"];
        [u setObject:self.committedScheduleWeekdays ?: @[] forKey:@"WF_PRO_SCHEDULE_COMMITTED_DAYS"];
        [u setInteger:self.committedScheduleStartMinutes forKey:@"WF_PRO_SCHEDULE_COMMITTED_START"];
        [u setInteger:self.committedScheduleEndMinutes forKey:@"WF_PRO_SCHEDULE_COMMITTED_END"];
        [u setObject:@(self.committedScheduleLocationID) forKey:@"WF_PRO_SCHEDULE_COMMITTED_LOCATION_ID"];

        NSMutableArray *ids = [NSMutableArray new];
        for (WolFoxProIdentifier *i in _mutableIdentifiers) {
            if (!i.uuid.length) continue;
            [ids addObject:@{ @"uuid": i.uuid, @"name": i.name ?: @"هوية محفوظة", @"date": @((i.createdAt ?: NSDate.date).timeIntervalSince1970) }];
            if (ids.count >= 50) break;
        }
        [u setObject:ids forKey:@"WF_PRO_IDS"];
        NSString *normalizedActive = WFNormalizedIdentifierUUIDString(self.activeIdentifierUUID);
        if (normalizedActive) [u setObject:normalizedActive forKey:@"WF_PRO_ACTIVE_ID"]; else [u removeObjectForKey:@"WF_PRO_ACTIVE_ID"];
        [u setBool:self.bluetoothActive forKey:@"WF_PRO_BT_ACT"];
        if (self.activeBleProfileID) [u setObject:self.activeBleProfileID forKey:@"WF_PRO_BT_ACTIVE_ID"]; else [u removeObjectForKey:@"WF_PRO_BT_ACTIVE_ID"];
        NSMutableArray *profiles = [NSMutableArray new];
        for (WolFoxBleProfile *p in self.savedBleProfiles) [profiles addObject:@{ @"profileID": p.profileID ?: @"", @"name": p.name ?: @"", @"uuid": p.uuid ?: @"", @"localName": p.localName ?: @"", @"rssi": @(p.rssi) }];
        [u setObject:profiles forKey:@"WF_PRO_BT_PROFILES"];
        [u synchronize];
    }
}

- (NSArray *)identifiers { return [_mutableIdentifiers copy]; }

- (void)saveIdentifier:(WolFoxProIdentifier *)i {
    if (!i) return;
    NSString *normalizedUUID = WFNormalizedIdentifierUUIDString(i.uuid);
    if (!normalizedUUID) return;
    WolFoxProIdentifier *safeIdentifier = [i copy];
    safeIdentifier.uuid = normalizedUUID;
    NSString *trimmedName = [safeIdentifier.name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    safeIdentifier.name = trimmedName.length ? trimmedName : @"هوية محفوظة";
    if (!safeIdentifier.createdAt) safeIdentifier.createdAt = NSDate.date;
    @synchronized(self) {
        for (WolFoxProIdentifier *existing in [_mutableIdentifiers copy]) if ([existing.uuid caseInsensitiveCompare:safeIdentifier.uuid] == NSOrderedSame) [_mutableIdentifiers removeObject:existing];
        [_mutableIdentifiers insertObject:safeIdentifier atIndex:0];
        while (_mutableIdentifiers.count > 50) [_mutableIdentifiers removeLastObject];
    }
    [self saveSettings];
}

- (NSUUID *)validatedActiveIdentifier {
    NSString *normalized = WFNormalizedIdentifierUUIDString(self.activeIdentifierUUID);
    return normalized.length ? [[NSUUID alloc] initWithUUIDString:normalized] : nil;
}

- (BOOL)activateIdentifierString:(NSString *)value {
    NSString *normalizedUUID = WFNormalizedIdentifierUUIDString(value);
    if (!normalizedUUID) return NO;
    self.activeIdentifierUUID = normalizedUUID;
    BOOL alreadySaved = NO;
    for (WolFoxProIdentifier *identifier in _mutableIdentifiers) {
        if ([identifier.uuid caseInsensitiveCompare:self.activeIdentifierUUID] == NSOrderedSame) { alreadySaved = YES; break; }
    }
    if (!alreadySaved) {
        WolFoxProIdentifier *item = [WolFoxProIdentifier new]; item.uuid = self.activeIdentifierUUID; item.name = @"هوية موحدة"; item.createdAt = [NSDate date]; [_mutableIdentifiers insertObject:item atIndex:0];
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
        if ([i.uuid caseInsensitiveCompare:uuid] != NSOrderedSame) return NO;
        *stop = YES; return YES;
    }];
    if (index != NSNotFound) [_mutableIdentifiers removeObjectAtIndex:index];
    if ([self.activeIdentifierUUID caseInsensitiveCompare:uuid] == NSOrderedSame) self.activeIdentifierUUID = nil;
    [self saveSettings];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WF_IDENTIFIER_CHANGED" object:self.activeIdentifierUUID];
}

- (void)saveBleProfile:(WolFoxBleProfile *)p { if (!p) return; if (!self.savedBleProfiles) self.savedBleProfiles = [NSMutableArray new]; [self.savedBleProfiles addObject:p]; [self saveSettings]; }
- (void)deleteBleProfileID:(NSString *)profileID { NSUInteger index = [self.savedBleProfiles indexOfObjectPassingTest:^BOOL(WolFoxBleProfile *p, NSUInteger idx, BOOL *stop) { return [p.profileID isEqualToString:profileID]; }]; if (index != NSNotFound) [self.savedBleProfiles removeObjectAtIndex:index]; if ([self.activeBleProfileID isEqualToString:profileID]) { self.activeBleProfileID = nil; self.bluetoothActive = NO; [[NSNotificationCenter defaultCenter] postNotificationName:@"WF_BT_PROFILE_DEACTIVATED" object:nil]; } [self saveSettings]; }

- (void)commitScheduleDraft {
    self.committedScheduleEnabled = self.scheduleEnabled;
    self.committedScheduleWeekdays = self.scheduleWeekdays ?: @[];
    self.committedScheduleStartMinutes = self.scheduleStartMinutes;
    self.committedScheduleEndMinutes = self.scheduleEndMinutes;
    self.committedScheduleLocationID = self.scheduleLocationID;
    self.scheduleDraftDirty = NO;
    self.scheduleApplied = NO;
}

@end
