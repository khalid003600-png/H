// WolFoxProTheme.m — v1.8.2 Dark Blue Panel UI
// تصميم آمن: خلفيات زرقاء داكنة، أزرق ساطع للتفاعل، وألوان حالة دلالية واضحة.
// فلسفة التصميم: تباين مرتفع، أسطح كحلية عميقة، وعدم استخدام البنفسجي أو الذهبي في الهوية.
#import "WolFoxProTheme.h"
#import "WolFoxProStore.h"

@implementation WolFoxProTheme

// themeIndex: 0 = داكن، 1 = فاتح
+ (BOOL)isDark { return [WolFoxProStore shared].themeIndex == 0; }

+ (UIColor *)windowBackground { return [self royalBackground]; }

// ── خلفيات البطاقات الزرقاء الداكنة ───────────────────────────
+ (UIColor *)surfacePrimary {
    return [self isDark]
        // داكن: أزرق كحلي يفصل البطاقة عن الخلفية
        ? [UIColor colorWithRed:0.035 green:0.075 blue:0.150 alpha:1.0]
        // فاتح: أبيض نقي للوضوح الكامل
        : [UIColor colorWithRed:1.000 green:1.000 blue:1.000 alpha:1.0];
}

+ (UIColor *)surfaceSecondary {
    return [self isDark]
        ? [UIColor colorWithRed:0.055 green:0.115 blue:0.230 alpha:1.0]
        : [UIColor colorWithRed:0.930 green:0.940 blue:0.950 alpha:1.0];
}

// ── نصوص ─────────────────────────────────────────────────────
+ (UIColor *)textPrimary {
    return [self isDark]
        // أبيض بارد مريح للعين وواضح على الخلفية الداكنة
        ? [UIColor colorWithRed:0.930 green:0.965 blue:1.000 alpha:1.0]
        // داكن جداً في الفاتح
        : [UIColor colorWithRed:0.080 green:0.100 blue:0.130 alpha:1.0];
}

+ (UIColor *)textSecondary {
    return [self isDark]
        ? [UIColor colorWithRed:0.620 green:0.735 blue:0.875 alpha:1.0]
        : [UIColor colorWithRed:0.380 green:0.430 blue:0.490 alpha:1.0];
}

// ── ألوان Dark Blue الأساسية عالية التباين ───────────────────
// accent: أزرق واضح للأزرار والتبويب النشط
+ (UIColor *)accent {
    return [self isDark]
        ? [UIColor colorWithRed:0.120 green:0.475 blue:0.925 alpha:1.0]  // أزرق داكن واضح
        : [UIColor colorWithRed:0.090 green:0.360 blue:0.760 alpha:1.0]; // أزرق للوضع الفاتح
}

// danger: أحمر وردي واضح للحالة الحرجة والتوقف
+ (UIColor *)danger {
    return [UIColor colorWithRed:1.000 green:0.333 blue:0.475 alpha:1.0]; // #F04545
}

// success: أخضر واضح للتفعيل
+ (UIColor *)success {
    return [UIColor colorWithRed:0.220 green:0.827 blue:0.624 alpha:1.0]; // #25BE74
}

// gold: alias أزرق فاتح للمفضلة والتمييز، مع إبقاء اسم API للتوافق
+ (UIColor *)gold {
    return [UIColor colorWithRed:0.260 green:0.650 blue:1.000 alpha:1.0]; // أزرق فاتح
}

// ── الخلفية الكحلية الداكنة ─────────────────────────────────
+ (UIColor *)royalBackground {
    return [self isDark]
        // داكن: كحلي عميق
        ? [UIColor colorWithRed:0.018 green:0.040 blue:0.085 alpha:1.0]
        // فاتح: رمادي ناعم جداً
        : [UIColor colorWithRed:0.950 green:0.955 blue:0.965 alpha:1.0];
}

+ (UIColor *)royalCard {
    // بطاقة داكنة: تعلو بوضوح فوق الخلفية الكحلية
    return [UIColor colorWithRed:0.035 green:0.075 blue:0.150 alpha:1.0];
}

+ (UIColor *)royalField {
    // حقل إدخال: أزرق أعمق قليلاً من البطاقة
    return [UIColor colorWithRed:0.045 green:0.100 blue:0.205 alpha:1.0];
}

+ (UIColor *)royalBlue {
    return [self accent];
}

// لون خلفية زر ثانوي (accent شفاف)
+ (UIColor *)accentSoft {
    return [[self accent] colorWithAlphaComponent:0.22];
}

+ (BOOL)reduceMotionEnabled {
    return UIAccessibilityIsReduceMotionEnabled() ||
           [NSUserDefaults.standardUserDefaults boolForKey:@"WF_REDUCE_MOTION"];
}

+ (NSTimeInterval)transitionDuration { return [self reduceMotionEnabled] ? 0.0 : 0.22; }

+ (UIFont *)fontOfSize:(double)size weight:(UIFontWeight)weight {
    UIFont *baseFont = [UIFont systemFontOfSize:size weight:weight];
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    BOOL dynamicTypeEnabled = [defaults objectForKey:@"WF_DYNAMIC_TYPE_ENABLED"] == nil ||
                              [defaults boolForKey:@"WF_DYNAMIC_TYPE_ENABLED"];
    if (!dynamicTypeEnabled) return baseFont;
    UIFontMetrics *metrics = [UIFontMetrics metricsForTextStyle:UIFontTextStyleBody];
    return [metrics scaledFontForFont:baseFont maximumPointSize:MAX(size, size * 1.35)];
}

+ (UIBlurEffectStyle)blurStyle {
    if (@available(iOS 13.0, *)) {
        return [self isDark]
            ? UIBlurEffectStyleSystemMaterialDark
            : UIBlurEffectStyleSystemMaterialLight;
    }
    return UIBlurEffectStyleDark;
}

@end
