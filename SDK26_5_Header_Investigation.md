# فحص اكتمال iPhoneOS26.5.sdk

أظهر اختبار بناء UIKit أن ملف الرأس التالي مفقود من النسخة المحلية من SDK:

```text
UIUtilities/UIDefines.h
```

ويستدعيه `UIKit.framework/Headers/UIKitDefines.h` مباشرة. أدى ذلك إلى فشل بناء WolFox قبل تجميع ملفات المشروع.

تم التحقق من مسار `PrivateFrameworks/UIUtilities.framework/Headers` في مصدر SDK المشار إليه، ولم يكن متاحاً في ذلك المسار. يجب استخدام SDK 26.5 مكتمل يحتوي UIUtilities.framework أو توفير طبقة توافق مراجعها مطابقة لنسخة SDK، ثم إعادة اختبار تضمين UIKit قبل بناء WolFox النهائي.

## المحاولات اللاحقة

أضافت طبقة تضمين محلية محدودة الرأسين `UIDefines.h` و`UIGeometry.h` حتى يمكن اختبار أثر الغياب من دون تعريف أي واجهات وقت تشغيل. بعد ذلك كشف UIKit عن اعتماد إضافي مفقود هو:

```text
UIUtilities/UICoordinateSpace.h
```

وهذا يثبت أن المشكلة ليست رأساً واحداً قابلاً للتجاوز، بل أن `UIUtilities.framework` ككل غير موجود في نسخة SDK. لذلك توقف مسار التوافق هنا عمداً؛ الاستمرار بإعادة إنشاء رؤوس خاصة سيجعل SDK غير موثوق وقد يخالف ABI. يلزم SDK 26.5 مكتمل من Xcode أو حزمة Theos موثوقة تحتوي UIUtilities.framework قبل أي بناء نهائي.

## التحقق من مصدر بديل

تم فحص مصدر بديل لـ iPhoneOS26.5.sdk من دون تنفيذ أي محتوى منه. لم تتوفر الملفات التالية في مسارات `Frameworks` أو `PrivateFrameworks` لذلك المصدر:

```text
UIUtilities.framework/Headers/UIDefines.h
UIUtilities.framework/Headers/UIGeometry.h
UIUtilities.framework/Headers/UICoordinateSpace.h
```

لذلك لا يصلح المصدر البديل لاستكمال SDK المحلي. يلزم توفير نسخة SDK كاملة ومصرح بها من تثبيت Xcode 26.5 أو من مصدر SDK موثوق يتضمن `UIUtilities.framework` كاملاً.
