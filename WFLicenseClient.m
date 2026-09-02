#import "WFRedactedLogger.h"
#import "WFLicenseClient.h"
#import <Security/Security.h>
#import <UIKit/UIKit.h>
#import <stdatomic.h>
#import "WFLicenseConfig.h"

static NSString * const kKeychainService = @"fun.p3nd.wolfox.license";
static NSString * const kCodeKey = @"wf_license_code";
static NSString * const kTokenKey = @"wf_access_token";
static NSString * const kCacheKey = @"wf_license_cache";
static NSString * const kActivatedKey = @"wf_is_activated";
static NSString * const kDeviceKey = @"wf_device_id";
static NSString *_baseURL = WF_PANEL_BASE_URL;
static NSString *_projectKey = WF_PROJECT_KEY;
static const NSTimeInterval kCacheTTL = 86400.0;
static atomic_bool _runtimeLicenseValid = false;
static WFLicenseResult *_lastResult = nil;

@interface WFLicenseClient ()
+ (void)setRuntimeResult:(WFLicenseResult *)result;
+ (void)complete:(void(^)(WFLicenseResult *))completion result:(WFLicenseResult *)result;
+ (void)postEndpoint:(NSString *)endpoint body:(NSDictionary *)body completion:(void(^)(NSDictionary *, NSInteger, NSError *))completion;
+ (WFLicenseResult *)resultFromJSON:(NSDictionary *)json fallbackSuccess:(BOOL)success license:(NSDictionary *)license;
+ (WFLicenseResult *)resultWithSuccess:(BOOL)success status:(WFLicenseStatus)status message:(NSString *)message started:(NSString *)started expires:(NSString *)expires plan:(NSString *)plan;
+ (NSString *)stringValue:(id)value;
+ (NSString *)dateFrom:(NSDictionary *)dictionary keys:(NSArray<NSString *> *)keys;
+ (NSDate *)dateFromServerString:(NSString *)value;
+ (void)saveCacheFromResponse:(NSDictionary *)json code:(NSString *)code;
+ (WFLicenseResult *)cachedResult;
+ (BOOL)isTransientResult:(WFLicenseResult *)result;
+ (WFLicenseResult *)preservedResultForTransientFailure:(WFLicenseResult *)failure;
+ (BOOL)saveToKeychain:(NSString *)value key:(NSString *)key;
+ (NSString *)loadFromKeychain:(NSString *)key;
@end

@implementation WFLicenseResult
@end

@implementation WFLicenseClient

+ (NSString *)baseURL { return _baseURL; }
+ (void)setBaseURL:(NSString *)value { if (value.length) _baseURL = [value copy]; }
+ (NSString *)projectKey { return _projectKey; }
+ (void)setProjectKey:(NSString *)value { if (value.length) _projectKey = [value copy]; }
+ (BOOL)isRuntimeLicenseValid { return atomic_load(&_runtimeLicenseValid); }
+ (WFLicenseResult *)lastLicenseResult { @synchronized(self) { return _lastResult; } }

+ (void)setRuntimeResult:(WFLicenseResult *)result {
    atomic_store(&_runtimeLicenseValid, result.success && result.status == WFLicenseStatusValid);
    @synchronized(self) { _lastResult = result; }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WF_LICENSE_STATE_CHANGED" object:result];
}

+ (void)complete:(void(^)(WFLicenseResult *))completion result:(WFLicenseResult *)result {
    [self setRuntimeResult:result];
    if (completion) completion(result);
}

+ (BOOL)isTransientResult:(WFLicenseResult *)result {
    if (!result) return NO;
    return result.status == WFLicenseStatusNetworkError ||
           result.status == WFLicenseStatusRateLimited;
}

+ (WFLicenseResult *)preservedResultForTransientFailure:(WFLicenseResult *)failure {
    WFLicenseResult *last = [self lastLicenseResult];
    WFLicenseResult *preserved = [self resultWithSuccess:YES
                                                   status:WFLicenseStatusValid
                                                  message:@"الترخيص محفوظ مؤقتاً؛ تعذر الوصول إلى الخادم"
                                                 started:last.startedAt
                                                 expires:last.expiresAt
                                                    plan:last.planName];
    preserved.errorCode = failure.errorCode;
    preserved.updateURL = last.updateURL;
    preserved.minimumVersion = last.minimumVersion;
    preserved.forceUpdate = NO;
    return preserved;
}

