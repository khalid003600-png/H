#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

PASS=0
FAIL=0

expect_pattern() {
    local label="$1" pattern="$2" file="$3"
    if rg -q -- "$pattern" "$file"; then
        echo "✅ $label"
        PASS=$((PASS + 1))
    else
        echo "❌ $label"
        FAIL=$((FAIL + 1))
    fi
}

expect_absent() {
    local label="$1" pattern="$2"
    shift 2
    if rg -q -- "$pattern" "$@"; then
        echo "❌ $label"
        FAIL=$((FAIL + 1))
    else
        echo "✅ $label"
        PASS=$((PASS + 1))
    fi
}

expect_pattern "اختيار صورة واحدة عبر PHPicker" 'selectionLimit = 1' WFVirtualCameraManager.mm
expect_pattern "فلتر المنتقي للصور فقط" 'PHPickerFilter[.]imagesFilter' WFVirtualCameraManager.mm
expect_pattern "معالجة إلغاء PHPicker" 'PHPickerResult \*result = results[.]firstObject' WFVirtualCameraManager.mm
expect_pattern "أيقونة الكاميرا تفتح الاستديو مباشرة" 'addTarget:self action:@selector[(]openVirtualCameraImagePicker:[)]' WolFoxMaster.mm
expect_pattern "التفعيل التلقائي بعد اختيار الصورة" '_enabled = \[WFLicenseClient isRuntimeLicenseValid\]' WFVirtualCameraManager.mm
expect_pattern "إخفاء الواجهة قبل فتح الاستديو" '\[self prepareCleanVirtualPhotoCapture\]' WolFoxMaster.mm
expect_pattern "تثبيت الاتجاه الطولي من UIImage" 'image[.]size[.]height \* sourceScale' WFVirtualCameraManager.mm
expect_pattern "إظهار الصورة كاملة بلا قص" 'CGFloat scale = MIN[(][(]CGFloat[)]width / imageWidth' WFVirtualCameraManager.mm
expect_pattern "هوك بدء جلسة AVFoundation" 'WFInstallInstanceHook\(AVCaptureSession[.]class' WolFoxIntegrated.mm
expect_pattern "هوك delegate لإطارات الفيديو" 'setSampleBufferDelegate:queue:' WolFoxIntegrated.mm
expect_pattern "وكيل delegate محتفظ به على video output" 'kWFVideoOutputProxyKey.*OBJC_ASSOCIATION_RETAIN_NONATOMIC' WolFoxIntegrated.mm
expect_pattern "معاينة الصورة داخل طبقة الكاميرا" 'WFVirtualCameraPortraitPreview' WolFoxIntegrated.mm
expect_pattern "المعاينة تحافظ على كامل الصورة" 'kCAGravityResizeAspect' WolFoxIntegrated.mm
expect_pattern "معاينة لوحة WolFox بلا قص" 'UIViewContentModeScaleAspectFit' WolFoxMaster.mm
expect_pattern "زر تصوير الكاميرا يمر عبر مسار الصورة المختارة" 'capturePhotoWithSettings:delegate:' WolFoxIntegrated.mm
expect_pattern "استبدال JPEG للصورة الثابتة" 'hook_AVCapturePhoto_fileDataRepresentation' WolFoxIntegrated.mm
expect_pattern "استبدال Pixel Buffer للصورة الثابتة" 'hook_AVCapturePhoto_pixelBuffer' WolFoxIntegrated.mm
expect_pattern "إخفاء أدوات WolFox قبل الالتقاط" 'prepareCleanVirtualPhotoCapture' WolFoxMaster.mm
expect_pattern "إخفاء الأدوات بعد اختيار الصورة" 'WFVirtualCameraImageDidSelectNotification' WolFoxMaster.mm
expect_pattern "استبدال sample buffer داخل callback" 'copyReplacementForSampleBuffer' WFVirtualCameraManager.mm
expect_pattern "دعم BGRA" 'kCVPixelFormatType_32BGRA' WFVirtualCameraManager.mm
expect_pattern "دعم NV12 Full Range" 'kCVPixelFormatType_420YpCbCr8BiPlanarFullRange' WFVirtualCameraManager.mm
expect_pattern "دعم NV12 Video Range" 'kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange' WFVirtualCameraManager.mm
expect_pattern "نسخ مرفقات pixel buffer" 'CVBufferCopyAttachments' WFVirtualCameraManager.mm
expect_pattern "نسخ توقيت sample buffer" 'CMSampleBufferGetSampleTimingInfo' WFVirtualCameraManager.mm
expect_pattern "وكيل NSProxy يرفع استثناءً عند تعذر التمرير" 'NSException raise:NSInvalidArgumentException' WFVirtualCameraManager.mm
expect_pattern "حفظ آخر صورة اختياري" 'rememberCameraImage' WolFoxProStore.h
expect_pattern "إظهار الأداة بالتعليق المطول" 'minimumPressDuration = 0[.]8' WolFoxMaster.mm
expect_pattern "منطقة التفعيل الوسطى بقيت كما هي" 'CGRectInset[(]bounds, CGRectGetWidth[(]bounds[)] \* 0[.]25, CGRectGetHeight[(]bounds[)] \* 0[.]25[)]' WolFoxMaster.mm
expect_pattern "اختصار السحب لأكثر من ثانيتين" 'duration > 2[.]0' WolFoxMaster.mm
expect_pattern "مدير الكاميرا ضمن ملفات البناء" 'WFVirtualCameraManager[.]mm' build_v1_deb.sh
expect_pattern "CoreMedia مرتبط" 'framework CoreMedia' build_v1_deb.sh
expect_pattern "CoreVideo مرتبط" 'framework CoreVideo' build_v1_deb.sh
expect_pattern "PhotosUI مرتبط" 'framework PhotosUI' build_v1_deb.sh

expect_absent "لا يوجد UIImagePickerController قديم" 'UIImagePickerController' WolFoxMaster.mm WolFoxIntegrated.mm WFVirtualCameraManager.mm
expect_absent "لا يوجد منسق معرض متعدد قديم" 'WFGalleryPickerCoordinator|openGalleryPicker|_galleryImages' WolFoxMaster.mm WolFoxIntegrated.mm build_v1_deb.sh
expect_absent "لا تفتح لوحة وسيطة بعد تعليق الكاميرا" 'if \(!self[.]floatingControlPanel\) \[self cameraIconPressed\]' WolFoxMaster.mm
expect_absent "لا يوجد استدعاء غير متوافق مع NSProxy" 'doesNotRecognizeSelector' WFVirtualCameraManager.mm
expect_absent "لا يوجد قص Aspect Fill للصورة المختارة" 'WFVirtualCameraCreateAspectFillBGRA' WFVirtualCameraManager.mm

if [ -e WFGalleryPickerCoordinator.h ] || [ -e WFGalleryPickerCoordinator.m ]; then
    echo "❌ ملفات المعرض القديمة ما زالت موجودة"
    FAIL=$((FAIL + 1))
else
    echo "✅ ملفات المعرض القديمة محذوفة"
    PASS=$((PASS + 1))
fi

echo "النتيجة: $PASS ناجح، $FAIL فاشل"
if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
