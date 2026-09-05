# WolFox Jailbreak Edition

هذا الفرع مخصص لنسخة الجيلبريك من WolFox.

## الفرع

`feature/jailbreak-edition`

## الهدف

- بناء حزم DEB لأنظمة الجيلبريك.
- دعم Rootful و Rootless من نفس المصدر.
- استخدام arm64 مع iOS 15.8+ حسب سياسة المشروع الحالية.
- إبقاء نسخة الجيلبريك منفصلة عن نسخة Full/Lite الأساسية.
- الاستفادة من نظام البحث الموحد الموجود في فرع `feature/unified-gps-search` كأساس للتطوير.

## البناء

البناء القياسي:

```bash
make package
```

أو مباشرة:

```bash
WOLFOX_EDITION=Full WOLFOX_VERSION=1.8.6-Jailbreak ./build_v1_deb.sh
```

المخرجات المستهدفة:

- Rootful DEB
- Rootless DEB

## ملاحظات

ملف `build_v1_deb.sh` الحالي يحتوي بالفعل على مسار موحد لتجهيز حزم Rootful وRootless، لذلك هذا الفرع يعتمد عليه بدل إنشاء نظام بناء مكرر.
