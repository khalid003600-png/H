#import "WFRedactedLogger.h"
#import "WFLicenseClient.h"
#import "WFLicenseConfig.h"
#import <Security/Security.h>
#import <UIKit/UIKit.h>
#import <stdatomic.h>

static NSString * const kKeychainService = @"fun.p3nd.wolfox.license";
static NSString * const kCodeKey = @"wf_license_code";
static NSString * const kTokenKey = @"wf_access_token";
static NSString * const kCacheKey = @"wf_license_cache";
static NSString * const kActivatedKey = @"wf_is_activated";
static NSString * const kDeviceKey = @"wf_device_id";
static NSString * const kSuspendedKey = @"wf_license_suspended_reason";
static NSString *_baseURL = WF_PANEL_BASE_URL;
static NSString *_projectKey = WF_PROJECT_KEY;
static atomic_bool _runtimeLicenseValid = false;
static WFLicenseResult *_lastResult = nil;
static NSURLSession *_licenseSession = nil;
static NSTimer *_WFHeartbeatTimer = nil;
static const NSUInteger kMaximumRequestAttempts = 2;

@interface WFLicenseClient ()
+ (void)setRuntimeResult:(WFLicenseResult *)result;
+ (void)complete:(void(^)(WFLicenseResult *))completion result:(WFLicenseResult *)result;
+ (void)postEndpoint:(NSString *)endpoint body:(NSDictionary *)body completion:(void(^)(NSDictionary *, NSInteger, NSError *))completion;
+ (void)postEndpoint:(NSString *)endpoint body:(NSDictionary *)body attempt:(NSUInteger)attempt completion:(void(^)(NSDictionary *, NSInteger, NSError *))completion;
+ (NSURLSession *)licenseSession;
+ (WFLicenseResult *)resultFromJSON:(NSDictionary *)json fallbackSuccess:(BOOL)success license:(NSDictionary *)license;
+ (WFLicenseResult *)resultWithSuccess:(BOOL)success status:(WFLicenseStatus)status message:(NSString *)message started:(NSString *)started expires:(NSString *)expires plan:(NSString *)plan;
+ (NSDictionary *)responseData:(NSDictionary *)json;
+ (NSDictionary *)licenseFromJSON:(NSDictionary *)json;
+ (NSString *)responseStatus:(NSDictionary *)json;
+ (NSString *)responseErrorCode:(NSDictionary *)json;
+ (NSString *)responseMessage:(NSDictionary *)json;
+ (NSString *)responseToken:(NSDictionary *)json;
+ (BOOL)isSuccessfulJSON:(NSDictionary *)json httpStatus:(NSInteger)httpStatus;
+ (BOOL)isTransientHTTPStatus:(NSInteger)httpStatus;
+ (BOOL)isExplicitExpirationResult:(WFLicenseResult *)result;
+ (BOOL)isExplicitSuspensionResult:(WFLicenseResult *)result json:(NSDictionary *)json;
+ (NSString *)stringValue:(id)value;
+ (NSString *)dateFrom:(NSDictionary *)dictionary keys:(NSArray<NSString *> *)keys;
+ (NSDate *)dateFromServerString:(NSString *)value;
+ (void)saveCacheFromResponse:(NSDictionary *)json code:(NSString *)code;
+ (WFLicenseResult *)cachedResult;
+ (BOOL)isTransientResult:(WFLicenseResult *)result;
+ (WFLicenseResult *)preservedResultForTransientFailure:(WFLicenseResult *)failure;
+ (void)markSuspendedKeepingCode:(NSString *)reason;
+ (void)clearSuspendedState;
+ (BOOL)saveToKeychain:(NSString *)value key:(NSString *)key;
+ (NSString *)loadFromKeychain:(NSString *)key;
+ (void)deleteKeychainKey:(NSString *)key;
@end

@implementation WFLicenseResult
@end

@implementation WFLicenseClient

+ (NSString *)baseURL { return _baseURL; }
+ (void)setBaseURL:(NSString *)value {
    NSString *trimmed = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length) _baseURL = [trimmed copy];
}
+ (NSString *)projectKey { return _projectKey; }
+ (void)setProjectKey:(NSString *)value {
    NSString *trimmed = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length) _projectKey = [trimmed copy];
}
+ (BOOL)isRuntimeLicenseValid { return atomic_load(&_runtimeLicenseValid); }
+ (WFLicenseResult *)lastLicenseResult { @synchronized(self) { return _lastResult; } }

