#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

DYLIB="$PROJECT_DIR/WolFox.dylib"
ROOTFUL="$(find "$PROJECT_DIR" -maxdepth 1 -type f -name 'WolFox*_Rootful.deb' -print -quit)"
ROOTLESS="$(find "$PROJECT_DIR" -maxdepth 1 -type f -name 'WolFox*_Rootless.deb' -print -quit)"

fail() {
    echo "❌ $*"
    exit 1
}

[ -s "$DYLIB" ] || fail "WolFox.dylib مفقود أو فارغ"
[ -n "$ROOTFUL" ] && [ -s "$ROOTFUL" ] || fail "حزمة Rootful مفقودة أو فارغة"
[ -n "$ROOTLESS" ] && [ -s "$ROOTLESS" ] || fail "حزمة Rootless مفقودة أو فارغة"

file "$DYLIB" | rg -qi 'Mach-O.*arm64' || fail "الملف التنفيذي ليس Mach-O arm64"
[ "$(dpkg-deb -f "$ROOTFUL" Architecture)" = "iphoneos-arm64" ] || fail "معمارية Rootful غير صحيحة"
[ "$(dpkg-deb -f "$ROOTLESS" Architecture)" = "iphoneos-arm64" ] || fail "معمارية Rootless غير صحيحة"

dpkg-deb -c "$ROOTFUL" | rg -q ' ./Library/MobileSubstrate/DynamicLibraries/WolFox[.]dylib$' ||
    fail "مسار dylib داخل Rootful غير صحيح"
dpkg-deb -c "$ROOTLESS" | rg -q ' ./var/jb/Library/MobileSubstrate/DynamicLibraries/WolFox[.]dylib$' ||
    fail "مسار dylib داخل Rootless غير صحيح"

VERIFY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/wolfox-artifacts.XXXXXX")"
trap 'rm -rf "$VERIFY_DIR"' EXIT
mkdir -p "$VERIFY_DIR/rootful" "$VERIFY_DIR/rootless"
dpkg-deb -x "$ROOTFUL" "$VERIFY_DIR/rootful"
dpkg-deb -x "$ROOTLESS" "$VERIFY_DIR/rootless"
cmp -s "$DYLIB" "$VERIFY_DIR/rootful/Library/MobileSubstrate/DynamicLibraries/WolFox.dylib" ||
    fail "ملف Rootful لا يطابق WolFox.dylib المبني"
cmp -s "$DYLIB" "$VERIFY_DIR/rootless/var/jb/Library/MobileSubstrate/DynamicLibraries/WolFox.dylib" ||
    fail "ملف Rootless لا يطابق WolFox.dylib المبني"

sha256sum "$DYLIB" "$ROOTFUL" "$ROOTLESS" > "$PROJECT_DIR/SHA256SUMS"
{
    echo "WolFox 1.8.2-Full release artifact manifest"
    echo "Architecture: arm64"
    echo "Minimum runtime: iOS 15.8"
    echo "Rootful: $(basename "$ROOTFUL")"
    echo "Rootless: $(basename "$ROOTLESS")"
    echo "Binary: $(file -b "$DYLIB")"
    echo "Rootful package architecture: $(dpkg-deb -f "$ROOTFUL" Architecture)"
    echo "Rootless package architecture: $(dpkg-deb -f "$ROOTLESS" Architecture)"
} > "$PROJECT_DIR/BUILD_MANIFEST.txt"

echo "✅ تحقق Rootful/Rootless وarm64 وتطابق الملفات وSHA-256 بنجاح."
