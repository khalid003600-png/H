# فحص السجلات الآمن قبل Commit

يمنع `tools/check_secure_logging.sh` استخدام `NSLog` أو `os_log` مباشرة في ملفات المصدر. الاستثناء الوحيد هو `WFRedactedLogger.m`، حيث يجب أن تمر القيم عبر `WFLogEvent` بعد تنقيحها.

## التشغيل اليدوي

من مجلد `client` شغّل:

```bash
chmod +x tools/check_secure_logging.sh
./tools/check_secure_logging.sh
```

لفحص ملفات محددة:

```bash
./tools/check_secure_logging.sh WFLicenseClient.m WolFoxMaster.mm
```

## التثبيت في Git

ضع مجلد `client` داخل مستودع Git، ثم شغّل:

```bash
./tools/install_secure_logging_hook.sh
```

يضبط المثبّت `core.hooksPath` على `.githooks`. قبل كل Commit يفحص Git الملفات المضافة إلى staging فقط، ثم يرفض العملية إذا وجد استدعاءً مباشرًا لـ `NSLog` أو `os_log`.

## السلوك عند المخالفة

مثال على كود مرفوض:

```objc
NSLog(@"token=%@", token);
```

البديل المسموح:

```objc
WFLogEvent(@"license_verify", @{
    @"success": @(result.success),
    @"stored": @(code.length > 0)
});
```

لا تستخدم `--no-verify` لتجاوز الفحص في الإصدار الإنتاجي. إذا كان هناك فحص تجريبي ضروري، أصلح المخالفة أو نفّذ الفحص اليدوي قبل Commit.

## ملاحظات

المجلدان الحاليان لمصدري Lite وFull لا يحتويان على Git repository مستقل بحسب بيئة البناء الحالية؛ لذلك يتوفر السكربت والـ hook للتثبيت داخل مستودع المصدر الفعلي. يجب إضافة `WFRedactedLogger.m` إلى قائمة ملفات Theos قبل البناء إذا لم يكن مدرجًا تلقائيًا.

هذا الفحص يمنع الاستخدام المباشر للأسماء المحددة، لكنه لا يغني عن مراجعة النصوص المرسلة إلى `WFLogEvent`، واختبارات Unit تمنع ظهور قيم `license_code` و`access_token` و`Authorization` في المخرجات.