+ (void)setRuntimeResult:(WFLicenseResult *)result {
    if (!result) return;
    atomic_store(&_runtimeLicenseValid, result.success && result.status == WFLicenseStatusValid);
    @synchronized(self) { _lastResult = result; }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WF_LICENSE_STATE_CHANGED" object:result];
}

+ (void)complete:(void(^)(WFLicenseResult *))completion result:(WFLicenseResult *)result {
    void (^deliver)(void) = ^{
        [self setRuntimeResult:result];
        if (completion) completion(result);
    };
    if (NSThread.isMainThread) deliver();
    else dispatch_async(dispatch_get_main_queue(), deliver);
}

+ (BOOL)isTransientResult:(WFLicenseResult *)result {
    if (!result) return NO;
    return result.status == WFLicenseStatusNetworkError ||
           result.status == WFLicenseStatusRateLimited;
}

+ (WFLicenseResult *)preservedResultForTransientFailure:(WFLicenseResult *)failure {
    WFLicenseResult *last = [self lastLicenseResult];
    if (!last.success) last = [self storedLicenseInfo];
    WFLicenseResult *preserved = [self resultWithSuccess:YES
                                                   status:WFLicenseStatusValid
                                                  message:@"الترخيص ما زال نشطاً؛ تعذر تحديثه من الخادم وسيُعاد الاتصال تلقائياً"
                                                 started:last.startedAt
                                                 expires:last.expiresAt
                                                    plan:last.planName];
    preserved.errorCode = failure.errorCode;
    preserved.updateURL = last.updateURL;
    preserved.minimumVersion = last.minimumVersion;
    preserved.forceUpdate = NO;
    return preserved;
}

