#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

PASS=0
FAIL=0

expect_pattern() {
    local label="$1"
    local pattern="$2"
    local file="$3"
    if rg -q -- "$pattern" "$file"; then
        echo "✅ $label"
        PASS=$((PASS + 1))
    else
        echo "❌ $label"
        FAIL=$((FAIL + 1))
    fi
}

expect_pattern "Runtime يبدأ من iOS 15.8" 'Runtime target: iOS 15[.]8 through iOS 26[.]5' build_v1_deb.sh
expect_pattern "Deployment Target متوافق مع Clang (15.0)" 'MIN_IOS="\$\{MIN_IOS:-15[.]0\}"' build_v1_deb.sh
expect_pattern "الحد الأعلى iOS 26.5" 'MAX_TARGET_IOS="26[.]5"' build_v1_deb.sh
expect_pattern "SDK النهائي المطلوب 16.5" 'REQUIRED_SDK_VERSION="\$\{REQUIRED_SDK_VERSION:-16[.]5\}"' build_v1_deb.sh
expect_pattern "Makefile يحدد TARGET المتوافق مع Clang" '^TARGET := iphone:latest:15[.]0$' Makefile
expect_pattern "Makefile يحدد arm64 فقط" '^ARCHS := arm64$' Makefile
expect_pattern "مسار arm64 فقط مفروض" 'WOLFOX_ARCHS="\$\{WOLFOX_ARCHS:-arm64\}"' build_v1_deb.sh
expect_pattern "بناء arm64 صريح" 'build_arch arm64' build_v1_deb.sh
expect_pattern "Makefile ينفذ سكربت البناء" 'WOLFOX_ARCHS=arm64.*build_v1_deb[.]sh' Makefile
expect_pattern "Makefile يوفّر اختبار Linux" '^test:' Makefile
expect_pattern "Makefile يوفّر تحقق البناء" '^verify:' Makefile
expect_pattern "فحص إصدار SDK قبل البناء" 'version_at_least "\$SDK_VERSION" "\$REQUIRED_SDK_VERSION"' build_v1_deb.sh
expect_pattern "Deployment Target يمر إلى clang" 'miphoneos-version-min="\$MIN_IOS"' build_v1_deb.sh
expect_pattern "توقيع dylib باستخدام ldid" '"\$LDID" -S "\$OUTPUT_DYLIB"' build_v1_deb.sh
expect_pattern "ملكية DEB تفرض root:root" 'DPKG_BUILD_FLAGS[+]?=?.*--root-owner-group|DPKG_BUILD_FLAGS\+=[(]--root-owner-group[)]' build_v1_deb.sh
expect_pattern "اعتماد firmware يبدأ من 15.8" 'Depends: firmware [(]>= 15[.]8[)]' build_v1_deb.sh
expect_pattern "اسم Rootful يتضمن النطاق الجديد" 'iOS15[.]8-26[.]5_Rootful[.]deb' build_v1_deb.sh
expect_pattern "اسم Rootless يتضمن النطاق الجديد" 'iOS15[.]8-26[.]5_Rootless[.]deb' build_v1_deb.sh
expect_pattern "فلترة Bundle IDs إلزامية" 'WOLFOX_TARGET_BUNDLE_IDS|WolFoxTargetBundles[.]txt' build_v1_deb.sh
expect_pattern "منع الحقن العام دون تطبيقات محددة" 'منع الحقن العام' build_v1_deb.sh
expect_pattern "توليد فلتر Bundles" 'Bundles = [(]' build_v1_deb.sh
expect_pattern "إجراء postinst لإعادة التحميل" 'sbreload' build_v1_deb.sh
expect_pattern "postinst قابل للتنفيذ" 'chmod 0755.*postinst' build_v1_deb.sh
expect_pattern "مصدر الكاميرا الافتراضية ضمن البناء" 'WFVirtualCameraManager[.]mm' build_v1_deb.sh
expect_pattern "ربط CoreMedia" 'framework CoreMedia' build_v1_deb.sh
expect_pattern "ربط CoreVideo" 'framework CoreVideo' build_v1_deb.sh

if rg -q 'iOS 14|iOS14|14[.]0|14–26|14-26' build_v1_deb.sh Makefile; then
    echo "❌ ما زال هناك مرجع قديم إلى iOS 14 في ملفات البناء"
    FAIL=$((FAIL + 1))
else
    echo "✅ لا توجد مراجع بناء قديمة إلى iOS 14"
    PASS=$((PASS + 1))
fi

if rg -q 'build_arch arm64e|llvm-lipo|WOLFOX_ARM64E' build_v1_deb.sh Makefile; then
    echo "❌ لا يزال تكوين arm64e أو الدمج العالمي موجوداً في مسار البناء المستقر"
    FAIL=$((FAIL + 1))
else
    echo "✅ مسار البناء لا يدمج arm64e غير متحققة"
    PASS=$((PASS + 1))
fi

echo "النتيجة: $PASS ناجح، $FAIL فاشل"
if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
