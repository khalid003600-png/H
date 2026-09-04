# WolFox 1.8.2-Full

WolFox أداة iOS عربية لإدارة محاكاة الموقع والمسارات وملفات المواقع والمُعرّفات وBluetooth والكاميرا الافتراضية، مع واجهة داكنة وإعدادات وصول واختصارات لوحة مفاتيح.

## المخرجات المدعومة

- iOS: يبدأ التشغيل من 15.8، مع توافق مصدر مستهدف حتى 26.5.
- المعمارية المستقرة: `arm64`.
- الحزم: Rootful وRootless بصيغة DEB، إضافة إلى `WolFox.dylib`.
- البناء: iPhoneOS 16.5 SDK وTheos و`ldid`.
- الأمان: فلترة Bundle IDs إلزامية، ومفتاح المشروع يُحقن من GitHub Secrets ولا يُحفظ في السورس.

## البناء السريع على Ubuntu

```bash
WOLFOX_TARGET_BUNDLE_IDS="com.example.authorized-app" ./wolfox_setup_build.sh
```

استخدم فقط Bundle IDs لتطبيقات تملك صلاحية اختبارها. ينتج البناء:

- `WolFox_v1.8.2-Full_iOS15.8-26.5_Rootful.deb`
- `WolFox_v1.8.2-Full_iOS15.8-26.5_Rootless.deb`
- `WolFox.dylib`

## GitHub Actions

يوجد Workflow واحد باسم **Build WolFox 1.8.2** يعمل عند طلبات السحب والدفع إلى `main` والتشغيل اليدوي. اضبط Secret باسم `WOLFOX_PROJECT_KEY` من إعدادات المستودع، ثم نزّل Artifact بعد نجاح الفحوص والبناء والتحقق من الحزم.

## قبل الإصدار

شغّل `./run_all_linux_tests.sh`، ثم أكمل [قائمة اختبار الجهاز](DEVICE_TEST_CHECKLIST.md). لا يُعتبر دعم جهاز arm64e أو Jailbreak بعينه مثبتًا قبل تجربة الحزمة فعليًا.

للتفاصيل والميزات كاملة راجع [README_AR.md](README_AR.md)، ولحالة التنفيذ راجع [DEVELOPMENT_ROADMAP.md](DEVELOPMENT_ROADMAP.md).
