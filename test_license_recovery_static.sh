#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
LICENSE_CLIENT="$PROJECT_DIR/WFLicenseClient.m"
LICENSE_CONFIG="$PROJECT_DIR/WFLicenseConfig.h"
MASTER="$PROJECT_DIR/WolFoxMaster.mm"

check() { grep -Fq "$2" "$1" || { echo "❌ $3"; exit 1; }; echo "✅ $3"; }
reject() { if grep -Fq "$2" "$1"; then echo "❌ $3"; exit 1; fi; echo "✅ $3"; }

# Verify license client implementation
check "$LICENSE_CLIENT" "WFLicenseResult" "فئة نتائج الترخيص معرّفة"
check "$LICENSE_CLIENT" "isRuntimeLicenseValid" "دالة التحقق من الترخيص موجودة"
check "$LICENSE_CLIENT" "cachedResult" "ذاكرة التخزين المؤقت للترخيص معرّفة"
check "$LICENSE_CLIENT" "verify_access_token" "التوقيع الرقمي للترخيص معرّف"

# Verify license config
check "$LICENSE_CONFIG" "WF_TWEAK_VERSION" "إصدار Tweak محدد"
check "$LICENSE_CONFIG" "WF_PANEL_BASE_URL" "خادم الترخيص معرّف"

# Verify recovery mechanisms
check "$MASTER" "showActivationScreen" "واجهة إعادة التفعيل موجودة"
check "$MASTER" "scheduleExpiryReminderIfEnabled" "تذكيرات انتهاء الصلاحية معرّفة"

# Ensure no hardcoded bypass
reject "$LICENSE_CLIENT" "return YES" "لا توجد مجاوزات ترخيص مباشرة"
reject "$LICENSE_CONFIG" "TESTING_MODE.*YES" "وضع الاختبار معطّل في الإنتاج"

echo "✅ اجتاز اختبارات استعادة الترخيص."
