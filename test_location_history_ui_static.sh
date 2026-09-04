#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
MASTER="$PROJECT_DIR/WolFoxMaster.mm"
STORE="$PROJECT_DIR/WolFoxProStore.m"
HEADER="$PROJECT_DIR/WolFoxProStore.h"

require_literal() {
    local file="$1"
    local literal="$2"
    local message="$3"
    rg -F -- "$literal" "$file" >/dev/null || { echo "❌ $message"; exit 1; }
}

require_literal "$STORE" 'postNotificationName:@"WF_LOCATION_HISTORY_CHANGED"' "يجب إشعار الواجهة عند تغير السجل"
require_literal "$MASTER" 'objc_setAssociatedObject(self, "_history_button"' "يجب الاحتفاظ بزر السجل للتحديث"
require_literal "$MASTER" '- (void)refreshLocationHistoryButton' "يجب تحديث عنوان وحالة زر السجل"
require_literal "$MASTER" 'recordLocationHistoryWithName:@"إحداثيات ملصقة"' "يجب تسجيل الإحداثيات الملصقة"
require_literal "$MASTER" 'routeButton.accessibilityLabel = @"بدء محاكاة المسار";' "يجب إعادة زر المسار بعد إيقافه"
require_literal "$HEADER" 'activeLocationID' "يجب تتبع المفضلة النشطة بهويتها"
require_literal "$MASTER" 'store.activeLocationID == location.ID' "يجب تعديل الموقع النشط بالمعرف لا بتطابق الإحداثيات"
require_literal "$MASTER" 'store.activeLocationID = l.ID;' "يجب تعيين المفضلة عند تفعيلها"
require_literal "$MASTER" 'store.activeLocationID = 0;' "يجب مسح ربط المفضلة في التفعيلات الأخرى"

echo "✅ تزامن السجل وهوية المفضلة وحالة زر المسار سليمة."
