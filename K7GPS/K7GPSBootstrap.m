#import <UIKit/UIKit.h>
#import "K7GPSViewController.h"

static UIButton *K7GPSFloatingButton(void) {
    static UIButton *button;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.frame = CGRectMake(18, 120, 58, 58);
        button.layer.cornerRadius = 29;
        button.backgroundColor = [UIColor colorWithRed:0.12 green:0.82 blue:0.32 alpha:0.96];
        [button setTitle:@"GPS" forState:UIControlStateNormal];
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBlack];
        button.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    });
    return button;
}

static UIViewController *K7GPSTopController(void) {
    UIWindow *window = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive) continue;
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (candidate.isKeyWindow) { window = candidate; break; }
        }
        if (window) break;
    }
    UIViewController *vc = window.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    if ([vc isKindOfClass:UINavigationController.class]) vc = ((UINavigationController *)vc).topViewController ?: vc;
    if ([vc isKindOfClass:UITabBarController.class]) vc = ((UITabBarController *)vc).selectedViewController ?: vc;
    return vc;
}

static void K7GPSOpen(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *top = K7GPSTopController();
        if (!top) return;
        K7GPSViewController *vc = [K7GPSViewController new];
        vc.modalPresentationStyle = UIModalPresentationFullScreen;
        [top presentViewController:vc animated:YES completion:nil];
    });
}

@interface K7GPSButtonTarget : NSObject
+ (instancetype)shared;
- (void)tap;
@end
@implementation K7GPSButtonTarget
+ (instancetype)shared { static id x; static dispatch_once_t t; dispatch_once(&t, ^{ x=[self new]; }); return x; }
- (void)tap { K7GPSOpen(); }
@end

static void K7GPSInstallButton(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = nil;
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive) continue;
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow *candidate in ((UIWindowScene *)scene).windows) if (candidate.isKeyWindow) { window = candidate; break; }
            if (window) break;
        }
        if (!window) return;
        UIButton *button = K7GPSFloatingButton();
        [button removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        [button addTarget:[K7GPSButtonTarget shared] action:@selector(tap) forControlEvents:UIControlEventTouchUpInside];
        if (button.superview != window) [window addSubview:button];
    });
}

__attribute__((constructor)) static void K7GPSBootstrap(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) { K7GPSInstallButton(); }];
        K7GPSInstallButton();
    });
}
