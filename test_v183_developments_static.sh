#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
MASTER="$PROJECT_DIR/WolFoxMaster.mm"
HOOKS="$PROJECT_DIR/WolFoxProHookManager.m"
CAMERA="$PROJECT_DIR/WFVirtualCameraManager.mm"
CONFIG="$PROJECT_DIR/WFLicenseConfig.h"

assert_contains() {
    local file="$1"
    local pattern="$2"
    local label="$3"
    if grep -Fq "$pattern" "$file"; then
        echo "✅ $label"
    else
        echo "❌ $label"
        exit 1
    fi
}

assert_not_contains() {
    local file="$1"
    local pattern="$2"
    local label="$3"
    if grep -Fq "$pattern" "$file"; then
        echo "❌ $label"
        exit 1
    else
        echo "✅ $label"
    fi
}

assert_contains "$HOOKS" "distanceFromLocation" "الحركة والمسارات تستخدم مسافة فعلية بالمتر"
assert_contains "$HOOKS" "updateIntervalSeconds" "سرعة الحركة تراعي فترة التحديث"
assert_contains "$HOOKS" "stepMeters" "خطوة الحركة محسوبة بوحدة المتر"

assert_not_contains "$MASTER" "[WFLicenseClient clearStoredLicense]" "إيقاف الأداة لا يمسح كود التفعيل"
assert_contains "$MASTER" "مع الاحتفاظ بكود التفعيل" "واجهة الإيقاف توضح حفظ التفعيل"

assert_contains "$MASTER" "initWithUUIDString" "التحقق من UUID البلوتوث مفعّل"
assert_contains "$MASTER" "صيغة UUID غير صحيحة" "رسالة واضحة لمعرّف البلوتوث غير الصالح"

assert_contains "$CAMERA" "maximumDimension = 4096.0" "حماية الذاكرة للصور الكبيرة"
assert_contains "$CAMERA" "invalidatePixelBufferCacheLocked" "إبطال ذاكرة الكاميرا المؤقتة عند التغيير"
assert_contains "$CAMERA" "format.opaque = YES" "تحسين رسم الصورة الافتراضية"
assert_contains "$CAMERA" "CGFloat scale = MIN((CGFloat)width / imageWidth" "الحفاظ على نسبة أبعاد الصورة"

assert_contains "$MASTER" "[_activeMapSearch cancel]" "إلغاء طلب البحث السابق"
assert_contains "$MASTER" "normalizedMapSearchText" "دعم تطبيع نص البحث والإحداثيات"
assert_contains "$MASTER" "CLGeocoder" "وجود مسار احتياطي للبحث الجغرافي"
assert_contains "$MASTER" "sin(dLon) * cos(lat2)" "اتجاه المسار محسوب كروياً"

assert_contains "$CONFIG" "1.8.4-Full" "رقم الإصدار 1.8.4-Full"

echo "✅ اجتازت تطويرات WolFox 1.8.3 اختبارات الحماية الثابتة."
