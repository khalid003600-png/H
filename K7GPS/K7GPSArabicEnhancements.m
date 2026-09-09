#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "K7GPSViewController.h"
#import "K7GPSStore.h"
#import "K7GPSEnhancements.h"

static NSString * const K7GPSArabicVariant = @"الواجهة الرئيسية";
static NSString * const K7GPSArabicVersion = @"1.0.1";

@implementation K7GPSViewController (K7GPSArabicEnhancements)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class c = self;
        method_exchangeImplementations(class_getInstanceMethod(c, @selector(stopAllPressed)), class_getInstanceMethod(c, @selector(k7_ar_stopAllPressed)));
        method_exchangeImplementations(class_getInstanceMethod(c, @selector(customizePressed)), class_getInstanceMethod(c, @selector(k7_ar_customizePressed)));
        method_exchangeImplementations(class_getInstanceMethod(c, @selector(performSearch:)), class_getInstanceMethod(c, @selector(k7_ar_performSearch:)));
    });
}

- (void)k7_ar_stopAllPressed {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"تأكيد إيقاف الكل" message:@"سيتم إيقاف تغيير الموقع والصورة البديلة وأي وضع نشط. هل تريد المتابعة؟" preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"إيقاف الكل" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) { [self k7_ar_stopAllPressed]; }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)k7_ar_customizePressed {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"التخصيص والإعدادات" message:@"اختر الإجراء المطلوب" preferredStyle:UIAlertControllerStyleActionSheet];
    [a addAction:[UIAlertAction actionWithTitle:@"طريقة إظهار الأداة" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [self k7_ar_customizePressed]; }]];
    [a addAction:[UIAlertAction actionWithTitle:@"تصدير الإعدادات" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [self k7_ar_exportSettings]; }]];
    [a addAction:[UIAlertAction actionWithTitle:@"استيراد الإعدادات" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [self k7_ar_importSettings]; }]];
    [a addAction:[UIAlertAction actionWithTitle:@"حول الإصدار" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [self k7_ar_showAbout]; }]];
    [a addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    if (a.popoverPresentationController) { a.popoverPresentationController.sourceView = self.view; a.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1); }
    [self presentViewController:a animated:YES completion:nil];
}

- (void)k7_ar_showAbout {
    NSString *msg = [NSString stringWithFormat:@"K7GPS\nالنسخة: %@\nالإصدار: %@\nمتوافق مع iOS 15 فأحدث", K7GPSArabicVariant, K7GPSArabicVersion];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"حول الإصدار" message:msg preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (NSDictionary *)k7_ar_settingsDictionary {
    K7GPSStore *s = K7GPSStore.shared;
    NSMutableDictionary *d = [@{ @"locationEnabled": @(s.locationEnabled), @"cameraEnabled": @(s.cameraEnabled), @"revealMode": @(s.revealMode), @"selectedTitle": s.selectedTitle ?: @"", @"savedLocations": s.savedLocations ?: @[] } mutableCopy];
    if (CLLocationCoordinate2DIsValid(s.selectedCoordinate)) { d[@"lat"] = @(s.selectedCoordinate.latitude); d[@"lon"] = @(s.selectedCoordinate.longitude); }
    return d;
}

- (void)k7_ar_exportSettings {
    NSError *error = nil;
    NSData *data = [K7GPSEnhancements exportSettingsDictionary:[self k7_ar_settingsDictionary] error:&error];
    if (!data || error) { [self k7_ar_showSimple:@"تعذر تصدير الإعدادات"]; return; }
    UIPasteboard.generalPasteboard.string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [self k7_ar_showSimple:@"تم نسخ الإعدادات إلى الحافظة بنجاح"];
}

- (void)k7_ar_importSettings {
    NSString *text = UIPasteboard.generalPasteboard.string;
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding]; NSError *error = nil;
    NSDictionary *d = [K7GPSEnhancements importSettingsData:data error:&error];
    if (!d || error) { [self k7_ar_showSimple:@"الحافظة لا تحتوي إعدادات K7GPS صالحة"]; return; }
    K7GPSStore *s = K7GPSStore.shared;
    s.locationEnabled = [d[@"locationEnabled"] boolValue]; s.cameraEnabled = [d[@"cameraEnabled"] boolValue]; s.revealMode = [d[@"revealMode"] integerValue];
    if ([d[@"selectedTitle"] isKindOfClass:NSString.class]) s.selectedTitle = d[@"selectedTitle"];
    if ([d[@"savedLocations"] isKindOfClass:NSArray.class]) s.savedLocations = d[@"savedLocations"];
    if (d[@"lat"] && d[@"lon"]) s.selectedCoordinate = CLLocationCoordinate2DMake([d[@"lat"] doubleValue], [d[@"lon"] doubleValue]);
    [s save]; [self k7_ar_showSimple:@"تم استيراد الإعدادات وحفظها"];
}

- (void)k7_ar_performSearch:(NSString *)query {
    NSDictionary *coord = [K7GPSEnhancements coordinateFromText:query];
    if (coord) {
        CLLocationCoordinate2D c = CLLocationCoordinate2DMake([coord[@"lat"] doubleValue], [coord[@"lon"] doubleValue]);
        SEL selector = NSSelectorFromString(@"showCoordinate:title:");
        NSMethodSignature *sig = [self methodSignatureForSelector:selector];
        if (sig) { NSInvocation *inv=[NSInvocation invocationWithMethodSignature:sig]; inv.target=self; inv.selector=selector; [inv setArgument:&c atIndex:2]; NSString *title=@"إحداثيات"; [inv setArgument:&title atIndex:3]; [inv invoke]; return; }
    }
    [self k7_ar_performSearch:query];
}

- (void)k7_ar_showSimple:(NSString *)message {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"K7GPS" message:message preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]]; [self presentViewController:a animated:YES completion:nil];
}

@end
