#!/bin/bash
set -euo pipefail
# المخرجات المؤقتة وملفات الحزم لا تحتاج صلاحيات عامة أثناء البناء.
umask 077

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

# Shared Full/Lite build. Full remains the default for backward compatibility.
# Runtime target: iOS 15.8 through iOS 26.5
# Build SDK: iPhoneOS 16.5. يظل Deployment Target عند iOS 15.8.
WOLFOX_EDITION="${WOLFOX_EDITION:-Full}"
VERSION="${WOLFOX_VERSION:-1.8.5-Full}"
if [ "$WOLFOX_EDITION" = "Lite" ]; then
    PRODUCT_NAME="WolFoxLite"
    PACKAGE_ID="com.wolfox.gpspro.lite"
    PACKAGE_TITLE="WolFox Lite"
else
    PRODUCT_NAME="WolFox"
    PACKAGE_ID="com.wolfox.gpspro"
    PACKAGE_TITLE="WolFox"
fi
# Clang يقبل X.Y فقط كـ deployment target — نستخدم 15.0 بدلاً من 15.8
# الكود نفسه يعمل على 15.8 لأنه لا يستخدم أي API فوق iOS 15.0
MIN_IOS="${MIN_IOS:-15.0}"
MAX_TARGET_IOS="26.5"
REQUIRED_SDK_VERSION="${REQUIRED_SDK_VERSION:-16.5}"
export THEOS="${THEOS:-/home/ubuntu/theos}"
export PATH="$THEOS/bin:$PATH"
# يعتمد هذا المسار المستقر على Clang النظام الحديث وSDK 16.5 النظيفة.
# لا يستخدم Toolchain Theos القديمة ولا يخلط ملفات من SDK أخرى.
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"

SDK_PATH="${SDKROOT:-${SDK_PATH:-$THEOS/sdks/iPhoneOS${REQUIRED_SDK_VERSION}.sdk}}"
THEOS_INC="$THEOS/include"
BUILD_DIR="$PROJECT_DIR/.wolfox-build"
OUTPUT_DYLIB="$PROJECT_DIR/$PRODUCT_NAME.dylib"
WOLFOX_ARCHS="${WOLFOX_ARCHS:-arm64}"
GENERATED_LICENSE_CONFIG="$BUILD_DIR/WFLicenseGeneratedConfig.h"

if [ "$MIN_IOS" != "15.0" ]; then
    echo "❌ MIN_IOS يجب أن يكون 15.0 في مسار البناء هذا (دعم التشغيل يبدأ من iOS 15.8)."
    exit 1
fi

if [ "$WOLFOX_ARCHS" != "arm64" ]; then
    echo "❌ هذا مسار البناء المستقر يتطلب arm64 فقط؛ لا تُضم arm64e من دون Toolchain تدعمها فعلياً."
    exit 1
fi

if [ ! -d "$SDK_PATH" ]; then
    echo "❌ لم يتم العثور على iPhoneOS SDK داخل: $THEOS/sdks"
    echo "   استخدم iPhoneOS${REQUIRED_SDK_VERSION}.sdk أو أحدث لبناء يستهدف iOS 15.8."
    exit 1
fi

SDK_BASENAME="$(basename "$SDK_PATH")"
if [[ "$SDK_BASENAME" =~ ^iPhoneOS([0-9]+([.][0-9]+)*)[.]sdk$ ]]; then
    SDK_VERSION="${BASH_REMATCH[1]}"
else
    echo "❌ تعذر تحديد إصدار SDK من الاسم: $SDK_BASENAME"
    echo "   استخدم اسماً مثل iPhoneOS${REQUIRED_SDK_VERSION}.sdk."
    exit 1
fi

version_at_least() {
    local actual="$1"
    local required="$2"
    [ "$(printf '%s\n' "$required" "$actual" | sort -V | head -n 1)" = "$required" ]
}

