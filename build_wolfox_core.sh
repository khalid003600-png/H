#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$ROOT/06_WolFox_Framework_Core"
THEOS="${THEOS:-$HOME/theos}"
SDKROOT="${SDKROOT:-$THEOS/sdks/iPhoneOS16.5.sdk}"
MIN_IOS="${MIN_IOS:-15.0}"
VERSION="${WOLFOX_CORE_VERSION:-1.0.0}"
CC="${CC:-/usr/bin/clang}"
LDID="${LDID:-$(command -v ldid || true)}"
BUILD="$ROOT/.wolfox-core-build"
OUT="$ROOT/WolFoxCore.dylib"

[ -d "$SDKROOT" ] || { echo "missing SDK: $SDKROOT"; exit 1; }
[ -x "$CC" ] || { echo "missing clang"; exit 1; }
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

FILES=(
  "$CORE_DIR/WolFoxCore.m"
  "$ROOT/WFRedactedLogger.m"
  "$ROOT/WolFoxProStore.m"
  "$ROOT/WFLicenseClient.m"
  "$ROOT/WolFoxProHookManager.m"
  "$ROOT/WolFoxProTheme.m"
)

OBJS=()
for src in "${FILES[@]}"; do
  [ -f "$src" ] || { echo "missing source: $src"; exit 1; }
  obj="$BUILD/$(basename "${src%.*}").o"
  "$CC" -target arm64-apple-ios${MIN_IOS} -isysroot "$SDKROOT" \
    -I"$ROOT" -I"$CORE_DIR" -I"$THEOS/include" -I"$ROOT/sdk_compat_headers" \
    -include "$BUILD/WFLicenseGeneratedConfig.h" -fobjc-arc -fblocks -O2 \
    -fvisibility=hidden -fstack-protector-strong -DWOLFOX_CORE_VERSION=\"$VERSION\" \
    -c "$src" -o "$obj"
  OBJS+=("$obj")
done

"$CC" -target arm64-apple-ios${MIN_IOS} -isysroot "$SDKROOT" -dynamiclib \
  -fuse-ld=lld -install_name /usr/lib/WolFox/WolFoxCore.dylib \
  -Wl,-dead_strip -Wl,-x -Wl,-S -Wl,-undefined,dynamic_lookup \
  -framework Foundation -framework UIKit -framework CoreLocation -framework MapKit \
  -framework Security -lsqlite3 "${OBJS[@]}" -o "$OUT"

"$LDID" -S "$OUT"
file "$OUT"
sha256sum "$OUT" > "$ROOT/SHA256SUMS-WolFoxCore.txt"
cat "$ROOT/SHA256SUMS-WolFoxCore.txt"
