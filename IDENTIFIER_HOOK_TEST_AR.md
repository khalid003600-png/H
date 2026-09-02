# اختبار هوكات المعرّفات — WolFox Full

يشغّل `test_identifier_hooks_static.sh` تدقيق ربط IDFA وIDFV وحقن WebView، ويتأكد من أن المسارات الثلاثة تستخدم `WFActivePublicIdentifier` نفسه وأن UUID يُتحقق منه قبل الحفظ. ثم يشغّل `run_linux_identifier_tests.sh` محاكاة مستقلة على لينكس للحالات الآتية:

- عدم وجود ملف نشط يعيد المعرّفات الأصلية.
- رفض UUID غير صالح وقبول UUID صالح بعد تطبيعه.
- الترخيص غير الصالح يمنع تغيير IDFA وIDFV وWebView.
- تغيير الملف النشط ينعكس فوراً على القراءات التالية.
- إلغاء التفعيل يعيد جميع المسارات إلى قيم التطبيق الأصلية.

لتشغيله منفرداً:

```bash
./test_identifier_hooks_static.sh
./run_linux_identifier_tests.sh
```

ولتجميعه مع بقية اختبارات المصدر:

```bash
./run_all_linux_tests.sh
```
