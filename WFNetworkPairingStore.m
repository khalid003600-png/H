// WFNetworkPairingStore.m
#import "WFNetworkPairingStore.h"
#import <Security/Security.h>

static NSString *const WFNetworkProfilesDefaultsKey = @"WF_NETWORK_PAIRING_PROFILES_V1";
static NSString *const WFNetworkSecretService = @"fun.p3nd.wolfox.network-pairing";
static NSString *const WFNetworkPairingErrorDomain = @"WFNetworkPairingError";

@implementation WFNetworkPairingProfile
- (id)copyWithZone:(NSZone *)zone {
    WFNetworkPairingProfile *copy = [[WFNetworkPairingProfile allocWithZone:zone] init];
    copy.profileID = self.profileID; copy.kind = self.kind; copy.name = self.name;
    copy.host = self.host; copy.port = self.port; copy.deviceIdentifier = self.deviceIdentifier;
    copy.ssid = self.ssid; copy.certificateSHA256 = self.certificateSHA256;
    copy.autoReconnect = self.autoReconnect; copy.updatedAt = self.updatedAt;
    return copy;
}
@end

@interface WFNetworkPairingStore ()
@property (nonatomic, strong) NSMutableArray<WFNetworkPairingProfile *> *mutableProfiles;
@end

@implementation WFNetworkPairingStore

+ (instancetype)shared {
    static WFNetworkPairingStore *store;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ store = [WFNetworkPairingStore new]; });
    return store;
}

- (instancetype)init {
    if ((self = [super init])) [self loadProfiles];
    return self;
}

- (NSArray<WFNetworkPairingProfile *> *)profiles {
    @synchronized (self) { return [[NSArray alloc] initWithArray:self.mutableProfiles copyItems:YES]; }
}

static NSString *WFTrim(NSString *value) {
    return [[value ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] copy];
}

static NSString *WFNormalizedPin(NSString *value) {
    NSString *pin = [[WFTrim(value) stringByReplacingOccurrencesOfString:@":" withString:@""] lowercaseString];
    NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet];
    return pin.length == 64 && [pin rangeOfCharacterFromSet:invalid].location == NSNotFound ? pin : @"";
}

- (NSError *)errorWithCode:(NSInteger)code message:(NSString *)message {
    return [NSError errorWithDomain:WFNetworkPairingErrorDomain code:code
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"خطأ في ملف الاقتران"}];
}

- (BOOL)validateProfile:(WFNetworkPairingProfile *)profile error:(NSError **)error {
    profile.name = WFTrim(profile.name);
    profile.host = WFTrim(profile.host);
    profile.deviceIdentifier = WFTrim(profile.deviceIdentifier);
    profile.ssid = WFTrim(profile.ssid);
    profile.certificateSHA256 = WFNormalizedPin(profile.certificateSHA256);
    if (!profile.profileID.length) profile.profileID = NSUUID.UUID.UUIDString;
    if (!profile.name.length) {
        if (error) *error = [self errorWithCode:1 message:@"اسم ملف الاقتران مطلوب"];
        return NO;
    }
    if (profile.kind == WFNetworkProfileKindRadar && !profile.deviceIdentifier.length && !profile.host.length) {
        if (error) *error = [self errorWithCode:2 message:@"معرّف جهاز الرادار أو عنوانه مطلوب"];
        return NO;
    }
    if (profile.kind == WFNetworkProfileKindWiFi && !profile.ssid.length) {
        if (error) *error = [self errorWithCode:3 message:@"اسم شبكة Wi‑Fi مطلوب"];
        return NO;
    }
    if (profile.kind == WFNetworkProfileKindTLS) {
        if (!profile.host.length || profile.port < 1 || profile.port > 65535) {
            if (error) *error = [self errorWithCode:4 message:@"عنوان SSL والمنفذ غير صالحين"];
            return NO;
        }
        if (!profile.certificateSHA256.length) {
            if (error) *error = [self errorWithCode:5 message:@"بصمة شهادة SHA‑256 مطلوبة وصيغتها 64 خانة"];
            return NO;
        }
    }
    profile.updatedAt = NSDate.date;
    return YES;
}

- (NSDictionary *)dictionaryForProfile:(WFNetworkPairingProfile *)profile {
    return @{@"id": profile.profileID, @"kind": @(profile.kind), @"name": profile.name,
             @"host": profile.host ?: @"", @"port": @(profile.port),
             @"device_id": profile.deviceIdentifier ?: @"", @"ssid": profile.ssid ?: @"",
             @"certificate_sha256": profile.certificateSHA256 ?: @"",
             @"auto_reconnect": @(profile.autoReconnect),
             @"updated_at": @([profile.updatedAt timeIntervalSince1970])};
}

