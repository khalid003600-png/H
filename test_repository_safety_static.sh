#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

fail() { echo "❌ $*"; exit 1; }

rg -q '^#define WF_PANEL_BASE_URL @""$' WFLicenseConfig.h \
    || fail "WFLicenseConfig.h يجب أن يبقى بلا عنوان خادم مضمّن"
rg -q '^#define WF_PROJECT_KEY @""$' WFLicenseConfig.h \
    || fail "WFLicenseConfig.h يجب أن يبقى بلا مفتاح مشروع مضمّن"
rg -q 'secrets[.]WOLFOX_PANEL_BASE_URL' .github/workflows/build-wolfox.yml \
    || fail "GitHub Actions لا يقرأ عنوان اللوحة من Secrets"
rg -q 'secrets[.]WOLFOX_PROJECT_KEY' .github/workflows/build-wolfox.yml \
    || fail "GitHub Actions لا يقرأ مفتاح المشروع من Secrets"
rg -q 'GENERATED_LICENSE_CONFIG' build_v1_deb.sh \
    || fail "سكربت البناء لا ينشئ إعداد الترخيص المؤقت"

if rg -q --pcre2 '(gh[pousr]_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----)' \
    . --glob '!.wolfox-build/**'; then
    fail "اكتُشف نمط اعتماد حساس داخل المصدر"
fi

echo "✅ فحص أمان المستودع: لا توجد إعدادات ترخيص مضمّنة أو أنماط اعتماد معروفة."
