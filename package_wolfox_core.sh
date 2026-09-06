#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

VERSION="${WOLFOX_CORE_VERSION:-1.0.0}"
DYLIB="$ROOT/WolFoxCore.dylib"
DPKG_DEB="${DPKG_DEB:-$(command -v dpkg-deb || true)}"

[ -s "$DYLIB" ] || { echo "missing WolFoxCore.dylib"; exit 1; }
[ -n "$DPKG_DEB" ] || { echo "missing dpkg-deb"; exit 1; }

build_pkg() {
  local mode="$1"
  local pkgroot="$ROOT/.wolfox-core-pkg-${mode,,}"
  local out="$ROOT/WolFoxCore-v${VERSION}-${mode}.deb"
  local install_dir

  rm -rf "$pkgroot"
  mkdir -p "$pkgroot/DEBIAN"

  if [ "$mode" = "Rootful" ]; then
    install_dir="$pkgroot/usr/lib/WolFox"
  else
    install_dir="$pkgroot/var/jb/usr/lib/WolFox"
  fi
  mkdir -p "$install_dir"
  install -m 0755 "$DYLIB" "$install_dir/WolFoxCore.dylib"

  cat > "$pkgroot/DEBIAN/control" <<EOF
Package: com.wolfox.core
Name: WolFox Framework Core
Version: $VERSION
Architecture: iphoneos-arm64
Description: Shared WolFox runtime core for licensing and location services.
Maintainer: WolFox
Section: Tweaks
EOF

  "$DPKG_DEB" -Zgzip --root-owner-group -b "$pkgroot" "$out"
  test -s "$out"
  "$DPKG_DEB" --info "$out" >/dev/null
  echo "built $out"
}

build_pkg Rootful
build_pkg Rootless
sha256sum WolFoxCore.dylib WolFoxCore-v${VERSION}-Rootful.deb WolFoxCore-v${VERSION}-Rootless.deb > SHA256SUMS-WolFoxCore.txt
cat SHA256SUMS-WolFoxCore.txt