+ (void)activateCode:(NSString *)code completion:(void(^)(WFLicenseResult *))completion {
    NSString *trimmed = [[code stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
#ifdef DEBUG
    WFLog(@"[WolFox][LICENSE] activate_request length=%lu", (unsigned long)trimmed.length);
#endif
    if (!trimmed.length) {
        [self complete:completion result:[self resultWithSuccess:NO status:WFLicenseStatusInvalid message:@"يرجى إدخال كود التفعيل أولاً" started:nil expires:nil plan:nil]];
        return;
    }
    NSDictionary *body = @{
        @"license_code": trimmed,
        @"device_uuid":  [self deviceIdentifier],
        @"device_name":  [UIDevice currentDevice].name ?: @"iOS Device",
        @"app_version":  WF_APP_VERSION,
        @"project_key":  _projectKey ?: @"",
        @"bundle_id":    [NSBundle mainBundle].bundleIdentifier ?: @"",
        @"app_name":     [NSBundle mainBundle].infoDictionary[@"CFBundleDisplayName"]
                         ?: [NSBundle mainBundle].infoDictionary[@"CFBundleName"]
                         ?: @""
    };
    [self postEndpoint:@"/activate.php" body:body completion:^(NSDictionary *json, NSInteger httpStatus, NSError *error) {
        if (error) {
            WFLicenseResult *failure = [self resultWithSuccess:NO status:WFLicenseStatusNetworkError message:[NSString stringWithFormat:@"فشل الاتصال بخادم التفعيل: %@", error.localizedDescription ?: @"خطأ غير معروف"] started:nil expires:nil plan:nil];
            // إعادة التفعيل لا تُبطل جلسة صحيحة عند انقطاع الشبكة.
            if ([self isRuntimeLicenseValid]) {
                if (completion) completion([self preservedResultForTransientFailure:failure]);
            } else {
                [self complete:completion result:failure];
            }
            return;
        }
        NSDictionary *data = [json[@"data"] isKindOfClass:NSDictionary.class] ? json[@"data"] : @{};
        NSDictionary *license = [data[@"license"] isKindOfClass:NSDictionary.class] ? data[@"license"] : data;
        BOOL success = [json[@"success"] boolValue] && httpStatus >= 200 && httpStatus < 300;
        if (success) {
            NSString *token = [data[@"access_token"] isKindOfClass:NSString.class] ? data[@"access_token"] : nil;
            BOOL stored = token.length && [self saveToKeychain:trimmed key:kCodeKey] && [self saveToKeychain:token key:kTokenKey] && [self saveToKeychain:@"YES" key:kActivatedKey];
            if (stored) {
                [self saveCacheFromResponse:json code:trimmed];
            } else {
                success = NO;
                [self clearStoredLicense];
                json = @{@"success": @NO, @"error_code": @"secure_storage_failed", @"message": @"تعذر حفظ بيانات التفعيل بأمان على الجهاز"};
                license = @{};
            }
        }
        [self complete:completion result:[self resultFromJSON:json fallbackSuccess:success license:license]];
    }];
}

+ (void)verifySavedLicenseWithCompletion:(void(^)(WFLicenseResult *))completion {
    [self validateStrictlyWithCompletion:completion];
}

+ (void)validateStrictlyWithCompletion:(void(^)(WFLicenseResult *))completion {
    NSString *code = [self storedCode];
#ifdef DEBUG
    WFLog(@"[WolFox][LICENSE] verify_begin stored=%d", code.length > 0);
#endif
    if (!code.length || ![self hasStoredLicense]) {
        [self complete:completion result:[self resultWithSuccess:NO status:WFLicenseStatusInvalid message:@"الجهاز غير مفعل" started:nil expires:nil plan:nil]];
        return;
    }
    NSDictionary *body = @{
        @"license_code": code,
        @"device_uuid": [self deviceIdentifier],
        @"access_token": [self loadFromKeychain:kTokenKey] ?: @"",
        @"app_version": WF_APP_VERSION,
        @"project_key": _projectKey ?: @""
    };
    [self postEndpoint:@"/verify.php" body:body completion:^(NSDictionary *json, NSInteger httpStatus, NSError *error) {
        if (error) {
            WFLicenseResult *cached = [self cachedResult];
            if (cached) {
                [self complete:completion result:cached];
            } else {
                WFLicenseResult *failure = [self resultWithSuccess:NO status:WFLicenseStatusNetworkError message:@"تعذر الاتصال بخادم الترخيص؛ سيُعاد التحقق لاحقاً" started:nil expires:nil plan:nil];
                // لا نغيّر حالة عميل مفعّل ولا نرسل إشعار إبطال عند انقطاع مؤقت.
                if ([self isRuntimeLicenseValid]) {
                    if (completion) completion([self preservedResultForTransientFailure:failure]);
                } else {
                    [self complete:completion result:failure];
                }
            }
            return;
        }
        NSDictionary *data = [json[@"data"] isKindOfClass:NSDictionary.class] ? json[@"data"] : @{};
        NSDictionary *license = [data[@"license"] isKindOfClass:NSDictionary.class] ? data[@"license"] : data;
        BOOL success = [json[@"success"] boolValue] && httpStatus >= 200 && httpStatus < 300;
        if (success) {
            NSString *token = [data[@"access_token"] isKindOfClass:NSString.class] ? data[@"access_token"] : nil;
            if (token.length && ![self saveToKeychain:token key:kTokenKey]) success = NO;
            if (success && ![self saveToKeychain:@"YES" key:kActivatedKey]) success = NO;
            if (success) [self saveCacheFromResponse:json code:code];
        } else {
            NSString *errorCode = [self stringValue:json[@"error_code"]].lowercaseString;
            // لا نحذف الكود المحلي عند فقد/تغير ربط الجهاز. بعد إعادة التثبيت قد
            // يتغير IDFV أو تفتقد بيانات Keychain؛ الاحتفاظ بالكود يتيح للمستخدم
            // طلب إعادة ضبط الارتباط من الإدارة ثم إعادة التفعيل من دون فقدانه.
            BOOL requiresClear = [@[@"invalid_license", @"license_deleted", @"license_cancelled", @"license_blocked", @"license_expired"] containsObject:errorCode];
            if (requiresClear) [self clearStoredLicense];
            if ([errorCode isEqualToString:@"device_mismatch"] || [errorCode isEqualToString:@"device_not_activated"]) {
#ifdef DEBUG
                WFLog(@"[WolFox][LICENSE] recovery_required code_retained=1 reason=%@", errorCode);
#endif
            }
        }
        WFLicenseResult *result = [self resultFromJSON:json fallbackSuccess:success license:license];
        BOOL transientHTTP = httpStatus == 408 || httpStatus == 425 || httpStatus == 429 || httpStatus >= 500;
        if ((!result.success && (transientHTTP || [self isTransientResult:result])) && [self isRuntimeLicenseValid]) {
            // أخطاء الشبكة وتحديد المعدل وأخطاء الخادم لا تفصل عميلاً مفعّلاً.
            if (completion) completion([self preservedResultForTransientFailure:result]);
        } else {
            [self complete:completion result:result];
        }
    }];
}

// FIX: timer at file scope so it survives the dispatch block and is properly invalidated on restart
static NSTimer *_WFHeartbeatTimer = nil;

+ (void)startHeartbeat {
    // Restartable — safe to call again after re-activation or clearStoredLicense.
    // Interval: 45s per License Hub v44.4 spec.
    dispatch_async(dispatch_get_main_queue(), ^{
        [_WFHeartbeatTimer invalidate];
        _WFHeartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:45.0
                                                            repeats:YES
                                                              block:^(__unused NSTimer *t) {
            [WFLicenseClient validateStrictlyWithCompletion:^(WFLicenseResult *result) {
                if (!result.success &&
                    result.status != WFLicenseStatusNetworkError &&
                    result.status != WFLicenseStatusRateLimited) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"WF_LICENSE_EXPIRED"
                                                                        object:result];
                }
            }];
        }];
    });
}

