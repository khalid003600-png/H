#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
VIEW="$PROJECT_DIR/WFActivationViewController.m"
CLIENT="$PROJECT_DIR/WFLicenseClient.m"

check() { grep -Fq "$2" "$1" || { echo "❌ $3"; exit 1; }; echo "✅ $3"; }

check "$VIEW" "normalizedActivationCode" "تنظيف كود التفعيل قبل الإرسال"
check "$VIEW" "تحقق من الكود وتفعيل الأداة" "زر التحقق واضح"
check "$VIEW" "الكود جاهز للتحقق" "توضيح حالة الإدخال"
check "$VIEW" "✅ تم التفعيل بنجاح" "نتيجة النجاح واضحة"
check "$VIEW" "الباقة:" "عرض باقة الاشتراك"
check "$VIEW" "بداية الاشتراك:" "عرض بداية الاشتراك"
check "$VIEW" "نهاية الاشتراك:" "عرض نهاية الاشتراك"
check "$VIEW" "الجهاز: مرتبط ومصرّح" "توضيح حالة ربط الجهاز"
check "$VIEW" "فتح لوحة WolFox الآن" "الإجراء التالي بعد التفعيل واضح"
check "$VIEW" "البقاء في التطبيق وفتح اللوحة لاحقاً" "خيار ما بعد التفعيل واضح"
check "$CLIENT" "storeLicenseCode" "استمرار حفظ الكود في طبقة الترخيص"

echo "✅ اجتازت واجهة التفعيل الجديدة اختبارات الحماية."
