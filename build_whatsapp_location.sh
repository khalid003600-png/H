#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
VERSION="${WOLFOX_WHATSAPP_VERSION:-1.0.0}"
PRODUCT="WolFoxWhatsAppLocation"
PACKAGE_ID="com.wolfox.whatsapp.location"
TARGET_BUNDLE="net.whatsapp.WhatsApp"
MIN_IOS="${MIN_IOS:-15.0}"
SDK_VERSION="${REQUIRED_SDK_VERSION:-16.5}"
THEOS="${THEOS:-$HOME/theos}"
SDK="${SDKROOT:-$THEOS/sdks/iPhoneOS${SDK_VERSION}.sdk}"
LDID="${LDID:-$(command -v ldid || true)}"
BUILD="$ROOT/.wolfox-whatsapp-build"
GEN="$BUILD/WFLicenseGeneratedConfig.h"
OUT="$ROOT/$PRODUCT.dylib"

[ -d "$SDK" ] || { echo "missing SDK: $SDK"; exit 1; }
[ -n "$LDID" ] && [ -x "$LDID" ] || { echo "missing ldid"; exit 1; }

FILES=(
  WFRedactedLogger.m
  WolFoxProTheme.m
  WolFoxProStore.m
  WFLicenseClient.m
  WFActivationViewController.m
  WolFoxProHookManager.m
  whatsapp/WFWhatsAppLocationViewController.m
  whatsapp/WFWhatsAppLocationEntry.mm
)
for f in "${FILES[@]}"; do [ -f "$ROOT/$f" ] || { echo "missing source: $f"; exit 1; }; done

rm -rf "$BUILD"
mkdir -p "$BUILD/obj"

PANEL="${WOLFOX_PANEL_BASE_URL:-https://gps.p3nd.fun/api/v1}"
KEY="${WOLFOX_PROJECT_KEY:-}"
PROJECT_BUNDLE="${WOLFOX_PROJECT_BUNDLE_ID:-com.wolfox.gpspro}"
[ -n "$KEY" ] || { echo "WOLFOX_PROJECT_KEY is required"; exit 1; }
[[ "$PANEL" == https://* ]] || { echo "panel URL must use https"; exit 1; }
esc(){ printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
{
  printf '#define WF_PANEL_BASE_URL @"%s"\n' "$(esc "$PANEL")"
  printf '#define WF_PROJECT_KEY @"%s"\n' "$(esc "$KEY")"
  printf '#define WF_PROJECT_BUNDLE_ID @"%s"\n' "$(esc "$PROJECT_BUNDLE")"
  printf '#define WF_TWEAK_VERSION @"%s"\n' "$VERSION"
} > "$GEN"
chmod 600 "$GEN"

COMMON=(
  -target arm64-apple-ios${MIN_IOS}
  -isysroot "$SDK"
  -I"$THEOS/include"
  -I"$ROOT"
  -I"$ROOT/whatsapp"
  -I"$ROOT/sdk_compat_headers"
  -include "$GEN"
  -miphoneos-version-min="$MIN_IOS"
  -fobjc-arc -fobjc-exceptions -fblocks -O2
  -fvisibility=hidden -fno-common -fstack-protector-strong
  -Wall -Wextra -Werror=return-type -Wno-deprecated-declarations -Wno-unused-parameter -Wno-unused-function
)
OBJS=()
for f in "${FILES[@]}"; do
  base="$(basename "$f")"; obj="$BUILD/obj/${base%.*}.o"
  /usr/bin/clang "${COMMON[@]}" -c "$ROOT/$f" -o "$obj"
  OBJS+=("$obj")
done

/usr/bin/clang++ -target arm64-apple-ios${MIN_IOS} -fuse-ld=lld -isysroot "$SDK" \
  -miphoneos-version-min="$MIN_IOS" -dynamiclib -install_name "@rpath/$PRODUCT.dylib" \
  -Wl,-ObjC -Wl,-undefined,dynamic_lookup -Wl,-dead_strip -Wl,-x -Wl,-S \
  -framework UIKit -framework Foundation -framework CoreLocation -framework MapKit \
  -framework Security -framework QuartzCore -lsqlite3 \
  -o "$OUT" "${OBJS[@]}"

"$LDID" -S "$OUT"
file "$OUT"

package_one(){
  local mode="$1" prefix="$2" arch="$3" output="$4"
  local pkg="$BUILD/pkg-$mode"
  local dir="$pkg$prefix/Library/MobileSubstrate/DynamicLibraries"
  mkdir -p "$dir" "$pkg/DEBIAN"
  chmod 0755 "$pkg" "$pkg/DEBIAN" "$dir"
  install -m 0755 "$OUT" "$dir/$PRODUCT.dylib"
  cat > "$dir/$PRODUCT.plist" <<PLIST
{
  Filter = {
    Bundles = (
      "$TARGET_BUNDLE",
    );
  };
}
PLIST
  chmod 0644 "$dir/$PRODUCT.plist"
  cat > "$pkg/DEBIAN/control" <<CTRL
Package: $PACKAGE_ID
Name: WolFox WhatsApp Location
Version: $VERSION
Architecture: $arch
Description: Lightweight WolFox location spoofing extension for WhatsApp only.
Author: WolFox
Maintainer: WolFox
Section: Tweaks
Depends: firmware (>= 15.8), mobilesubstrate
CTRL
  cat > "$pkg/DEBIAN/postinst" <<'POST'
#!/bin/sh
if [ -x /var/jb/usr/bin/sbreload ]; then /var/jb/usr/bin/sbreload || true; elif [ -x /usr/bin/sbreload ]; then /usr/bin/sbreload || true; fi
exit 0
POST
  chmod 0755 "$pkg/DEBIAN/postinst"
  dpkg-deb --root-owner-group -Zgzip -b "$pkg" "$output"
}

RF="$ROOT/WolFox-WhatsApp-Location-v${VERSION}-iOS15.8-26.5-Rootful.deb"
RL="$ROOT/WolFox-WhatsApp-Location-v${VERSION}-iOS15.8-26.5-Rootless.deb"
package_one rootful "" iphoneos-arm64 "$RF"
package_one rootless "/var/jb" iphoneos-arm64 "$RL"

test -s "$OUT" && test -s "$RF" && test -s "$RL"
dpkg-deb --info "$RF" >/dev/null
dpkg-deb --info "$RL" >/dev/null
sha256sum "$OUT" "$RF" "$RL" > "$ROOT/SHA256SUMS-WhatsApp-Location.txt"
echo "WhatsApp Location build complete: $VERSION"
