#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

fail() { echo "❌ $*"; exit 1; }

rg -q '^#define WF_PANEL_BASE_URL @"https://gps[.]p3nd[.]fun/api/v1"$' WFLicenseConfig.h \
    || fail "عنوان API العام gps.p3nd.fun غير مضبوط"
rg -q '^#define WF_PROJECT_KEY @""$' WFLicenseConfig.h \
    || fail "يجب ألا يُحفظ مفتاح المشروع داخل المصدر العام"
rg -q '^#define WF_PROJECT_BUNDLE_ID @"com[.]wolfox[.]gpspro"$' WFLicenseConfig.h \
    || fail "Bundle ID الخاص بمشروع الترخيص غير مضبوط"
rg -q 'WOLFOX_PANEL_BASE_URL: https://gps[.]p3nd[.]fun/api/v1' .github/workflows/build.yml \
    || fail "GitHub Actions لا يستخدم عنوان API الصحيح"
test -f .github/workflows/build.yml \
    && ! rg -q 'secrets[.]WOLFOX_PROJECT_KEY' .github/workflows/build.yml \
    || fail "يجب أن يستخدم البناء معرّف المشروع العام القياسي دون Secret"
rg -q 'GENERATED_LICENSE_CONFIG' build_v1_deb.sh \
    || fail "سكربت البناء لا ينشئ إعداد الترخيص المؤقت"
rg -q 'WOLFOX_PANEL_BASE_URL:-https://gps[.]p3nd[.]fun/api/v1' build_v1_deb.sh \
    || fail "سكربت البناء لا يستخدم عنوان API العام الصحيح"
rg -Fq 'PROJECT_KEY_VALUE="${WOLFOX_PROJECT_KEY:-wfpk_5af5d8d4d9283f340af3eafa43fbdc4b}"' build_v1_deb.sh \
    || fail "سكربت البناء يجب أن يملك قيمة المشروع العامة القياسية"

if rg -qi 'WF_PROJECT[_]SECRET|WOLFOX_PROJECT[_]SECRET|X-Project-''Secret' \
    . --glob '!.wolfox-build/**'; then
    fail "يُمنع تضمين Project Secret في المصدر أو الحزمة"
fi

if rg -q --pcre2 '(gh[pousr]_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----)' \
    . --glob '!.wolfox-build/**'; then
    fail "اكتُشف نمط اعتماد حساس داخل المصدر"
fi

echo "✅ فحص أمان المستودع: gps.p3nd.fun مضبوط والمفتاح خارج المصدر."
