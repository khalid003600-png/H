#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

fail() { echo "❌ $*"; exit 1; }

rg -q '^#define WF_PANEL_BASE_URL @"https://wolfox[.]bitsyscore[.]com"$' WFLicenseConfig.h \
    || fail "عنوان لوحة WolFox العام الافتراضي غير مضبوط"
rg -q '^#define WF_PROJECT_KEY @"wolfox_ios"$' WFLicenseConfig.h \
    || fail "معرّف مشروع WolFox العام الافتراضي غير مضبوط"
rg -q '^#define WF_PROJECT_BUNDLE_ID @"com[.]wolfox[.]gpspro"$' WFLicenseConfig.h \
    || fail "Bundle ID الخاص بمشروع الترخيص غير مضبوط"
rg -q 'secrets[.]WOLFOX_PANEL_BASE_URL' .github/workflows/build-wolfox.yml \
    || fail "GitHub Actions لا يدعم تجاوز عنوان اللوحة اختيارياً"
rg -q 'secrets[.]WOLFOX_PROJECT_KEY' .github/workflows/build-wolfox.yml \
    || fail "GitHub Actions لا يدعم تجاوز معرّف المشروع اختيارياً"
rg -q 'GENERATED_LICENSE_CONFIG' build_v1_deb.sh \
    || fail "سكربت البناء لا ينشئ إعداد الترخيص المؤقت"
rg -q 'WOLFOX_PANEL_BASE_URL:-https://wolfox[.]bitsyscore[.]com' build_v1_deb.sh \
    || fail "سكربت البناء لا يستخدم عنوان اللوحة العام عند غياب Secrets"
rg -q 'WOLFOX_PROJECT_KEY:-wolfox_ios' build_v1_deb.sh \
    || fail "سكربت البناء لا يستخدم معرّف المشروع العام عند غياب Secrets"

if rg -qi 'WF_PROJECT[_]SECRET|WOLFOX_PROJECT[_]SECRET|X-Project-''Secret' \
    . --glob '!.wolfox-build/**'; then
    fail "يُمنع تضمين Project Secret في المصدر أو الحزمة"
fi

if rg -q --pcre2 '(gh[pousr]_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----)' \
    . --glob '!.wolfox-build/**'; then
    fail "اكتُشف نمط اعتماد حساس داخل المصدر"
fi

echo "✅ فحص أمان المستودع: المعرّفات العامة مضبوطة ولا توجد أسرار أو أنماط اعتماد معروفة."
