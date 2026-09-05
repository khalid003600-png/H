#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
HEADER="$PROJECT_DIR/WFNetworkPairingStore.h"
STORE="$PROJECT_DIR/WFNetworkPairingStore.m"

require() {
    grep -Fq "$2" "$1" || { echo "❌ $3"; exit 1; }
    echo "✅ $3"
}
reject() {
    if grep -Eq "$2" "$1"; then echo "❌ $3"; exit 1; fi
    echo "✅ $3"
}

require "$STORE" "kSecClassGenericPassword" "الأسرار تستخدم Keychain"
require "$STORE" "kSecAttrAccessibleWhenUnlockedThisDeviceOnly" "الأسرار مرتبطة بالجهاز ومتاحة بعد فتحه فقط"
require "$STORE" "SecTrustEvaluateWithError" "ثقة SSL للنظام إلزامية"
require "$STORE" "SecCertificateCopyData" "قراءة شهادة الخادم للتثبيت"
require "$STORE" "CC_SHA256" "بصمة الشهادة SHA-256"
require "$STORE" "difference |= a[i] ^ b[i]" "مقارنة البصمة ثابتة الزمن"
require "$STORE" "pin.length == 64" "صيغة بصمة SSL محكومة"
require "$STORE" "automaticReconnectProfiles" "الاتصال التلقائي محصور بالملفات المصرح بها"
require "$STORE" "SecItemDelete" "حذف أسرار الملف من Keychain"
reject "$STORE" "(NSLog|WFLog).*secret" "لا تُكتب الأسرار في السجلات"
reject "$STORE" "set(Object|Value):secret" "لا تُحفظ الأسرار في NSUserDefaults"
reject "$STORE" "allowsAnyHTTPSCertificate|setAllowsAnyHTTPSCertificate|kCFStreamSSLAllowsAnyRoot" "لا يوجد تجاوز للتحقق من SSL"

echo "✅ اجتاز تخزين الاقتران الشبكي مراجعة الأمن الثابتة."
