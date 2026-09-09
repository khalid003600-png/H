#import <UIKit/UIKit.h>
#import "K7GPSViewController.h"

static UIViewController *K7TopController(void) {
    UIWindow *window = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) if (w.isKeyWindow) { window = w; break; }
        if (window) break;
    }
    UIViewController *vc = window.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    if ([vc isKindOfClass:UINavigationController.class]) vc = ((UINavigationController *)vc).topViewController ?: vc;
    if ([vc isKindOfClass:UITabBarController.class]) vc = ((UITabBarController *)vc).selectedViewController ?: vc;
    return vc;
}

@interface K7GPSLauncher : NSObject
+ (instancetype)shared;
- (void)open;
@end
@implementation K7GPSLauncher
+ (instancetype)shared { static id x; static dispatch_once_t t; dispatch_once(&t, ^{ x=[self new]; }); return x; }
- (void)open {
    UIViewController *top = K7TopController(); if (!top) return;
    K7GPSViewController *vc = [K7GPSViewController new]; vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [top presentViewController:vc animated:YES completion:nil];
}
@end

static void K7InstallButton(void) {
    UIWindow *window = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) if (w.isKeyWindow) { window = w; break; }
        if (window) break;
    }
    if (!window || [window viewWithTag:770077]) return;
    UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem]; b.tag=770077; b.frame=CGRectMake(18,120,58,58); b.layer.cornerRadius=29;
    b.backgroundColor=[UIColor colorWithRed:0.12 green:0.82 blue:0.32 alpha:0.96]; [b setTitle:@"GPS" forState:UIControlStateNormal]; [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [b addTarget:[K7GPSLauncher shared] action:@selector(open) forControlEvents:UIControlEventTouchUpInside]; [window addSubview:b];
}

__attribute__((constructor)) static void K7Bootstrap(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *n){ K7InstallButton(); }];
        K7InstallButton();
    });
}
