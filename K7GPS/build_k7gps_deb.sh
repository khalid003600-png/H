#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$PROJECT_DIR/K7GPS"
VERSION="${K7GPS_VERSION:-1.0.0}"
VARIANT="${K7GPS_VARIANT:-standalone}"
SAFE_VARIANT="$(printf '%s' "$VARIANT" | tr '/_' '--' | tr -cd 'A-Za-z0-9.-')"
PRODUCT="K7GPS-${SAFE_VARIANT}"
PACKAGE_ID="com.wfx.k7gps.${SAFE_VARIANT}"
TARGET_IDS="${K7GPS_TARGET_BUNDLE_IDS:-sa.gov.moia.mosques2,sa.gov.moia.mosques-2}"
THEOS="${THEOS:-$PROJECT_DIR/.theos}"
SDKROOT="${SDKROOT:-$THEOS/sdks/iPhoneOS16.5.sdk}"
MIN_IOS="${MIN_IOS:-15.0}"
BUILD="$PROJECT_DIR/.k7gps-build"
CC="${CC:-/usr/bin/clang}"
FILES=(K7GPSViewController.m K7GPSStore.m K7GPSEngine.m K7GPSBootstrap.m)
for f in "${FILES[@]}"; do test -s "$SRC_DIR/$f" || { echo "Missing $f"; exit 1; }; done
test -d "$SDKROOT" || { echo "Missing SDK: $SDKROOT"; exit 1; }
rm -rf "$BUILD" && mkdir -p "$BUILD/obj"
FLAGS=(-target arm64-apple-ios${MIN_IOS} -isysroot "$SDKROOT" -I"$SRC_DIR" -fobjc-arc -fblocks -O2 -Wall -Wextra -Wno-deprecated-declarations -Wno-unused-parameter)
FRAMEWORKS=(-framework UIKit -framework Foundation -framework MapKit -framework CoreLocation -framework Photos -framework PhotosUI -framework QuartzCore)
OBJS=()
for f in "${FILES[@]}"; do o="$BUILD/obj/${f%.*}.o"; "$CC" "${FLAGS[@]}" -c "$SRC_DIR/$f" -o "$o"; OBJS+=("$o"); done
"$CC" -target arm64-apple-ios${MIN_IOS} -isysroot "$SDKROOT" -dynamiclib -fuse-ld=lld -install_name "@rpath/K7GPS.dylib" "${OBJS[@]}" "${FRAMEWORKS[@]}" -o "$PROJECT_DIR/K7GPS.dylib"
IFS=',' read -r -a BUNDLES <<< "$TARGET_IDS"; FILTER=""; for b in "${BUNDLES[@]}"; do FILTER+="\"$b\","; done; FILTER="${FILTER%,}"
make_deb(){ mode="$1"; root="$BUILD/pkg-$mode"; rm -rf "$root"; mkdir -p "$root/DEBIAN"; prefix="$root"; [ "$mode" = rootless ] && prefix="$root/var/jb"; mkdir -p "$prefix/Library/MobileSubstrate/DynamicLibraries"; cp "$PROJECT_DIR/K7GPS.dylib" "$prefix/Library/MobileSubstrate/DynamicLibraries/K7GPS.dylib"; printf '{ Filter = { Bundles = ( %s ); }; }\n' "$FILTER" > "$prefix/Library/MobileSubstrate/DynamicLibraries/K7GPS.plist"; cat > "$root/DEBIAN/control" <<EOF
Package: $PACKAGE_ID
Name: K7GPS $SAFE_VARIANT
Version: $VERSION
Architecture: iphoneos-arm
Depends: firmware (>= 15.0)
Description: K7GPS standalone build - $SAFE_VARIANT
Maintainer: WFX
Author: WFX
Section: Tweaks
EOF
chmod 0755 "$root/DEBIAN"; chmod 0644 "$root/DEBIAN/control" "$prefix/Library/MobileSubstrate/DynamicLibraries/K7GPS.plist" "$prefix/Library/MobileSubstrate/DynamicLibraries/K7GPS.dylib"; out="$PROJECT_DIR/${PRODUCT}_v${VERSION}_${mode}.deb"; dpkg-deb --root-owner-group -Zgzip --build "$root" "$out"; }
make_deb rootful
make_deb rootless
sha256sum "$PROJECT_DIR/K7GPS.dylib" "$PROJECT_DIR/${PRODUCT}_v${VERSION}_rootful.deb" "$PROJECT_DIR/${PRODUCT}_v${VERSION}_rootless.deb" > "$PROJECT_DIR/K7GPS-SHA256SUMS.txt"
