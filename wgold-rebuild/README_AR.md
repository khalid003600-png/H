# WGold Rebuild

هذا المسار هو إعادة بناء مصدرية clean-room لسلوك WGold اعتماداً على السلوك الظاهر والـruntime metadata والموارد الموجودة في WGold.bundle. ليس هذا استرجاعاً حرفياً للسورس الأصلي من الملف الثنائي.

## الهدف
- نفس أسلوب WGold داخل إعدادات WhatsApp.
- دعم net.whatsapp.WhatsApp ونسخ sideload مثل net.whatsapp.WhatsApp1.
- طبقة توافق App Group منفصلة.
- تقسيم الميزات إلى Modules مستقلة بدلاً من ملف dylib ضخم واحد.
- إمكانية البناء كـ dylib ثم دمجه تدريجياً مع الموارد الأصلية.

## الوحدات المكتشفة من WGold.dylib
- Settings / About
- Ghost Mode + Exceptions
- Messages / Deleted / Edited
- Statuses / Deleted Status / View Once
- Voice Changer / Upload Voice
- Call Recordings
- Multi Account
- Cleaning
- Fake Contact
- Online Activity Notifications
- Google Drive Backup
- Sideload / App Group Compatibility

## الحالة الحالية
المرحلة الأولى تنشئ Core وCompatibility وSettings Registry. ثم تضاف الـHooks لكل ميزة على حدة مع اختبار كل وحدة قبل الانتقال للتالية.
