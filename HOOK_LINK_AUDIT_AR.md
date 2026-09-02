# تدقيق ربط الهوكات — WolFox v1.8.2 Full

## نطاق الإصدارات

- Deployment Target الممرّر إلى Clang: ‏iOS 15.0، وسياسة التشغيل المعلنة تبدأ من iOS 15.8.
- Build SDK المطلوب: `iPhoneOS16.5.sdk` أو أحدث متوافق مع أداة البناء.
- المعمارية: `arm64` فقط في مسار البناء المستقر.
- الحزم: Rootful بالمسار التقليدي، وRootless تحت `/var/jb`.
- الوصول إلى النوافذ يبدأ بـ`UIWindowScene/connectedScenes` المتوفر قبل الحد
  الأدنى للمشروع، مع إبقاء المسار القديم كاحتياط فقط.

## نتيجة الربط

يتم تثبيت الهوكات فور تحميل المكتبة من `WolFoxIntegrated.mm`، من دون تأخير
زمني قد يفوّت كائنات التطبيق المبكرة. ويُثبت اعتراض
`CLLocationManager.setDelegate:` مرة واحدة من `WolFoxProHookManager`.

جميع مسارات التزييف تعتمد على `WFLicenseClient.isRuntimeLicenseValid`، أي أن
وجود بيانات قديمة في Keychain وحده لا يشغّل أي هوك. عند تعطيل المشروع أو انتهاء
الاشتراك أو فرض تحديث، تتوقف الهوكات والمسار مباشرة مع الاحتفاظ ببيانات التفعيل
في الحالات التي تسمح فيها سياسة اللوحة بإعادة المحاولة.

## الهوكات المثبتة

1. `CLLocationManager.setDelegate:`
2. `CLLocationManager.location`
3. `CLLocation.coordinate`
4. `ASIdentifierManager.advertisingIdentifier`
5. `UIDevice.identifierForVendor`
6. `AVCaptureSession.startRunning`
7. `AVCaptureVideoDataOutput.setSampleBufferDelegate:queue:`
8. `NSJSONSerialization.JSONObjectWithData:options:error:`
9. `WKWebView.initWithFrame:configuration:`
10. `CBCentralManager.initWithDelegate:queue:options:`
11. `CBCentralManager.scanForPeripheralsWithServices:options:`
12. `CBPeripheral.name`
13. `CBPeripheral.identifier`
14. `UIApplication.pressesBegan:withEvent:`

## أزرار الصوت والإخفاء

- ثلاث ضغطات متتابعة خلال 1.5 ثانية تبدّل ظهور الأداة.
- هوك `UIApplication` يستدعي التنفيذ الأصلي أولاً حتى لا يعطّل تحكم التطبيق بالصوت.
- المسار الأساسي يراقب إشعار تغيير صوت النظام الصريح
  `AVSystemController_SystemVolumeDidChangeNotification`، ويوجد مساران احتياطيان
  عبر `UIApplication.pressesBegan` و`AVAudioSession.outputVolume`.
- تُفعّل جلسة `AVAudioSession` عند الإخفاء وعند عودة التطبيق للنشاط حتى يبقى
  مراقب `outputVolume` مستجيباً بعد اختفاء نافذة Wolfox.
- تُؤخر الإشارات الاحتياطية 180ms وتُدمج مع إشعار النظام في عدّاد واحد، فلا
  تُحسب الضغطة نفسها مرتين.
- إخفاء الأداة يعيد نافذة التطبيق الأصلية كنافذة رئيسية، لكنه لا يزيل هوكات
  الصوت ولا مراقب الصوت؛ لذلك يمكن إظهار الأداة مجدداً بعد الإخفاء.
- تحفظ حالة الإخفاء في `NSUserDefaults`؛ لا تُعرض الواجهة أو نافذة التفعيل
  تلقائياً في التشغيل اللاحق، ويظل طلب أزرار الصوت قادراً على عرضها مباشرة.
