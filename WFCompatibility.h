// WFCompatibility.h — WolFox GPS Pro runtime compatibility
// Design note: preserve iOS 15.8 as the package policy while allowing newer
// iOS versions to run without an artificial upper-version rejection.
#import <UIKit/UIKit.h>

#ifndef WF_COMPATIBILITY_H
#define WF_COMPATIBILITY_H

// Package policy: install on iOS 15.8 and later.
#define WF_REQUIRED_IOS_MAJOR 15
#define WF_REQUIRED_IOS_MINOR 8
#define WF_BUILD_ARCH_NAME "arm64"

// Last version explicitly validated by the current build matrix. This is
// informational only; runtime support is intentionally open-ended above 15.8.
#define WF_LAST_VALIDATED_IOS_MAJOR 26
#define WF_LAST_VALIDATED_IOS_MINOR 5

static inline BOOL WFIsSupportedRuntime(void) {
    NSOperatingSystemVersion version = NSProcessInfo.processInfo.operatingSystemVersion;
    if (version.majorVersion > WF_REQUIRED_IOS_MAJOR) return YES;
    if (version.majorVersion < WF_REQUIRED_IOS_MAJOR) return NO;
    return version.minorVersion >= WF_REQUIRED_IOS_MINOR;
}

static inline BOOL WFIsBeyondValidatedRuntime(void) {
    NSOperatingSystemVersion version = NSProcessInfo.processInfo.operatingSystemVersion;
    if (version.majorVersion > WF_LAST_VALIDATED_IOS_MAJOR) return YES;
    if (version.majorVersion < WF_LAST_VALIDATED_IOS_MAJOR) return NO;
    return version.minorVersion > WF_LAST_VALIDATED_IOS_MINOR;
}

// Availability queries are intentionally written as if-statements. This
// lets Clang treat them as real availability guards and avoids
// -Wunsupported-availability-guard while keeping identical boolean behavior.
static inline BOOL __attribute__((unused)) WFHasSceneLifecycle(void) {
    if (@available(iOS 13.0, *)) return YES;
    return NO;
}

static inline BOOL __attribute__((unused)) WFHasSystemSymbols(void) {
    if (@available(iOS 13.0, *)) return YES;
    return NO;
}

static inline BOOL __attribute__((unused)) WFHasModernPickerBehavior(void) {
    if (@available(iOS 14.0, *)) return YES;
    return NO;
}

static inline BOOL __attribute__((unused)) WFHasModernWindowScenes(void) {
    if (@available(iOS 15.0, *)) return YES;
    return NO;
}

static inline BOOL __attribute__((unused)) WFHasModernObservationAPIs(void) {
    if (@available(iOS 17.0, *)) return YES;
    return NO;
}

static inline BOOL __attribute__((unused)) WFHasLatestSystemAPIs(void) {
    if (@available(iOS 18.0, *)) return YES;
    return NO;
}

#endif
