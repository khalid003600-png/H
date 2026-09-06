#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "WFWhatsAppLocationViewController.h"
#import "WolFoxProHookManager.h"

static const void *kWFWhatsAppEntryKey = &kWFWhatsAppEntryKey;

@interface WFWhatsAppEntryTarget : NSObject
+ (instancetype)shared;
- (void)openFrom:(UIViewController *)vc;
@end

@implementation WFWhatsAppEntryTarget
+ (instancetype)shared { static id x; static dispatch_once_t once; dispatch_once(&once, ^{ x=[self new]; }); return x; }
- (void)openFrom:(UIViewController *)vc {
    if (!vc) return;
    WFWhatsAppLocationViewController *tool = [WFWhatsAppLocationViewController new];
    tool.title = @"WolFox WhatsApp Location";
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:tool];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [vc presentViewController:nav animated:YES completion:nil];
}
@end

static UITableView *WFFindTable(UIView *v) {
    if ([v isKindOfClass:UITableView.class]) return (UITableView *)v;
    for (UIView *s in v.subviews) { UITableView *t=WFFindTable(s); if (t) return t; }
    return nil;
}

static BOOL WFCellIsSubscriptions(UITableViewCell *cell) {
    NSMutableArray<UIView *> *stack=[NSMutableArray arrayWithObject:cell.contentView];
    while (stack.count) {
        UIView *v=stack.lastObject; [stack removeLastObject];
        if ([v isKindOfClass:UILabel.class]) {
            NSString *s=((UILabel *)v).text.lowercaseString ?: @"";
            if ([s containsString:@"subscriptions"] || [s containsString:@"الاشتراكات"]) return YES;
        }
        [stack addObjectsFromArray:v.subviews];
    }
    return NO;
}

static void WFInstallEntry(UIViewController *vc) {
    if (objc_getAssociatedObject(vc, kWFWhatsAppEntryKey)) return;
    UITableView *table=WFFindTable(vc.view);
    if (!table) return;
    UITableViewCell *anchor=nil;
    for (UITableViewCell *cell in table.visibleCells) { if (WFCellIsSubscriptions(cell)) { anchor=cell; break; } }
    if (!anchor) return;

    CGRect r=[table convertRect:anchor.frame toView:vc.view];
    CGFloat h=50.0;
    UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
    button.frame=CGRectMake(0, MAX(0, CGRectGetMinY(r)-h), vc.view.bounds.size.width, h);
    button.autoresizingMask=UIViewAutoresizingFlexibleWidth;
    button.backgroundColor=UIColor.secondarySystemBackgroundColor;
    [button setTitle:@"WolFox WhatsApp Location" forState:UIControlStateNormal];
    button.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeading;
    button.titleLabel.font=[UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
    button.accessibilityLabel=@"WolFox WhatsApp Location";
    [button addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
        [[WFWhatsAppEntryTarget shared] openFrom:vc];
    }] forControlEvents:UIControlEventTouchUpInside];
    [vc.view addSubview:button];
    objc_setAssociatedObject(vc, kWFWhatsAppEntryKey, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void (*WFOrigViewDidAppear)(id,SEL,BOOL)=NULL;
static void WFViewDidAppear(id self, SEL _cmd, BOOL animated) {
    if (WFOrigViewDidAppear) WFOrigViewDidAppear(self,_cmd,animated);
    dispatch_async(dispatch_get_main_queue(), ^{ WFInstallEntry((UIViewController *)self); });
}

static void WFTryHookSettingsClass(NSString *name) {
    Class cls=NSClassFromString(name); if (!cls) return;
    Method m=class_getInstanceMethod(cls,@selector(viewDidAppear:)); if (!m) return;
    IMP old=method_getImplementation(m);
    if (old==(IMP)WFViewDidAppear) return;
    WFOrigViewDidAppear=(void(*)(id,SEL,BOOL))old;
    method_setImplementation(m,(IMP)WFViewDidAppear);
}

__attribute__((constructor)) static void WFWhatsAppLocationInit(void) {
    @autoreleasepool {
        NSString *bid=NSBundle.mainBundle.bundleIdentifier ?: @"";
        if (![bid isEqualToString:@"net.whatsapp.WhatsApp"]) return;
        [[WolFoxProHookManager shared] installHooks];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSArray<NSString *> *candidates=@[@"WASettingsViewController", @"SettingsViewController", @"WAAccountSettingsViewController"];
            for (NSString *name in candidates) WFTryHookSettingsClass(name);
        });
    }
}