+ (void)stopHeartbeat {
    dispatch_async(dispatch_get_main_queue(), ^{
        [_WFHeartbeatTimer invalidate];
        _WFHeartbeatTimer = nil;
    });
}

+ (BOOL)hasStoredLicense {
    return [self storedCode].length > 0 && [self loadFromKeychain:kActivatedKey].length > 0 && [self loadFromKeychain:kTokenKey].length > 0;
}

+ (void)markAsActivated { [self saveToKeychain:@"YES" key:kActivatedKey]; }
+ (NSString *)storedCode { return [self loadFromKeychain:kCodeKey]; }

+ (WFLicenseResult *)storedLicenseInfo {
    NSString *cached = [self loadFromKeychain:kCacheKey];
    if (!cached.length) return nil;
    id object = [NSJSONSerialization JSONObjectWithData:[cached dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    if (![object isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *data = object;
    return [self resultWithSuccess:[data[@"success"] boolValue] status:WFLicenseStatusValid message:@"آخر معلومات اشتراك محفوظة" started:[self stringValue:data[@"started_at"]] expires:[self stringValue:data[@"expires_at"]] plan:[self stringValue:data[@"plan"]]];
}

+ (NSString *)deviceIdentifier {
    NSString *stored = [self loadFromKeychain:kDeviceKey];
    if (stored.length) return stored;
    NSString *identifier = [UIDevice currentDevice].identifierForVendor.UUIDString;
    if (!identifier.length) identifier = [NSUUID UUID].UUIDString;
    [self saveToKeychain:identifier key:kDeviceKey];
    return identifier;
}

+ (void)validateWithCompletion:(void(^)(BOOL, NSString *))completion {
    [self verifySavedLicenseWithCompletion:^(WFLicenseResult *result) {
        if (completion) completion(result.success, result.message ?: @"");
    }];
}

+ (void)postEndpoint:(NSString *)endpoint body:(NSDictionary *)body completion:(void(^)(NSDictionary *, NSInteger, NSError *))completion {
    NSURL *url = [NSURL URLWithString:[_baseURL stringByAppendingString:endpoint]];
#ifdef DEBUG
    WFLog(@"[WolFox][LICENSE] request_endpoint=%@", endpoint);
#endif
    if (!url) {
        completion(@{}, 0, [NSError errorWithDomain:@"WFLicenseClient" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"رابط خادم الترخيص غير صالح"}]);
        return;
    }
    if (![url.scheme.lowercaseString isEqualToString:@"https"]) {
        completion(@{}, 0, [NSError errorWithDomain:@"WFLicenseClient" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"يتطلب التحقق خادماً يعمل عبر HTTPS"}]);
        return;
    }
    NSError *encodeError = nil;
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&encodeError];
    if (!bodyData) { completion(@{}, 0, encodeError); return; }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15.0];
    request.HTTPMethod = @"POST";
    request.HTTPBody = bodyData;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:_projectKey ?: @"" forHTTPHeaderField:@"X-Project-Key"];
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    configuration.URLCredentialStorage = nil;
    configuration.HTTPCookieStorage = nil;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        NSError *parseError = nil;
        id object = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError] : nil;
        NSDictionary *json = [object isKindOfClass:NSDictionary.class] ? object : @{};
        NSError *finalError = error ?: (object && ![object isKindOfClass:NSDictionary.class] ? [NSError errorWithDomain:@"WFLicenseClient" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"استجابة الخادم غير صالحة"}] : parseError);
        dispatch_async(dispatch_get_main_queue(), ^{ completion(json, statusCode, finalError); });
    }] resume];
}

