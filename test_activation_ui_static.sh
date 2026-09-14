#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
VIEW="$PROJECT_DIR/WFActivationViewController.m"
CLIENT="$PROJECT_DIR/WFLicenseClient.m"

check() { grep -Fq "$2" "$1" || { echo "❌ $3"; exit 1; }; echo "✅ $3"; }

check "$VIEW" "normalizedActivationCode" "تنظيف كود التفعيل قبل الإرسال"
check "$VIEW" "تفعيل الاشتراك" "زر تفعيل الاشتراك واضح"
check "$VIEW" "الكود جاهز للتحقق" "توضيح حالة الإدخال"
check "$VIEW" "✅ تم التفعيل بنجاح" "نتيجة النجاح واضحة"
check "$VIEW" "الباقة:" "عرض باقة الاشتراك"
check "$VIEW" "بداية الاشتراك:" "عرض بداية الاشتراك"
check "$VIEW" "نهاية الاشتراك:" "عرض نهاية الاشتراك"
check "$VIEW" "الجهاز: مرتبط ومصرّح" "توضيح حالة ربط الجهاز"
check "$VIEW" "externalPasteButton" "زر اللصق خارج الخانة"
check "$VIEW" "externalCopyButton" "زر النسخ خارج الخانة"
check "$VIEW" "presentResultAlertForResult" "الإشعار المستقل للنتيجة"
check "$CLIENT" "saveToKeychain:trimmed key:kCodeKey" "حفظ الكود في Keychain عند نجاح التفعيل"
check "$CLIENT" "+ (NSString *)storedCode { return [self loadFromKeychain:kCodeKey]; }" "استعادة الكود المحفوظ من Keychain"

echo "✅ اجتازت واجهة التفعيل الجديدة اختبارات الحماية."
