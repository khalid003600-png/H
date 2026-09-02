# حماية سورس WolFox من دون تعطيل البناء

## ما تم تطبيقه

1. **تشفير حزمة التوزيع** باستخدام `AES-256-CBC` مع اشتقاق المفتاح
   `PBKDF2-SHA256` و250,000 دورة. السورس لا يظهر إلا بعد فك الحزمة بكلمة المرور.
2. **تقوية ملف WolFox.dylib** أثناء البناء عبر إخفاء رموز C/C++ غير اللازمة،
   إزالة الكود غير المستخدم، وحذف الرموز المحلية من جدول الرموز. إذا لم يقبل
   linker القديم خياري `dead_strip/-x` يعيد السكربت الربط تلقائياً بالخيارات
   الأساسية، فلا تتعطل الحزمة بسبب خيار الحماية.
3. **حماية ربط الهوكات**: لم تُغيّر أسماء كلاسات Objective-C أو `selectors` أو
   النصوص التي يستدعيها Runtime مثل `WolFoxController` و
   `WolFoxMainViewController`، لأن تشويهها عشوائياً قد يمنع ظهور الأداة أو يكسر الهوكات.

## فك الحزمة

ضع `decrypt_source_package.sh` بجانب ملف `.zip.aes` ثم نفّذ:

```bash
chmod +x decrypt_source_package.sh
./decrypt_source_package.sh WolFox_v1.6.1_iOS15.8-26.5_Source.zip.aes
```

أو عيّن كلمة المرور من البيئة للتشغيل غير التفاعلي:

```bash
WOLFOX_SOURCE_PASSWORD='YOUR_PASSWORD' \
  ./decrypt_source_package.sh WolFox_v1.6.1_iOS15.8-26.5_Source.zip.aes ./output
```

بعد فك الحزمة يبقى البناء المعتاد كما هو:

```bash
cd WolFox_v1.6.1_iOS15.8-26.5_Source
chmod +x build_v1_deb.sh
./build_v1_deb.sh
```

## إنشاء حزمة جديدة بكلمة مرور خاصة

```bash
chmod +x secure_source_package.sh
./secure_source_package.sh /path/to/WolFox_Source.zip.aes
```

للتشخيص فقط يمكن تعطيل تقوية الـdylib من دون تعديل الملفات:

```bash
WOLFOX_HARDENING=0 ./build_v1_deb.sh
```

## حدود الحماية

لا يمكن للمترجم بناء سورس مشفر مباشرة؛ يجب أن يكون النص واضحاً في بيئة البناء بعد
فك الحزمة. لذلك تحمي هذه الآلية السورس أثناء التخزين والنقل، ثم تحمي الملف التنفيذي
الناتج بتقليل الرموز المكشوفة، من دون إدخال obfuscation عدواني يهدد استقرار الهوكات.