+ (WFLicenseResult *)resultFromJSON:(NSDictionary *)json fallbackSuccess:(BOOL)success license:(NSDictionary *)license {
    NSDictionary *data = [json[@"data"] isKindOfClass:NSDictionary.class] ? json[@"data"] : @{};
    NSString *statusText = [self stringValue:json[@"status"]].lowercaseString;
    NSString *errorCode = [self stringValue:json[@"error_code"]].lowercaseString;
    WFLicenseStatus status = success ? WFLicenseStatusValid : WFLicenseStatusInvalid;
    if ([statusText isEqualToString:@"expired"] || [errorCode isEqualToString:@"license_expired"]) status = WFLicenseStatusExpired;
    else if ([statusText isEqualToString:@"blocked"] || [errorCode isEqualToString:@"license_blocked"]) status = WFLicenseStatusBlocked;
    else if ([errorCode isEqualToString:@"device_mismatch"] || [errorCode isEqualToString:@"device_not_activated"]) status = WFLicenseStatusDeviceRecovery;
    else if ([errorCode isEqualToString:@"invalid_access_token"]) status = WFLicenseStatusInvalidToken;
    else if ([errorCode isEqualToString:@"project_disabled"] || [errorCode isEqualToString:@"invalid_project_key"]) status = WFLicenseStatusProjectDisabled;
    else if ([errorCode isEqualToString:@"update_required"]) status = WFLicenseStatusUpdateRequired;
    else if ([errorCode isEqualToString:@"rate_limited"] || [errorCode isEqualToString:@"too_many_requests"]) status = WFLicenseStatusRateLimited;
    NSString *message = [self stringValue:json[@"message"]] ?: (success ? @"تم تفعيل الترخيص" : @"فشل التحقق من الكود");
    WFLicenseResult *result = [self resultWithSuccess:success status:status message:message started:[self dateFrom:license keys:@[@"activated_at", @"activation_date", @"start_date"]] expires:[self dateFrom:license keys:@[@"expires_at", @"expiration_date", @"expiry_date"]] plan:[self stringValue:license[@"plan"]] ?: [self stringValue:license[@"plan_name"]]];
    result.errorCode = errorCode;
    result.updateURL = [self stringValue:data[@"update_url"]] ?: [self stringValue:json[@"update_url"]];
    result.minimumVersion = [self stringValue:data[@"minimum_version"]] ?: [self stringValue:data[@"min_version"]];
    result.forceUpdate = status == WFLicenseStatusUpdateRequired || [data[@"force_update"] boolValue];
    return result;
}

