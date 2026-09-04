#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
STORE="$PROJECT_DIR/WolFoxProStore.m"

require_literal() {
    local literal="$1"
    local message="$2"
    if ! rg -F -- "$literal" "$STORE" >/dev/null; then
        echo "❌ $message"
        exit 1
    fi
}

require_literal 'if (![rawIdentifier isKindOfClass:[NSDictionary class]]) continue;' "يجب تجاهل سجلات المعرّفات التالفة"
require_literal 'if (_mutableIdentifiers.count >= 50) break;' "يجب تقييد عدد المعرّفات المحفوظة"
require_literal 'if (!profileUUID || [seenBleUUIDs containsObject:profileUUID.UUIDString]) continue;' "يجب رفض UUID Bluetooth غير الصالح والمكرر"
require_literal 'p.rssi = MAX(-127, MIN(20, rawRSSI));' "يجب تقييد RSSI ضمن نطاق آمن"
require_literal 'if (self.activeBleProfileID.length && !activeProfileFound) {' "يجب إيقاف ملف Bluetooth النشط إذا فُقد"
require_literal 'while (self.savedBleProfiles.count > 25)' "يجب تقييد ملفات Bluetooth المحفوظة"
require_literal 'if (!CLLocationCoordinate2DIsValid(self.targetRouteCoords)) {' "يجب تصحيح هدف المسار التالف"
require_literal 'if (self.spoofedImagePath.length && ![[NSFileManager defaultManager] fileExistsAtPath:self.spoofedImagePath]) {' "يجب تعطيل صورة الكاميرا المفقودة"
require_literal 'self.mediaUploadActive = NO;' "يجب إيقاف تزييف الوسائط عند فقدان الصورة"

echo "✅ سلامة المعرّفات وBluetooth والكاميرا والهدف المحفوظ سليمة."
