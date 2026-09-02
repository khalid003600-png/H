#!/bin/bash
set -euo pipefail

INPUT="${1:-}"
OUTPUT_DIR="${2:-$PWD}"
ITERATIONS="${WOLFOX_PBKDF2_ITERATIONS:-250000}"

if [ -z "$INPUT" ]; then
    echo "الاستخدام: $0 WolFox_Source.zip.aes [مجلد_فك_الحزمة]"
    exit 1
fi
if [ ! -f "$INPUT" ]; then
    echo "❌ الحزمة غير موجودة: $INPUT"
    exit 1
fi
for COMMAND in openssl unzip; do
    if ! command -v "$COMMAND" >/dev/null 2>&1; then
        echo "❌ الأمر المطلوب غير متوفر: $COMMAND"
        exit 1
    fi
done
if ! openssl enc -help 2>&1 | grep -q -- '-pbkdf2'; then
    echo "❌ إصدار OpenSSL الحالي لا يدعم PBKDF2. استخدم OpenSSL 1.1.1 أو أحدث."
    exit 1
fi

PASSWORD="${WOLFOX_SOURCE_PASSWORD:-}"
if [ -z "$PASSWORD" ]; then
    if [ ! -t 0 ]; then
        echo "❌ عيّن WOLFOX_SOURCE_PASSWORD أو شغّل السكربت من طرفية تفاعلية."
        exit 1
    fi
    read -r -s -p "كلمة مرور الحزمة: " PASSWORD
    echo
fi

TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/wolfox-decrypt.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT
PLAIN_ZIP="$TEMP_ROOT/WolFox_Source.zip"

WOLFOX_OPENSSL_PASS="$PASSWORD" openssl enc \
    -d \
    -aes-256-cbc \
    -salt \
    -pbkdf2 \
    -iter "$ITERATIONS" \
    -md sha256 \
    -in "$INPUT" \
    -out "$PLAIN_ZIP" \
    -pass env:WOLFOX_OPENSSL_PASS

mkdir -p "$OUTPUT_DIR"
unzip -q "$PLAIN_ZIP" -d "$OUTPUT_DIR"
echo "✅ فُكّت الحزمة داخل: $OUTPUT_DIR"
