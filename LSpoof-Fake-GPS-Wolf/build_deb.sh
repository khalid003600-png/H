#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

VERSION="${FGW_VERSION:-1.8.6}"
PACKAGE_ID="${FGW_PACKAGE_ID:-com.fakegpswolf.lspoof}"
NAME="Fake GPS Wolf LSpoof"
OUT_DIR="$PROJECT_DIR/packages"
BUILD_DIR="$PROJECT_DIR/.deb-build"

rm -rf "$OUT_DIR" "$BUILD_DIR"
mkdir -p "$OUT_DIR" "$BUILD_DIR"

: "${THEOS:?Set THEOS to your Theos installation path}"

make clean
make FINALPACKAGE=1

DYLIB="$(find .theos -type f -name 'LocationSpoofer.dylib' | head -n 1)"
if [[ -z "$DYLIB" || ! -f "$DYLIB" ]]; then
  echo "error: LocationSpoofer.dylib was not produced" >&2
  exit 1
fi

build_deb() {
  local scheme="$1"
  local prefix="$2"
  local suffix="$3"
  local stage="$BUILD_DIR/$scheme"
  local install_dir="$stage${prefix}/Library/Application Support/Fake GPS Wolf"

  mkdir -p "$stage/DEBIAN" "$install_dir"
  install -m 0755 "$DYLIB" "$install_dir/LocationSpoofer.dylib"
  install -m 0644 README.md "$install_dir/README.md"

  cat > "$stage/DEBIAN/control" <<CONTROL
Package: $PACKAGE_ID
Name: $NAME
Version: $VERSION
Architecture: iphoneos-arm
Description: Fake GPS Wolf LSpoof location library and UI resources.
Section: Tweaks
Priority: optional
Maintainer: Fake GPS Wolf
Author: Fake GPS Wolf
Depends: firmware (>= 15.0)
CONTROL

  dpkg-deb --root-owner-group -Zxz --build "$stage" "$OUT_DIR/FakeGPSWolf-LSpoof_${VERSION}_${suffix}.deb"
}

build_deb rootful "" "Rootful"
build_deb rootless "/var/jb" "Rootless"
cp "$DYLIB" "$OUT_DIR/LocationSpoofer.dylib"

printf '\nBuild complete:\n'
ls -lh "$OUT_DIR"
