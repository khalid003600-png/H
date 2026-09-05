#!/usr/bin/env bash
# WolFox Full/Lite — إعداد وبناء مشترك على Ubuntu 20.04/22.04/24.04.
# الناتج: حزمة Rootful وحزمة Rootless وملف WolFox.dylib موقّع ad-hoc.
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[WF]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*"; exit 1; }

SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
THEOS="${THEOS:-${HOME}/theos}"
SDK_VERSION="16.5"
COMPAT_SDK_VERSION="13.7"
SDK_RELEASE_TAG="master-146e41f"
SDK_RELEASE_BASE="https://github.com/theos/sdks/releases/download/${SDK_RELEASE_TAG}"
WOLFOX_EDITION="${WOLFOX_EDITION:-Full}"
WOLFOX_VERSION="${WOLFOX_VERSION:-1.8.6-Full}"
TARGET_BUNDLE_IDS="${WOLFOX_TARGET_BUNDLE_IDS:-sa.gov.moia.mosques-2}"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

echo
echo "╔══════════════════════════════════════════════╗"
echo "║  WolFox v${WOLFOX_VERSION} — Ubuntu Build Setup  ║"
echo "╚══════════════════════════════════════════════╝"
echo

if [ "$(uname -s)" != "Linux" ]; then
    error "هذا السكربت مخصص لنظام Linux/Ubuntu."
fi

if [ "$(id -u)" -eq 0 ]; then
    SUDO=()
elif command -v sudo >/dev/null 2>&1; then
    SUDO=(sudo)
else
    error "يلزم تشغيل السكربت كـ root أو توفير sudo لتثبيت المتطلبات."
fi

info "تثبيت متطلبات النظام..."
"${SUDO[@]}" apt-get update -qq
DEBIAN_FRONTEND=noninteractive "${SUDO[@]}" apt-get install -y -qq \
    build-essential ca-certificates clang curl dpkg-dev fakeroot file git \
    libplist-dev libssl-dev libxml2-dev lld llvm make patch perl pkg-config \
    python3 ripgrep unzip wget xz-utils zip zlib1g-dev
success "متطلبات النظام جاهزة"

if [ -d "$THEOS/.git" ]; then
    info "تحديث Theos الموجود..."
    git -C "$THEOS" pull --ff-only --quiet
    git -C "$THEOS" submodule update --init --recursive --depth 1
else
    info "تثبيت Theos..."
    git clone --quiet --depth 1 --recurse-submodules https://github.com/theos/theos.git "$THEOS"
fi
success "Theos: $THEOS"

SDK_DIR="$THEOS/sdks"
mkdir -p "$SDK_DIR"

install_sdk() {
    local version="$1"
    local destination="$SDK_DIR/iPhoneOS${version}.sdk"
    local archive="$TEMP_DIR/iPhoneOS${version}.sdk.tar.xz"

    if [ -d "$destination" ]; then
        success "SDK موجود: $destination"
        return 0
    fi

    info "تحميل iPhoneOS ${version} SDK..."
    curl --fail --location --retry 3 --retry-delay 2 \
        --output "$archive" \
        "$SDK_RELEASE_BASE/iPhoneOS${version}.sdk.tar.xz"
    tar -xJf "$archive" -C "$SDK_DIR"
    [ -d "$destination" ] || error "فشل فك iPhoneOS ${version} SDK."
    success "SDK مثبّت: $destination"
}

install_sdk "$SDK_VERSION"
SDK_PATH="$SDK_DIR/iPhoneOS${SDK_VERSION}.sdk"

# SDK 16.5 المنشور من Theos قد يفتقد WebKit headers/TBD. نأخذ هذه الملفات
# فقط من SDK 13.7 الرسمي في الإصدار نفسه، مع إبقاء هدف البناء على 16.5.
WEBKIT_PATH="$SDK_PATH/System/Library/Frameworks/WebKit.framework"
if [ ! -d "$WEBKIT_PATH/Headers" ] || [ ! -f "$WEBKIT_PATH/WebKit.tbd" ]; then
    warn "استكمال ملفات WebKit المتوافقة..."
    install_sdk "$COMPAT_SDK_VERSION"
    COMPAT_WEBKIT="$SDK_DIR/iPhoneOS${COMPAT_SDK_VERSION}.sdk/System/Library/Frameworks/WebKit.framework"
    mkdir -p "$WEBKIT_PATH"
    if [ ! -d "$WEBKIT_PATH/Headers" ] && [ -d "$COMPAT_WEBKIT/Headers" ]; then
        cp -a "$COMPAT_WEBKIT/Headers" "$WEBKIT_PATH/Headers"
    fi
    if [ ! -f "$WEBKIT_PATH/WebKit.tbd" ] && [ -f "$COMPAT_WEBKIT/WebKit.tbd" ]; then
        cp "$COMPAT_WEBKIT/WebKit.tbd" "$WEBKIT_PATH/WebKit.tbd"
    fi
fi
[ -d "$WEBKIT_PATH/Headers" ] || error "WebKit headers غير متوفرة بعد إعداد SDK."
[ -f "$WEBKIT_PATH/WebKit.tbd" ] || error "WebKit.tbd غير متوفر بعد إعداد SDK."

LDID_PATH="$(command -v ldid || true)"
if [ -z "$LDID_PATH" ]; then
    info "بناء ldid من المصدر..."
    git clone --quiet --depth 1 --recurse-submodules \
        https://github.com/ProcursusTeam/ldid.git "$TEMP_DIR/ldid"
    make -C "$TEMP_DIR/ldid" -j"$(nproc)"
    LDID_PATH="$TEMP_DIR/ldid/ldid"
fi
[ -x "$LDID_PATH" ] || error "تعذر تجهيز ldid."
success "ldid: $LDID_PATH"

info "تشغيل اختبارات Linux..."
chmod +x "$SOURCE_DIR"/*.sh "$SOURCE_DIR"/tools/*.sh
"$SOURCE_DIR/run_all_linux_tests.sh"

info "بدء بناء WolFox v${WOLFOX_VERSION}..."
THEOS="$THEOS" \
SDKROOT="$SDK_PATH" \
LDID="$LDID_PATH" \
MIN_IOS=15.0 \
REQUIRED_SDK_VERSION="$SDK_VERSION" \
WOLFOX_ARCHS=arm64 \
WOLFOX_EDITION="$WOLFOX_EDITION" \
WOLFOX_VERSION="$WOLFOX_VERSION" \
WOLFOX_TARGET_BUNDLE_IDS="$TARGET_BUNDLE_IDS" \
WOLFOX_REQUIRE_SIGNING=1 \
WOLFOX_HARDENING=1 \
    "$SOURCE_DIR/build_v1_deb.sh"

echo
success "اكتمل البناء بنجاح"
for output in "$SOURCE_DIR"/WolFox*.deb "$SOURCE_DIR"/WolFox*.dylib; do
    [ -f "$output" ] && echo "  ✅ $output ($(du -h "$output" | cut -f1))"
done
