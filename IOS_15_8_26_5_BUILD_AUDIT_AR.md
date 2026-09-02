# تدقيق بناء iOS 15.8–26.5

## شروط النسخة النهائية

- Deployment Target: ‏iOS 15.8.
- Build SDK: ‏`iPhoneOS26.5.sdk` أو أحدث.
- المعماريات: `arm64` ومحاولة `arm64e` تلقائياً.
- توقيع Mach-O: إلزامي باستخدام `ldid -S`.
- ملكية ملفات DEB: ‏`root:root` باستخدام `--root-owner-group` أو `fakeroot`.
- حزم منفصلة لمساري Rootful وRootless.

يرفض سكربت البناء SDK الأقدم أو غياب `ldid` للنسخة النهائية. يسمح المتغيران
`ALLOW_OLDER_SDK=1` و`WOLFOX_REQUIRE_SIGNING=0` ببناء أولي للتشخيص فقط، ولا
ينبغي توزيع ناتجه أو اعتباره نسخة متوافقة نهائية.

## التحقق على لينكس

```bash
./test_build_compatibility_static.sh
./run_all_linux_tests.sh
```

لا يثبت الفحص الثابت توافق CoreLocation/UIKit ديناميكياً؛ يلزم بناء فعلي بـSDK
26.5 ثم اختبار الحزمة على أجهزة أو بيئات iOS ممثلة للحد الأدنى والأعلى.
