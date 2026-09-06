#!/bin/bash
set -euo pipefail
umask 077

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

# Runtime target: iOS 15.8 through iOS 26.5
WOLFOX_EDITION="${WOLFOX_EDITION:-Full}"
VERSION="${WOLFOX_VERSION:-2.0.0}"
if [ "$WOLFOX_EDITION" = "Lite" ]; then
    PRODUCT_NAME="WolFoxLite"
    PACKAGE_ID="com.wolfox.gpspro.lite"
    PACKAGE_TITLE="WolFox Lite"
else
    PRODUCT_NAME="WolFox"
    PACKAGE_ID="com.wolfox.gpspro"
    PACKAGE_TITLE="FAKE GPS WFX"
fi

# Clang deployment target is 15.0; supported packaged runtime starts at 15.8.
MIN_IOS="${MIN_IOS:-15.0}"
MAX_TARGET_IOS="26.5"
REQUIRED_SDK_VERSION="${REQUIRED_SDK_VERSION:-16.5}"
export THEOS="${THEOS:-/home/ubuntu/theos}"
export PATH="$THEOS/bin:$PATH"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"
SDK_PATH="${SDKROOT:-${SDK_PATH:-$THEOS/sdks/iPhoneOS${REQUIRED_SDK_VERSION}.sdk}}"
THEOS_INC="$THEOS/include"
BUILD_DIR="$PROJECT_DIR/.wolfox-build"
OUTPUT_DYLIB="$PROJECT_DIR/$PRODUCT_NAME.dylib"
WOLFOX_ARCHS="${WOLFOX_ARCHS:-arm64}"
GENERATED_LICENSE_CONFIG="$BUILD_DIR/WFLicenseGeneratedConfig.h"

if [ "$MIN_IOS" != "15.0" ]; then echo "❌ MIN_IOS يجب أن يكون 15.0"; exit 1; fi
if [ "$WOLFOX_ARCHS" != "arm64" ]; then echo "❌ arm64 فقط"; exit 1; fi
if [ ! -d "$SDK_PATH" ]; then echo "❌ SDK غير موجود: $SDK_PATH"; exit 1; fi

SDK_BASENAME="$(basename "$SDK_PATH")"
if [[ "$SDK_BASENAME" =~ ^iPhoneOS([0-9]+([.][0-9]+)*)[.]sdk$ ]]; then
    SDK_VERSION="${BASH_REMATCH[1]}"
else
    echo "❌ تعذر تحديد إصدار SDK: $SDK_BASENAME"
    exit 1
fi
version_at_least() {
    local actual="$1" required="$2"
    [ "$(printf '%s\n' "$required" "$actual" | sort -V | head -n 1)" = "$required" ]
}
if ! version_at_least "$SDK_VERSION" "$REQUIRED_SDK_VERSION"; then
    echo "❌ SDK $SDK_VERSION أقدم من المطلوب $REQUIRED_SDK_VERSION"
    exit 1
fi

CC="${CC:-/usr/bin/clang}"
CXX="${CXX:-/usr/bin/clang++}"
DPKG_DEB="${DPKG_DEB:-$(command -v dpkg-deb || true)}"
LDID="${LDID:-/usr/local/bin/ldid}"
if [ ! -x "$LDID" ]; then LDID="$(command -v ldid || true)"; fi
[ -n "$DPKG_DEB" ] || { echo "❌ dpkg-deb غير متوفر"; exit 1; }
if [ "${WOLFOX_REQUIRE_SIGNING:-1}" != "0" ] && [ -z "$LDID" ]; then
    echo "❌ ldid مطلوب للبناء النهائي"
    exit 1
fi

DPKG_BUILD_FLAGS=(-Zgzip)
if "$DPKG_DEB" --help 2>&1 | grep -q -- '--root-owner-group'; then
    DPKG_BUILD_FLAGS+=(--root-owner-group)
elif [ "$(id -u)" != "0" ] && [ -z "${FAKEROOTKEY:-}" ]; then
    echo "❌ يلزم --root-owner-group أو fakeroot"
    exit 1
fi

