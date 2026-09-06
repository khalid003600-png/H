#!/bin/bash
set -euo pipefail
# المخرجات المؤقتة وملفات الحزم لا تحتاج صلاحيات عامة أثناء البناء.
umask 077

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

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
CC="${CC:-/usr/bin/clang}"; CXX="${CXX:-/usr/bin/clang++}"; DPKG_DEB="${DPKG_DEB:-$(command -v dpkg-deb || true)}"; LDID="${LDID:-/usr/local/bin/ldid}"
if [ ! -x "$LDID" ]; then LDID="$(command -v ldid || true)"; fi
DPKG_BUILD_FLAGS=(-Zgzip)
if "$DPKG_DEB" --help 2>&1 | grep -q -- '--root-owner-group'; then DPKG_BUILD_FLAGS+=(--root-owner-group); fi
TARGET_BUNDLES_FILE="${TARGET_BUNDLES_FILE:-$PROJECT_DIR/WolFoxTargetBundles.txt}"
TARGET_BUNDLE_IDS="${WOLFOX_TARGET_BUNDLE_IDS:-}"
TARGET_BUNDLES=()
add_target_bundle(){ local value="$1"; value="${value#"${value%%[![:space:]]*}"}"; value="${value%"${value##*[![:space:]]}"}"; [ -z "$value" ] && return 0; [[ "$value" == \#* ]] && return 0; TARGET_BUNDLES+=("$value"); }
if [ -n "$TARGET_BUNDLE_IDS" ]; then IFS=',' read -r -a REQUESTED_BUNDLES <<< "$TARGET_BUNDLE_IDS"; for bundle in "${REQUESTED_BUNDLES[@]}"; do add_target_bundle "$bundle"; done; elif [ -f "$TARGET_BUNDLES_FILE" ]; then while IFS= read -r bundle || [ -n "$bundle" ]; do add_target_bundle "$bundle"; done < "$TARGET_BUNDLES_FILE"; else echo "❌ لا توجد Bundle IDs"; exit 1; fi
FILES=("WFRedactedLogger.m" "WFNetworkPairingStore.m" "WFVirtualCameraManager.mm" "WolFoxProCellModel.m" "WolFoxProTheme.m" "WolFoxProStore.m" "WFSpoofScheduleManager.m" "WFLicenseClient.m" "WFActivationViewController.m" "WolFoxProHookManager.m" "WolFoxIntegrated.mm" "WolFoxMaster.mm")
for file in "${FILES[@]}"; do [ -f "$PROJECT_DIR/$file" ] || { echo "❌ ملف مفقود: $file"; exit 1; }; done
COMMON_FLAGS=(-isysroot "$SDK_PATH" -I"$THEOS_INC" -I"$PROJECT_DIR" -I"$PROJECT_DIR/sdk_compat_headers" -include "$GENERATED_LICENSE_CONFIG" -miphoneos-version-min="$MIN_IOS" -fobjc-arc -fobjc-exceptions -fblocks -O2 -Wall -Wextra -Werror=return-type -Wno-deprecated-declarations -Wno-unused-parameter -Wno-unused-function)
BASE_LINK_FLAGS=(-fuse-ld=lld -isysroot "$SDK_PATH" -miphoneos-version-min="$MIN_IOS" -dynamiclib -install_name "@rpath/$PRODUCT_NAME.dylib" -Wl,-ObjC -Wl,-undefined,dynamic_lookup -framework UIKit -framework Foundation -framework CoreLocation -framework CoreBluetooth -framework MapKit -framework Security -framework Photos -framework PhotosUI -framework AVFoundation -framework CoreMedia -framework CoreVideo -framework QuartzCore -framework AdSupport -framework WebKit -framework UserNotifications -lsqlite3)
LINK_FLAGS=("${BASE_LINK_FLAGS[@]}"); [ "$WOLFOX_EDITION" = "Lite" ] && COMMON_FLAGS+=(-DWOLFOX_LITE=1)
if [ "${WOLFOX_HARDENING:-1}" != "0" ]; then COMMON_FLAGS+=(-fvisibility=hidden -fno-common -fstack-protector-strong); LINK_FLAGS+=(-Wl,-dead_strip -Wl,-x -Wl,-S); fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; echo " FAKE GPS WFX v$VERSION — iOS $MIN_IOS إلى iOS $MAX_TARGET_IOS"; echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
rm -rf "$BUILD_DIR"; mkdir -p "$BUILD_DIR"
escape_objc_string(){ printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
PANEL_BASE_URL_VALUE="${WOLFOX_PANEL_BASE_URL:-https://gps.p3nd.fun/api/v1}"; PROJECT_KEY_VALUE="${WOLFOX_PROJECT_KEY:-}"; PROJECT_BUNDLE_ID_VALUE="${WOLFOX_PROJECT_BUNDLE_ID:-com.wolfox.gpspro}"
cat > "$GENERATED_LICENSE_CONFIG" <<EOF
#define WOLFOX_LICENSE_BASE_URL @"$(escape_objc_string "$PANEL_BASE_URL_VALUE")"
#define WOLFOX_LICENSE_PROJECT_KEY @"$(escape_objc_string "$PROJECT_KEY_VALUE")"
#define WOLFOX_LICENSE_PROJECT_BUNDLE_ID @"$(escape_objc_string "$PROJECT_BUNDLE_ID_VALUE")"
EOF
build_arch(){ local arch="$1" target="${1}-apple-ios${MIN_IOS}" arch_dir="$BUILD_DIR/$1"; mkdir -p "$arch_dir"; local objects=(); for file in "${FILES[@]}"; do local object="$arch_dir/${file%.*}.o"; "$CC" -target "$target" "${COMMON_FLAGS[@]}" -c "$PROJECT_DIR/$file" -o "$object"; objects+=("$object"); done; "$CXX" -target "$target" "${LINK_FLAGS[@]}" -o "$arch_dir/WolFox.dylib" "${objects[@]}"; }
build_arch arm64
cp "$BUILD_DIR/arm64/WolFox.dylib" "$OUTPUT_DYLIB"
[ -n "$LDID" ] && "$LDID" -S "$OUTPUT_DYLIB"
make_deb(){ local mode="$1" root="$BUILD_DIR/pkg-$mode" prefix; rm -rf "$root"; mkdir -p "$root/DEBIAN"; if [ "$mode" = rootless ]; then prefix="$root/var/jb"; else prefix="$root"; fi; mkdir -p "$prefix/Library/MobileSubstrate/DynamicLibraries"; cp "$OUTPUT_DYLIB" "$prefix/Library/MobileSubstrate/DynamicLibraries/$PRODUCT_NAME.dylib"; cat > "$prefix/Library/MobileSubstrate/DynamicLibraries/$PRODUCT_NAME.plist" <<EOF
{ Filter = { Bundles = ( $(printf '"%s",' "${TARGET_BUNDLES[@]}" | sed 's/,$//') ); }; }
EOF
cat > "$root/DEBIAN/control" <<EOF
Package: $PACKAGE_ID
Name: $PACKAGE_TITLE
Version: $VERSION
Architecture: iphoneos-arm
Description: FAKE GPS WFX Full
Maintainer: WFX
Author: WFX
Section: Tweaks
EOF
local out="$PROJECT_DIR/${PRODUCT_NAME}_v${VERSION}_iOS15.8-26.5_${mode^}.deb"; "$DPKG_DEB" "${DPKG_BUILD_FLAGS[@]}" --build "$root" "$out"; echo "✅ $out"; }
make_deb rootful
make_deb rootless
