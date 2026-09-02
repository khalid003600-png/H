// WFLicenseConfig.h — public, repository-safe connection identifiers.
// These values are not credentials. A deployment may override them at build
// time, but the private Project Secret must never be committed or embedded.

#ifndef WF_LICENSE_CONFIG_H
#define WF_LICENSE_CONFIG_H

#ifndef WF_PANEL_BASE_URL
#define WF_PANEL_BASE_URL @"https://wolfox.bitsyscore.com/api/v1"
#endif

#ifndef WF_PROJECT_KEY
#define WF_PROJECT_KEY @""
#endif

#ifndef WF_PROJECT_BUNDLE_ID
#define WF_PROJECT_BUNDLE_ID @"com.wolfox.gpspro"
#endif

#ifndef WF_TWEAK_VERSION
#define WF_TWEAK_VERSION @"1.8.2-Full"
#endif

#define WF_APP_VERSION WF_TWEAK_VERSION

#endif /* WF_LICENSE_CONFIG_H */
