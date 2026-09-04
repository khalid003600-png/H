#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERIFY="$PROJECT_DIR/verify_release_artifacts.sh"
WORKFLOW="$PROJECT_DIR/.github/workflows/build.yml"

require_literal() {
    local file="$1"
    local literal="$2"
    local message="$3"
    if ! rg -F -- "$literal" "$file" >/dev/null; then
        echo "❌ $message"
        exit 1
    fi
}

require_literal "$VERIFY" "Mach-O.*arm64" "يجب فحص شريحة arm64"
require_literal "$VERIFY" 'iphoneos-arm64' "يجب فحص معمارية حزم Debian"
require_literal "$VERIFY" './Library/MobileSubstrate/DynamicLibraries/WolFox[.]dylib' "يجب فحص مسار Rootful"
require_literal "$VERIFY" './var/jb/Library/MobileSubstrate/DynamicLibraries/WolFox[.]dylib' "يجب فحص مسار Rootless"
require_literal "$VERIFY" 'cmp -s "$DYLIB"' "يجب مقارنة الملف التنفيذي داخل الحزمتين"
require_literal "$VERIFY" 'sha256sum' "يجب إنتاج بصمات SHA-256"
require_literal "$WORKFLOW" './verify_release_artifacts.sh' "يجب تشغيل بوابة الحزم في GitHub Actions"
require_literal "$WORKFLOW" 'SHA256SUMS' "يجب رفع بصمات الحزم"
require_literal "$WORKFLOW" 'BUILD_MANIFEST.txt' "يجب رفع بيان البناء"

echo "✅ بوابة إصدار الحزم مضبوطة."
