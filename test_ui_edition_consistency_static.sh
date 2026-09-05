#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
MASTER="$PROJECT_DIR/WolFoxMaster.mm"
ACTIVATION="$PROJECT_DIR/WFActivationViewController.m"
CONFIG="$PROJECT_DIR/WFLicenseConfig.h"

check() { grep -Fq "$2" "$1" || { echo "❌ $3"; exit 1; }; echo "✅ $3"; }
reject() { if grep -Fq "$2" "$1"; then echo "❌ $3"; exit 1; fi; echo "✅ $3"; }

check "$MASTER" '_titleLabel.text = @"WolFox Lite";' "اسم Lite معتمد في الواجهة الرئيسية"
check "$MASTER" '_titleLabel.text = @"WolFox Full";' "اسم Full معتمد في الواجهة الرئيسية"
check "$MASTER" 'NSString *onboardingEdition = @"WOLFOX LITE";' "عداد الجولة يعرض Lite الصحيح"
check "$MASTER" 'NSString *onboardingEdition = @"WOLFOX FULL";' "عداد الجولة يعرض Full الصحيح"
check "$MASTER" 'displayVersion = [NSString stringWithFormat:@"WolFox %@ v%@"' "عرض الإصدار والنسخة ديناميكي"
reject "$MASTER" 'Fake GPS Wolf' "لا يوجد اسم منتج قديم ظاهر للمستخدم"
check "$ACTIVATION" 'showToolHeightConstraint.constant = 0.0;' "طي أزرار النجاح عند الفشل"
check "$ACTIVATION" 'exclamationmark.triangle.fill' "أيقونة الفشل واضحة"
check "$ACTIVATION" 'تعذّر تفعيل الكود' "رسالة الفشل عربية وواضحة"
check "$CONFIG" 'WF_TWEAK_VERSION @"1.8.6-Full"' "الإصدار الأساسي 1.8.6"

echo "✅ اجتاز اتساق واجهة Full/Lite اختبارات الحماية."
