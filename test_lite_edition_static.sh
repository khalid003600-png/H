#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
MASTER="$PROJECT_DIR/WolFoxMaster.mm"
BUILD="$PROJECT_DIR/build_v1_deb.sh"
LITE_BUILD="$PROJECT_DIR/build_lite_deb.sh"

check() { grep -Fq "$2" "$1" || { echo "❌ $3"; exit 1; }; echo "✅ $3"; }

check "$MASTER" "#if WOLFOX_LITE" "وجود واجهة Lite المشروطة"
check "$MASTER" '@[@"location.fill", @"gearshape.fill"]' "Lite تعرض الموقع والإعدادات فقط"
check "$MASTER" '@[@"الموقع والمفضلة", @"الإعدادات والإخفاء"]' "توضيح أقسام Lite"
check "$MASTER" "if (candidate.tag == page)" "تنقل Lite الصحيح بين القسمين"
check "$MASTER" "BOOL active = store.spoofActive;" "حالة Lite تعتمد على تزييف الموقع فقط"
check "$BUILD" 'COMMON_FLAGS+=(-DWOLFOX_LITE=1)' "علامة Lite تضاف أثناء الترجمة"
check "$BUILD" 'PACKAGE_ID="com.wolfox.gpspro.lite"' "معرّف تثبيت مستقل لنسخة Lite"
check "$BUILD" 'printf '"'"'#define WF_TWEAK_VERSION @"%s"' "حقن رقم الإصدار حسب عملية البناء"
check "$LITE_BUILD" 'WOLFOX_VERSION="1.8.6-Lite"' "رقم Lite المستقل 1.8.6"
check "$LITE_BUILD" 'exec ./build_v1_deb.sh' "Lite تستخدم نفس مسار المصدر والبناء"

echo "✅ اجتازت بنية WolFox Lite اختبارات الفصل الآمن."
