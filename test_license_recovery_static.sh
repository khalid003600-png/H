#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
CLIENT="$ROOT/WFLicenseClient.m"
HEADER="$ROOT/WFLicenseClient.h"
VIEW="$ROOT/WFActivationViewController.m"

grep -q 'WFLicenseStatusDeviceRecovery' "$HEADER"
grep -q 'recovery_required code_retained=1' "$CLIENT"
grep -q 'WFLicenseStatusDeviceRecovery' "$VIEW"

# عقد API: الحقول الحالية مع الأسماء التوافقية القديمة.
grep -q '@"code": code' "$CLIENT"
grep -q '@"device_id": deviceID' "$CLIENT"
grep -q '@"bundle_id": WF_PROJECT_BUNDLE_ID' "$CLIENT"
grep -q '@"app_version": WF_APP_VERSION' "$CLIENT"
grep -q '@"license_code": code' "$CLIENT"
grep -q '@"device_uuid": deviceID' "$CLIENT"
grep -q '@"Authorization"' "$CLIENT"

# نجاح اللوحة مقبول سواءً أعادت success=true أو حالة active/valid/success.
grep -q '@"active", @"success", @"valid", @"activated"' "$CLIENT"

# access_token اختياري، ولا يجوز أن يكون شرطاً لوجود ترخيص محفوظ.
HAS_STORED_BLOCK="$(sed -n '/+ (BOOL)hasStoredLicense/,/^}/p' "$CLIENT")"
if grep -q 'kTokenKey' <<< "$HAS_STORED_BLOCK"; then
    echo "FAIL: access_token must remain optional for stored licenses"
    exit 1
fi

# لا توجد مهلة 24 ساعة تفصل العميل أثناء انقطاع الشبكة.
if grep -q 'kCacheTTL\|age >' "$CLIENT"; then
    echo "FAIL: cached activation must be governed by expires_at, not an artificial TTL"
    exit 1
fi
grep -q 'انتهاء المدة هو الحالة الوحيدة التي تمسح الكود نهائياً' "$CLIENT"
grep -q 'status == WFLicenseStatusExpired' "$CLIENT"

# طلب التفعيل يبدأ فوراً بلا عدّ تنازلي مصطنع.
grep -q '\[self finalizeActivation\];' "$VIEW"
if grep -q 'countdown\|tickTimer\|activationTimer' "$VIEW"; then
    echo "FAIL: activation UI still contains an artificial countdown"
    exit 1
fi

grep -q 'markSuspendedKeepingCode' "$CLIENT"
if sed -n '/isExplicitSuspensionResult/,/return/p' "$CLIENT" | grep -q 'clearStoredLicense'; then
    echo "FAIL: device recovery and suspension errors must retain the locally saved code"
    exit 1
fi

grep -q 'SecItemUpdate' "$CLIENT"
if sed -n '/+ (BOOL)saveToKeychain:/,/^}/p' "$CLIENT" | grep -q 'SecItemDelete'; then
    echo "FAIL: Keychain save must not delete the existing value before replacement"
    exit 1
fi

echo "License connection and recovery static test: passed"