if ! version_at_least "$SDK_VERSION" "$REQUIRED_SDK_VERSION"; then
    if [ "${ALLOW_OLDER_SDK:-0}" = "1" ]; then
        echo "⚠️  بناء أولي فقط: SDK $SDK_VERSION أقدم من المطلوب $REQUIRED_SDK_VERSION."
    else
        echo "❌ SDK الحالي $SDK_VERSION أقدم من المطلوب $REQUIRED_SDK_VERSION."
        echo "   أضف iPhoneOS${REQUIRED_SDK_VERSION}.sdk أو استخدم ALLOW_OLDER_SDK=1 لبناء أولي غير معتمد."
        exit 1
    fi
fi

CC="${CC:-/usr/bin/clang}"
CXX="${CXX:-/usr/bin/clang++}"
DPKG_DEB="${DPKG_DEB:-$(command -v dpkg-deb || true)}"
LDID="${LDID:-/usr/local/bin/ldid}"

if [ ! -x "$LDID" ]; then LDID="$(command -v ldid || true)"; fi

if [ -z "$CC" ] || [ -z "$CXX" ]; then
    echo "❌ clang/clang++ غير متوفرين في Theos toolchain."
    exit 1
fi
if [ -z "$DPKG_DEB" ]; then
    echo "❌ dpkg-deb غير متوفر."
    exit 1
fi
if [ "${WOLFOX_REQUIRE_SIGNING:-1}" != "0" ] && [ -z "$LDID" ]; then
    echo "❌ ldid غير متوفر؛ التوقيع مطلوب للنسخة النهائية."
    echo "   ثبّت ldid أو استخدم WOLFOX_REQUIRE_SIGNING=0 لبناء أولي غير موقّع فقط."
    exit 1
fi

DPKG_BUILD_FLAGS=(-Zgzip)
if "$DPKG_DEB" --help 2>&1 | grep -q -- '--root-owner-group'; then
    DPKG_BUILD_FLAGS+=(--root-owner-group)
elif [ "$(id -u)" != "0" ] && [ -z "${FAKEROOTKEY:-}" ]; then
    echo "❌ dpkg-deb لا يدعم --root-owner-group والبناء ليس داخل fakeroot."
    echo "   شغّل: fakeroot ./build_v1_deb.sh"
    exit 1
fi

# يمنع البناء الحقن العام. عيّن التطبيقات المستهدفة بإحدى الطريقتين:
#   WOLFOX_TARGET_BUNDLE_IDS="com.example.app,com.example.second" ./build_v1_deb.sh
# أو أنشئ WolFoxTargetBundles.txt بجانب هذا السكربت، سطراً واحداً لكل Bundle ID.
TARGET_BUNDLES_FILE="${TARGET_BUNDLES_FILE:-$PROJECT_DIR/WolFoxTargetBundles.txt}"
TARGET_BUNDLE_IDS="${WOLFOX_TARGET_BUNDLE_IDS:-}"
TARGET_BUNDLES=()

