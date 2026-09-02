// WolFoxProTheme.h
#import <UIKit/UIKit.h>

@interface WolFoxProTheme : NSObject

+ (UIColor *)windowBackground;
+ (BOOL)isDark;
+ (UIColor *)surfacePrimary;
+ (UIColor *)surfaceSecondary;
+ (UIColor *)textPrimary;
+ (UIColor *)textSecondary;
+ (UIColor *)accent;
+ (UIColor *)danger;
+ (UIColor *)success;
+ (UIColor *)gold;
+ (UIColor *)royalBackground;
+ (UIColor *)royalCard;
+ (UIColor *)royalField;
+ (UIColor *)royalBlue;
+ (UIColor *)accentSoft;
+ (NSTimeInterval)transitionDuration;
+ (BOOL)reduceMotionEnabled;

+ (UIFont *)fontOfSize:(double)size weight:(UIFontWeight)weight;
+ (UIBlurEffectStyle)blurStyle;

@end