# منع الحقن العام: لا يُبنى أي فلتر دون Bundle IDs محددة.
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
        echo "❌ Bundle ID غير صالح: $value"; exit 1
    fi
    local existing
    for existing in "${TARGET_BUNDLES[@]:-}"; do [ "$existing" = "$value" ] && return 0; done
    TARGET_BUNDLES+=("$value")
}
if [ -n "$TARGET_BUNDLE_IDS" ]; then
    IFS=',' read -r -a REQUESTED_BUNDLES <<< "$TARGET_BUNDLE_IDS"
    for bundle in "${REQUESTED_BUNDLES[@]}"; do add_target_bundle "$bundle"; done
elif [ -f "$TARGET_BUNDLES_FILE" ]; then
    while IFS= read -r bundle || [ -n "$bundle" ]; do add_target_bundle "$bundle"; done < "$TARGET_BUNDLES_FILE"
else
    echo "❌ لا توجد Bundle IDs؛ تم منع الحقن العام"
    exit 1
fi
[ "${#TARGET_BUNDLES[@]}" -gt 0 ] || { echo "❌ لا توجد Bundle IDs صالحة؛ تم منع الحقن العام"; exit 1; }

FILES=("WFRedactedLogger.m" "WFNetworkPairingStore.m" "WFVirtualCameraManager.mm" "WolFoxProCellModel.m" "WolFoxProTheme.m" "WolFoxProStore.m" "WFSpoofScheduleManager.m" "WFLicenseClient.m" "WFActivationViewController.m" "WolFoxProHookManager.m" "WolFoxIntegrated.mm" "WolFoxMaster.mm")
for file in "${FILES[@]}"; do [ -f "$PROJECT_DIR/$file" ] || { echo "❌ ملف مفقود: $file"; exit 1; }; done

COMMON_FLAGS=(-isysroot "$SDK_PATH" -I"$THEOS_INC" -I"$PROJECT_DIR" -I"$PROJECT_DIR/sdk_compat_headers" -include "$GENERATED_LICENSE_CONFIG" -miphoneos-version-min="$MIN_IOS" -fobjc-arc -fobjc-exceptions -fblocks -O2 -Wall -Wextra -Werror=return-type -Wno-deprecated-declarations -Wno-unused-parameter -Wno-unused-function)
BASE_LINK_FLAGS=(-fuse-ld=lld -isysroot "$SDK_PATH" -miphoneos-version-min="$MIN_IOS" -dynamiclib -install_name "@rpath/$PRODUCT_NAME.dylib" -Wl,-ObjC -Wl,-undefined,dynamic_lookup -framework UIKit -framework Foundation -framework CoreLocation -framework CoreBluetooth -framework MapKit -framework Security -framework Photos -framework PhotosUI -framework AVFoundation -framework CoreMedia -framework CoreVideo -framework QuartzCore -framework AdSupport -framework WebKit -framework UserNotifications -lsqlite3)
LINK_FLAGS=("${BASE_LINK_FLAGS[@]}")
[ "$WOLFOX_EDITION" = "Lite" ] && COMMON_FLAGS+=(-DWOLFOX_LITE=1)
if [ "${WOLFOX_HARDENING:-1}" != "0" ]; then
    COMMON_FLAGS+=(-fvisibility=hidden -fno-common -fstack-protector-strong)
    LINK_FLAGS+=(-Wl,-dead_strip -Wl,-x -Wl,-S)
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " $PACKAGE_TITLE v$VERSION — iOS 15.8 إلى iOS $MAX_TARGET_IOS"
echo " SDK: $SDK_BASENAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

