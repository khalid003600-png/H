#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
THEOS="${THEOS:-$ROOT/.theos}"
SDKROOT="${SDKROOT:-$THEOS/sdks/iPhoneOS16.5.sdk}"
MIN_IOS="${MIN_IOS:-15.0}"
VERSION="${WOLFOX_VERSION:-2.0.0-Full}"
CC="${CC:-/usr/bin/clang}"
CXX="${CXX:-/usr/bin/clang++}"
LDID="${LDID:-$(command -v ldid || true)}"
BUILD="$ROOT/.wolfox-full-core-build"
OUT="$ROOT/WolFoxFullJailbreak.dylib"
CORE="$ROOT/WolFoxCore.dylib"

[ -d "$SDKROOT" ] || { echo "missing SDK: $SDKROOT"; exit 1; }
[ -s "$CORE" ] || { echo "missing WolFoxCore.dylib; run build_wolfox_core.sh first"; exit 1; }
[ -n "$LDID" ] && [ -x "$LDID" ] || { echo "missing ldid"; exit 1; }
[ -n "${WOLFOX_PROJECT_KEY:-}" ] || { echo "missing WOLFOX_PROJECT_KEY"; exit 1; }

rm -rf "$BUILD"
mkdir -p "$BUILD"

escape_objc_string() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
PANEL="$(escape_objc_string "${WOLFOX_PANEL_BASE_URL:-https://gps.p3nd.fun/api/v1}")"
KEY="$(escape_objc_string "$WOLFOX_PROJECT_KEY")"
BUNDLE="$(escape_objc_string "${WOLFOX_PROJECT_BUNDLE_ID:-com.wolfox.gpspro}")"
cat > "$BUILD/WFLicenseGeneratedConfig.h" <<EOF
#define WF_PANEL_BASE_URL @"$PANEL"
#define WF_PROJECT_KEY @"$KEY"
#define WF_PROJECT_BUNDLE_ID @"$BUNDLE"
#define WF_TWEAK_VERSION @"$VERSION"
EOF

# Shared implementations live only in WolFoxCore. This target keeps Full-only/UI pieces.
FILES=(
  WFNetworkPairingStore.m
  WFVirtualCameraManager.mm
  WolFoxProCellModel.m
  WFSpoofScheduleManager.m
  WFActivationViewController.m
  WolFoxIntegrated.mm
  WolFoxMaster.mm
)
OBJS=()
for src in "${FILES[@]}"; do
  [ -f "$src" ] || { echo "missing source: $src"; exit 1; }
  obj="$BUILD/${src%.*}.o"
  "$CC" -target arm64-apple-ios${MIN_IOS} -isysroot "$SDKROOT" \
    -I"$ROOT" -I"$ROOT/06_WolFox_Framework_Core" -I"$THEOS/include" -I"$ROOT/sdk_compat_headers" \
    -include "$BUILD/WFLicenseGeneratedConfig.h" -fobjc-arc -fobjc-exceptions -fblocks -O2 \
    -Wall -Wextra -Werror=return-type -Wno-deprecated-declarations -Wno-unused-parameter -Wno-unused-function \
    -fvisibility=hidden -fno-common -fstack-protector-strong -c "$src" -o "$obj"
  OBJS+=("$obj")
done

"$CXX" -target arm64-apple-ios${MIN_IOS} -isysroot "$SDKROOT" -dynamiclib -fuse-ld=lld \
  -install_name @rpath/WolFoxFullJailbreak.dylib \
  -L"$ROOT" -Wl,-rpath,/usr/lib/WolFox -Wl,-rpath,/var/jb/usr/lib/WolFox \
  -Wl,-needed_library,"$CORE" -Wl,-ObjC -Wl,-undefined,dynamic_lookup -Wl,-dead_strip -Wl,-x -Wl,-S \
  -framework UIKit -framework Foundation -framework CoreLocation -framework CoreBluetooth -framework MapKit \
  -framework Security -framework Photos -framework PhotosUI -framework AVFoundation -framework CoreMedia \
  -framework CoreVideo -framework QuartzCore -framework AdSupport -framework WebKit -framework UserNotifications \
  -lsqlite3 "${OBJS[@]}" -o "$OUT"
"$LDID" -S "$OUT"

repack() {
  local deb="$1"
  local work="$2"
  rm -rf "$work"
  dpkg-deb -R "$deb" "$work"
  local target
  target="$(find "$work" -type f -name '*.dylib' | head -n1)"
  [ -n "$target" ] || { echo "no dylib in $deb"; exit 1; }
  cp "$OUT" "$target"
  chmod 0755 "$target"
  local control="$work/DEBIAN/control"
  if grep -q '^Depends:' "$control"; then
    sed -i '/^Depends:/ { /com.wolfox.core/! s/$/, com.wolfox.core (>= 1.0.0)/; }' "$control"
  else
    printf '\nDepends: com.wolfox.core (>= 1.0.0)\n' >> "$control"
  fi
  chmod 0755 "$work/DEBIAN"
  chmod 0644 "$control"
  dpkg-deb --root-owner-group -Zgzip -b "$work" "$deb"
}

ROOTFUL="WolFox_v${VERSION}_iOS15.8-26.5_Rootful.deb"
ROOTLESS="WolFox_v${VERSION}_iOS15.8-26.5_Rootless.deb"
[ -s "$ROOTFUL" ] || { echo "missing base package: $ROOTFUL"; exit 1; }
[ -s "$ROOTLESS" ] || { echo "missing base package: $ROOTLESS"; exit 1; }
repack "$ROOTFUL" "$BUILD/rootful"
repack "$ROOTLESS" "$BUILD/rootless"

echo "Verifying Core dependency"
dpkg-deb -f "$ROOTFUL" Depends | grep -F 'com.wolfox.core'
dpkg-deb -f "$ROOTLESS" Depends | grep -F 'com.wolfox.core'
file "$OUT"
sha256sum "$OUT" "$ROOTFUL" "$ROOTLESS" > SHA256SUMS-Full-Jailbreak-Core.txt
cat SHA256SUMS-Full-Jailbreak-Core.txt