- إذا تغيّرت حالة الترخيص عبر Heartbeat أثناء الإخفاء، تبقى النافذة مخفية؛
  ويُعرض طلب التفعيل فقط عند تنفيذ المستخدم أمر أزرار الصوت.
- عند الإخفاء تختفي أيضاً أيقونة الكاميرا الافتراضية العائمة وتصبح نافذة التراكب مخفية
  بالكامل، مع بقاء التزييف المرخّص والهوكات العاملة غير المرتبطة بالواجهة.
- توجد تغذية لمسية عند نجاح أمر الصوت وعند زر الإخفاء.

## البلوتوث والكاميرا

- البلوتوث يطبّق ملف الجهاز النشط على أول نتيجة مسح: الاسم المحلي، اسم
  `CBPeripheral`، المعرّف وRSSI، ثم يمنع خلط أجهزة حقيقية أخرى داخل المسح نفسه.
- مسح الأجهزة داخل واجهة Wolfox يبقى حقيقياً حتى يمكن حفظ ملف جهاز جديد.
- اختيار WolFox للصورة يتم عبر `PHPicker` بصورة واحدة فقط، من دون تحويل مصدر
  كاميرا التطبيق إلى مكتبة الصور.
- يعترض `WFVirtualCameraOutputProxy` إطارات `AVCaptureVideoDataOutput` ويستبدلها
  بإطار مطابق للأبعاد وصيغة البكسل (`BGRA` أو `NV12`) مع إبقاء التوقيت والمرفقات.
- تُطبَّع جهة `UIImage` قبل التخزين، وتستخدم معاينة الفيديو Aspect Fit كي تظهر الصورة
  الطولية كاملة بلا قص، مع طبقة معاينة مرتبطة بـ `AVCaptureVideoPreviewLayer`.
- يعترض مسار `AVCapturePhotoOutput` الالتقاط الثابت؛ ويعيد `fileDataRepresentation`
  و`CGImageRepresentation` وPixel Buffer من الصورة المختارة نفسها. تُخفى لوحة WolFox
  وأيقونتها قبل تشغيل الالتقاط، لذلك لا تُدمج عناصر الأداة في ملف الصورة الناتج.
- خيار «حفظ آخر صورة» وحده يكتب الصورة داخل `Application Support/WolFox/Media`؛
  عند تعطيله تبقى الصورة في الذاكرة للجلسة الحالية ولا تُحفظ على القرص.
- بدء `AVCaptureSession` يجهّز التعليق المطول في منتصف نافذة التطبيق لإظهار
  أيقونة الاستديو وحدها؛ ضغطة واحدة تفتح `PHPicker` مباشرة، والسحب لأكثر من
  ثانيتين يبدّل البث سريعاً.

## العزل والأمان التشغيلي

- لا تعمل المكتبة داخل حزم Apple أو SpringBoard/BackBoard.
- لا تُسرق نافذة التطبيق عند تهيئة الأداة؛ تصبح نافذة Wolfox رئيسية فقط أثناء
  العرض، ثم تعود النافذة السابقة عند الإخفاء.
- أزيل `WFLicenseRuntimeBridge` القديم لتفادي وجود بوابتين مختلفتين للترخيص،
  ويستخدم البناء `WolFoxProStore` كمصدر الحالة الوحيد.

## سجل التشغيل المتوقع

- `[WolFox][BOOT] dylib_loaded`
- `[WolFox][GPS] install_hooks_complete`
- `[WolFox][HOOK] installed ...`
- `[WolFox][BOOT] hooks_install_complete`
- `[WolFox][UI] volume_kvo_ready`
- `[WolFox][UI] hidden_volume_listener_active`
- `[WolFox][UI] volume_request_progress=1/3`
- `[WolFox][UI] volume_toggle_confirmed`
- `[WolFox][BOOT] startup_ui_stays_hidden_until_volume_request`

تشغيل `build_v1_deb.sh` داخل بيئة Theos ينشئ حزمتين منفصلتين Rootful وRootless.