+ (NSDictionary *)requestBodyForCode:(NSString *)code token:(NSString *)token {
    NSString *deviceID = [self deviceIdentifier];
    NSString *targetBundleID = NSBundle.mainBundle.bundleIdentifier ?: @"";
    NSString *appName = NSBundle.mainBundle.infoDictionary[@"CFBundleDisplayName"]
                      ?: NSBundle.mainBundle.infoDictionary[@"CFBundleName"]
                      ?: @"";
    NSMutableDictionary *body = [@{
        // الحقول المعتمدة في لوحة WolFox الحالية.
        @"code": code ?: @"",
        @"device_id": deviceID,
        @"bundle_id": WF_PROJECT_BUNDLE_ID,
        @"app_version": WF_APP_VERSION,
        // أسماء توافقية للإصدارات السابقة من API.
        @"license_code": code ?: @"",
        @"device_uuid": deviceID,
        @"project_key": _projectKey ?: @"",
        @"target_bundle_id": targetBundleID,
        @"device_name": UIDevice.currentDevice.name ?: @"iOS Device",
        @"app_name": appName
    } mutableCopy];
    if (token.length) body[@"access_token"] = token;
    return body;
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

    NSDictionary *body = [self requestBodyForCode:trimmed token:nil];
    [self postEndpoint:@"/activate.php" body:body completion:^(NSDictionary *json, NSInteger httpStatus, NSError *error) {
        BOOL transientHTTP = [self isTransientHTTPStatus:httpStatus];
        if (error || transientHTTP) {
            WFLicenseStatus status = httpStatus == 429 ? WFLicenseStatusRateLimited : WFLicenseStatusNetworkError;
            NSString *message = httpStatus == 429
                ? @"الخادم مشغول مؤقتاً؛ سيُعاد المحاولة تلقائياً"
                : [NSString stringWithFormat:@"تعذر الوصول إلى خادم التفعيل: %@", error.localizedDescription ?: @"استجابة مؤقتة من الخادم"];
            WFLicenseResult *failure = [self resultWithSuccess:NO status:status message:message started:nil expires:nil plan:nil];
            WFLicenseResult *cached = [self cachedResult];
            if (cached && !cached.success) {
                [self complete:completion result:cached];
            } else if (cached.success || [self isRuntimeLicenseValid]) {
                [self complete:completion result:[self preservedResultForTransientFailure:failure]];
            } else {
                [self complete:completion result:failure];
            }
            return;
        }

        NSDictionary *license = [self licenseFromJSON:json];
        BOOL success = [self isSuccessfulJSON:json httpStatus:httpStatus];
        if (success) {
            NSString *token = [self responseToken:json];
            BOOL stored = [self saveToKeychain:trimmed key:kCodeKey] &&
                          [self saveToKeychain:@"YES" key:kActivatedKey];
            if (stored && token.length) stored = [self saveToKeychain:token key:kTokenKey];
            if (stored && !token.length) [self deleteKeychainKey:kTokenKey];
            if (stored) {
                [self clearSuspendedState];
                [self saveCacheFromResponse:json code:trimmed];
            } else {
                success = NO;
                json = @{@"success": @NO,
                         @"error_code": @"secure_storage_failed",
                         @"message": @"تعذر حفظ بيانات التفعيل بأمان على الجهاز"};
                license = @{};
            }
        }

        WFLicenseResult *result = [self resultFromJSON:json fallbackSuccess:success license:license];
        if (!result.success) {
            NSString *storedCode = [self storedCode];
            BOOL sameStoredCode = storedCode.length && [storedCode caseInsensitiveCompare:trimmed] == NSOrderedSame;
            if (sameStoredCode && [self isExplicitExpirationResult:result]) {
                // انتهاء الاشتراك يعطّل التشغيل، لكنه لا يحذف كود العميل المحفوظ.
                [self markSuspendedKeepingCode:result.errorCode ?: @"license_expired"];
            } else if (sameStoredCode && [self isExplicitSuspensionResult:result json:json]) {
                [self markSuspendedKeepingCode:result.errorCode ?: [self responseStatus:json] ?: @"suspended"];
            }
        }
        [self complete:completion result:result];
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

    NSString *token = [self loadFromKeychain:kTokenKey];
    NSDictionary *body = [self requestBodyForCode:code token:token];
    [self postEndpoint:@"/verify.php" body:body completion:^(NSDictionary *json, NSInteger httpStatus, NSError *error) {
        BOOL transientHTTP = [self isTransientHTTPStatus:httpStatus];
        if (error || transientHTTP) {
            WFLicenseResult *cached = [self cachedResult];
            if (cached) {
                [self complete:completion result:cached];
            } else if ([self isRuntimeLicenseValid]) {
                WFLicenseResult *failure = [self resultWithSuccess:NO
                                                             status:(httpStatus == 429 ? WFLicenseStatusRateLimited : WFLicenseStatusNetworkError)
                                                            message:@"تعذر الاتصال بخادم الترخيص؛ سيُعاد التحقق تلقائياً"
                                                           started:nil expires:nil plan:nil];
                [self complete:completion result:[self preservedResultForTransientFailure:failure]];
            } else {
                WFLicenseStatus status = httpStatus == 429 ? WFLicenseStatusRateLimited : WFLicenseStatusNetworkError;
                [self complete:completion result:[self resultWithSuccess:NO status:status message:@"تعذر الاتصال بخادم الترخيص؛ سيُعاد التحقق تلقائياً" started:nil expires:nil plan:nil]];
            }
            return;
        }

        NSDictionary *license = [self licenseFromJSON:json];
        BOOL success = [self isSuccessfulJSON:json httpStatus:httpStatus];
        if (success) {
            NSString *newToken = [self responseToken:json];
            BOOL stored = [self saveToKeychain:@"YES" key:kActivatedKey];
            if (stored && newToken.length) stored = [self saveToKeychain:newToken key:kTokenKey];
            if (!stored) {
                json = @{@"success": @NO,
                         @"error_code": @"secure_storage_failed",
                         @"message": @"تعذر تحديث بيانات الترخيص الآمنة"};
                license = @{};
                success = NO;
            } else {
                [self clearSuspendedState];
                [self saveCacheFromResponse:json code:code];
            }
        }

        WFLicenseResult *result = [self resultFromJSON:json fallbackSuccess:success license:license];
        if (result.success) {
            [self complete:completion result:result];
            return;
        }

        if (result.status == WFLicenseStatusInvalidToken) {
            // قد تنتهي جلسة الخادم بينما يبقى الكود صالحاً. احذف الرمز فقط ثم
            // أعد ربط الكود نفسه تلقائياً من دون إجبار المستخدم على إدخاله.
            [self deleteKeychainKey:kTokenKey];
            [self activateCode:code completion:completion];
            return;
        }

        if ([self isExplicitExpirationResult:result]) {
            // نحظر التشغيل عند انتهاء المدة مع الاحتفاظ بالكود لإعادة التجديد
            // أو المعالجة من لوحة الإدارة من دون إجبار العميل على إدخاله مجدداً.
            [self markSuspendedKeepingCode:result.errorCode ?: @"license_expired"];
            [self complete:completion result:result];
            return;
        }

        if ([self isExplicitSuspensionResult:result json:json]) {
            // الحظر/الإلغاء/اختلاف الجهاز يوقف الأداء، لكنه لا يحذف الكود.
            [self markSuspendedKeepingCode:result.errorCode ?: [self responseStatus:json] ?: @"suspended"];
#ifdef DEBUG
            WFLog(@"[WolFox][LICENSE] recovery_required code_retained=1 reason=%@", result.errorCode ?: @"suspended");
#endif
            [self complete:completion result:result];
            return;
        }

        // أي استجابة غير معروفة أو غير مكتملة لا تفصل عميلاً كان مفعّلاً.
        // نحتفظ بالحالة حتى يصل رد صريح من لوحة الإدارة.
        WFLicenseResult *cached = [self cachedResult];
        if (cached.success || [self isRuntimeLicenseValid]) {
            [self complete:completion result:[self preservedResultForTransientFailure:result]];
        } else {
            [self complete:completion result:result];
        }
    }];
}

+ (void)startHeartbeat {
    dispatch_async(dispatch_get_main_queue(), ^{
        [_WFHeartbeatTimer invalidate];
        _WFHeartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:45.0
                                                            repeats:YES
                                                              block:^(__unused NSTimer *timer) {
            [WFLicenseClient validateStrictlyWithCompletion:^(WFLicenseResult *result) {
                // لا نرسل إشعار انتهاء أو نغلق الواجهة بسبب الشبكة أو رد غامض.
                // انتهاء مدة الترخيص المؤكد فقط يستخدم إشعار الانتهاء.
                if (!result.success && result.status == WFLicenseStatusExpired) {
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
    // access_token اختياري لأن بعض إصدارات لوحة الإدارة تعتمد الكود والجهاز فقط.
    return [self storedCode].length > 0 && [self loadFromKeychain:kActivatedKey].length > 0;
}

+ (void)markAsActivated {
    if ([self saveToKeychain:@"YES" key:kActivatedKey]) [self clearSuspendedState];
}
+ (NSString *)storedCode { return [self loadFromKeychain:kCodeKey]; }

+ (WFLicenseResult *)storedLicenseInfo {
    NSString *cached = [self loadFromKeychain:kCacheKey];
    if (!cached.length) return nil;
    id object = [NSJSONSerialization JSONObjectWithData:[cached dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    if (![object isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *data = object;
    NSString *expires = [self stringValue:data[@"expires_at"]];
    NSDate *expiresDate = [self dateFromServerString:expires];
    BOOL expired = expiresDate && [expiresDate timeIntervalSinceNow] <= 0;
    BOOL suspended = [self loadFromKeychain:kSuspendedKey].length > 0;
    WFLicenseStatus status = expired ? WFLicenseStatusExpired : (suspended ? WFLicenseStatusBlocked : WFLicenseStatusValid);
    NSString *message = expired ? @"انتهت مدة الترخيص" : (suspended ? @"الترخيص موقوف مؤقتاً من الإدارة" : @"آخر معلومات اشتراك محفوظة");
    return [self resultWithSuccess:(!expired && !suspended)
                            status:status
                           message:message
                          started:[self stringValue:data[@"started_at"]]
                          expires:expires
                             plan:[self stringValue:data[@"plan"]]];
}

+ (NSString *)deviceIdentifier {
    NSString *stored = [self loadFromKeychain:kDeviceKey];
    if (stored.length) return stored;
    NSString *identifier = UIDevice.currentDevice.identifierForVendor.UUIDString;
    if (!identifier.length) identifier = NSUUID.UUID.UUIDString;
    [self saveToKeychain:identifier key:kDeviceKey];
    return identifier;
}

+ (void)validateWithCompletion:(void(^)(BOOL, NSString *))completion {
    [self verifySavedLicenseWithCompletion:^(WFLicenseResult *result) {
        if (completion) completion(result.success, result.message ?: @"");
    }];
}

+ (NSURLSession *)licenseSession {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        configuration.URLCredentialStorage = nil;
        configuration.HTTPCookieStorage = nil;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        configuration.timeoutIntervalForRequest = 12.0;
        configuration.timeoutIntervalForResource = 25.0;
        configuration.HTTPMaximumConnectionsPerHost = 2;
        if (@available(iOS 11.0, *)) configuration.waitsForConnectivity = YES;
        _licenseSession = [NSURLSession sessionWithConfiguration:configuration];
    });
    return _licenseSession;
}

+ (void)postEndpoint:(NSString *)endpoint body:(NSDictionary *)body completion:(void(^)(NSDictionary *, NSInteger, NSError *))completion {
    [self postEndpoint:endpoint body:body attempt:0 completion:completion];
}

+ (void)postEndpoint:(NSString *)endpoint body:(NSDictionary *)body attempt:(NSUInteger)attempt completion:(void(^)(NSDictionary *, NSInteger, NSError *))completion {
    NSString *base = [_baseURL stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    while ([base hasSuffix:@"/"]) base = [base substringToIndex:base.length - 1];
    NSString *path = [endpoint hasPrefix:@"/"] ? endpoint : [@"/" stringByAppendingString:endpoint ?: @""];
    NSURLComponents *components = [NSURLComponents componentsWithString:[base stringByAppendingString:path]];
    NSURL *url = components.URL;
#ifdef DEBUG
    WFLog(@"[WolFox][LICENSE] request_endpoint=%@ attempt=%lu", endpoint, (unsigned long)attempt + 1);
#endif
    void (^finish)(NSDictionary *, NSInteger, NSError *) = ^(NSDictionary *json, NSInteger status, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(json ?: @{}, status, error); });
    };
    if (!url || !components.host.length) {
        finish(@{}, 0, [NSError errorWithDomain:@"WFLicenseClient" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"رابط خادم الترخيص غير صالح"}]);
        return;
    }
    if (![components.scheme.lowercaseString isEqualToString:@"https"]) {
        finish(@{}, 0, [NSError errorWithDomain:@"WFLicenseClient" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"يتطلب التحقق خادماً يعمل عبر HTTPS"}]);
        return;
    }

    NSError *encodeError = nil;
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:body ?: @{} options:0 error:&encodeError];
    if (!bodyData) {
        finish(@{}, 0, encodeError);
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:12.0];
    request.HTTPMethod = @"POST";
    request.HTTPBody = bodyData;
    [request setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:_projectKey ?: @"" forHTTPHeaderField:@"X-Project-Key"];
    [request setValue:[NSString stringWithFormat:@"WolFox/%@ (iOS)", WF_APP_VERSION] forHTTPHeaderField:@"User-Agent"];
    NSString *token = [self stringValue:body[@"access_token"]];
    if (token.length) {
        [request setValue:[@"Bearer " stringByAppendingString:token] forHTTPHeaderField:@"Authorization"];
        [request setValue:token forHTTPHeaderField:@"X-Access-Token"];
    }

    [[[self licenseSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResponse = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        NSInteger statusCode = httpResponse.statusCode;
        BOOL shouldRetry = error || [self isTransientHTTPStatus:statusCode];
        if (shouldRetry && attempt + 1 < kMaximumRequestAttempts) {
            NSTimeInterval delay = 0.55;
            NSString *retryAfter = [self stringValue:httpResponse.allHeaderFields[@"Retry-After"]];
            if (retryAfter.doubleValue > 0) delay = MIN(retryAfter.doubleValue, 2.0);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                           dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                [self postEndpoint:endpoint body:body attempt:attempt + 1 completion:completion];
            });
            return;
        }

        NSError *parseError = nil;
        id object = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError] : nil;
        NSDictionary *json = [object isKindOfClass:NSDictionary.class] ? object : @{};
        NSError *finalError = error;
        if (!finalError && data.length && ![object isKindOfClass:NSDictionary.class]) {
            finalError = [NSError errorWithDomain:@"WFLicenseClient"
                                             code:-2
                                         userInfo:@{NSLocalizedDescriptionKey: @"استجابة خادم الترخيص غير صالحة",
                                                    NSUnderlyingErrorKey: parseError ?: [NSNull null]}];
        }
        finish(json, statusCode, finalError);
    }] resume];
}

+ (NSDictionary *)responseData:(NSDictionary *)json {
    return [json[@"data"] isKindOfClass:NSDictionary.class] ? json[@"data"] : @{};
}

+ (NSDictionary *)licenseFromJSON:(NSDictionary *)json {
    NSDictionary *data = [self responseData:json];
    if ([data[@"license"] isKindOfClass:NSDictionary.class]) return data[@"license"];
    if ([json[@"license"] isKindOfClass:NSDictionary.class]) return json[@"license"];
    return data;
}

+ (NSString *)responseStatus:(NSDictionary *)json {
    NSDictionary *data = [self responseData:json];
    NSDictionary *license = [self licenseFromJSON:json];
    for (NSDictionary *container in @[json ?: @{}, data, license]) {
        for (NSString *key in @[@"status", @"license_status", @"state"]) {
            NSString *value = [self stringValue:container[key]].lowercaseString;
            if (value.length) return value;
        }
    }
    return nil;
}

+ (NSString *)responseErrorCode:(NSDictionary *)json {
    NSDictionary *data = [self responseData:json];
    for (NSDictionary *container in @[json ?: @{}, data]) {
        for (NSString *key in @[@"error_code", @"error", @"reason"]) {
            NSString *value = [self stringValue:container[key]].lowercaseString;
            if (value.length) return value;
        }
    }
    return nil;
}

+ (NSString *)responseMessage:(NSDictionary *)json {
    NSDictionary *data = [self responseData:json];
    return [self stringValue:json[@"message"]] ?: [self stringValue:data[@"message"]];
}

+ (NSString *)responseToken:(NSDictionary *)json {
    NSDictionary *data = [self responseData:json];
    for (NSDictionary *container in @[data, json ?: @{}]) {
        for (NSString *key in @[@"access_token", @"session_token", @"token"]) {
            NSString *value = [self stringValue:container[key]];
            if (value.length) return value;
        }
    }
    return nil;
}

+ (BOOL)isSuccessfulJSON:(NSDictionary *)json httpStatus:(NSInteger)httpStatus {
    if (httpStatus < 200 || httpStatus >= 300) return NO;
    NSDictionary *data = [self responseData:json];
    for (id flag in @[json[@"success"] ?: NSNull.null,
                      data[@"success"] ?: NSNull.null,
                      json[@"valid"] ?: NSNull.null,
                      data[@"valid"] ?: NSNull.null]) {
        if ([flag isKindOfClass:NSNumber.class] && [flag boolValue]) return YES;
    }
    NSString *status = [self responseStatus:json];
    return status.length && [@[@"active", @"success", @"valid", @"activated", @"ok"] containsObject:status];
}

+ (BOOL)isTransientHTTPStatus:(NSInteger)httpStatus {
    return httpStatus == 408 || httpStatus == 425 || httpStatus == 429 ||
           (httpStatus >= 500 && httpStatus <= 599);
}

+ (BOOL)isExplicitExpirationResult:(WFLicenseResult *)result {
    if (result.status == WFLicenseStatusExpired) return YES;
    NSString *errorCode = result.errorCode.lowercaseString;
    return errorCode.length && [@[@"expired", @"license_expired", @"subscription_expired"] containsObject:errorCode];
}

+ (BOOL)isExplicitSuspensionResult:(WFLicenseResult *)result json:(NSDictionary *)json {
    if (result.status == WFLicenseStatusBlocked ||
        result.status == WFLicenseStatusProjectDisabled ||
        result.status == WFLicenseStatusDeviceRecovery) return YES;
    NSString *errorCode = result.errorCode.lowercaseString;
    NSString *status = [self responseStatus:json];
    NSArray<NSString *> *terminalCodes = @[
        @"invalid_license", @"license_deleted", @"license_cancelled", @"license_canceled",
        @"license_blocked", @"license_revoked", @"license_banned", @"license_disabled",
        @"device_mismatch", @"device_not_activated", @"project_disabled", @"invalid_project_key"
    ];
    NSArray<NSString *> *terminalStates = @[@"blocked", @"revoked", @"banned", @"disabled", @"cancelled", @"canceled", @"invalid"];
    return (errorCode.length && [terminalCodes containsObject:errorCode]) ||
           (status.length && [terminalStates containsObject:status]);
}

+ (WFLicenseResult *)resultFromJSON:(NSDictionary *)json fallbackSuccess:(BOOL)success license:(NSDictionary *)license {
    NSDictionary *data = [self responseData:json];
    NSString *statusText = [self responseStatus:json];
    NSString *errorCode = [self responseErrorCode:json];
    WFLicenseStatus status = success ? WFLicenseStatusValid : WFLicenseStatusInvalid;
    if ([statusText isEqualToString:@"expired"] || (errorCode.length && [@[@"expired", @"license_expired", @"subscription_expired"] containsObject:errorCode])) {
        status = WFLicenseStatusExpired;
    } else if ((statusText.length && [@[@"blocked", @"revoked", @"banned", @"disabled", @"cancelled", @"canceled"] containsObject:statusText]) ||
               (errorCode.length && [@[@"license_blocked", @"license_revoked", @"license_banned", @"license_disabled", @"license_deleted", @"license_cancelled", @"license_canceled"] containsObject:errorCode])) {
        status = WFLicenseStatusBlocked;
    } else if (errorCode.length && [@[@"device_mismatch", @"device_not_activated"] containsObject:errorCode]) {
        status = WFLicenseStatusDeviceRecovery;
    } else if (errorCode.length && [@[@"invalid_access_token", @"token_expired", @"unauthorized_token"] containsObject:errorCode]) {
        status = WFLicenseStatusInvalidToken;
    } else if (errorCode.length && [@[@"project_disabled", @"invalid_project_key"] containsObject:errorCode]) {
        status = WFLicenseStatusProjectDisabled;
    } else if ([errorCode isEqualToString:@"update_required"]) {
        status = WFLicenseStatusUpdateRequired;
    } else if (errorCode.length && [@[@"rate_limited", @"too_many_requests"] containsObject:errorCode]) {
        status = WFLicenseStatusRateLimited;
    }

    NSString *message = [self responseMessage:json] ?: (success ? @"تم تفعيل الترخيص" : @"فشل التحقق من الكود");
    WFLicenseResult *result = [self resultWithSuccess:success
                                               status:status
                                              message:message
                                             started:[self dateFrom:license keys:@[@"activated_at", @"activation_date", @"start_date", @"started_at", @"valid_from"]]
                                             expires:[self dateFrom:license keys:@[@"expires_at", @"expiration_date", @"expiry_date", @"expires_on", @"valid_until"]]
                                                plan:[self stringValue:license[@"plan"]] ?: [self stringValue:license[@"plan_name"]]];
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
    NSDictionary *license = [self licenseFromJSON:json];
    NSDictionary *cache = @{
        @"code": code ?: @"",
        @"success": @YES,
        @"cached_at": @(NSDate.date.timeIntervalSince1970),
        @"started_at": [self dateFrom:license keys:@[@"activated_at", @"activation_date", @"start_date", @"started_at", @"valid_from"]] ?: @"",
        @"expires_at": [self dateFrom:license keys:@[@"expires_at", @"expiration_date", @"expiry_date", @"expires_on", @"valid_until"]] ?: @"",
        @"plan": [self stringValue:license[@"plan"]] ?: [self stringValue:license[@"plan_name"]] ?: @""
    };
    NSData *dataToStore = [NSJSONSerialization dataWithJSONObject:cache options:0 error:nil];
    if (dataToStore.length) {
        NSString *string = [[NSString alloc] initWithData:dataToStore encoding:NSUTF8StringEncoding];
        [self saveToKeychain:string key:kCacheKey];
    }
}

+ (WFLicenseResult *)cachedResult {
    if ([self loadFromKeychain:kSuspendedKey].length) return nil;
    if (![self hasStoredLicense]) return nil;
    NSString *cached = [self loadFromKeychain:kCacheKey];
    id object = cached.length ? [NSJSONSerialization JSONObjectWithData:[cached dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] : nil;
    if (![object isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *data = object;
    NSString *cachedCode = [self stringValue:data[@"code"]];
    if (cachedCode.length && [cachedCode caseInsensitiveCompare:[self storedCode]] != NSOrderedSame) return nil;

    NSString *expires = [self stringValue:data[@"expires_at"]];
    NSDate *expiresDate = [self dateFromServerString:expires];
    if (expiresDate && [expiresDate timeIntervalSinceNow] <= 0) {
        WFLicenseResult *expired = [self resultWithSuccess:NO
                                                     status:WFLicenseStatusExpired
                                                    message:@"انتهت مدة الترخيص"
                                                   started:[self stringValue:data[@"started_at"]]
                                                   expires:expires
                                                      plan:[self stringValue:data[@"plan"]]];
        expired.errorCode = @"license_expired";
        // الكاش المنتهي يوقف الترخيص فقط؛ يبقى الكود محفوظاً للاستعادة أو التجديد.
        [self markSuspendedKeepingCode:expired.errorCode];
        return expired;
    }

    // لا نستخدم مهلة 24 ساعة مصطنعة: ما دام تاريخ الانتهاء لم يصل، يبقى
    // آخر تحقق ناجح صالحاً أثناء انقطاع الشبكة. إن لم ترسل اللوحة تاريخاً
    // فهذا ترخيص بلا مدة محددة حتى يصل رد إداري صريح.
    WFLicenseResult *result = [self resultWithSuccess:YES
                                                status:WFLicenseStatusValid
                                               message:@"الترخيص نشط (آخر تحقق محفوظ)"
                                              started:[self stringValue:data[@"started_at"]]
                                              expires:expires
                                                 plan:[self stringValue:data[@"plan"]]];
    atomic_store(&_runtimeLicenseValid, true);
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

+ (void)markSuspendedKeepingCode:(NSString *)reason {
    atomic_store(&_runtimeLicenseValid, false);
    [self saveToKeychain:(reason.length ? reason : @"suspended") key:kSuspendedKey];
}

+ (void)clearSuspendedState {
    [self deleteKeychainKey:kSuspendedKey];
}

+ (BOOL)saveToKeychain:(NSString *)value key:(NSString *)key {
    if (!value.length || !key.length) return NO;
    NSDictionary *query = @{
        (id)kSecClass: (id)kSecClassGenericPassword,
        (id)kSecAttrService: kKeychainService,
        (id)kSecAttrAccount: key
    };
    NSData *valueData = [value dataUsingEncoding:NSUTF8StringEncoding];
    OSStatus updateStatus = SecItemUpdate((__bridge CFDictionaryRef)query,
                                          (__bridge CFDictionaryRef)@{(id)kSecValueData: valueData});
    if (updateStatus == errSecSuccess) return YES;
    if (updateStatus != errSecItemNotFound) return NO;

    // لا نحذف القيمة السابقة قبل تأكيد البديل؛ هذا يمنع فقدان الكود بسبب إخفاق عابر.
    NSMutableDictionary *item = [query mutableCopy];
    item[(id)kSecValueData] = valueData;
    item[(id)kSecAttrAccessible] = (id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
    return SecItemAdd((__bridge CFDictionaryRef)item, NULL) == errSecSuccess;
}

+ (NSString *)loadFromKeychain:(NSString *)key {
    NSDictionary *query = @{
        (id)kSecClass: (id)kSecClassGenericPassword,
        (id)kSecAttrService: kKeychainService,
        (id)kSecAttrAccount: key,
        (id)kSecReturnData: (id)kCFBooleanTrue,
        (id)kSecMatchLimit: (id)kSecMatchLimitOne
    };
    CFTypeRef result = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &result) == errSecSuccess) {
        return [[NSString alloc] initWithData:(__bridge_transfer NSData *)result encoding:NSUTF8StringEncoding];
    }
    return nil;
}

+ (void)deleteKeychainKey:(NSString *)key {
    if (!key.length) return;
    NSDictionary *query = @{
        (id)kSecClass: (id)kSecClassGenericPassword,
        (id)kSecAttrService: kKeychainService,
        (id)kSecAttrAccount: key
    };
    SecItemDelete((__bridge CFDictionaryRef)query);
}

+ (void)clearStoredLicense {
    atomic_store(&_runtimeLicenseValid, false);
    for (NSString *key in @[kCodeKey, kTokenKey, kCacheKey, kActivatedKey, kSuspendedKey]) {
        [self deleteKeychainKey:key];
    }
    [self stopHeartbeat];
}

@end
