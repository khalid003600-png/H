#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

export WOLFOX_EDITION="Lite"
export WOLFOX_VERSION="1.8.6-Lite"
# تستخدم Lite نفس مشروع الترخيص والكود المحفوظ؛ تختلف هوية حزمة التثبيت فقط.
exec ./build_v1_deb.sh