rm -rf "$BUILD_DIR"; mkdir -p "$BUILD_DIR"
escape_objc_string() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
PANEL_BASE_URL_VALUE="${WOLFOX_PANEL_BASE_URL:-https://gps.p3nd.fun/api/v1}"
PROJECT_KEY_VALUE="${WOLFOX_PROJECT_KEY:-}"
PROJECT_BUNDLE_ID_VALUE="${WOLFOX_PROJECT_BUNDLE_ID:-com.wolfox.gpspro}"
[[ "$PANEL_BASE_URL_VALUE" == https://* ]] || { echo "❌ رابط اللوحة يجب أن يكون HTTPS"; exit 1; }
[ -n "$PROJECT_KEY_VALUE" ] || { echo "❌ WOLFOX_PROJECT_KEY مفقود"; exit 1; }
cat > "$GENERATED_LICENSE_CONFIG" <<EOF
#define WOLFOX_LICENSE_BASE_URL @"$(escape_objc_string "$PANEL_BASE_URL_VALUE")"
#define WOLFOX_LICENSE_PROJECT_KEY @"$(escape_objc_string "$PROJECT_KEY_VALUE")"
#define WOLFOX_LICENSE_PROJECT_BUNDLE_ID @"$(escape_objc_string "$PROJECT_BUNDLE_ID_VALUE")"
printf '#define WF_TWEAK_VERSION @"%s"\n' "$(escape_objc_string "$VERSION")"
#define WOLFOX_LICENSE_APP_VERSION @"$(escape_objc_string "$VERSION")"
EOF
chmod 0600 "$GENERATED_LICENSE_CONFIG"

build_arch() {
    local arch="$1" target="${1}-apple-ios${MIN_IOS}" arch_dir="$BUILD_DIR/$1"
    local objects=()
    mkdir -p "$arch_dir"
    for file in "${FILES[@]}"; do
        local object="$arch_dir/${file%.*}.o"
        "$CC" -target "$target" "${COMMON_FLAGS[@]}" -c "$PROJECT_DIR/$file" -o "$object"
        objects+=("$object")
    done
    "$CXX" -target "$target" "${LINK_FLAGS[@]}" -o "$arch_dir/WolFox.dylib" "${objects[@]}"
}

build_arch arm64
cp "$BUILD_DIR/arm64/WolFox.dylib" "$OUTPUT_DYLIB"
if [ -n "$LDID" ]; then "$LDID" -S "$OUTPUT_DYLIB"; fi

make_deb() {
    local mode="$1" root="$BUILD_DIR/pkg-$1" prefix=""
    rm -rf "$root"; mkdir -p "$root/DEBIAN"
    if [ "$mode" = "rootless" ]; then prefix="$root/var/jb"; else prefix="$root"; fi
    mkdir -p "$prefix/Library/MobileSubstrate/DynamicLibraries"
    cp "$OUTPUT_DYLIB" "$prefix/Library/MobileSubstrate/DynamicLibraries/$PRODUCT_NAME.dylib"
    chmod 0644 "$prefix/Library/MobileSubstrate/DynamicLibraries/$PRODUCT_NAME.dylib"
    cat > "$prefix/Library/MobileSubstrate/DynamicLibraries/$PRODUCT_NAME.plist" <<EOF
{ Filter = { Bundles = ( $(printf '"%s",' "${TARGET_BUNDLES[@]}" | sed 's/,$//') ); }; }
EOF
    chmod 0644 "$prefix/Library/MobileSubstrate/DynamicLibraries/$PRODUCT_NAME.plist"
    cat > "$root/DEBIAN/control" <<EOF
Package: $PACKAGE_ID
Name: $PACKAGE_TITLE
Version: $VERSION
Architecture: iphoneos-arm
Depends: firmware (>= 15.8)
Description: $PACKAGE_TITLE
Maintainer: WFX
Author: WFX
Section: Tweaks
EOF
    cat > "$root/DEBIAN/postinst" <<'EOF'
#!/bin/sh
if command -v sbreload >/dev/null 2>&1; then
    sbreload || true
elif command -v killall >/dev/null 2>&1; then
    killall -9 SpringBoard 2>/dev/null || true
fi
exit 0
EOF
    chmod 0644 "$root/DEBIAN/control"
    chmod 0755 "$root/DEBIAN/postinst"
    chmod 0755 "$root" "$root/DEBIAN"
    find "$prefix/Library" -type d -exec chmod 0755 {} +
    local out
    if [ "$mode" = "rootless" ]; then
        out="$PROJECT_DIR/${PRODUCT_NAME}_v${VERSION}_iOS15.8-26.5_Rootless.deb"
    else
        out="$PROJECT_DIR/${PRODUCT_NAME}_v${VERSION}_iOS15.8-26.5_Rootful.deb"
    fi
    "$DPKG_DEB" "${DPKG_BUILD_FLAGS[@]}" --build "$root" "$out"
    echo "✅ $out"
}
make_deb rootful
make_deb rootless
