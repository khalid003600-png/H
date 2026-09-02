#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$PROJECT_DIR/linux_tests/virtual_camera_geometry_test.cpp"
BINARY="$(mktemp "$PROJECT_DIR/.virtual-camera-geometry.XXXXXX")"
trap 'rm -f "$BINARY"' EXIT

GXX="${CXX:-$(command -v g++)}"
if [ -z "$GXX" ]; then
    echo "❌ g++ غير متوفر لاختبار هندسة الكاميرا الافتراضية."
    exit 1
fi

"$GXX" -std=c++17 -O2 -Wall -Wextra -Werror "$SOURCE" -o "$BINARY"
"$BINARY"
echo "✅ اكتمل اختبار أبعاد الصورة الطولية على لينكس."
