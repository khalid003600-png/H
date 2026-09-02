// WFHookDefaults.h — WolFox 1.8.2
// ثوابت GPS العامة فقط؛ لا يحتوي مفاتيح ترخيص أو أسرارًا.
// Altitude Jitter اختياري ويعمل فقط عندما يكون jitterActive مفعّلًا.

#ifndef WF_HOOK_DEFAULTS_H
#define WF_HOOK_DEFAULTS_H

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <math.h>

static const double WFDefaultSimulationSpeedKmh = 5.0;
static const double WFMinimumSimulationSpeedKmh = 1.0;
static const double WFMaximumSimulationSpeedKmh = 120.0;
static const BOOL WFDefaultJitterEnabled = NO;
static const double WFDefaultJitterDegrees = 0.000025;

// قيم الارتفاع الافتراضية والحدود الآمنة بالمتر.
static const double WFDefaultAltitudeMeters = 300.0;
static const BOOL WFDefaultAltitudeJitterEnabled = NO;
static const double WFDefaultAltitudeJitterMeters = 2.0;
static const double WFMinimumAltitudeJitterMeters = 0.0;
static const double WFMaximumAltitudeJitterMeters = 50.0;

// زمن تحديث المسار الوهمي بالثواني؛ لا يغيّر معدل Core Location الحقيقي.
static const NSTimeInterval WFDefaultGPSUpdateIntervalSeconds = 1.0;
static const NSTimeInterval WFMinimumGPSUpdateIntervalSeconds = 0.25;
static const NSTimeInterval WFMaximumGPSUpdateIntervalSeconds = 10.0;

static inline NSTimeInterval WFClampGPSUpdateInterval(NSTimeInterval interval) {
    if (!isfinite(interval)) return WFDefaultGPSUpdateIntervalSeconds;
    return MAX(WFMinimumGPSUpdateIntervalSeconds,
               MIN(WFMaximumGPSUpdateIntervalSeconds, interval));
}

static inline double WFClampSimulationSpeed(double speedKmh) {
    if (!isfinite(speedKmh)) return WFDefaultSimulationSpeedKmh;
    return MAX(WFMinimumSimulationSpeedKmh,
               MIN(WFMaximumSimulationSpeedKmh, speedKmh));
}

static inline CLLocationCoordinate2D WFApplyJitter(CLLocationCoordinate2D coordinate) {
    coordinate.latitude +=
        (((double)arc4random_uniform(200001) / 100000.0) - 1.0)
        * WFDefaultJitterDegrees;
    coordinate.longitude +=
        (((double)arc4random_uniform(200001) / 100000.0) - 1.0)
        * WFDefaultJitterDegrees;
    return coordinate;
}

static inline double WFClampAltitudeJitter(double meters) {
    if (!isfinite(meters)) return WFDefaultAltitudeJitterMeters;
    return MAX(WFMinimumAltitudeJitterMeters,
               MIN(WFMaximumAltitudeJitterMeters, meters));
}

static inline double WFApplyAltitudeJitter(double altitudeMeters) {
    if (!isfinite(altitudeMeters)) altitudeMeters = WFDefaultAltitudeMeters;
    double amplitude = WFClampAltitudeJitter(WFDefaultAltitudeJitterMeters);
    double randomUnit = (double)arc4random_uniform(200001) / 100000.0 - 1.0;
    return altitudeMeters + (randomUnit * amplitude);
}

#endif /* WF_HOOK_DEFAULTS_H */
