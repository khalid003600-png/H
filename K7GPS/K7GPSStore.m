#import "K7GPSStore.h"

static NSString * const K7GPSDefaultsKey = @"K7GPS_SETTINGS_V1";

@implementation K7GPSStore

+ (instancetype)shared {
    static K7GPSStore *store;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        store = [K7GPSStore new];
        [store load];
    });
    return store;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _selectedCoordinate = kCLLocationCoordinate2DInvalid;
        _selectedTitle = @"";
        _savedLocations = @[];
        _revealMode = 0;
    }
    return self;
}

- (void)load {
    NSDictionary *d = [[NSUserDefaults standardUserDefaults] dictionaryForKey:K7GPSDefaultsKey];
    if (![d isKindOfClass:NSDictionary.class]) return;
    self.locationEnabled = [d[@"locationEnabled"] boolValue];
    self.cameraEnabled = [d[@"cameraEnabled"] boolValue];
    self.revealMode = [d[@"revealMode"] integerValue];
    self.selectedTitle = [d[@"selectedTitle"] isKindOfClass:NSString.class] ? d[@"selectedTitle"] : @"";
    NSNumber *lat = d[@"lat"], *lon = d[@"lon"];
    if ([lat isKindOfClass:NSNumber.class] && [lon isKindOfClass:NSNumber.class]) {
        self.selectedCoordinate = CLLocationCoordinate2DMake(lat.doubleValue, lon.doubleValue);
    }
    NSArray *saved = d[@"savedLocations"];
    if ([saved isKindOfClass:NSArray.class]) self.savedLocations = saved;
}

- (void)save {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"locationEnabled"] = @(self.locationEnabled);
    d[@"cameraEnabled"] = @(self.cameraEnabled);
    d[@"revealMode"] = @(self.revealMode);
    d[@"selectedTitle"] = self.selectedTitle ?: @"";
    if (CLLocationCoordinate2DIsValid(self.selectedCoordinate)) {
        d[@"lat"] = @(self.selectedCoordinate.latitude);
        d[@"lon"] = @(self.selectedCoordinate.longitude);
    }
    d[@"savedLocations"] = self.savedLocations ?: @[];
    [[NSUserDefaults standardUserDefaults] setObject:d forKey:K7GPSDefaultsKey];
}

- (void)addSavedLocationWithTitle:(NSString *)title coordinate:(CLLocationCoordinate2D)coordinate {
    if (!CLLocationCoordinate2DIsValid(coordinate)) return;
    NSMutableArray *items = [self.savedLocations mutableCopy] ?: [NSMutableArray array];
    NSDictionary *item = @{
        @"title": title.length ? title : @"موقع محفوظ",
        @"lat": @(coordinate.latitude),
        @"lon": @(coordinate.longitude)
    };
    [items addObject:item];
    self.savedLocations = items;
    [self save];
}

- (void)removeSavedLocationAtIndex:(NSUInteger)index {
    if (index >= self.savedLocations.count) return;
    NSMutableArray *items = [self.savedLocations mutableCopy];
    [items removeObjectAtIndex:index];
    self.savedLocations = items;
    [self save];
}

@end
