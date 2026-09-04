#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
MASTER="$PROJECT_DIR/WolFoxMaster.mm"
THEME="$PROJECT_DIR/WolFoxProTheme.m"

require_literal() {
    local file="$1"
    local literal="$2"
    local message="$3"
    if ! rg -F -- "$literal" "$file" >/dev/null; then
        echo "❌ $message"
        exit 1
    fi
}

require_literal "$THEME" 'UIAccessibilityIsReduceMotionEnabled()' "يجب احترام تقليل الحركة في iOS"
require_literal "$THEME" 'WF_REDUCE_MOTION' "يجب دعم خيار تقليل الحركة داخل WolFox"
require_literal "$THEME" 'UIFontMetrics' "يجب دعم النص الديناميكي"
require_literal "$THEME" 'WF_DYNAMIC_TYPE_ENABLED' "يجب حفظ تفضيل حجم النص"
require_literal "$MASTER" 'UIContentSizeCategoryDidChangeNotification' "يجب تحديث الواجهة عند تغير حجم النص"
require_literal "$MASTER" 'adjustsFontForContentSizeCategory = YES;' "يجب تفعيل استجابة عناصر النص"
require_literal "$MASTER" 'UIScrollViewKeyboardDismissModeInteractive' "يجب تحسين التمرير مع لوحة المفاتيح"
require_literal "$MASTER" 'w < 340.0 ? 10.0 : 15.0' "يجب استخدام هوامش مناسبة للشاشات الصغيرة"

if rg -n 'animateWithDuration:[0-9]' "$MASTER" >/dev/null; then
    echo "❌ توجد حركة لا تمر عبر إعداد تقليل الحركة"
    exit 1
fi

echo "✅ إعدادات الوصول والنص الديناميكي وتقليل الحركة متسقة."