+ (NSString *)stringValue:(id)value {
    return [value isKindOfClass:NSString.class] && [value length] ? value : nil;
}

+ (NSString *)dateFrom:(NSDictionary *)dictionary keys:(NSArray<NSString *> *)keys {
    for (NSString *key in keys) {
        NSString *value = [self stringValue:dictionary[key]];
        if (value.length) return value;
    }
    return nil;
}

+ (NSDate *)dateFromServerString:(NSString *)value {
    if (!value.length) return nil;
    if (@available(iOS 10.0, *)) {
        NSISO8601DateFormatter *iso = [NSISO8601DateFormatter new];
        NSDate *date = [iso dateFromString:value];
        if (date) return date;
    }
    // أنشئ NSDateFormatter مرة واحدة خارج الـ loop — الإنشاء المتكرر مكلف
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    for (NSString *format in @[@"yyyy-MM-dd HH:mm:ss", @"yyyy-MM-dd'T'HH:mm:ssZ", @"yyyy-MM-dd"]) {
        formatter.dateFormat = format;
        NSDate *date = [formatter dateFromString:value];
        if (date) return date;
    }
    return nil;
}

+ (void)saveCacheFromResponse:(NSDictionary *)json code:(NSString *)code {
    NSDictionary *data = [json[@"data"] isKindOfClass:NSDictionary.class] ? json[@"data"] : @{};
    NSDictionary *license = [data[@"license"] isKindOfClass:NSDictionary.class] ? data[@"license"] : data;
    NSDictionary *cache = @{
        @"code": code ?: @"", @"success": @YES, @"cached_at": @(NSDate.date.timeIntervalSince1970),
        @"started_at": [self dateFrom:license keys:@[@"activated_at", @"activation_date", @"start_date"]] ?: @"",
        @"expires_at": [self dateFrom:license keys:@[@"expires_at", @"expiration_date", @"expiry_date"]] ?: @"",
        @"plan": [self stringValue:license[@"plan"]] ?: [self stringValue:license[@"plan_name"]] ?: @""
    };
    NSData *dataToStore = [NSJSONSerialization dataWithJSONObject:cache options:0 error:nil];
    if (dataToStore.length) [self saveToKeychain:[[NSString alloc] initWithData:dataToStore encoding:NSUTF8StringEncoding] key:kCacheKey];
}