- (WFNetworkPairingProfile *)profileFromDictionary:(NSDictionary *)raw {
    if (![raw isKindOfClass:NSDictionary.class] || ![raw[@"id"] isKindOfClass:NSString.class]) return nil;
    WFNetworkPairingProfile *p = [WFNetworkPairingProfile new];
    p.profileID = raw[@"id"]; p.kind = [raw[@"kind"] integerValue];
    if (p.kind < WFNetworkProfileKindRadar || p.kind > WFNetworkProfileKindTLS) return nil;
    p.name = [raw[@"name"] isKindOfClass:NSString.class] ? raw[@"name"] : @"";
    p.host = [raw[@"host"] isKindOfClass:NSString.class] ? raw[@"host"] : @"";
    p.port = [raw[@"port"] integerValue];
    p.deviceIdentifier = [raw[@"device_id"] isKindOfClass:NSString.class] ? raw[@"device_id"] : @"";
    p.ssid = [raw[@"ssid"] isKindOfClass:NSString.class] ? raw[@"ssid"] : @"";
    p.certificateSHA256 = [raw[@"certificate_sha256"] isKindOfClass:NSString.class] ? raw[@"certificate_sha256"] : @"";
    p.autoReconnect = [raw[@"auto_reconnect"] boolValue];
    p.updatedAt = [NSDate dateWithTimeIntervalSince1970:[raw[@"updated_at"] doubleValue]];
    return p;
}

- (void)loadProfiles {
    self.mutableProfiles = [NSMutableArray new];
    NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:WFNetworkProfilesDefaultsKey] ?: @[];
    for (NSDictionary *raw in saved) {
        WFNetworkPairingProfile *profile = [self profileFromDictionary:raw];
        if (profile) [self.mutableProfiles addObject:profile];
    }
}

- (void)persistProfiles {
    NSMutableArray *encoded = [NSMutableArray new];
    for (WFNetworkPairingProfile *profile in self.mutableProfiles) [encoded addObject:[self dictionaryForProfile:profile]];
    [[NSUserDefaults standardUserDefaults] setObject:encoded forKey:WFNetworkProfilesDefaultsKey];
}

- (NSMutableDictionary *)keychainQueryForProfileID:(NSString *)profileID {
    return [@{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
              (__bridge id)kSecAttrService: WFNetworkSecretService,
              (__bridge id)kSecAttrAccount: profileID ?: @""} mutableCopy];
}

- (BOOL)saveSecret:(NSString *)secret profileID:(NSString *)profileID error:(NSError **)error {
    NSMutableDictionary *query = [self keychainQueryForProfileID:profileID];
    NSData *data = [secret dataUsingEncoding:NSUTF8StringEncoding];
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query,
                                    (__bridge CFDictionaryRef)@{(__bridge id)kSecValueData: data});
    if (status == errSecItemNotFound) {
        query[(__bridge id)kSecValueData] = data;
        query[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
        status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    }
    if (status != errSecSuccess && error) *error = [self errorWithCode:status message:@"تعذر حفظ سر الاقتران في Keychain"];
    return status == errSecSuccess;
}

- (BOOL)saveProfile:(WFNetworkPairingProfile *)profile secret:(NSString *)secret error:(NSError **)error {
    if (![self validateProfile:profile error:error]) return NO;
    @synchronized (self) {
        NSUInteger index = [self.mutableProfiles indexOfObjectPassingTest:^BOOL(WFNetworkPairingProfile *item, NSUInteger idx, BOOL *stop) {
            return [item.profileID isEqualToString:profile.profileID];
        }];
        if (secret != nil && ![self saveSecret:secret profileID:profile.profileID error:error]) return NO;
        WFNetworkPairingProfile *saved = [profile copy];
        if (index == NSNotFound) [self.mutableProfiles addObject:saved]; else self.mutableProfiles[index] = saved;
        [self persistProfiles];
    }
    return YES;
}

- (WFNetworkPairingProfile *)profileWithID:(NSString *)profileID {
    @synchronized (self) {
        for (WFNetworkPairingProfile *profile in self.mutableProfiles)
            if ([profile.profileID isEqualToString:profileID]) return [profile copy];
    }
    return nil;
}

- (NSString *)secretForProfileID:(NSString *)profileID error:(NSError **)error {
    NSMutableDictionary *query = [self keychainQueryForProfileID:profileID];
    query[(__bridge id)kSecReturnData] = @YES;
    query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status == errSecItemNotFound) return nil;
    if (status != errSecSuccess) {
        if (error) *error = [self errorWithCode:status message:@"تعذر قراءة سر الاقتران من Keychain"];
        return nil;
    }
    NSData *data = CFBridgingRelease(result);
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (BOOL)deleteProfileID:(NSString *)profileID error:(NSError **)error {
    if (!profileID.length) return NO;
    @synchronized (self) {
        NSIndexSet *indexes = [self.mutableProfiles indexesOfObjectsPassingTest:^BOOL(WFNetworkPairingProfile *item, NSUInteger idx, BOOL *stop) {
            return [item.profileID isEqualToString:profileID];
        }];
        [self.mutableProfiles removeObjectsAtIndexes:indexes];
        [self persistProfiles];
    }
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)[self keychainQueryForProfileID:profileID]);
    if (status != errSecSuccess && status != errSecItemNotFound) {
        if (error) *error = [self errorWithCode:status message:@"حُذف الملف وتعذر حذف سره من Keychain"];
        return NO;
    }
    return YES;
}
@end
