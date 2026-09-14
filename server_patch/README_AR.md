# WolFox v1 server patch

ارفع الملف server_patch/api/v1/verify.php إلى نفس المسار في لوحة الخادم بعد أخذ نسخة احتياطية. لا تستبدل config/database.local.php.

## التحكم من لوحة الإدارة

أضف أو حدّث السجل التالي في project_settings للمشروع المطلوب:

```sql
INSERT INTO project_settings (project_id, setting_key, setting_value)
VALUES (<PROJECT_ID>, 'runtime_enabled', '1')
ON DUPLICATE KEY UPDATE setting_value='1';
```

لإيقاف التشغيل:

```sql
UPDATE project_settings SET setting_value='0' WHERE project_id=<PROJECT_ID> AND setting_key='runtime_enabled';
```

القيم 1/true/on تشغّل، والقيم 0/false/off/disabled/stopped توقف. عند غياب المفتاح يبقى التشغيل مفعلاً. التطبيق لا يفصل بسبب انقطاع الشبكة؛ الإيقاف لا يحدث إلا من رد صريح بحالة disabled أو عند انتهاء/إلغاء الترخيص.

اختبر الاستجابة وتأكد من وجود data.control.enabled و data.control.source=admin_panel.
