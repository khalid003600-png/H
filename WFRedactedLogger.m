#import "WFRedactedLogger.h"
#import <os/log.h>

static os_log_t WFLogger(void) {
    static os_log_t logger;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logger = os_log_create("fun.p3nd.wolfox", "secure-logging");
    });
    return logger;
}

static BOOL WFIsSensitiveKey(NSString *key) {
    NSString *normalized = key.lowercaseString;
    NSArray<NSString *> *sensitiveKeys = @[
        @"license_code", @"license-code", @"access_token", @"refresh_token",
        @"authorization", @"x-project-key", @"project_key", @"password",
        @"secret", @"cookie", @"device_uuid", @"device_id"
    ];
    for (NSString *candidate in sensitiveKeys) {
        if ([normalized containsString:candidate]) return YES;
    }
    return [normalized hasSuffix:@"token"];
}

NSString *WFRedactString(NSString *input) {
    if (!input.length) return input ?: @"";
    NSString *result = [input copy];
    NSArray<NSArray<NSString *> *> *rules = @[
        @[ @"(?i)(license[_-]?code|access[_-]?token|refresh[_-]?token|authorization|x-project-key|project-key|password|secret)\\s*[\\\"']?\\s*[:=]\\s*[\\\"']?[^\\s,;\\\"'}]+", @"$1=[REDACTED]" ],
        @[ @"(?i)Bearer\\s+[A-Za-z0-9._~+\\/=-]+", @"Bearer [REDACTED]" ],
        @[ @"\\b[A-Za-z0-9_-]{20,}\\.[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{10,}\\b", @"[JWT_REDACTED]" ]
    ];
    for (NSArray *rule in rules) {
        NSError *error = nil;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:rule[0] options:0 error:&error];
        if (error || !regex) continue;
        result = [regex stringByReplacingMatchesInString:result options:0 range:NSMakeRange(0, result.length) withTemplate:rule[1]];
    }
    return result;
}

static id WFSanitizeObject(id object, NSString *key) {
    if (!object || object == [NSNull null]) return [NSNull null];
    if (key.length && WFIsSensitiveKey(key)) return @"[REDACTED]";
    if ([object isKindOfClass:NSString.class]) return WFRedactString((NSString *)object);
    if ([object isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *safe = [NSMutableDictionary dictionary];
        [(NSDictionary *)object enumerateKeysAndObjectsUsingBlock:^(id childKey, id childValue, BOOL *stop) {
            NSString *stringKey = [childKey isKindOfClass:NSString.class] ? childKey : [childKey description];
            safe[stringKey] = WFSanitizeObject(childValue, stringKey);
        }];
        return [safe copy];
    }
    if ([object isKindOfClass:NSArray.class]) {
        NSMutableArray *safe = [NSMutableArray array];
        for (id child in (NSArray *)object) [safe addObject:WFSanitizeObject(child, nil) ?: [NSNull null]];
        return [safe copy];
    }
    return object;
}

void WFLog(NSString *format, ...) {
    if (!format.length) return;
    va_list args;
    va_start(args, format);
    NSString *raw = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSString *safe = WFRedactString(raw);
    os_log_with_type(WFLogger(), OS_LOG_TYPE_DEFAULT, "%{public}s", safe.UTF8String);
}

void WFLogEvent(NSString *event, NSDictionary<NSString *, id> *fields) {
    NSString *safeEvent = WFRedactString(event ?: @"event");
    NSString *safeFields = [WFSanitizeObject(fields ?: @{}, nil) description];
    NSString *line = [NSString stringWithFormat:@"%@ %@", safeEvent, safeFields];
    os_log_with_type(WFLogger(), OS_LOG_TYPE_DEFAULT, "%{public}s", line.UTF8String);
}
