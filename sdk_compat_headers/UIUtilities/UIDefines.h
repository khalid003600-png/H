#ifndef WF_UIUTILITIES_UIDEFINES_H
#define WF_UIUTILITIES_UIDEFINES_H

// iPhoneOS26.5.sdk المستورد لا يتضمن UIUtilities.framework رغم أن
// UIKitDefines.h يضمّن هذا الرأس. هذه طبقة تضمين فارغة عمداً: لا تعرّف
// واجهات أو رموزاً أو سلوكاً وقت التشغيل، وتسمح فقط باستخدام UIKit العام.
#import <Availability.h>

#ifndef UIKIT_EXTERN
    #ifdef __cplusplus
        #define UIKIT_EXTERN extern "C" __attribute__((visibility("default")))
    #else
        #define UIKIT_EXTERN extern __attribute__((visibility("default")))
    #endif
#endif

#ifndef UIKIT_STATIC_INLINE
    #define UIKIT_STATIC_INLINE static inline
#endif

#if !defined(UIKIT_EXTERN_C_BEGIN) && !defined(UIKIT_EXTERN_C_END)
    #ifdef __cplusplus
        #define UIKIT_EXTERN_C_BEGIN extern "C" {
        #define UIKIT_EXTERN_C_END }
    #else
        #define UIKIT_EXTERN_C_BEGIN
        #define UIKIT_EXTERN_C_END
    #endif
#endif

#endif
