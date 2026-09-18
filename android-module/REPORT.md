# 🦊 WolFox GPS Module v2.0.0 — تقرير المشروع

## معلومات الموديول

| الحقل         | القيمة                    |
|---------------|---------------------------|
| Package       | `com.wolfox.gps`          |
| Version       | 2.0.0 (versionCode: 200)  |
| Min SDK       | 21 (Android 5.0)          |
| Target SDK    | 34 (Android 14)           |
| LSPosed Min   | 93                        |
| Scope         | `k7.gps`                  |
| نوع الخريطة  | MapLibre + Nominatim OSM  |

---

## سجل الإصلاحات (v2.0.0-fixed)

| # | الملف | المشكلة | الإصلاح |
|---|-------|---------|---------|
| 1 | `app/build.gradle` | `com.android.library` لا ينتج APK | تغيير إلى `com.android.application` + `applicationId` |
| 2 | `WFStorage.java` | `saveLastLocation` يحوّل double→float فيخسر الدقة | استخدام `Double.doubleToLongBits` → `putLong` |
| 3 | `WolFoxHook.java` | Fused `requestLocationUpdates` غير معترض | إضافة هوك كامل مع `injectFusedCallback` |
| 4 | `WolFoxHook.java` | `LocationResult.getLocations()` غير معترض | إضافة هوك يُعيد قائمة بموقع واحد مزيف |
| 5 | `ActivityHook.java` | `onResume` لا يُبلّغ `FloatingManager` بالـ Activity الجديد | إضافة `FloatingManager.onActivityResumed(act)` |
| 6 | `WolFoxUI.java` | `onAppReady` تُعيد فتح `WolFoxLicense` في كل `onResume` | تفويض لـ `checkAndShowIfNeeded` |
| 7 | `WolFoxLicense.java` | لا حارس لمنع تكرار الـ Dialog | إضافة `currentDialog` + `isShowing` + `onDismissListener` |
| 8 | `GPSMockManager.java` | `Location.isFromMockProvider()` يكشف التزييف | استدعاء `setIsFromMockProvider(false)` |
| 9 | `LicenseHook.java` | يعترض توقيع `(String)` فقط | إضافة توقيع `(Object)` لتغطية JSONObject وغيره |
| 10 | `FloatingManager.java` | `removeView` قد يرمي exception إذا تغيّر الـ parent | `safeRemove()` مع try-catch + null-check |
| 11 | `FloatingManager.java` | `snapToEdge` تنهار إذا `getParent() == null` | إضافة `instanceof ViewGroup` check |
| 12 | `WolFoxPanel.java` | `setRadius` يُعيد دائماً navy بغض النظر عن اللون | `setRoundedBg(view, color, radius)` يأخذ اللون كمعامل |
| 13 | `WolFoxPanel.java` | زر "📍 موقعي" لا يفعل شيئاً | يُظهر الإحداثيات الحالية عبر Toast |
| 14 | `AndroidManifest.xml` | بدون `networkSecurityConfig` → HTTP مرفوض في API 28+ | إضافة `network_security_config.xml` |
| 15 | `lspatch_module_info.json` | `scope: []` فارغ → LSPatch لا يعرف يدمج مع من | `scope: ["k7.gps"]` |

---

## هيكل الملفات

```
wolfox-module/
├── app/src/main/
│   ├── AndroidManifest.xml
│   ├── assets/
│   │   ├── xposed_init
│   │   ├── lspatch_module_info.json   ← scope: ["k7.gps"]
│   │   └── wolfox_map.html
│   ├── res/
│   │   ├── values/colors.xml
│   │   ├── values/strings.xml
│   │   └── xml/network_security_config.xml  ← جديد
│   └── java/com/wolfox/gps/
│       ├── hook/
│       │   ├── WolFoxHook.java   ← + Fused.requestLocationUpdates + getLocations
│       │   ├── ActivityHook.java ← + FloatingManager.onActivityResumed
│       │   └── LicenseHook.java  ← + توقيع Object
│       ├── manager/
│       │   ├── GPSMockManager.java ← setIsFromMockProvider(false)
│       │   └── FloatingManager.java ← safeRemove + snapToEdge fix
│       ├── ui/
│       │   ├── WolFoxUI.java       ← checkAndShowIfNeeded
│       │   ├── WolFoxLicense.java  ← حارس isShowing
│       │   ├── WolFoxPanel.java    ← setRoundedBg fix + موقعي fix
│       │   └── ...
│       └── util/
│           └── WFStorage.java  ← double precision fix
└── app/build.gradle  ← application + applicationId
```

---

## الهوكات المُثبَّتة (محدّثة)

| الهوك | الدالة | الوصف |
|-------|--------|-------|
| LocationManager | `getLastKnownLocation` | يُعيد الموقع المزيف |
| LocationManager | `requestLocationUpdates` | يُرسل callback بالموقع المزيف |
| LocationManager | `requestSingleUpdate` | callback فوري |
| LocationManager | `getCurrentLocation` | API 30+ |
| FusedLocation | `getLastLocation` | Task<Location> وهمي |
| FusedLocation | `requestLocationUpdates` | ✅ جديد — يستدعي LocationCallback |
| LocationResult | `getLastLocation` | نتيجة Fused |
| LocationResult | `getLocations()` | ✅ جديد — قائمة بموقع واحد |
| LocationAvailability | `isLocationAvailable` | true دائماً |
| WebView | `loadUrl / loadDataWithBaseURL` | حقن JS لـ navigator.geolocation |
| Activity | `onResume / onPause / onDestroy` | ربط FloatingManager |
| Application | `onCreate` | تهيئة السياق |

---

## طريقة البناء

```bash
# 1. بناء
./gradlew assembleRelease

# 2. zipalign
zipalign -v 4 app/build/outputs/apk/release/*.apk k7.gps.module-aligned.apk

# 3. توقيع v2 + v3
apksigner sign \
  --ks wolfox.keystore \
  --ks-key-alias wolfox \
  --v2-signing-enabled true \
  --v3-signing-enabled true \
  --out k7.gps.module-signed.apk \
  k7.gps.module-aligned.apk

# 4. تحقق
apksigner verify --verbose k7.gps.module-signed.apk
sha256sum k7.gps.module-signed.apk
```

---

## GitHub Actions Secrets المطلوبة

| Secret | الوصف |
|--------|-------|
| `KEYSTORE_BASE64` | keystore مُشفَّر بـ base64 |
| `KEY_ALIAS` | اسم المفتاح |
| `KEYSTORE_PASS` | كلمة سر الـ keystore |
| `KEY_PASS` | كلمة سر المفتاح |
