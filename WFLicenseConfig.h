// WFLicenseConfig.h — shared license connection contract for every WolFox edition.
// All editions use the same control-panel API path. Project secrets stay injected
// at build time and are never committed to source.

#ifndef WF_LICENSE_CONFIG_H
#define WF_LICENSE_CONFIG_H

// Canonical control-panel path for Full, Lite, Jailbreak and WhatsApp editions.
// Do not allow an edition-specific build to drift to another panel endpoint.
#ifdef WF_PANEL_BASE_URL
#undef WF_PANEL_BASE_URL
#endif
#define WF_PANEL_BASE_URL @"https://gps.p3nd.fun/api/v1"

// Build scripts generate WOLFOX_LICENSE_PROJECT_KEY / BUNDLE_ID. Bridge those
// generated values into the runtime client so every edition actually uses them.
#ifndef WF_PROJECT_KEY
#ifdef WOLFOX_LICENSE_PROJECT_KEY
#define WF_PROJECT_KEY WOLFOX_LICENSE_PROJECT_KEY
#else
#define WF_PROJECT_KEY @""
#endif
#endif

#ifndef WF_PROJECT_BUNDLE_ID
#ifdef WOLFOX_LICENSE_PROJECT_BUNDLE_ID
#define WF_PROJECT_BUNDLE_ID WOLFOX_LICENSE_PROJECT_BUNDLE_ID
#else
#define WF_PROJECT_BUNDLE_ID @"com.wolfox.gpspro"
#endif
#endif

#ifndef WF_TWEAK_VERSION
#ifdef WOLFOX_LICENSE_APP_VERSION
#define WF_TWEAK_VERSION WOLFOX_LICENSE_APP_VERSION
#else
#define WF_TWEAK_VERSION @"2.0.0-Full"
#endif
#endif

#define WF_APP_VERSION WF_TWEAK_VERSION

#endif /* WF_LICENSE_CONFIG_H */
