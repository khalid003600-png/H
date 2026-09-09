#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#ifndef WF_TWEAK_VERSION
#define WF_TWEAK_VERSION @"غير محدد"
#endif

static const void *WFAArabicGestureKey = &WFAArabicGestureKey;

static BOOL WFAKeyAllowedForTransfer(NSString *key) {
    if (![key isKindOfClass:NSString.class] || !key.length) return NO;
    NSString *k = key.lowercaseString;
    NSArray *blocked = @[@"license", @"token", @"secret", @"password", @"authorization", @"project_key", @"project-key", @"device_uuid", @"device_id", @"cookie"];
    for (NSString *part in blocked) if ([k containsString:part]) return NO;
    return [key hasPrefix:@"WF_"] || [key hasPrefix:@"WOLFOX_"];
}

static NSDictionary *WFASafeSettingsSnapshot(void) {
    NSDictionary *all = NSUserDefaults.standardUserDefaults.dictionaryRepresentation;
    NSMutableDictionary *safe = [NSMutableDictionary dictionary];
    [all enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        if (!WFAKeyAllowedForTransfer(key)) return;
        if ([NSJSONSerialization isValidJSONObject:@{key:value ?: [NSNull null]}]) safe[key] = value ?: [NSNull null];
    }];
    return safe;
}

static void WFAShowMessage(UIViewController *vc, NSString *title, NSString *message) {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
    [vc presentViewController:a animated:YES completion:nil];
}

static void WFAExportSettings(UIViewController *vc) {
    NSDictionary *root = @{ @"الصيغة": @"WolFox-إعدادات-1", @"الإعدادات": WFASafeSettingsSnapshot() };
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:root options:NSJSONWritingPrettyPrinted error:&error];
    if (!data || error) { WFAShowMessage(vc, @"تصدير الإعدادات", @"تعذر تصدير الإعدادات."); return; }
    UIPasteboard.generalPasteboard.string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    WFAShowMessage(vc, @"تصدير الإعدادات", @"تم نسخ الإعدادات الآمنة إلى الحافظة. لا يتم تصدير بيانات الترخيص أو الرموز السرية.");
}

static void WFAImportSettings(UIViewController *vc) {
    NSString *text = UIPasteboard.generalPasteboard.string;
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    if (!data.length) { WFAShowMessage(vc, @"استيراد الإعدادات", @"الحافظة فارغة."); return; }
    NSError *error = nil;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error || ![obj isKindOfClass:NSDictionary.class] || ![obj[@"الصيغة"] isEqual:@"WolFox-إعدادات-1"] || ![obj[@"الإعدادات"] isKindOfClass:NSDictionary.class]) {
        WFAShowMessage(vc, @"استيراد الإعدادات", @"البيانات الموجودة في الحافظة ليست إعدادات WolFox صالحة."); return;
    }
    NSDictionary *settings = obj[@"الإعدادات"];
    [settings enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        if (!WFAKeyAllowedForTransfer(key)) return;
        if (value == [NSNull null]) [NSUserDefaults.standardUserDefaults removeObjectForKey:key];
        else [NSUserDefaults.standardUserDefaults setObject:value forKey:key];
    }];
    [NSUserDefaults.standardUserDefaults synchronize];
    WFAShowMessage(vc, @"استيراد الإعدادات", @"تم استيراد الإعدادات الآمنة. أغلق الواجهة وافتحها لتحديث جميع العناصر.");
}

static void WFAArabicMenu(UIViewController *vc) {
#if WOLFOX_LITE
    NSString *edition = @"WolFox لايت";
#else
    NSString *edition = @"WolFox فل";
#endif
    NSString *message = [NSString stringWithFormat:@"النسخة: %@\nالإصدار: %@", edition, WF_TWEAK_VERSION];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"إضافات WolFox" message:message preferredStyle:UIAlertControllerStyleActionSheet];
    [a addAction:[UIAlertAction actionWithTitle:@"تصدير الإعدادات الآمنة" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *x){ WFAExportSettings(vc); }]];
    [a addAction:[UIAlertAction actionWithTitle:@"استيراد الإعدادات الآمنة" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *x){ WFAImportSettings(vc); }]];
    [a addAction:[UIAlertAction actionWithTitle:@"حول الإصدار" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *x){ WFAShowMessage(vc, @"حول الإصدار", message); }]];
    [a addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    if (a.popoverPresentationController) { a.popoverPresentationController.sourceView = vc.view; a.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(vc.view.bounds), CGRectGetMidY(vc.view.bounds), 1, 1); }
    [vc presentViewController:a animated:YES completion:nil];
}

static void WFAArabicGestureFired(UILongPressGestureRecognizer *g) {
    if (g.state != UIGestureRecognizerStateBegan) return;
    UIViewController *vc = (UIViewController *)g.view.nextResponder;
    while (vc && ![vc isKindOfClass:UIViewController.class]) vc = (UIViewController *)[(UIResponder *)vc nextResponder];
    if (vc) WFAArabicMenu(vc);
}

static void (*WFAOriginalViewDidAppear)(id, SEL, BOOL) = NULL;
static void WFAViewDidAppear(id self, SEL _cmd, BOOL animated) {
    if (WFAOriginalViewDidAppear) WFAOriginalViewDidAppear(self, _cmd, animated);
    if (![self isKindOfClass:UIViewController.class]) return;
    UIViewController *vc = (UIViewController *)self;
    if (objc_getAssociatedObject(vc, WFAArabicGestureKey)) return;
    UILongPressGestureRecognizer *g = [[UILongPressGestureRecognizer alloc] initWithTarget:[NSBlockOperation blockOperationWithBlock:^{}] action:NULL];
    g.minimumPressDuration = 0.8;
    g.numberOfTouchesRequired = 2;
    [g addTarget:(id)vc action:@selector(wfa_handleArabicEnhancementGesture:)];
    [vc.view addGestureRecognizer:g];
    objc_setAssociatedObject(vc, WFAArabicGestureKey, g, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@interface UIViewController (WFAArabicEnhancementGesture)
- (void)wfa_handleArabicEnhancementGesture:(UILongPressGestureRecognizer *)gesture;
@end
@implementation UIViewController (WFAArabicEnhancementGesture)
- (void)wfa_handleArabicEnhancementGesture:(UILongPressGestureRecognizer *)gesture { WFAArabicGestureFired(gesture); }
@end

__attribute__((constructor)) static void WFAInstallArabicEnhancements(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"WolFoxMainViewController");
        Method m = class_getInstanceMethod(cls, @selector(viewDidAppear:));
        if (!cls || !m) return;
        WFAOriginalViewDidAppear = (void (*)(id,SEL,BOOL))method_getImplementation(m);
        method_setImplementation(m, (IMP)WFAViewDidAppear);
    });
}