add_target_bundle() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    [ -z "$value" ] && return 0
    [[ "$value" == \#* ]] && return 0
    if ! [[ "$value" =~ ^([A-Za-z0-9-]+\.)+[A-Za-z0-9-]+$ ]]; then
        echo "❌ Bundle ID غير صالح: $value"
        exit 1
    fi
    local existing
    for existing in "${TARGET_BUNDLES[@]:-}"; do
        [ "$existing" = "$value" ] && return 0
    done
    TARGET_BUNDLES+=("$value")
}

if [ -n "$TARGET_BUNDLE_IDS" ]; then
    IFS=',' read -r -a REQUESTED_BUNDLES <<< "$TARGET_BUNDLE_IDS"
    for bundle in "${REQUESTED_BUNDLES[@]}"; do add_target_bundle "$bundle"; done
elif [ -f "$TARGET_BUNDLES_FILE" ]; then
    while IFS= read -r bundle || [ -n "$bundle" ]; do add_target_bundle "$bundle"; done < "$TARGET_BUNDLES_FILE"
else
    echo "❌ لم تُحدّد Bundle IDs مستهدفة. تم إيقاف البناء لمنع الحقن العام."
    echo "   استخدم WOLFOX_TARGET_BUNDLE_IDS أو أنشئ: $TARGET_BUNDLES_FILE"
    exit 1
fi

if [ "${#TARGET_BUNDLES[@]}" -eq 0 ]; then
    echo "❌ لا توجد Bundle IDs صالحة للبناء. تم إيقاف البناء لمنع الحقن العام."
    exit 1
fi

FILES=(
    "WFRedactedLogger.m"
    "WFNetworkPairingStore.m"
    "WFVirtualCameraManager.mm"
    "WolFoxProCellModel.m"
    "WolFoxProTheme.m"
    "WolFoxProStore.m"
    "WFSpoofScheduleManager.m"
    "WFLicenseClient.m"
    "WFActivationViewController.m"
    "WolFoxProHookManager.m"
    "WolFoxIntegrated.mm"
    "WolFoxMaster.mm"
)

for file in "${FILES[@]}"; do
    if [ ! -f "$PROJECT_DIR/$file" ]; then
        echo "❌ ملف مفقود: $file"
        exit 1
    fi
done

# فحص الـ headers الأساسية أيضاً
REQUIRED_HEADERS=(
    "WFLicenseConfig.h"
    "WFVirtualCameraManager.h"
    "WolFoxProHookManager.h"
    "WolFoxProCellModel.h"
    "WFActivationViewController.h"
    "WFCompatibility.h"
    "WFLicenseClient.h"
    "WFSpoofScheduleManager.h"
    "WolFoxProStore.h"
    "WolFoxProTheme.h"
)
for hdr in "${REQUIRED_HEADERS[@]}"; do
    if [ ! -f "$PROJECT_DIR/$hdr" ]; then
        echo "❌ header مفقود: $hdr"
        exit 1
    fi
done
echo "✅ جميع ملفات المصدر والـ headers موجودة"

COMMON_FLAGS=(
    -isysroot "$SDK_PATH"
    -I"$THEOS_INC"
    -I"$PROJECT_DIR"
    -I"$PROJECT_DIR/sdk_compat_headers"
    -include "$GENERATED_LICENSE_CONFIG"
    -miphoneos-version-min="$MIN_IOS"
    -fobjc-arc
    -fobjc-exceptions
    -fblocks
    -O2
    -Wall
    -Wextra
    -Werror=return-type
    -Wno-deprecated-declarations
    -Wno-unused-parameter
    -Wno-unused-function
)

BASE_LINK_FLAGS=(
    -fuse-ld=lld
    -isysroot "$SDK_PATH"
    -miphoneos-version-min="$MIN_IOS"
    -dynamiclib
    -install_name "@rpath/$PRODUCT_NAME.dylib"
    -Wl,-ObjC
    -Wl,-undefined,dynamic_lookup
    -framework UIKit
    -framework Foundation
    -framework CoreLocation
    -framework CoreBluetooth
    -framework MapKit
    -framework Security
    -framework Photos
    -framework PhotosUI
    -framework AVFoundation
    -framework CoreMedia
    -framework CoreVideo
    -framework QuartzCore
    -framework AdSupport
    -framework WebKit
    -framework UserNotifications
    -lsqlite3
)
LINK_FLAGS=("${BASE_LINK_FLAGS[@]}")
if [ "$WOLFOX_EDITION" = "Lite" ]; then
    COMMON_FLAGS+=(-DWOLFOX_LITE=1)
fi

# تقوية آمنة للإصدار النهائي دون تغيير أسماء كلاسات Objective-C أو selectors
# التي تعتمد عليها الهوكات وقت التشغيل. يمكن تعطيلها فقط للتشخيص عبر:
# WOLFOX_HARDENING=0 ./build_v1_deb.sh
if [ "${WOLFOX_HARDENING:-1}" != "0" ]; then
    COMMON_FLAGS+=(
        -fvisibility=hidden
        -fno-common
        -fstack-protector-strong
    )
    LINK_FLAGS+=(
        -Wl,-dead_strip
        -Wl,-x
        -Wl,-S
    )
fi

build_arch() {
    local arch="$1"
    local target="${arch}-apple-ios${MIN_IOS}"
    local arch_dir="$BUILD_DIR/$arch"
    local objects=()
    mkdir -p "$arch_dir"

    echo "⚙  بناء شريحة $arch — target $target"
    for file in "${FILES[@]}"; do
        local object="$arch_dir/${file%.*}.o"
        "$CC" -target "$target" "${COMMON_FLAGS[@]}" -c "$PROJECT_DIR/$file" -o "$object" || return 1
        objects+=("$object")
    done

    if ! "$CXX" -target "$target" "${LINK_FLAGS[@]}" -o "$arch_dir/WolFox.dylib" "${objects[@]}"; then
        if [ "${WOLFOX_HARDENING:-1}" != "0" ] && [ "${WOLFOX_ALLOW_LINK_FALLBACK:-0}" = "1" ]; then
            echo "⚠️  ربط تشخيصي فقط: إعادة الربط دون تقوية بناءً على WOLFOX_ALLOW_LINK_FALLBACK=1."
            "$CXX" -target "$target" "${BASE_LINK_FLAGS[@]}" -o "$arch_dir/WolFox.dylib" "${objects[@]}" || return 1
        else
            echo "❌ فشل الربط المقوّى؛ تم إيقاف البناء لمنع إنتاج حزمة أخف حماية."
            echo "   استخدم WOLFOX_ALLOW_LINK_FALLBACK=1 فقط لتشخيص محلي غير قابل للتسليم."
            return 1
        fi
    fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " WolFox v$VERSION — iOS $MIN_IOS إلى iOS $MAX_TARGET_IOS"
echo " SDK: $(basename "$SDK_PATH")"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# رابط API عام، أما مفتاح المشروع فيجب حقنه من بيئة البناء ولا يُحفظ في المصدر.
escape_objc_string() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

PANEL_BASE_URL_VALUE="${WOLFOX_PANEL_BASE_URL:-https://gps.p3nd.fun/api/v1}"
PROJECT_KEY_VALUE="${WOLFOX_PROJECT_KEY:-}"
PROJECT_BUNDLE_ID_VALUE="${WOLFOX_PROJECT_BUNDLE_ID:-com.wolfox.gpspro}"

if [[ "$PANEL_BASE_URL_VALUE" != https://* ]]; then
    echo "❌ رابط لوحة الترخيص يجب أن يبدأ بـ https://"
    exit 1
fi
if [ -z "$PROJECT_KEY_VALUE" ] || [ -z "$PROJECT_BUNDLE_ID_VALUE" ]; then
    echo "❌ اضبط WOLFOX_PROJECT_KEY في GitHub Secrets قبل البناء؛ Bundle ID لا يمكن أن يكون فارغاً."
    exit 1
fi

PANEL_BASE_URL_ESCAPED="$(escape_objc_string "$PANEL_BASE_URL_VALUE")"
PROJECT_KEY_ESCAPED="$(escape_objc_string "$PROJECT_KEY_VALUE")"
PROJECT_BUNDLE_ID_ESCAPED="$(escape_objc_string "$PROJECT_BUNDLE_ID_VALUE")"
{
    printf '#define WF_PANEL_BASE_URL @"%s"\n' "$PANEL_BASE_URL_ESCAPED"
    printf '#define WF_PROJECT_KEY @"%s"\n' "$PROJECT_KEY_ESCAPED"
    printf '#define WF_PROJECT_BUNDLE_ID @"%s"\n' "$PROJECT_BUNDLE_ID_ESCAPED"
    printf '#define WF_TWEAK_VERSION @"%s"\n' "$VERSION"
} > "$GENERATED_LICENSE_CONFIG"
chmod 0600 "$GENERATED_LICENSE_CONFIG"

echo "✅ تم حقن إعدادات لوحة الترخيص من بيئة البناء دون حفظ المفتاح في المصدر."

build_arch arm64
cp "$BUILD_DIR/arm64/WolFox.dylib" "$OUTPUT_DYLIB"
echo "✅ Dylib: arm64"

if [ "${WOLFOX_REQUIRE_SIGNING:-1}" != "0" ]; then
    "$LDID" -S "$OUTPUT_DYLIB"
    echo "✅ تم توقيع WolFox.dylib توقيعاً ad-hoc باستخدام ldid"
else
    echo "⚠️  خرج WolFox.dylib بلا توقيع؛ هذه نسخة أولية غير معتمدة للتثبيت."
fi

make_package() {
    local scheme="$1"
    local prefix="$2"
    local architecture="$3"
    local output="$4"
    local package_dir="$BUILD_DIR/package_$scheme"
    local tweak_dir="$package_dir$prefix/Library/MobileSubstrate/DynamicLibraries"

    mkdir -p "$tweak_dir" "$package_dir/DEBIAN"
    # يتطلب dpkg-deb أن يكون DEBIAN قابلاً للعبور، كما تحتاج مسارات MobileSubstrate
    # إلى أذونات قراءة/عبور قياسية بعد التثبيت. تبقى ملفات البناء خارج الحزمة تحت umask المقيد.
    chmod 0755 "$package_dir" "$package_dir/DEBIAN"
    chmod 0755 "$tweak_dir" "$(dirname "$tweak_dir")" "$(dirname "$(dirname "$tweak_dir")")" "$(dirname "$(dirname "$(dirname "$tweak_dir")")")" "$(dirname "$(dirname "$(dirname "$(dirname "$tweak_dir")")")")"
    install -m 0755 "$OUTPUT_DYLIB" "$tweak_dir/$PRODUCT_NAME.dylib"

    {
        echo "{"
        echo "    Filter = {"
        echo "        Bundles = ("
        for bundle in "${TARGET_BUNDLES[@]}"; do
            printf '            "%s",\n' "$bundle"
        done
        echo "        );"
        echo "    };"
        echo "}"
    } > "$tweak_dir/$PRODUCT_NAME.plist"
    chmod 0644 "$tweak_dir/$PRODUCT_NAME.plist"

    cat > "$package_dir/DEBIAN/control" <<CTRL
Package: $PACKAGE_ID
Name: $PACKAGE_TITLE
Version: $VERSION
Architecture: $architecture
Description: $PACKAGE_TITLE iOS 15.8-26.5 arm64 — shared-source licensed edition.
Author: WolFox
Maintainer: WolFox
Section: Tweaks
Depends: firmware (>= 15.8), mobilesubstrate
CTRL

    cat > "$package_dir/DEBIAN/postinst" <<'POSTINST'
#!/bin/sh
# يعاد التحميل فقط إن وُجد sbreload؛ بخلاف ذلك يكفي إغلاق التطبيقات المستهدفة
# وفتحها من جديد ليحمّل MobileSubstrate التعديل ضمن نطاق Bundle IDs المحدد.
if [ -x /var/jb/usr/bin/sbreload ]; then
    /var/jb/usr/bin/sbreload || true
elif [ -x /usr/bin/sbreload ]; then
    /usr/bin/sbreload || true
fi
exit 0
POSTINST
    chmod 0755 "$package_dir/DEBIAN/postinst"

    "$DPKG_DEB" "${DPKG_BUILD_FLAGS[@]}" -b "$package_dir" "$output"
}

ROOTFUL_DEB="$PROJECT_DIR/${PRODUCT_NAME}_v${VERSION}_iOS15.8-26.5_Rootful.deb"
ROOTLESS_DEB="$PROJECT_DIR/${PRODUCT_NAME}_v${VERSION}_iOS15.8-26.5_Rootless.deb"

make_package rootful "" "iphoneos-arm64" "$ROOTFUL_DEB"
make_package rootless "/var/jb" "iphoneos-arm64" "$ROOTLESS_DEB"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ اكتمل البناء المتوافق"
echo " Rootful : $ROOTFUL_DEB"
echo " Rootless: $ROOTLESS_DEB"
echo " Minimum : iOS $MIN_IOS"
echo " Target  : iOS $MIN_IOS–$MAX_TARGET_IOS source compatibility"
echo " SDK     : iPhoneOS $SDK_VERSION (required >= $REQUIRED_SDK_VERSION)"
echo " Arch    : arm64 only"
echo " Signed  : $([ "${WOLFOX_REQUIRE_SIGNING:-1}" != "0" ] && echo yes || echo no)"
echo " Filter  : ${TARGET_BUNDLES[*]}"
echo " Protect : binary hardening ${WOLFOX_HARDENING:-1} (visibility/dead-strip/local symbols)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
