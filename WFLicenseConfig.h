// WFLicenseConfig.h — public, repository-safe defaults.
// Supply deployment-specific values through WOLFOX_PANEL_BASE_URL and
// WOLFOX_PROJECT_KEY at build time. Never commit private credentials here.

#ifndef WF_LICENSE_CONFIG_H
#define WF_LICENSE_CONFIG_H

#ifndef WF_PANEL_BASE_URL
#define WF_PANEL_BASE_URL @""
#endif

#ifndef WF_PROJECT_KEY
#define WF_PROJECT_KEY @""
#endif

#ifndef WF_TWEAK_VERSION
#define WF_TWEAK_VERSION @"1.8.2-Full"
#endif

#define WF_APP_VERSION WF_TWEAK_VERSION

#endif /* WF_LICENSE_CONFIG_H */
