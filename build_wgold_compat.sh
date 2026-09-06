#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
THEOS="${THEOS:-$ROOT/.theos}"
SDKROOT="${SDKROOT:-$THEOS/sdks/iPhoneOS16.5.sdk}"
CC="${CC:-/usr/bin/clang}"
LDID="${LDID:-$(command -v ldid || true)}"
OUT="$ROOT/WGoldCompat.dylib"
BUILD="$ROOT/.wgold-compat-build"

[ -d "$SDKROOT" ] || { echo "missing SDK: $SDKROOT"; exit 1; }
[ -x "$CC" ] || { echo "missing clang"; exit 1; }
[ -n "$LDID" ] && [ -x "$LDID" ] || { echo "missing ldid"; exit 1; }

rm -rf "$BUILD" && mkdir -p "$BUILD"
"$CC" -target arm64-apple-ios15.0 -isysroot "$SDKROOT" \
  -fobjc-arc -fblocks -O2 -fvisibility=hidden -fstack-protector-strong \
  -c "$ROOT/wgold/WGoldCompat.mm" -o "$BUILD/WGoldCompat.o"

"$CC" -target arm64-apple-ios15.0 -isysroot "$SDKROOT" -dynamiclib \
  -fuse-ld=lld -install_name /Library/MobileSubstrate/DynamicLibraries/WGoldCompat.dylib \
  -Wl,-dead_strip -Wl,-x -Wl,-S -Wl,-undefined,dynamic_lookup \
  -framework Foundation -framework UIKit \
  "$BUILD/WGoldCompat.o" -o "$OUT"

"$LDID" -S "$OUT"
file "$OUT"
sha256sum "$OUT" > "$ROOT/SHA256SUMS-WGoldCompat.txt"
cat "$ROOT/SHA256SUMS-WGoldCompat.txt"