+ (WFLicenseResult *)cachedResult {
    NSString *cached = [self loadFromKeychain:kCacheKey];
    id object = cached.length ? [NSJSONSerialization JSONObjectWithData:[cached dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] : nil;
    if (![object isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *data = object;
    NSTimeInterval age = NSDate.date.timeIntervalSince1970 - [data[@"cached_at"] doubleValue];
    if (age < 0 || age > kCacheTTL) return nil;
    NSString *expires = [self stringValue:data[@"expires_at"]];
    NSDate *expiresDate = [self dateFromServerString:expires];
    if (expiresDate && [expiresDate timeIntervalSinceNow] <= 0) return nil;
    WFLicenseResult *result = [self resultWithSuccess:YES status:WFLicenseStatusValid message:@"الترخيص نشط (تحقق مخزّن)" started:[self stringValue:data[@"started_at"]] expires:expires plan:[self stringValue:data[@"plan"]]];
    // حدِّث _runtimeLicenseValid فوراً حتى تعمل الهوكات قبل وصول رد الـ server
    // لا نطلق WF_LICENSE_STATE_CHANGED هنا؛ الإشعار يُطلق لاحقاً من complete:result:
    // بعد الرد الفعلي من الخادم. نكتفي بتحديث القيمة الذرية فقط.
    atomic_store(&_runtimeLicenseValid, result.success && result.status == WFLicenseStatusValid);
    @synchronized(self) { _lastResult = result; }
    return result;
}

+ (WFLicenseResult *)resultWithSuccess:(BOOL)success status:(WFLicenseStatus)status message:(NSString *)message started:(NSString *)started expires:(NSString *)expires plan:(NSString *)plan {
    WFLicenseResult *result = [WFLicenseResult new];
    result.success = success;
    result.status = status;
    result.message = message ?: @"";
    result.startedAt = started;
    result.expiresAt = expires;
    result.planName = plan;
    return result;
}

+ (BOOL)saveToKeychain:(NSString *)value key:(NSString *)key {
    if (!value.length || !key.length) return NO;
    NSDictionary *query = @{(id)kSecClass:(id)kSecClassGenericPassword, (id)kSecAttrService:kKeychainService, (id)kSecAttrAccount:key};
    NSData *valueData = [value dataUsingEncoding:NSUTF8StringEncoding];
    OSStatus updateStatus = SecItemUpdate((__bridge CFDictionaryRef)query,
                                         (__bridge CFDictionaryRef)@{(id)kSecValueData: valueData});
    if (updateStatus == errSecSuccess) return YES;
    if (updateStatus != errSecItemNotFound) return NO;

    // لا نحذف القيمة السابقة قبل تأكيد البديل؛ هذا يمنع فقدان الكود بسبب إخفاقٍ عابر.
    NSMutableDictionary *item = [query mutableCopy];
    item[(id)kSecValueData] = valueData;
    item[(id)kSecAttrAccessible] = (id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
    return SecItemAdd((__bridge CFDictionaryRef)item, NULL) == errSecSuccess;
}

+ (NSString *)loadFromKeychain:(NSString *)key {
    NSDictionary *query = @{(id)kSecClass:(id)kSecClassGenericPassword, (id)kSecAttrService:kKeychainService, (id)kSecAttrAccount:key, (id)kSecReturnData:(id)kCFBooleanTrue, (id)kSecMatchLimit:(id)kSecMatchLimitOne};
    CFTypeRef result = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &result) == errSecSuccess) return [[NSString alloc] initWithData:(__bridge_transfer NSData *)result encoding:NSUTF8StringEncoding];
    return nil;
}

+ (void)clearStoredLicense {
    atomic_store(&_runtimeLicenseValid, false);
    for (NSString *key in @[kCodeKey, kTokenKey, kCacheKey, kActivatedKey]) {
        NSDictionary *query = @{(id)kSecClass:(id)kSecClassGenericPassword, (id)kSecAttrService:kKeychainService, (id)kSecAttrAccount:key};
        SecItemDelete((__bridge CFDictionaryRef)query);
    }
    // أوقف الـ heartbeat فوراً عند مسح الترخيص
    [self stopHeartbeat];
}

@end
