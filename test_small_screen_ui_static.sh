#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
ACTIVATION="$PROJECT_DIR/WFActivationViewController.m"
MASTER="$PROJECT_DIR/WolFoxMaster.mm"

check() { grep -Fq "$2" "$1" || { echo "❌ $3"; exit 1; }; echo "✅ $3"; }
reject() { if grep -Fq "$2" "$1"; then echo "❌ $3"; exit 1; fi; echo "✅ $3"; }

check "$ACTIVATION" 'card.widthAnchor constraintEqualToAnchor:self.view.widthAnchor multiplier:0.90' "بطاقة التفعيل متجاوبة مع عرض الشاشة"
check "$ACTIVATION" 'card.widthAnchor constraintLessThanOrEqualToConstant:400' "بطاقة التفعيل لا تتمدد أكثر من الحد الآمن"
check "$ACTIVATION" 'self.cardCenterY.constant = -(keyboardHeight / 2.0) + 40' "تحريك البطاقة عند ظهور لوحة المفاتيح"
check "$ACTIVATION" 'self.cardCenterY.constant = 0' "إعادة البطاقة بعد إخفاء لوحة المفاتيح"
check "$ACTIVATION" 'self.statusLabel.numberOfLines = 0' "رسائل الحالة تقبل عدة أسطر"
check "$ACTIVATION" 'self.uuidLabel.numberOfLines = 0' "معرّف الجهاز يلتف على الشاشات الضيقة"
check "$ACTIVATION" 'self.showToolHeightConstraint.constant = 0.0' "طي عناصر النجاح في الحالة الفاشلة"
check "$MASTER" 'CGFloat width = self.view.bounds.size.width - 32.0' "بطاقة الجولة تراعي عرض الشاشة"
check "$MASTER" 'MAX(self.view.safeAreaInsets.bottom, 14.0)' "الجولة تراعي safe area السفلية"
check "$MASTER" 'self.view.bounds.size.width < 240.0' "منع عرض الجولة في عرض غير صالح"
check "$MASTER" '_scrollDashboard' "لوحة Full/Lite قابلة للتمرير عموديًا"
check "$MASTER" '#if WOLFOX_LITE' "اختبار فرع Lite مستقل"
check "$MASTER" 'CGRectMake(16.0, y, width, height)' "بطاقة الجولة تستخدم عرضًا ديناميكيًا"

echo "✅ اجتاز توافق واجهة Full/Lite مع الشاشات الصغيرة الفحص الثابت."
