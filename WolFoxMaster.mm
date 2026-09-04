#import "WFRedactedLogger.h"
// WolFoxMaster.mm - WolFox v1.8.2 Full "Dark Blue Panel UI"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <UserNotifications/UserNotifications.h>
#import <MapKit/MapKit.h>
#import <objc/runtime.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <math.h>

#import "WolFoxProStore.h"
#import "WolFoxProTheme.h"
#import "WolFoxProHookManager.h"
#import "WolFoxProCellModel.h"
#import "WFLicenseClient.h"
#import "WFActivationViewController.h"
#import "WFSpoofScheduleManager.h"
#import "WFHookDefaults.h"
#import "WFVirtualCameraManager.h"

@class WolFoxMainViewController;
static NSString * const WFUIHiddenOnLaunchKey = @"WF_UI_HIDDEN_UNTIL_VOLUME_REQUEST";
static char kLiveLicenseValueKey;
static char kLiveLicenseDotKey;
static char kLiveSpoofValueKey;
static char kLiveSpoofDotKey;
static char kLiveRouteValueKey;
static char kLiveRouteDotKey;
static char kLiveIntervalValueKey;
static char kLiveIntervalDotKey;

static BOOL WFMasterProcessIsEligible(void) {
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier.lowercaseString;
    NSString *process = NSProcessInfo.processInfo.processName.lowercaseString;
    return bundleID.length && ![bundleID hasPrefix:@"com.apple."] && ![process containsString:@"springboard"] && ![process containsString:@"backboard"];
}

@interface WolFoxController : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, strong) WolFoxMainViewController *mainVC;
@property (nonatomic, strong) UIButton *floatingIcon;
@property (nonatomic, strong) UIView *spoofQuickPanel;
@property (nonatomic, strong) UILabel *spoofQuickStatusLabel;
@property (nonatomic, strong) UIButton *spoofQuickToggleButton;
@property (nonatomic, strong) UIButton *spoofQuickFavoriteButton;
@property (nonatomic, strong) UIButton *cameraIcon;
@property (nonatomic, strong) UIView *floatingControlPanel;
@property (nonatomic, strong) UILabel *floatingStatusLabel;
@property (nonatomic, strong) UIButton *floatingToggleButton;
@property (nonatomic, strong) UIButton *floatingClearButton;
@property (nonatomic, strong) UISwitch *floatingRememberSwitch;
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, weak) UIWindow *previousKeyWindow;
@property (nonatomic, strong) UILongPressGestureRecognizer *virtualCameraLongPressGesture;
@property (nonatomic, weak) UIWindow *virtualCameraGestureHostWindow;
@property (nonatomic, assign) CFTimeInterval cameraDragStartTime;
@property (nonatomic, assign) BOOL cameraIconDidDrag;
@property (nonatomic, assign) BOOL reopenCameraIconAfterPicker;
@property (nonatomic, strong) AVAudioSession *volumeSession;
@property (nonatomic, assign) NSInteger volumePulseCount;
@property (nonatomic, assign) NSTimeInterval lastVolumePulseTime;
@property (nonatomic, assign) NSTimeInterval lastVolumeToggleTime;
@property (nonatomic, assign) NSTimeInterval lastSystemVolumeNotificationTime;
@property (nonatomic, assign) NSTimeInterval lastFallbackVolumePulseTime;
@property (nonatomic, assign) NSInteger sequentialTapCount;
@property (nonatomic, assign) NSTimeInterval lastSequentialTapTime;
+ (instancetype)shared;
- (void)showUI;
- (void)dismissUI;
- (void)toggleUI;
- (void)toggleCameraIcon:(BOOL)show;
- (void)handleVolumeGesturePulse;
- (void)prepareHiddenVolumeListening;
- (void)recordVolumeButtonPress;
- (void)showActivationScreen;
- (void)showActivationScreenWithResult:(WFLicenseResult *)result;
- (nullable UIWindow *)hostKeyWindow;
- (void)openVirtualCameraImagePicker:(nullable UIButton *)sender;
- (void)cameraIconPressed;
- (void)refreshFloatingControlPanel;
- (void)refreshFloatingStatusIcon;
- (void)handleFloatingStatusTap:(UIButton *)sender;
- (void)handleFloatingStatusPan:(UIPanGestureRecognizer *)gesture;
- (void)setFloatingStatusIconVisible:(BOOL)visible;
- (void)applyFloatingStatusPreferences;
- (void)resetFloatingStatusPosition;
- (void)toggleSpoofQuickPanel:(nullable UIButton *)sender;
- (void)closeSpoofQuickPanel:(nullable UIButton *)sender;
- (void)refreshSpoofQuickPanel;
- (void)toggleSpoofFromQuickPanel:(nullable UIButton *)sender;
- (void)openMapFromQuickPanel:(nullable UIButton *)sender;
- (void)activateFavoriteFromQuickPanel:(nullable UIButton *)sender;
- (void)handleFloatingStatusLongPress:(UILongPressGestureRecognizer *)gesture;
- (void)closeFloatingControlPanel:(nullable UIButton *)sender;
- (void)prepareVirtualCameraLongPress;
@end

@interface WolFoxOverlayWindow : UIWindow
@end

@interface WolFoxMainViewController : UIViewController <MKMapViewDelegate, UITextFieldDelegate, UISearchBarDelegate, CBCentralManagerDelegate, CLLocationManagerDelegate>
@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) MKPointAnnotation *realLocPin;
- (void)refreshSpoofHeaderStatus;
- (UIView *)liveStatusCardWithFrame:(CGRect)frame title:(NSString *)title labelKey:(const void *)labelKey dotKey:(const void *)dotKey;
- (void)refreshLiveStatusCards;
- (void)closeExpandedMapIfNeeded;
- (void)configureKeyboardToolbarForTextField:(UITextField *)textField searchMode:(BOOL)searchMode;
- (void)hideInputKeyboard;
- (void)keyboardBackPressed;
- (void)pasteSearchText;
- (void)copySearchText;
- (void)copyCoordinates;
- (void)keyboardNextPressed;
- (void)searchFromKeyboard;
- (void)applyCoordinatesFromKeyboard;
- (void)refreshSpoofSchedulePage;
- (void)showScheduleLocationMissingNotice;
- (void)scheduleExpiryReminderIfEnabled:(nullable WFLicenseResult *)result;
- (void)refreshRealLocationPinWithoutRecentering;
- (void)presentOnboardingIfNeeded;
- (void)refreshVirtualCameraPage;
- (void)openGPSPage;
- (void)volumePressCountChanged:(UISegmentedControl *)control;
- (void)floatingIconSizeChanged:(UISegmentedControl *)control;
- (void)floatingIconOpacityChanged:(UISlider *)slider;
- (void)resetFloatingIconPosition;
- (void)showLocationHistory;
- (void)historySelected:(UIButton *)button;
- (void)clearLocationHistoryPressed;
- (void)showLocationProfiles;
- (void)saveCurrentLocationProfile;
- (void)locationProfileSelected:(UIButton *)button;
- (void)deleteLocationProfile:(UIButton *)button;
- (void)editFav:(UIButton *)button;
- (void)exportLocationData;
- (void)importLocationDataFromClipboard;
- (void)showLocationDataResetOptions;
- (void)copyDiagnosticReport;
@end

@implementation WolFoxOverlayWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || self.alpha < 0.01) return nil;
    
    UIViewController *root = self.rootViewController;
    if (root) {
        if (root.presentedViewController) return [super hitTest:point withEvent:event];
        if ([root isKindOfClass:objc_getClass("WolFoxMainViewController")]) {
            WolFoxMainViewController *vc = (WolFoxMainViewController *)root;
            if (vc.view && !vc.view.hidden && vc.view.alpha > 0.5) return [super hitTest:point withEvent:event];
        }
    }
    
    Class ctrlCls = objc_getClass("WolFoxController");
    if (ctrlCls) {
        WolFoxController *ctrl = [ctrlCls shared];
        if (ctrl && ctrl.spoofQuickPanel && !ctrl.spoofQuickPanel.hidden && ctrl.spoofQuickPanel.alpha > 0.1) {
            CGPoint quickPoint = [self convertPoint:point toView:ctrl.spoofQuickPanel];
            if ([ctrl.spoofQuickPanel pointInside:quickPoint withEvent:event]) return [super hitTest:point withEvent:event];
        }
        if (ctrl && ctrl.floatingControlPanel && !ctrl.floatingControlPanel.hidden && ctrl.floatingControlPanel.alpha > 0.1) {
            CGPoint panelPoint = [self convertPoint:point toView:ctrl.floatingControlPanel];
            if ([ctrl.floatingControlPanel pointInside:panelPoint withEvent:event]) return [super hitTest:point withEvent:event];
        }
        if (ctrl && ctrl.floatingIcon && !ctrl.floatingIcon.hidden && ctrl.floatingIcon.alpha > 0.1) {
            CGPoint p = [self convertPoint:point toView:ctrl.floatingIcon];
            if ([ctrl.floatingIcon pointInside:p withEvent:event]) return ctrl.floatingIcon;
        }
        if (ctrl && ctrl.cameraIcon && !ctrl.cameraIcon.hidden && ctrl.cameraIcon.alpha > 0.1) {
            CGPoint p = [self convertPoint:point toView:ctrl.cameraIcon];
            if ([ctrl.cameraIcon pointInside:p withEvent:event]) return ctrl.cameraIcon;
        }
    }
    return nil;
}

// Volume buttons handled via UIApplication hook in WolFoxIntegrated.mm
@end

@implementation WolFoxMainViewController {
    UIVisualEffectView *_blurView;
    UIView *_tabsBar;
    UIView *_dashboard;
    UIView *_header;
    UILabel *_titleLabel;
    UILabel *_spoofStatusLabel;
    MKPointAnnotation *_currentPin;
    UIView *_mapCard;
    UILabel *_realLocationNoticeLabel;
    UIImageView *_realLocationNoticeIcon;
    NSString *_lastToastKey;
    NSTimeInterval _lastToastTime;
    UIView *_expandedMapContainer;
    UIButton *_expandedMapCloseButton;
    MKLocalSearch *_activeMapSearch;
    BOOL _mapExpanded;
    UITextField *_latInput;
    UITextField *_lonInput;
    UIScrollView *_scrollDashboard;
    NSMutableArray *_tabBtns;
    NSInteger _activePage; // 0: GPS, 1: ID, 2: BT, 3: Camera, 4: Settings
    CLLocationManager *_realLocManager;
    CBCentralManager *_btManager;
    NSMutableArray *_discoveredDevices; // array of NSDictionary
    UIView *_schedulePage;
    UIView *_scheduleTimePickerOverlay;
    UIDatePicker *_scheduleTimePicker;
    BOOL _editingScheduleStartTime;
    UIView *_onboardingOverlay;
    NSInteger _onboardingStep;
    UIImageView *_cameraPreviewImageView;
    UILabel *_cameraStateLabel;
    UIButton *_cameraToggleButton;
    UISwitch *_cameraRememberSwitch;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [WolFoxProTheme windowBackground];
    _tabBtns = [NSMutableArray new];
    _realLocManager = [CLLocationManager new];
    _realLocManager.delegate = self;
    _realLocManager.desiredAccuracy = kCLLocationAccuracyBest;
    [_realLocManager requestWhenInUseAuthorization];
    [_realLocManager startUpdatingLocation];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(routeFinished) name:@"WF_ROUTE_FINISHED" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(routeStepUpdated) name:@"WF_ROUTE_STEP_UPDATED" object:nil];
    // ADDED: تحديث واجهة البلوتوث عند حذف الملف النشط
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(btProfileDeactivated) name:@"WF_BT_PROFILE_DEACTIVATED" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(virtualCameraStateChanged:) name:WFVirtualCameraStateDidChangeNotification object:nil];
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"WF_ROUTE_FINISHED" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"WF_ROUTE_STEP_UPDATED" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"WF_BT_PROFILE_DEACTIVATED" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:WFVirtualCameraStateDidChangeNotification object:nil];
    [_activeMapSearch cancel];
    [_realLocManager stopUpdatingLocation];
    _realLocManager.delegate = nil;
    _btManager.delegate = nil;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (_mapExpanded) [self layoutExpandedMap];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    // Setup UI here so bounds are guaranteed non-zero
    if (_tabBtns.count == 0) {
        [self setupUI];
        [self switchPage:0];
    }
}

- (void)presentOnboardingIfNeeded {
    if (_onboardingOverlay || [[NSUserDefaults standardUserDefaults] boolForKey:@"WF_ONBOARDING_COMPLETED"]) return;
    if (!self.view.window || self.view.bounds.size.width < 240.0) return;
    _onboardingStep = 0;
    [self showOnboardingStep];
}

- (void)finishOnboarding {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"WF_ONBOARDING_COMPLETED"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [UIView animateWithDuration:0.18 animations:^{ self->_onboardingOverlay.alpha = 0.0; } completion:^(__unused BOOL finished) {
        [self->_onboardingOverlay removeFromSuperview];
        self->_onboardingOverlay = nil;
    }];
}

- (void)showOnboardingStep {
    [_onboardingOverlay removeFromSuperview];
    _onboardingOverlay = [[UIView alloc] initWithFrame:self.view.bounds];
    _onboardingOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _onboardingOverlay.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.76];
    [self.view addSubview:_onboardingOverlay];

    NSArray<NSString *> *titles = @[@"مرحباً بك في WolFox Full", @"الخريطة", @"الكاميرا الافتراضية", @"المفضلة والجدولة", @"الإخفاء والواجهة العائمة", @"الإعدادات والاشتراك"];
    NSArray<NSString *> *messages = @[
        @"هذه جولة إرشادية قصيرة لشرح أهم وظائف النسخة الكاملة. يمكنك الضغط على تخطي في أي وقت.",
        @"استخدم الخريطة والبحث والإحداثيات والمفضلة لتحديد الموقع وتشغيل الوظائف المرتبطة به.",
        @"اختر صورة واحدة من قسم الكاميرا، ثم شغّل أو أوقف البث واحفظ آخر صورة اختيارياً للاستخدام القادم.",
        @"احفظ المواقع واستخدم الجدولة لتحديد الأيام ووقت البداية والنهاية حسب إعداداتك.",
        @"بعد فتح كاميرا التطبيق اضغط مطولاً في منتصف الشاشة لإظهار الأيقونة؛ اسحبها لأكثر من ثانيتين للتبديل السريع.",
        @"من الإعدادات غيّر المظهر والألوان والتنبيهات، وراجع حالة الاشتراك وإصدار WolFox Full."
    ];
    NSInteger step = MIN(_onboardingStep, (NSInteger)titles.count - 1);
    CGFloat width = self.view.bounds.size.width - 32.0;
    CGFloat height = 190.0;
    CGFloat y = self.view.bounds.size.height - height - MAX(self.view.safeAreaInsets.bottom, 14.0);
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(16.0, y, width, height)];
    card.backgroundColor = [WolFoxProTheme surfacePrimary];
    card.layer.cornerRadius = 20.0;
    card.layer.borderWidth = 1.5;
    card.layer.borderColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.85].CGColor;
    [_onboardingOverlay addSubview:card];

    UILabel *counter = [[UILabel alloc] initWithFrame:CGRectMake(18, 12, width - 36, 18)];
    counter.text = [NSString stringWithFormat:@"WOLFOX FULL  •  %ld / %lu", (long)step + 1, (unsigned long)titles.count];
    counter.textColor = [WolFoxProTheme accent];
    counter.font = [WolFoxProTheme fontOfSize:10 weight:UIFontWeightBlack];
    counter.textAlignment = NSTextAlignmentRight;
    [card addSubview:counter];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(18, 35, width - 36, 30)];
    title.text = titles[step];
    title.textColor = [WolFoxProTheme textPrimary];
    title.font = [WolFoxProTheme fontOfSize:19 weight:UIFontWeightBlack];
    title.textAlignment = NSTextAlignmentRight;
    [card addSubview:title];

    UILabel *message = [[UILabel alloc] initWithFrame:CGRectMake(18, 70, width - 36, 54)];
    message.text = messages[step];
    message.textColor = [WolFoxProTheme textSecondary];
    message.font = [WolFoxProTheme fontOfSize:12 weight:UIFontWeightSemibold];
    message.textAlignment = NSTextAlignmentRight;
    message.numberOfLines = 3;
    [card addSubview:message];

    UIButton *skip = [UIButton buttonWithType:UIButtonTypeSystem];
    skip.frame = CGRectMake(18, 140, 100, 38);
    [skip setTitle:@"تخطي" forState:UIControlStateNormal];
    [skip setTitleColor:[WolFoxProTheme textSecondary] forState:UIControlStateNormal];
    skip.titleLabel.font = [WolFoxProTheme fontOfSize:13 weight:UIFontWeightBold];
    [skip addTarget:self action:@selector(finishOnboarding) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:skip];

    UIButton *next = [UIButton buttonWithType:UIButtonTypeSystem];
    next.frame = CGRectMake(width - 138, 140, 120, 38);
    next.backgroundColor = [WolFoxProTheme accent];
    next.layer.cornerRadius = 11.0;
    [next setTitle:(step == (NSInteger)titles.count - 1 ? @"تم" : @"التالي") forState:UIControlStateNormal];
    [next setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    next.titleLabel.font = [WolFoxProTheme fontOfSize:14 weight:UIFontWeightBlack];
    next.tag = (step == (NSInteger)titles.count - 1) ? -1 : 1;
    [next addTarget:self action:@selector(onboardingNextPressed:) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:next];
}

- (void)onboardingNextPressed:(UIButton *)sender {
    if (sender.tag < 0) { [self finishOnboarding]; return; }
    _onboardingStep++;
    [self showOnboardingStep];
}

- (void)setupUI {
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    CGFloat safeTop = MAX(self.view.safeAreaInsets.top, 28.0);
    CGFloat headerHeight = safeTop + 58.0;
    
    _blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:[WolFoxProTheme blurStyle]]];
    _blurView.frame = self.view.bounds;
    [self.view addSubview:_blurView];
    
    // 1. Header — respects the status area and keeps every SF Symbol aligned.
    _header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, headerHeight)];
    _header.backgroundColor = [WolFoxProTheme surfacePrimary];
    _header.layer.borderWidth = 1.0;
    _header.layer.borderColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.28].CGColor;
    [self.view addSubview:_header];
    
    _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(18, safeTop + 7, 135, 26)];
    _titleLabel.text = @"Wolfox";
    _titleLabel.textAlignment = NSTextAlignmentLeft;
    _titleLabel.font = [WolFoxProTheme fontOfSize:20 weight:UIFontWeightBlack];
    _titleLabel.textColor = [WolFoxProTheme textPrimary];
    [_header addSubview:_titleLabel];

    _spoofStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(18, safeTop + 34, 190, 16)];
    _spoofStatusLabel.textAlignment = NSTextAlignmentLeft;
    _spoofStatusLabel.font = [WolFoxProTheme fontOfSize:11 weight:UIFontWeightBold];
    _spoofStatusLabel.isAccessibilityElement = YES;
    [_header addSubview:_spoofStatusLabel];
    [self refreshSpoofHeaderStatus];
    
    UIButton *closeBtn = [self headerCircleBtn:@"xmark" color:[WolFoxProTheme danger] x:w - 58];
    [closeBtn addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
    closeBtn.accessibilityLabel = @"إخفاء Wolfox مع إبقاء أزرار الصوت فعالة";
    [_header addSubview:closeBtn];
    
    UIButton *crownBtn = [self headerCircleBtn:@"crown.fill" color:[WolFoxProTheme accent] x:w - 110];
    [crownBtn addTarget:self action:@selector(showSubscriptionInfo) forControlEvents:UIControlEventTouchUpInside];
    crownBtn.accessibilityLabel = @"معلومات الاشتراك";
    [_header addSubview:crownBtn];

    // 2. Top Tabs Bar
    _tabsBar = [[UIView alloc] initWithFrame:CGRectMake(0, headerHeight, w, 58)];
    _tabsBar.backgroundColor = [WolFoxProTheme surfaceSecondary];
    _tabsBar.layer.borderWidth = 1.0;
    _tabsBar.layer.borderColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.18].CGColor;
    [self.view addSubview:_tabsBar];
    
    UIView *indicator = [[UIView alloc] initWithFrame:CGRectMake(0, 54, w / 5.0, 4)];
    indicator.backgroundColor = [WolFoxProTheme accent];
    objc_setAssociatedObject(self, "_tab_indicator", indicator, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [_tabsBar addSubview:indicator];
    
    NSArray *icons = @[@"location.fill", @"person.text.rectangle.fill", @"antenna.radiowaves.left.and.right", @"camera.fill", @"gearshape.fill"];
    NSArray *tabLabels = @[@"الموقع GPS", @"معرف الجهاز", @"البلوتوث", @"الكاميرا", @"الإعدادات"];
    CGFloat tw = w / icons.count;
    UIImageSymbolConfiguration *tabConfig = nil;
    if (@available(iOS 13.0, *)) {
        tabConfig = [UIImageSymbolConfiguration configurationWithPointSize:21 weight:UIImageSymbolWeightSemibold];
    }
    for (NSUInteger i = 0; i < icons.count; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.frame = CGRectMake(i * tw, 0, tw, 58);
        if (@available(iOS 13.0, *)) {
            [b setImage:[UIImage systemImageNamed:icons[i] withConfiguration:tabConfig] forState:UIControlStateNormal];
        }
        b.tintColor = [UIColor whiteColor];
        b.adjustsImageWhenHighlighted = NO;
        b.tag = i;
        b.accessibilityLabel = tabLabels[i];
        b.accessibilityHint = @"يفتح هذا القسم";
        [b addTarget:self action:@selector(tabBtnPressed:) forControlEvents:UIControlEventTouchUpInside];
        [_tabsBar addSubview:b];
        [_tabBtns addObject:b];
    }
    
    // 3. Dashboard (Main Content)
    _dashboard = [[UIView alloc] initWithFrame:CGRectMake(0, headerHeight + 58, w, h - headerHeight - 58)];
    _dashboard.backgroundColor = [WolFoxProTheme windowBackground];
    [self.view addSubview:_dashboard];
    
    _scrollDashboard = [[UIScrollView alloc] initWithFrame:_dashboard.bounds];
    _scrollDashboard.alwaysBounceVertical = YES;
    _scrollDashboard.backgroundColor = [WolFoxProTheme windowBackground];
    [_dashboard addSubview:_scrollDashboard];
}

- (UIButton *)headerCircleBtn:(NSString *)icon color:(UIColor *)color x:(CGFloat)x {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    CGFloat safeTop = MAX(self.view.safeAreaInsets.top, 28.0);
    b.frame = CGRectMake(x, safeTop + 3, 44, 44);
    b.backgroundColor = [color colorWithAlphaComponent:0.18];
    b.layer.cornerRadius = 13;
    b.layer.borderWidth = 1.0;
    b.layer.borderColor = [color colorWithAlphaComponent:0.42].CGColor;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightBold];
        [b setImage:[UIImage systemImageNamed:icon withConfiguration:config] forState:UIControlStateNormal];
    } else {
        // iOS 12 fallback: SF Symbols غير متاح، اعتمد على النص
        [b setTitle:@"✕" forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    }
    b.tintColor = color;
    b.adjustsImageWhenHighlighted = NO;
    return b;
}

- (UIView *)liveStatusCardWithFrame:(CGRect)frame title:(NSString *)title labelKey:(const void *)labelKey dotKey:(const void *)dotKey {
    UIView *card = [[UIView alloc] initWithFrame:frame];
    card.backgroundColor = [[WolFoxProTheme surfaceSecondary] colorWithAlphaComponent:0.86];
    card.layer.cornerRadius = 10;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.25].CGColor;

    UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(12, 13, 10, 10)];
    dot.layer.cornerRadius = 5;
    dot.backgroundColor = [WolFoxProTheme textSecondary];
    [card addSubview:dot];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(30, 3, frame.size.width - 42, 15)];
    titleLabel.text = title;
    titleLabel.textColor = [WolFoxProTheme textSecondary];
    titleLabel.textAlignment = NSTextAlignmentRight;
    titleLabel.font = [WolFoxProTheme fontOfSize:10 weight:UIFontWeightSemibold];
    [card addSubview:titleLabel];

    UILabel *valueLabel = [[UILabel alloc] initWithFrame:CGRectMake(30, 17, frame.size.width - 42, 16)];
    valueLabel.text = @"جارٍ التحقق";
    valueLabel.textColor = [WolFoxProTheme textPrimary];
    valueLabel.textAlignment = NSTextAlignmentRight;
    valueLabel.font = [WolFoxProTheme fontOfSize:11 weight:UIFontWeightBold];
    [card addSubview:valueLabel];

    objc_setAssociatedObject(self, labelKey, valueLabel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, dotKey, dot, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return card;
}

- (void)refreshLiveStatusCards {
    WolFoxProStore *store = [WolFoxProStore shared];
    BOOL licensed = [WFLicenseClient isRuntimeLicenseValid];
    BOOL spoofing = store.spoofActive && licensed;
    BOOL route = store.routeActive && spoofing;
    UILabel *licenseLabel = objc_getAssociatedObject(self, &kLiveLicenseValueKey);
    UILabel *spoofLabel = objc_getAssociatedObject(self, &kLiveSpoofValueKey);
    UILabel *routeLabel = objc_getAssociatedObject(self, &kLiveRouteValueKey);
    UILabel *intervalLabel = objc_getAssociatedObject(self, &kLiveIntervalValueKey);
    UIView *licenseDot = objc_getAssociatedObject(self, &kLiveLicenseDotKey);
    UIView *spoofDot = objc_getAssociatedObject(self, &kLiveSpoofDotKey);
    UIView *routeDot = objc_getAssociatedObject(self, &kLiveRouteDotKey);
    UIView *intervalDot = objc_getAssociatedObject(self, &kLiveIntervalDotKey);

    licenseLabel.text = licensed ? @"مفعل" : @"غير متاح";
    licenseLabel.textColor = licensed ? [WolFoxProTheme success] : [WolFoxProTheme danger];
    licenseDot.backgroundColor = licensed ? [WolFoxProTheme success] : [WolFoxProTheme danger];
    spoofLabel.text = spoofing ? @"يعمل" : @"متوقف";
    spoofLabel.textColor = spoofing ? [WolFoxProTheme danger] : [WolFoxProTheme textSecondary];
    spoofDot.backgroundColor = spoofing ? [WolFoxProTheme danger] : [WolFoxProTheme textSecondary];
    routeLabel.text = route ? @"نشط" : @"جاهز";
    routeLabel.textColor = route ? [WolFoxProTheme accent] : [WolFoxProTheme textSecondary];
    routeDot.backgroundColor = route ? [WolFoxProTheme accent] : [WolFoxProTheme textSecondary];
    intervalLabel.text = [NSString stringWithFormat:@"%.2f ث", WFClampGPSUpdateInterval(store.updateIntervalSeconds)];
    intervalLabel.textColor = [WolFoxProTheme gold];
    intervalDot.backgroundColor = [WolFoxProTheme gold];
}

- (void)refreshSpoofHeaderStatus {
    WolFoxProStore *store = [WolFoxProStore shared];
    BOOL active = store.spoofActive || store.bluetoothActive || store.mediaUploadActive || [store validatedActiveIdentifier] != nil;
    _spoofStatusLabel.text = active ? @"● نشط • التزييف مفعّل" : @"○ متوقف • الوضع الحقيقي";
    _spoofStatusLabel.textColor = active ? [WolFoxProTheme success] : [WolFoxProTheme textSecondary];
    _spoofStatusLabel.accessibilityLabel = active ? @"حالة التزييف: نشط" : @"حالة التزييف: متوقف";
    [self refreshLocationModeNotice];
    [self refreshLiveStatusCards];
}

- (void)tabBtnPressed:(UIButton *)b { [self switchPage:b.tag]; }

- (void)openGPSPage {
    [self switchPage:0];
}

- (void)switchPage:(NSInteger)page {
    if (_mapExpanded) [self closeExpandedMapIfNeeded];
    CGFloat w = self.view.bounds.size.width;
    UIView *indicator = objc_getAssociatedObject(self, "_tab_indicator");

    if (!indicator) {
        for (UIView *v in _tabsBar.subviews) { if (v.frame.size.height == 3) { indicator = v; break; } }
    }

    // Full يعرض خمسة أقسام فعلية؛ يحسب المؤشر والتحديد من عدد الأزرار الحقيقي.
    CGFloat tabCount = MAX((CGFloat)_tabBtns.count, 1.0);
    NSInteger tabIndex = MIN(MAX(page, 0), (NSInteger)_tabBtns.count - 1);
    CGFloat tw = w / tabCount;
    if (indicator) {
        [UIView performWithoutAnimation:^{
            indicator.frame = CGRectMake(tabIndex * tw, 55, tw, 3);
        }];
    }
    for (UIButton *b in _tabBtns) {
        b.tintColor = (b.tag == tabIndex) ? [WolFoxProTheme accent] : [UIColor whiteColor];
        b.accessibilityTraits = (b.tag == tabIndex) ? UIAccessibilityTraitSelected : UIAccessibilityTraitNone;
    }

    for (UIView *v in _scrollDashboard.subviews) [v removeFromSuperview];
    if (page != 3) {
        _cameraPreviewImageView = nil;
        _cameraStateLabel = nil;
        _cameraToggleButton = nil;
        _cameraRememberSwitch = nil;
    }

    // Stop BT scan if leaving BT tab (check before updating _activePage)
    if (_activePage == 2 && page != 2 && _btManager) {
        [_btManager stopScan];
    }
    // ADDED: إذا غادرنا صفحة GPS ولم يكن هناك مسار نشط، امسح دبوس الهدف
    if (_activePage == 0 && page != 0 && ![WolFoxProStore shared].routeActive) {
        MKPointAnnotation *targetPin = objc_getAssociatedObject(self, "_target_pin");
        if (targetPin && self.mapView) {
            [self.mapView removeAnnotation:targetPin];
            objc_setAssociatedObject(self, "_target_pin", nil, OBJC_ASSOCIATION_ASSIGN);
        }
    }

    _activePage = page;
    [self refreshSpoofHeaderStatus];
    [_scrollDashboard setContentOffset:CGPointZero animated:NO];

    if (page == 0) [self setupGPSPage];
    else if (page == 1) [self setupIDPage];
    else if (page == 2) [self setupBluetoothPage];
    else if (page == 3) [self setupCameraPage];
    else if (page == 4) [self setupSettingsPage];
}

#pragma mark - Bluetooth Page

- (void)setupBluetoothPage {
    CGFloat w = _scrollDashboard.bounds.size.width;
    CGFloat y = 10;

    // ── Toggle Card ──
    UIView *toggleCard = [[UIView alloc] initWithFrame:CGRectMake(15, y, w - 30, 65)];
    toggleCard.backgroundColor = [WolFoxProTheme surfacePrimary]; toggleCard.layer.cornerRadius = 15;
    [_scrollDashboard addSubview:toggleCard];

    UILabel *tl = [[UILabel alloc] initWithFrame:CGRectMake(15, 0, toggleCard.bounds.size.width - 80, 65)];
    tl.text = @"تفعيل تزييف البلوتوث"; tl.textColor = [WolFoxProTheme textPrimary];
    tl.font = [WolFoxProTheme fontOfSize:15 weight:UIFontWeightBold]; tl.textAlignment = NSTextAlignmentRight;
    [toggleCard addSubview:tl];

    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(15, 17, 50, 30)];
    sw.on = [WolFoxProStore shared].bluetoothActive; sw.onTintColor = [WolFoxProTheme accent];
    sw.accessibilityLabel = @"تزييف البلوتوث";
    [sw addTarget:self action:@selector(btToggleChanged:) forControlEvents:UIControlEventValueChanged];
    [toggleCard addSubview:sw];
    y += 80;

    UILabel *btStatus = [[UILabel alloc] initWithFrame:CGRectMake(20, y, w - 40, 28)];
    btStatus.text = [WolFoxProStore shared].bluetoothActive ? @"حالة تزييف البلوتوث: مفعّل" : @"حالة تزييف البلوتوث: متوقف";
    btStatus.textColor = [WolFoxProStore shared].bluetoothActive ? [WolFoxProTheme success] : [WolFoxProTheme textSecondary];
    btStatus.backgroundColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.10];
    btStatus.layer.cornerRadius = 10; btStatus.clipsToBounds = YES;
    btStatus.font = [WolFoxProTheme fontOfSize:12 weight:UIFontWeightBold];
    btStatus.textAlignment = NSTextAlignmentCenter;
    [_scrollDashboard addSubview:btStatus];
    objc_setAssociatedObject(self, "_bt_status_label", btStatus, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    y += 40;

    // ── Action Buttons Row ──
    CGFloat bw = (w - 45) / 2.0;

    UIButton *scanBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    scanBtn.frame = CGRectMake(15, y, bw, 50);
    scanBtn.backgroundColor = [WolFoxProTheme accent]; scanBtn.layer.cornerRadius = 14;
    if (@available(iOS 13.0, *)) [scanBtn setImage:[UIImage systemImageNamed:@"antenna.radiowaves.left.and.right"] forState:UIControlStateNormal];
    [scanBtn setTitle:@"  بحث" forState:UIControlStateNormal];
    [scanBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    scanBtn.tintColor = [UIColor whiteColor];
    scanBtn.titleLabel.font = [WolFoxProTheme fontOfSize:14 weight:UIFontWeightBlack];
    [scanBtn addTarget:self action:@selector(startBTScan) forControlEvents:UIControlEventTouchUpInside];
    objc_setAssociatedObject(self, "bt_scan_btn", scanBtn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [_scrollDashboard addSubview:scanBtn];

    UIButton *addBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    addBtn.frame = CGRectMake(bw + 30, y, bw, 50);
    addBtn.backgroundColor = [WolFoxProTheme surfacePrimary]; addBtn.layer.cornerRadius = 14;
    if (@available(iOS 13.0, *)) [addBtn setImage:[UIImage systemImageNamed:@"plus.circle.fill"] forState:UIControlStateNormal];
    [addBtn setTitle:@"  إضافة يدوي" forState:UIControlStateNormal];
    [addBtn setTitleColor:[WolFoxProTheme textPrimary] forState:UIControlStateNormal];
    addBtn.tintColor = [WolFoxProTheme accent];
    addBtn.titleLabel.font = [WolFoxProTheme fontOfSize:14 weight:UIFontWeightBold];
    [addBtn addTarget:self action:@selector(addBleDeviceManually) forControlEvents:UIControlEventTouchUpInside];
    [_scrollDashboard addSubview:addBtn];
    y += 65;

    // ── Discovered Devices (scan results) ──
    NSArray *discovered = _discoveredDevices ?: @[];
    if (discovered.count > 0) {
        UILabel *discTitle = [[UILabel alloc] initWithFrame:CGRectMake(15, y, w - 30, 28)];
        discTitle.text = @"أجهزة مكتشفة"; discTitle.textColor = [WolFoxProTheme textSecondary];
        discTitle.font = [WolFoxProTheme fontOfSize:13 weight:UIFontWeightBold];
        [_scrollDashboard addSubview:discTitle];
        y += 33;

        for (NSDictionary *dev in discovered) {
            UIView *row = [[UIView alloc] initWithFrame:CGRectMake(15, y, w - 30, 58)];
            row.backgroundColor = [WolFoxProTheme surfacePrimary]; row.layer.cornerRadius = 13;
            [_scrollDashboard addSubview:row];

            UILabel *nl = [[UILabel alloc] initWithFrame:CGRectMake(55, 8, row.bounds.size.width - 105, 22)];
            nl.text = dev[@"name"] ?: @"جهاز غير معروف";
            nl.textColor = [WolFoxProTheme textPrimary]; nl.font = [WolFoxProTheme fontOfSize:14 weight:UIFontWeightBold];
            nl.textAlignment = NSTextAlignmentRight; [row addSubview:nl];

            UILabel *ul = [[UILabel alloc] initWithFrame:CGRectMake(55, 30, row.bounds.size.width - 105, 18)];
            NSString *uuidStr = dev[@"uuid"] ?: @"";
            ul.text = uuidStr.length > 8 ? [uuidStr substringToIndex:8] : uuidStr;
            ul.textColor = [WolFoxProTheme textSecondary]; ul.font = [WolFoxProTheme fontOfSize:11 weight:UIFontWeightMedium];
            ul.textAlignment = NSTextAlignmentRight; [row addSubview:ul];

            UILabel *rssiL = [[UILabel alloc] initWithFrame:CGRectMake(10, 15, 40, 28)];
            rssiL.text = [NSString stringWithFormat:@"%@ dBm", dev[@"rssi"] ?: @"0"];
            rssiL.textColor = [WolFoxProTheme accent]; rssiL.font = [WolFoxProTheme fontOfSize:10 weight:UIFontWeightBold];
            rssiL.numberOfLines = 2; rssiL.textAlignment = NSTextAlignmentCenter; [row addSubview:rssiL];

            UIButton *saveB = [UIButton buttonWithType:UIButtonTypeSystem];
            saveB.frame = CGRectMake(row.bounds.size.width - 50, 7, 44, 44);
            if (@available(iOS 13.0, *)) [saveB setImage:[UIImage systemImageNamed:@"square.and.arrow.down"] forState:UIControlStateNormal];
            saveB.tintColor = [WolFoxProTheme success];
            objc_setAssociatedObject(saveB, "bt_dev_dict", dev, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [saveB addTarget:self action:@selector(saveDiscoveredDevice:) forControlEvents:UIControlEventTouchUpInside];
            saveB.accessibilityLabel = @"حفظ جهاز البلوتوث المكتشف";
            [row addSubview:saveB];
            y += 66;
        }
        y += 5;
    }

    // ── Saved Profiles ──
    NSArray *profiles = [WolFoxProStore shared].savedBleProfiles;
    UILabel *savedTitle = [[UILabel alloc] initWithFrame:CGRectMake(15, y, w - 30, 28)];
    savedTitle.text = [NSString stringWithFormat:@"الأجهزة المحفوظة (%lu)", (unsigned long)profiles.count];
    savedTitle.textColor = [WolFoxProTheme textSecondary]; savedTitle.font = [WolFoxProTheme fontOfSize:13 weight:UIFontWeightBold];
    [_scrollDashboard addSubview:savedTitle];
    y += 33;

    if (profiles.count == 0) {
        UILabel *empty = [[UILabel alloc] initWithFrame:CGRectMake(15, y, w - 30, 44)];
        empty.text = @"لا توجد أجهزة محفوظة بعد";
        empty.textColor = [WolFoxProTheme textSecondary]; empty.font = [UIFont systemFontOfSize:13];
        empty.textAlignment = NSTextAlignmentCenter; [_scrollDashboard addSubview:empty];
        y += 50;
    } else {
        for (WolFoxBleProfile *p in profiles) {
            UIView *row = [[UIView alloc] initWithFrame:CGRectMake(15, y, w - 30, 62)];
            BOOL isActive = [p.profileID isEqualToString:[WolFoxProStore shared].activeBleProfileID];
            row.backgroundColor = isActive ? [[WolFoxProTheme accent] colorWithAlphaComponent:0.15] : [WolFoxProTheme surfacePrimary];
            row.layer.cornerRadius = 14;
            if (isActive) { row.layer.borderColor = [WolFoxProTheme accent].CGColor; row.layer.borderWidth = 1.5; }
            [_scrollDashboard addSubview:row];

            UILabel *nl = [[UILabel alloc] initWithFrame:CGRectMake(50, 8, row.bounds.size.width - 100, 22)];
            nl.text = p.name ?: @"جهاز"; nl.textColor = [WolFoxProTheme textPrimary];
            nl.font = [WolFoxProTheme fontOfSize:14 weight:UIFontWeightBold]; nl.textAlignment = NSTextAlignmentRight;
            [row addSubview:nl];

            UILabel *idl = [[UILabel alloc] initWithFrame:CGRectMake(50, 30, row.bounds.size.width - 100, 18)];
            NSString *disp = p.localName.length ? p.localName : (p.uuid.length > 8 ? [p.uuid substringToIndex:8] : p.uuid);
            idl.text = disp; idl.textColor = [WolFoxProTheme textSecondary];
            idl.font = [WolFoxProTheme fontOfSize:11 weight:UIFontWeightMedium]; idl.textAlignment = NSTextAlignmentRight;
            [row addSubview:idl];

            if (isActive) {
                UILabel *actL = [[UILabel alloc] initWithFrame:CGRectMake(10, 20, 35, 22)];
                actL.text = @"✓"; actL.textColor = [WolFoxProTheme accent];
                actL.font = [WolFoxProTheme fontOfSize:18 weight:UIFontWeightBlack]; actL.textAlignment = NSTextAlignmentCenter;
                [row addSubview:actL];
            }

            // Select button (full row tap)
            UIButton *selB = [UIButton buttonWithType:UIButtonTypeCustom];
            selB.frame = CGRectMake(0, 0, row.bounds.size.width - 45, row.bounds.size.height);
            objc_setAssociatedObject(selB, "bt_profile", p, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [selB addTarget:self action:@selector(activateBleProfile:) forControlEvents:UIControlEventTouchUpInside];
            [row addSubview:selB];

            // Delete button
            UIButton *delB = [UIButton buttonWithType:UIButtonTypeSystem];
            delB.frame = CGRectMake(row.bounds.size.width - 50, 9, 44, 44);
            if (@available(iOS 13.0, *)) [delB setImage:[UIImage systemImageNamed:@"trash"] forState:UIControlStateNormal];
            delB.tintColor = [WolFoxProTheme danger];
            objc_setAssociatedObject(delB, "bt_profile", p, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [delB addTarget:self action:@selector(deleteBleProfile:) forControlEvents:UIControlEventTouchUpInside];
            delB.accessibilityLabel = @"حذف جهاز البلوتوث المحفوظ";
            [row addSubview:delB];

            y += 70;
        }
    }

    _scrollDashboard.contentSize = CGSizeMake(w, y + 30);
}

- (void)btToggleChanged:(UISwitch *)sw {
    if (sw.on) {
        [WolFoxProStore shared].bluetoothActive = YES;
        [[WolFoxProStore shared] saveSettings];
        [self refreshSpoofHeaderStatus];
        UILabel *status = objc_getAssociatedObject(self, "_bt_status_label");
        status.text = @"حالة تزييف البلوتوث: مفعّل";
        status.textColor = [WolFoxProTheme success];
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"إيقاف تزييف البلوتوث؟" message:@"ستعود معلومات البلوتوث الحقيقية بعد التأكيد." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"متابعة التزييف" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *action) { [sw setOn:YES animated:YES]; }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"إيقاف الآن" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [WolFoxProStore shared].bluetoothActive = NO;
        [[WolFoxProStore shared] saveSettings];
        [self refreshSpoofHeaderStatus];
        UILabel *status = objc_getAssociatedObject(self, "_bt_status_label");
        status.text = @"حالة تزييف البلوتوث: متوقف";
        status.textColor = [WolFoxProTheme textSecondary];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

// ADDED: يُستدعى عند حذف الملف النشط من Store
- (void)btProfileDeactivated {
    [self refreshSpoofHeaderStatus];
    if (_activePage == 2) [self switchPage:2];
    [self showToast:@"تم حذف ملف البلوتوث النشط — تم إيقاف التزييف تلقائياً"];
}

- (void)startBTScan {
    if (_discoveredDevices == nil) _discoveredDevices = [NSMutableArray new];
    [_discoveredDevices removeAllObjects];

    UIButton *scanBtn = objc_getAssociatedObject(self, "bt_scan_btn");
    [scanBtn setTitle:@"  جاري البحث..." forState:UIControlStateNormal];
    scanBtn.enabled = NO;

    if (!_btManager) {
        _btManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:@{CBCentralManagerOptionShowPowerAlertKey: @NO}];
    } else {
        [self _doStartBTScan];
    }
    [self showToast:@"🔍 جاري البحث عن أجهزة Bluetooth..."];
}

- (void)_doStartBTScan {
    if (_btManager.state != CBManagerStatePoweredOn) {
        [self showToast:@"❌ البلوتوث غير مفعّل على الجهاز"];
        UIButton *scanBtn = objc_getAssociatedObject(self, "bt_scan_btn");
        [scanBtn setTitle:@"  بحث" forState:UIControlStateNormal]; scanBtn.enabled = YES;
        return;
    }
    [_btManager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @NO}];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf->_btManager stopScan];
        UIButton *scanBtn = objc_getAssociatedObject(strongSelf, "bt_scan_btn");
        [scanBtn setTitle:@"  بحث" forState:UIControlStateNormal]; scanBtn.enabled = YES;
        [strongSelf switchPage:2]; // Refresh BT page
        [strongSelf showToast:[NSString stringWithFormat:@"✅ تم العثور على %lu جهاز", (unsigned long)strongSelf->_discoveredDevices.count]];
    });
}

// CBCentralManagerDelegate
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state == CBManagerStatePoweredOn) [self _doStartBTScan];
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)adData RSSI:(NSNumber *)RSSI {
    NSString *name = peripheral.name ?: adData[CBAdvertisementDataLocalNameKey] ?: @"جهاز غير معروف";
    NSString *uuidStr = peripheral.identifier.UUIDString;
    // Avoid duplicates
    for (NSDictionary *d in _discoveredDevices) {
        if ([d[@"uuid"] isEqualToString:uuidStr]) return;
    }
    [_discoveredDevices addObject:@{@"name": name, @"uuid": uuidStr, @"localName": adData[CBAdvertisementDataLocalNameKey] ?: @"", @"rssi": RSSI ?: @0}];
}

- (void)saveDiscoveredDevice:(UIButton *)btn {
    NSDictionary *dev = objc_getAssociatedObject(btn, "bt_dev_dict");
    if (!dev) return;
    WolFoxBleProfile *p = [WolFoxBleProfile new];
    p.profileID = [[NSUUID UUID] UUIDString];
    p.name      = dev[@"name"] ?: @"جهاز";
    p.uuid      = dev[@"uuid"] ?: @"";
    p.localName = dev[@"localName"] ?: @"";
    p.rssi      = [dev[@"rssi"] integerValue];
    [[WolFoxProStore shared] saveBleProfile:p];
    [self showToast:[NSString stringWithFormat:@"✅ تم حفظ: %@", p.name]];
    [self switchPage:2];
}

- (void)addBleDeviceManually {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"إضافة جهاز يدوي" message:@"أدخل اسم الجهاز والـ UUID" preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf){
        tf.placeholder = @"اسم الجهاز (مثال: iPhone 13)";
        tf.textAlignment = NSTextAlignmentRight;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf){
        tf.placeholder = @"UUID (اختياري)";
        tf.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    [ac addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"حفظ" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        NSString *name = ac.textFields[0].text;
        NSString *uuid = ac.textFields[1].text;
        if (name.length == 0) { [self showToast:@"❌ الاسم مطلوب"]; return; }
        WolFoxBleProfile *p = [WolFoxBleProfile new];
        p.profileID = [[NSUUID UUID] UUIDString];
        p.name      = name;
        p.uuid      = uuid.length > 0 ? uuid : [[NSUUID UUID] UUIDString];
        p.localName = name;
        p.rssi      = -60;
        [[WolFoxProStore shared] saveBleProfile:p];
        [self showToast:[NSString stringWithFormat:@"✅ تم إضافة: %@", name]];
        [self switchPage:2];
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)activateBleProfile:(UIButton *)btn {
    WolFoxBleProfile *p = objc_getAssociatedObject(btn, "bt_profile");
    if (!p) return;
    [WolFoxProStore shared].activeBleProfileID = p.profileID;
    [[WolFoxProStore shared] saveSettings];
    [self showToast:[NSString stringWithFormat:@"✅ تم تفعيل: %@", p.name]];
    [self switchPage:2];
}

- (void)deleteBleProfile:(UIButton *)btn {
    WolFoxBleProfile *p = objc_getAssociatedObject(btn, "bt_profile");
    if (!p) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"حذف جهاز البلوتوث؟" message:@"سيتم حذف الملف المحفوظ ولن يمكن التراجع عن العملية." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"حذف" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [[WolFoxProStore shared] deleteBleProfileID:p.profileID];
        [self showToast:@"✅ تم حذف جهاز البلوتوث"];
        [self switchPage:2];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - GPS Page (Royal Keyboard Style)

- (void)setupGPSPage {
    CGFloat w = _scrollDashboard.bounds.size.width;
    
    // Map Card
    UIView *mapCard = [[UIView alloc] initWithFrame:CGRectMake(15, 10, w - 30, 260)];
    _mapCard = mapCard;
    mapCard.backgroundColor = [WolFoxProTheme surfacePrimary];
    mapCard.layer.cornerRadius = 20; mapCard.clipsToBounds = YES;
    [_scrollDashboard addSubview:mapCard];
    
    self.mapView = [[MKMapView alloc] initWithFrame:mapCard.bounds];
    self.mapView.delegate = self;
    self.mapView.mapType = (MKMapType)[WolFoxProStore shared].mapStyle;
    [mapCard addSubview:self.mapView];
    
    // يظهر الموقع الحقيقي أولاً، ولا تظهر دبوس الإحداثيات الوهمية قبل تفعيل التزييف.
    CLLocation *real = [WolFoxProHookManager shared].lastRealLocation;
    if (real && ![WolFoxProStore shared].spoofActive) {
        self.realLocPin = [MKPointAnnotation new];
        self.realLocPin.coordinate = real.coordinate;
        self.realLocPin.title = @"REAL_LOC";
        [self.mapView addAnnotation:self.realLocPin];
    }
    
    // Search Bar
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(10, 10, mapCard.bounds.size.width - 20, 44)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"إحداثيات أو عنوان / اسم مكان";
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.barTintColor = [UIColor clearColor];
    self.searchBar.keyboardAppearance = UIKeyboardAppearanceDark;
    self.searchBar.returnKeyType = UIReturnKeySearch;
    self.searchBar.accessibilityLabel = @"البحث بالإحداثيات أو العنوان";
    if (@available(iOS 13.0, *)) {
        UITextField *searchField = self.searchBar.searchTextField;
        searchField.backgroundColor = [[WolFoxProTheme surfaceSecondary] colorWithAlphaComponent:0.92];
        searchField.textColor = [WolFoxProTheme textPrimary];
        searchField.tintColor = [WolFoxProTheme accent];
        searchField.layer.cornerRadius = 12;
        searchField.clipsToBounds = YES;
        [self configureKeyboardToolbarForTextField:searchField searchMode:YES];
    } else {
        // iOS 12 fallback: ضبط ألوان الـ search bar مباشرة
        self.searchBar.tintColor = [WolFoxProTheme accent];
        [[UITextField appearanceWhenContainedInInstancesOfClasses:@[UISearchBar.class]]
            setDefaultTextAttributes:@{NSForegroundColorAttributeName: [WolFoxProTheme textPrimary]}];
    }
    [mapCard addSubview:self.searchBar];
    
    // Style Toggle Button
    UIButton *styleBtn = [self mapCircleBtn:@"map.fill" x:10 y:mapCard.bounds.size.height - 54];
    styleBtn.accessibilityLabel = @"تغيير نمط الخريطة";
    [styleBtn addTarget:self action:@selector(toggleMapStyle) forControlEvents:UIControlEventTouchUpInside];
    [mapCard addSubview:styleBtn];
    
    // Real Location Button
    UIButton *realLocBtn = [self mapCircleBtn:@"person.fill" x:62 y:mapCard.bounds.size.height - 54];
    realLocBtn.accessibilityLabel = @"عرض الموقع الحقيقي";
    [realLocBtn addTarget:self action:@selector(showRealLocation) forControlEvents:UIControlEventTouchUpInside];
    [mapCard addSubview:realLocBtn];

    // Expand Map Button
    UIButton *expandBtn = [self mapCircleBtn:@"arrow.up.left.and.arrow.down.right" x:114 y:mapCard.bounds.size.height - 54];
    expandBtn.accessibilityLabel = @"توسيع الخريطة إلى ملء الشاشة";
    [expandBtn addTarget:self action:@selector(expandMap) forControlEvents:UIControlEventTouchUpInside];
    [mapCard addSubview:expandBtn];
    
    // Locate Me Button (Fake Pin)
    UIButton *locateBtn = [self mapCircleBtn:@"location.fill" x:mapCard.bounds.size.width - 54 y:mapCard.bounds.size.height - 54];
    locateBtn.accessibilityLabel = @"التمركز على الموقع الوهمي";
    [locateBtn addTarget:self action:@selector(centerMapOnPin) forControlEvents:UIControlEventTouchUpInside];
    [mapCard addSubview:locateBtn];
    
    // Remove any existing long press recognizers to prevent accumulation on tab switch
    for (UIGestureRecognizer *gr in [self.mapView.gestureRecognizers copy]) {
        if ([gr isKindOfClass:[UILongPressGestureRecognizer class]]) {
            [self.mapView removeGestureRecognizer:gr];
        }
    }
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    [self.mapView addGestureRecognizer:lp];
    if ([WolFoxProStore shared].spoofActive) [self updateMapPin:[WolFoxProStore shared].currentFakeCoords];
    else [self showRealLocation];
    
    // Real-location notice placed between the map and coordinate inputs.
    UIView *realNotice = [[UIView alloc] initWithFrame:CGRectMake(15, 282, w - 30, 54)];
    realNotice.backgroundColor = [[WolFoxProTheme success] colorWithAlphaComponent:0.12];
    realNotice.layer.cornerRadius = 12;
    realNotice.layer.borderWidth = 1.0;
    realNotice.layer.borderColor = [[WolFoxProTheme success] colorWithAlphaComponent:0.50].CGColor;
    [_scrollDashboard addSubview:realNotice];
    _realLocationNoticeIcon = [[UIImageView alloc] initWithFrame:CGRectMake(realNotice.bounds.size.width - 34, 5, 20, 20)];
    if (@available(iOS 13.0, *)) _realLocationNoticeIcon.image = [UIImage systemImageNamed:@"checkmark.circle.fill"];
    _realLocationNoticeIcon.tintColor = [WolFoxProTheme success];
    _realLocationNoticeIcon.contentMode = UIViewContentModeScaleAspectFit;
    [realNotice addSubview:_realLocationNoticeIcon];
    _realLocationNoticeLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, realNotice.bounds.size.width - 58, 30)];
    _realLocationNoticeLabel.text = @"الموقع الحقيقي: جاهز للعرض";
    _realLocationNoticeLabel.textColor = [WolFoxProTheme success];
    _realLocationNoticeLabel.font = [WolFoxProTheme fontOfSize:14 weight:UIFontWeightBold];
    _realLocationNoticeLabel.textAlignment = NSTextAlignmentRight;
    [realNotice addSubview:_realLocationNoticeLabel];

    UILabel *mapLegend = [[UILabel alloc] initWithFrame:CGRectMake(16, 30, realNotice.bounds.size.width - 32, 20)];
    mapLegend.text = @"النقطة الزرقاء: موقعك الحقيقي  •  الدبوس الأحمر: الموقع المزيّف";
    mapLegend.textColor = [WolFoxProTheme textSecondary];
    mapLegend.font = [WolFoxProTheme fontOfSize:10 weight:UIFontWeightSemibold];
    mapLegend.textAlignment = NSTextAlignmentCenter;
    [realNotice addSubview:mapLegend];

    // Live Status + Information Cards
    UIView *liveSection = [[UIView alloc] initWithFrame:CGRectMake(15, 348, w - 30, 104)];
    UILabel *liveTitle = [[UILabel alloc] initWithFrame:CGRectMake(18, 0, liveSection.bounds.size.width - 36, 20)];
    liveTitle.text = @"الحالة المباشرة";
    liveTitle.textColor = [WolFoxProTheme textPrimary];
    liveTitle.textAlignment = NSTextAlignmentRight;
    liveTitle.font = [WolFoxProTheme fontOfSize:14 weight:UIFontWeightBlack];
    [liveSection addSubview:liveTitle];
    CGFloat liveCardW = (liveSection.bounds.size.width - 48) / 2.0;
    [liveSection addSubview:[self liveStatusCardWithFrame:CGRectMake(18, 25, liveCardW, 36) title:@"الترخيص" labelKey:&kLiveLicenseValueKey dotKey:&kLiveLicenseDotKey]];
    [liveSection addSubview:[self liveStatusCardWithFrame:CGRectMake(30 + liveCardW, 25, liveCardW, 36) title:@"التزييف" labelKey:&kLiveSpoofValueKey dotKey:&kLiveSpoofDotKey]];
    [liveSection addSubview:[self liveStatusCardWithFrame:CGRectMake(18, 66, liveCardW, 36) title:@"المسار" labelKey:&kLiveRouteValueKey dotKey:&kLiveRouteDotKey]];
    [liveSection addSubview:[self liveStatusCardWithFrame:CGRectMake(30 + liveCardW, 66, liveCardW, 36) title:@"التحديث" labelKey:&kLiveIntervalValueKey dotKey:&kLiveIntervalDotKey]];
    [_scrollDashboard addSubview:liveSection];
    [self refreshLiveStatusCards];

    // Keyboard Input Area
    UIView *kbCard = [[UIView alloc] initWithFrame:CGRectMake(15, 466, w - 30, 210)];
    kbCard.backgroundColor = [WolFoxProTheme surfacePrimary]; kbCard.layer.cornerRadius = 20;
    [_scrollDashboard addSubview:kbCard];
    
    CGFloat iw = (kbCard.bounds.size.width - 60) / 2.0;
    _latInput = [self royalInput:@"24.713600" frame:CGRectMake(15, 15, iw, 45)];
    _latInput.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    _latInput.returnKeyType = UIReturnKeyNext;
    _latInput.accessibilityLabel = @"خط العرض";
    [self configureKeyboardToolbarForTextField:_latInput searchMode:NO];
    [kbCard addSubview:_latInput];
    _lonInput = [self royalInput:@"46.675300" frame:CGRectMake(iw + 25, 15, iw - 45, 45)];
    _lonInput.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    _lonInput.returnKeyType = UIReturnKeyDone;
    _lonInput.accessibilityLabel = @"خط الطول";
    [self configureKeyboardToolbarForTextField:_lonInput searchMode:NO];
    [kbCard addSubview:_lonInput];
    
    // Paste Button
    UIButton *pasteBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    pasteBtn.frame = CGRectMake(kbCard.bounds.size.width - 54, 15, 44, 45);
    pasteBtn.backgroundColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.1];
    pasteBtn.layer.cornerRadius = 10;
    if (@available(iOS 13.0, *)) [pasteBtn setImage:[UIImage systemImageNamed:@"doc.on.clipboard.fill"] forState:UIControlStateNormal];
    pasteBtn.tintColor = [WolFoxProTheme accent];
    [pasteBtn addTarget:self action:@selector(pasteCoordinates) forControlEvents:UIControlEventTouchUpInside];
    pasteBtn.accessibilityLabel = @"لصق الإحداثيات من الحافظة";
    [kbCard addSubview:pasteBtn];
    
    // Activate / Apply Button
    UIButton *applyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    applyBtn.frame = CGRectMake(15, 75, kbCard.bounds.size.width - 30, 44);
    applyBtn.backgroundColor = [WolFoxProTheme accent]; applyBtn.layer.cornerRadius = 12;
    [applyBtn setTitle:@"إضافة وتفعيل الإحداثيات" forState:UIControlStateNormal]; [applyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    applyBtn.titleLabel.font = [WolFoxProTheme fontOfSize:15 weight:UIFontWeightBlack];
    [applyBtn addTarget:self action:@selector(applyManualCoords) forControlEvents:UIControlEventTouchUpInside];
    applyBtn.accessibilityLabel = @"تطبيق الإحداثيات وتشغيل الموقع الوهمي";
    [kbCard addSubview:applyBtn];

    // GPS input and activation live in one card to reduce visual fragmentation.
    [kbCard addSubview:[self royalSwitchInside:kbCard t:@"تفعيل الموقع الوهمي" i:@"location.fill" isOn:[WolFoxProStore shared].spoofActive y:130 action:^(UISwitch *s){
        if (s.on) {
            [WolFoxProStore shared].spoofActive = YES;
            [[WolFoxProStore shared] saveSettings];
            [[WolFoxProHookManager shared] deliverFakeUpdate];
            [self showRealLocation];
            [self refreshSpoofHeaderStatus];
            [self showToast:@"✅ تم تشغيل تزييف الموقع وسيستمر حتى إيقافه"];
        } else {
            [self confirmDisableSpoofForSwitch:s];
        }
    }]];

    WolFoxProStore *locationStore = [WolFoxProStore shared];
    NSArray *savedLocations = locationStore.locations;
    NSUInteger historyCount = locationStore.locationHistory.count;
    NSUInteger profileCount = locationStore.locationProfiles.count;
    BOOL favoritesEmpty = savedLocations.count == 0;
    CGFloat favoritesHeight = favoritesEmpty ? 308.0 : 246.0;
    // favoritesY محسوبة بناءً على kbCard (y=466, h=210) + 15 margin
    CGFloat favoritesY = 466.0 + 210.0 + 15.0; // = 691.0 — ثابتة لمحاذاة المحتوى
    CGFloat cy = favoritesY + favoritesHeight + 15.0;

    // FIX: أنشئ favoritesCard أولاً حتى يصبح Z-order صحيحاً (routeCard فوقها)
    UIView *favoritesCard = [[UIView alloc] initWithFrame:CGRectMake(15, favoritesY, w - 30, favoritesHeight)];
    favoritesCard.backgroundColor = [WolFoxProTheme surfacePrimary];
    favoritesCard.layer.cornerRadius = 18;
    [_scrollDashboard addSubview:favoritesCard];

    UIView *routeCard = [[UIView alloc] initWithFrame:CGRectMake(15, cy, w - 30, 276)];
    routeCard.backgroundColor = [WolFoxProTheme surfacePrimary];
    routeCard.layer.cornerRadius = 18;
    [_scrollDashboard addSubview:routeCard];

    UILabel *speedLabel = [[UILabel alloc] initWithFrame:CGRectMake(18, 12, routeCard.bounds.size.width - 36, 24)];
    speedLabel.text = [NSString stringWithFormat:@"السرعة: %.0f كم/س", [WolFoxProStore shared].simSpeed];
    speedLabel.textColor = [WolFoxProTheme textPrimary];
    speedLabel.textAlignment = NSTextAlignmentRight;
    speedLabel.font = [WolFoxProTheme fontOfSize:14 weight:UIFontWeightBold];
    [routeCard addSubview:speedLabel];
    objc_setAssociatedObject(self, "_speed_label", speedLabel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UISlider *speedSlider = [[UISlider alloc] initWithFrame:CGRectMake(18, 38, routeCard.bounds.size.width - 36, 30)];
    speedSlider.minimumValue = 1;
    speedSlider.maximumValue = 120;
    speedSlider.value = MAX(1, [WolFoxProStore shared].simSpeed);
    speedSlider.minimumTrackTintColor = [WolFoxProTheme accent];
    [speedSlider addTarget:self action:@selector(speedChanged:) forControlEvents:UIControlEventValueChanged];
    [routeCard addSubview:speedSlider];

    UILabel *intervalLabel = [[UILabel alloc] initWithFrame:CGRectMake(18, 68, routeCard.bounds.size.width - 36, 22)];
    intervalLabel.text = [NSString stringWithFormat:@"معدل التحديث: %.2f ث", [WolFoxProStore shared].updateIntervalSeconds];
    intervalLabel.textColor = [WolFoxProTheme textPrimary];
    intervalLabel.textAlignment = NSTextAlignmentRight;
    intervalLabel.font = [WolFoxProTheme fontOfSize:13 weight:UIFontWeightBold];
    [routeCard addSubview:intervalLabel];
    objc_setAssociatedObject(self, "_interval_label", intervalLabel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UISlider *intervalSlider = [[UISlider alloc] initWithFrame:CGRectMake(18, 88, routeCard.bounds.size.width - 36, 26)];
    intervalSlider.minimumValue = WFMinimumGPSUpdateIntervalSeconds;
    intervalSlider.maximumValue = WFMaximumGPSUpdateIntervalSeconds;
    intervalSlider.value = WFClampGPSUpdateInterval([WolFoxProStore shared].updateIntervalSeconds);
    intervalSlider.minimumTrackTintColor = [WolFoxProTheme gold];
    intervalSlider.accessibilityLabel = @"معدل تحديث المسار بالثواني";
    [intervalSlider addTarget:self action:@selector(updateIntervalChanged:) forControlEvents:UIControlEventValueChanged];
    [routeCard addSubview:intervalSlider];

    UILabel *jitterLabel = [[UILabel alloc] initWithFrame:CGRectMake(80, 116, routeCard.bounds.size.width - 98, 32)];
    jitterLabel.text = @"حركة طبيعية بسيطة";
    jitterLabel.textColor = [WolFoxProTheme textSecondary];
    jitterLabel.textAlignment = NSTextAlignmentRight;
    jitterLabel.font = [WolFoxProTheme fontOfSize:13 weight:UIFontWeightSemibold];
    [routeCard addSubview:jitterLabel];
    UISwitch *jitterSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(18, 116, 50, 30)];
    jitterSwitch.on = [WolFoxProStore shared].jitterActive;
    jitterSwitch.onTintColor = [WolFoxProTheme accent];
    [jitterSwitch addTarget:self action:@selector(jitterChanged:) forControlEvents:UIControlEventValueChanged];
    [routeCard addSubview:jitterSwitch];

    UIButton *routeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    routeButton.frame = CGRectMake(18, 156, routeCard.bounds.size.width - 36, 42);
    routeButton.backgroundColor = [WolFoxProStore shared].routeActive ? [WolFoxProTheme danger] : [WolFoxProTheme accent];
    routeButton.layer.cornerRadius = 12;
    [routeButton setTitle:[WolFoxProStore shared].routeActive ? @"إيقاف المحاكاة" : @"بدء محاكاة المسار" forState:UIControlStateNormal];
    [routeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    routeButton.titleLabel.font = [WolFoxProTheme fontOfSize:14 weight:UIFontWeightBlack];
    [routeButton addTarget:self action:@selector(toggleRouteSimulation) forControlEvents:UIControlEventTouchUpInside];
    routeButton.accessibilityLabel = [WolFoxProStore shared].routeActive ? @"إيقاف محاكاة المسار" : @"بدء محاكاة المسار";
    [routeCard addSubview:routeButton];
    objc_setAssociatedObject(self, "_route_btn", routeButton, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UIButton *saveRouteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    saveRouteButton.frame = CGRectMake(18, 208, (routeCard.bounds.size.width - 48) / 2.0, 48);
    saveRouteButton.backgroundColor = [WolFoxProTheme accentSoft];
    saveRouteButton.layer.cornerRadius = 12;
    [saveRouteButton setTitle:@"حفظ المسار" forState:UIControlStateNormal];
    [saveRouteButton setTitleColor:[WolFoxProTheme accent] forState:UIControlStateNormal];
    saveRouteButton.titleLabel.font = [WolFoxProTheme fontOfSize:13 weight:UIFontWeightBold];
    [saveRouteButton addTarget:self action:@selector(saveCurrentRoute) forControlEvents:UIControlEventTouchUpInside];
    saveRouteButton.accessibilityLabel = @"حفظ مسار الحركة الحالي";
    [routeCard addSubview:saveRouteButton];

    UIButton *savedRoutesButton = [UIButton buttonWithType:UIButtonTypeSystem];
    savedRoutesButton.frame = CGRectMake(30 + (routeCard.bounds.size.width - 48) / 2.0, 208, (routeCard.bounds.size.width - 48) / 2.0, 48);
    savedRoutesButton.backgroundColor = [WolFoxProTheme accentSoft];
    savedRoutesButton.layer.cornerRadius = 12;
    [savedRoutesButton setTitle:@"المسارات المحفوظة" forState:UIControlStateNormal];
    [savedRoutesButton setTitleColor:[WolFoxProTheme accent] forState:UIControlStateNormal];
    savedRoutesButton.titleLabel.font = [WolFoxProTheme fontOfSize:13 weight:UIFontWeightBold];
    [savedRoutesButton addTarget:self action:@selector(showSavedRoutes) forControlEvents:UIControlEventTouchUpInside];
    savedRoutesButton.accessibilityLabel = @"إدارة مسارات الحركة المحفوظة";
    [routeCard addSubview:savedRoutesButton];
    cy += 291;

    UILabel *favoritesTitle = [[UILabel alloc] initWithFrame:CGRectMake(18, 14, favoritesCard.bounds.size.width - 36, 24)];
    favoritesTitle.text = @"المفضلة";
    favoritesTitle.textAlignment = NSTextAlignmentRight;
    favoritesTitle.textColor = [WolFoxProTheme textPrimary];
    favoritesTitle.font = [WolFoxProTheme fontOfSize:16 weight:UIFontWeightBold];
    [favoritesCard addSubview:favoritesTitle];

    UILabel *favoritesCount = [[UILabel alloc] initWithFrame:CGRectMake(18, 16, 150, 22)];
    favoritesCount.text = favoritesEmpty ? @"لا توجد مواقع" : [NSString stringWithFormat:@"%lu مواقع محفوظة", (unsigned long)savedLocations.count];
    favoritesCount.textAlignment = NSTextAlignmentLeft;
    favoritesCount.textColor = [WolFoxProTheme accent];
    favoritesCount.font = [WolFoxProTheme fontOfSize:12 weight:UIFontWeightBold];
    [favoritesCard addSubview:favoritesCount];

    CGFloat actionW = (favoritesCard.bounds.size.width - 48) / 2.0;
    CGFloat favoritesActionsY = favoritesEmpty ? 116.0 : 54.0;
    if (favoritesEmpty) {
        UIImageView *emptyIcon = [[UIImageView alloc] initWithFrame:CGRectMake((favoritesCard.bounds.size.width - 34) / 2.0, 48, 34, 34)];
        if (@available(iOS 13.0, *)) emptyIcon.image = [UIImage systemImageNamed:@"star.slash"];
        emptyIcon.tintColor = [WolFoxProTheme textSecondary];
        emptyIcon.contentMode = UIViewContentModeScaleAspectFit;
        emptyIcon.isAccessibilityElement = NO;
        [favoritesCard addSubview:emptyIcon];
        UILabel *emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 84, favoritesCard.bounds.size.width - 40, 22)];
        emptyLabel.text = @"احفظ موقعك الأول للوصول إليه سريعاً";
        emptyLabel.textColor = [WolFoxProTheme textSecondary];
        emptyLabel.font = [WolFoxProTheme fontOfSize:12 weight:UIFontWeightSemibold];
        emptyLabel.textAlignment = NSTextAlignmentCenter;
        [favoritesCard addSubview:emptyLabel];
    }
    UIButton *saveFav = [UIButton buttonWithType:UIButtonTypeSystem];
    saveFav.frame = favoritesEmpty ? CGRectMake(16, favoritesActionsY, favoritesCard.bounds.size.width - 32, 52) : CGRectMake(16, favoritesActionsY, actionW, 52);
    saveFav.backgroundColor = [[WolFoxProTheme gold] colorWithAlphaComponent:0.12];
    saveFav.layer.cornerRadius = 13;
    [saveFav setTitle:@"حفظ الموقع" forState:UIControlStateNormal];
    [saveFav setTitleColor:[WolFoxProTheme gold] forState:UIControlStateNormal];
    saveFav.titleLabel.font = [WolFoxProTheme fontOfSize:14 weight:UIFontWeightBold];
    if (@available(iOS 13.0, *)) [saveFav setImage:[UIImage systemImageNamed:@"star.fill"] forState:UIControlStateNormal];
    saveFav.tintColor = [WolFoxProTheme gold];
    [saveFav addTarget:self action:@selector(saveCurrentLocation) forControlEvents:UIControlEventTouchUpInside];
    saveFav.accessibilityLabel = @"حفظ الموقع الحالي في المفضلة";
    [favoritesCard addSubview:saveFav];

    if (!favoritesEmpty) {
        UIButton *showFav = [UIButton buttonWithType:UIButtonTypeSystem];
        showFav.frame = CGRectMake(32 + actionW, favoritesActionsY, actionW, 52);
        showFav.backgroundColor = [[WolFoxProTheme gold] colorWithAlphaComponent:0.12];
        showFav.layer.cornerRadius = 13;
        [showFav setTitle:@"عرض المفضلة" forState:UIControlStateNormal];
        [showFav setTitleColor:[WolFoxProTheme gold] forState:UIControlStateNormal];
        showFav.titleLabel.font = [WolFoxProTheme fontOfSize:14 weight:UIFontWeightBold];
        if (@available(iOS 13.0, *)) [showFav setImage:[UIImage systemImageNamed:@"list.bullet"] forState:UIControlStateNormal];
        showFav.tintColor = [WolFoxProTheme gold];
        [showFav addTarget:self action:@selector(showSavedLocations) forControlEvents:UIControlEventTouchUpInside];
        showFav.accessibilityLabel = @"عرض المواقع المحفوظة";
        [favoritesCard addSubview:showFav];
    }

    UIButton *historyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    CGFloat historyY = favoritesEmpty ? 178.0 : 116.0;
    historyButton.frame = CGRectMake(16, historyY, favoritesCard.bounds.size.width - 32, 52);
    historyButton.backgroundColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.12];
    historyButton.layer.cornerRadius = 13;
    [historyButton setTitle:(historyCount ? [NSString stringWithFormat:@"سجل المواقع • %lu", (unsigned long)historyCount] : @"سجل المواقع فارغ") forState:UIControlStateNormal];
    [historyButton setTitleColor:[WolFoxProTheme accent] forState:UIControlStateNormal];
    historyButton.titleLabel.font = [WolFoxProTheme fontOfSize:14 weight:UIFontWeightBold];
    if (@available(iOS 13.0, *)) [historyButton setImage:[UIImage systemImageNamed:@"clock.arrow.circlepath"] forState:UIControlStateNormal];
    historyButton.tintColor = [WolFoxProTheme accent];
    historyButton.enabled = historyCount > 0;
    historyButton.alpha = historyCount > 0 ? 1.0 : 0.5;
    [historyButton addTarget:self action:@selector(showLocationHistory) forControlEvents:UIControlEventTouchUpInside];
    historyButton.accessibilityLabel = historyCount > 0 ? @"عرض سجل المواقع المستخدمة" : @"سجل المواقع فارغ";
    [favoritesCard addSubview:historyButton];

    UIButton *profilesButton = [UIButton buttonWithType:UIButtonTypeSystem];
    CGFloat profilesY = favoritesEmpty ? 240.0 : 178.0;
    profilesButton.frame = CGRectMake(16, profilesY, favoritesCard.bounds.size.width - 32, 52);
    profilesButton.backgroundColor = [[WolFoxProTheme gold] colorWithAlphaComponent:0.12];
    profilesButton.layer.cornerRadius = 13;
    [profilesButton setTitle:(profileCount ? [NSString stringWithFormat:@"ملفات المواقع السريعة • %lu", (unsigned long)profileCount] : @"إنشاء ملف موقع سريع") forState:UIControlStateNormal];
    [profilesButton setTitleColor:[WolFoxProTheme gold] forState:UIControlStateNormal];
    profilesButton.titleLabel.font = [WolFoxProTheme fontOfSize:14 weight:UIFontWeightBold];
    if (@available(iOS 13.0, *)) [profilesButton setImage:[UIImage systemImageNamed:@"slider.horizontal.3"] forState:UIControlStateNormal];
    profilesButton.tintColor = [WolFoxProTheme gold];
    [profilesButton addTarget:self action:@selector(showLocationProfiles) forControlEvents:UIControlEventTouchUpInside];
    profilesButton.accessibilityLabel = @"عرض أو إنشاء ملفات المواقع السريعة";
    [favoritesCard addSubview:profilesButton];

    UIView *scheduleCard = [[UIView alloc] initWithFrame:CGRectMake(15, cy, w - 30, 72)];
    scheduleCard.backgroundColor = [WolFoxProTheme surfacePrimary];
    scheduleCard.layer.cornerRadius = 18;
    [_scrollDashboard addSubview:scheduleCard];
    UIButton *scheduleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    scheduleButton.frame = scheduleCard.bounds;
    [scheduleButton setTitle:@"جدولة التزييف   " forState:UIControlStateNormal];
    [scheduleButton setTitleColor:[WolFoxProTheme textPrimary] forState:UIControlStateNormal];
    scheduleButton.titleLabel.font = [WolFoxProTheme fontOfSize:16 weight:UIFontWeightBold];
    scheduleButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    scheduleButton.contentEdgeInsets = UIEdgeInsetsMake(0, 18, 0, 18);
#pragma clang diagnostic pop
    if (@available(iOS 13.0, *)) [scheduleButton setImage:[UIImage systemImageNamed:@"calendar.badge.clock"] forState:UIControlStateNormal];
    scheduleButton.tintColor = [WolFoxProTheme accent];
    scheduleButton.accessibilityLabel = @"فتح قسم جدولة التزييف";
    [scheduleButton addTarget:self action:@selector(showSpoofSchedulePage) forControlEvents:UIControlEventTouchUpInside];
    [scheduleCard addSubview:scheduleButton];
    cy += 87;

    // إعدادات الكاميرا الافتراضية موجودة في تبويب الكاميرا المستقل لتبقى واضحة ومعزولة.
    cy += 20.0;
    _scrollDashboard.contentSize = CGSizeMake(w, cy + 30);
}


#pragma mark - Unified virtual camera

- (void)setupVirtualCameraCardAtY:(CGFloat)y width:(CGFloat)w {
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(15, y, w - 30, 450)];
    card.backgroundColor = [WolFoxProTheme surfacePrimary];
    card.layer.cornerRadius = 18.0;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.30].CGColor;
    [_scrollDashboard addSubview:card];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(18, 12, card.bounds.size.width - 36, 26)];
    title.text = @"الكاميرا الافتراضية";
    title.textAlignment = NSTextAlignmentCenter;
    title.textColor = [WolFoxProTheme textPrimary];
    title.font = [WolFoxProTheme fontOfSize:17 weight:UIFontWeightBlack];
    [card addSubview:title];

    _cameraStateLabel = [[UILabel alloc] initWithFrame:CGRectMake(18, 41, card.bounds.size.width - 36, 22)];
    _cameraStateLabel.textAlignment = NSTextAlignmentCenter;
    _cameraStateLabel.font = [WolFoxProTheme fontOfSize:12 weight:UIFontWeightBold];
    _cameraStateLabel.accessibilityTraits = UIAccessibilityTraitUpdatesFrequently;
    [card addSubview:_cameraStateLabel];

    _cameraPreviewImageView = [[UIImageView alloc] initWithFrame:CGRectMake(18, 70, card.bounds.size.width - 36, 145)];
    _cameraPreviewImageView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.38];
    _cameraPreviewImageView.contentMode = UIViewContentModeScaleAspectFit;
    _cameraPreviewImageView.clipsToBounds = YES;
    _cameraPreviewImageView.layer.cornerRadius = 13.0;
    _cameraPreviewImageView.isAccessibilityElement = YES;
    [card addSubview:_cameraPreviewImageView];

    UILabel *placeholder = [[UILabel alloc] initWithFrame:_cameraPreviewImageView.bounds];
    placeholder.tag = 2742;
    placeholder.text = @"اختر صورة لعرضها مكان بث الكاميرا";
    placeholder.textAlignment = NSTextAlignmentCenter;
    placeholder.numberOfLines = 2;
    placeholder.textColor = [WolFoxProTheme textSecondary];
    placeholder.font = [WolFoxProTheme fontOfSize:12 weight:UIFontWeightSemibold];
    [_cameraPreviewImageView addSubview:placeholder];

    UIButton *selectButton = [UIButton buttonWithType:UIButtonTypeSystem];
    selectButton.frame = CGRectMake(18, 226, card.bounds.size.width - 36, 44);
    selectButton.backgroundColor = [WolFoxProTheme accent];
    selectButton.layer.cornerRadius = 12.0;
    [selectButton setTitle:@"اختيار صورة وتشغيلها" forState:UIControlStateNormal];
    [selectButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    selectButton.titleLabel.font = [WolFoxProTheme fontOfSize:14 weight:UIFontWeightBold];
    if (@available(iOS 13.0, *)) [selectButton setImage:[UIImage systemImageNamed:@"photo.on.rectangle.angled"] forState:UIControlStateNormal];
    selectButton.tintColor = UIColor.whiteColor;
    selectButton.accessibilityLabel = @"اختيار صورة واحدة وتشغيل الكاميرا الافتراضية";
    [selectButton addTarget:self action:@selector(selectVirtualCameraImage) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:selectButton];

    _cameraToggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _cameraToggleButton.frame = CGRectMake(18, 280, card.bounds.size.width - 36, 44);
    _cameraToggleButton.layer.cornerRadius = 12.0;
    [_cameraToggleButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _cameraToggleButton.titleLabel.font = [WolFoxProTheme fontOfSize:14 weight:UIFontWeightBold];
    [_cameraToggleButton addTarget:self action:@selector(toggleVirtualCameraFromPage) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:_cameraToggleButton];

    UIView *rememberRow = [[UIView alloc] initWithFrame:CGRectMake(18, 334, card.bounds.size.width - 36, 48)];
    rememberRow.backgroundColor = [WolFoxProTheme surfaceSecondary];
    rememberRow.layer.cornerRadius = 12.0;
    [card addSubview:rememberRow];
    UILabel *rememberLabel = [[UILabel alloc] initWithFrame:CGRectMake(70, 0, rememberRow.bounds.size.width - 84, 48)];
    rememberLabel.text = @"حفظ آخر صورة للاستخدام القادم";
    rememberLabel.textAlignment = NSTextAlignmentRight;
    rememberLabel.textColor = [WolFoxProTheme textPrimary];
    rememberLabel.font = [WolFoxProTheme fontOfSize:12 weight:UIFontWeightSemibold];
    [rememberRow addSubview:rememberLabel];
    _cameraRememberSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(10, 8, 52, 32)];
    _cameraRememberSwitch.onTintColor = [WolFoxProTheme accent];
    [_cameraRememberSwitch addTarget:self action:@selector(rememberVirtualCameraChanged:) forControlEvents:UIControlEventValueChanged];
    [rememberRow addSubview:_cameraRememberSwitch];

    UIButton *clearButton = [UIButton buttonWithType:UIButtonTypeSystem];
    clearButton.frame = CGRectMake(18, 393, card.bounds.size.width - 36, 40);
    clearButton.backgroundColor = [[WolFoxProTheme danger] colorWithAlphaComponent:0.14];
    clearButton.layer.cornerRadius = 11.0;
    clearButton.layer.borderWidth = 1.0;
    clearButton.layer.borderColor = [[WolFoxProTheme danger] colorWithAlphaComponent:0.55].CGColor;
    [clearButton setTitle:@"مسح الصورة وإيقاف البث" forState:UIControlStateNormal];
    [clearButton setTitleColor:[WolFoxProTheme danger] forState:UIControlStateNormal];
    clearButton.titleLabel.font = [WolFoxProTheme fontOfSize:12 weight:UIFontWeightBold];
    [clearButton addTarget:self action:@selector(clearSpoofedImage) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:clearButton];

    [self refreshVirtualCameraPage];
}

- (void)selectVirtualCameraImage {
    [[WFVirtualCameraManager shared] presentImagePickerFromViewController:self];
}

- (void)toggleVirtualCameraFromPage {
    WFVirtualCameraManager *manager = [WFVirtualCameraManager shared];
    if (manager.enabled) manager.enabled = NO;
    else if (![manager enableUsingAvailableImage]) [self selectVirtualCameraImage];
    [self refreshVirtualCameraPage];
}

- (void)rememberVirtualCameraChanged:(UISwitch *)sender {
    [WFVirtualCameraManager shared].rememberLastImage = sender.isOn;
}

- (void)virtualCameraStateChanged:(__unused NSNotification *)notification {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self virtualCameraStateChanged:nil]; });
        return;
    }
    [self refreshSpoofHeaderStatus];
    [self refreshVirtualCameraPage];
}

- (void)refreshVirtualCameraPage {
    WFVirtualCameraManager *manager = [WFVirtualCameraManager shared];
    UIImage *image = manager.currentImage;
    _cameraPreviewImageView.image = image;
    UIView *placeholder = [_cameraPreviewImageView viewWithTag:2742];
    placeholder.hidden = image != nil;
    _cameraPreviewImageView.accessibilityLabel = image ? @"معاينة الصورة المستخدمة في البث" : @"لا توجد صورة مختارة";
    _cameraRememberSwitch.on = manager.rememberLastImage;
    if (manager.enabled) {
        _cameraStateLabel.text = @"● البث الافتراضي يعمل الآن";
        _cameraStateLabel.textColor = [WolFoxProTheme success];
        [_cameraToggleButton setTitle:@"إيقاف البث الافتراضي مؤقتاً" forState:UIControlStateNormal];
        _cameraToggleButton.backgroundColor = [WolFoxProTheme success];
    } else {
        _cameraStateLabel.text = image ? @"○ توجد صورة جاهزة — البث متوقف" : @"○ لم يتم اختيار صورة";
        _cameraStateLabel.textColor = [WolFoxProTheme textSecondary];
        [_cameraToggleButton setTitle:@"تشغيل البث الافتراضي" forState:UIControlStateNormal];
        _cameraToggleButton.backgroundColor = [UIColor colorWithRed:0.16 green:0.24 blue:0.34 alpha:1.0];
    }
}

#pragma mark - Local Spoof Schedule

- (NSString *)scheduleTimeText:(NSInteger)minutes {
    NSInteger value = MAX(0, MIN(1439, minutes));
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)(value / 60), (long)(value % 60)];
}

- (WolFoxProLocation *)selectedScheduleLocation {
    long long identifier = [WolFoxProStore shared].scheduleLocationID;
    for (WolFoxProLocation *location in [WolFoxProStore shared].locations) {
        if (location.ID == identifier) return location;
    }
    return nil;
}

- (void)showSpoofSchedulePage {
    if (_schedulePage) return;
    if (_mapExpanded) [self closeExpandedMapIfNeeded];
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    CGFloat safeTop = MAX(self.view.safeAreaInsets.top, 18.0);
    UIView *page = [[UIView alloc] initWithFrame:self.view.bounds];
    page.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    page.backgroundColor = [WolFoxProTheme royalBackground];
    page.accessibilityViewIsModal = YES;
    _schedulePage = page;
    [self.view addSubview:page];

    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, safeTop + 62)];
    header.backgroundColor = [WolFoxProTheme surfacePrimary];
    [page addSubview:header];
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(70, safeTop + 12, w - 140, 34)];
    title.text = @"جدولة التزييف";
    title.textColor = [WolFoxProTheme textPrimary];
    title.font = [WolFoxProTheme fontOfSize:20 weight:UIFontWeightBlack];
    title.textAlignment = NSTextAlignmentCenter;
    [header addSubview:title];
    UIButton *close = [self headerCircleBtn:@"xmark" color:[WolFoxProTheme danger] x:w - 58];
    close.accessibilityLabel = @"إغلاق جدولة التزييف";
    [close addTarget:self action:@selector(closeSpoofSchedulePage) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:close];

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(header.frame), w, h - CGRectGetMaxY(header.frame))];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scroll.alwaysBounceVertical = YES;
    [page addSubview:scroll];

    CGFloat y = 16;
    UIView *statusCard = [[UIView alloc] initWithFrame:CGRectMake(15, y, w - 30, 98)];
    statusCard.backgroundColor = [WolFoxProTheme surfacePrimary];
    statusCard.layer.cornerRadius = 18;
    [scroll addSubview:statusCard];
    UILabel *statusTitle = [[UILabel alloc] initWithFrame:CGRectMake(18, 14, statusCard.bounds.size.width - 96, 25)];
    statusTitle.text = @"تشغيل الجدول";
    statusTitle.textColor = [WolFoxProTheme textPrimary];
    statusTitle.textAlignment = NSTextAlignmentRight;
    statusTitle.font = [WolFoxProTheme fontOfSize:16 weight:UIFontWeightBold];
    [statusCard addSubview:statusTitle];
    UISwitch *enabled = [[UISwitch alloc] initWithFrame:CGRectMake(16, 12, 52, 32)];
    enabled.tag = 9101;
    enabled.onTintColor = [WolFoxProTheme accent];
    [enabled addTarget:self action:@selector(scheduleEnabledChanged:) forControlEvents:UIControlEventValueChanged];
    [statusCard addSubview:enabled];
    UILabel *status = [[UILabel alloc] initWithFrame:CGRectMake(18, 52, statusCard.bounds.size.width - 36, 28)];
    status.tag = 9102;
    status.backgroundColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.10];
    status.layer.cornerRadius = 9; status.clipsToBounds = YES;
    status.textAlignment = NSTextAlignmentCenter;
    status.font = [WolFoxProTheme fontOfSize:12 weight:UIFontWeightBold];
    [statusCard addSubview:status];
    y += 114;

    UILabel *daysTitle = [[UILabel alloc] initWithFrame:CGRectMake(18, y, w - 36, 24)];
    daysTitle.text = @"أيام التشغيل";
    daysTitle.textColor = [WolFoxProTheme textPrimary];
    daysTitle.textAlignment = NSTextAlignmentRight;
    daysTitle.font = [WolFoxProTheme fontOfSize:16 weight:UIFontWeightBold];
    [scroll addSubview:daysTitle];
    y += 32;
    NSArray *dayNames = @[@"الأحد", @"الاثنين", @"الثلاثاء", @"الأربعاء", @"الخميس", @"الجمعة", @"السبت"];
    NSArray *dayShortNames = @[@"ح", @"ن", @"ث", @"ر", @"خ", @"ج", @"س"];
    CGFloat buttonW = (w - 46) / 7.0;
    for (NSInteger index = 0; index < 7; index++) {
        UIButton *dayButton = [UIButton buttonWithType:UIButtonTypeSystem];
        dayButton.frame = CGRectMake(15 + index * (buttonW + 2), y, buttonW, 46);
        dayButton.tag = 9301 + index;
        dayButton.layer.cornerRadius = 12;
        dayButton.titleLabel.font = [WolFoxProTheme fontOfSize:15 weight:UIFontWeightBlack];
        [dayButton setTitle:dayShortNames[index] forState:UIControlStateNormal];
        dayButton.accessibilityLabel = dayNames[index];
        [dayButton addTarget:self action:@selector(scheduleDayPressed:) forControlEvents:UIControlEventTouchUpInside];
        [scroll addSubview:dayButton];
    }
    y += 62;

    UILabel *locationTitle = [[UILabel alloc] initWithFrame:CGRectMake(18, y, w - 36, 24)];
    locationTitle.text = @"الموقع من المفضلة";
    locationTitle.textColor = [WolFoxProTheme textPrimary];
    locationTitle.textAlignment = NSTextAlignmentRight;
    locationTitle.font = [WolFoxProTheme fontOfSize:16 weight:UIFontWeightBold];
    [scroll addSubview:locationTitle];
    y += 30;
    UIButton *locationButton = [UIButton buttonWithType:UIButtonTypeSystem];
    locationButton.tag = 9103;
    locationButton.frame = CGRectMake(15, y, w - 30, 56);
    locationButton.backgroundColor = [WolFoxProTheme surfacePrimary];
    locationButton.layer.cornerRadius = 15;
    locationButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    locationButton.contentEdgeInsets = UIEdgeInsetsMake(0, 18, 0, 18);
#pragma clang diagnostic pop
    locationButton.titleLabel.font = [WolFoxProTheme fontOfSize:14 weight:UIFontWeightBold];
    locationButton.tintColor = [WolFoxProTheme accent];
    if (@available(iOS 13.0, *)) [locationButton setImage:[UIImage systemImageNamed:@"star.fill"] forState:UIControlStateNormal];
    [locationButton addTarget:self action:@selector(selectScheduleLocation) forControlEvents:UIControlEventTouchUpInside];
    [scroll addSubview:locationButton];
    y += 74;

    UILabel *timesTitle = [[UILabel alloc] initWithFrame:CGRectMake(18, y, w - 36, 24)];
    timesTitle.text = @"وقت التزييف";
    timesTitle.textColor = [WolFoxProTheme textPrimary];
    timesTitle.textAlignment = NSTextAlignmentRight;
    timesTitle.font = [WolFoxProTheme fontOfSize:16 weight:UIFontWeightBold];
    [scroll addSubview:timesTitle];
    y += 30;
    CGFloat timeWidth = (w - 45) / 2.0;
    for (NSInteger index = 0; index < 2; index++) {
        UIButton *timeButton = [UIButton buttonWithType:UIButtonTypeSystem];
        timeButton.tag = 9201 + index;
        timeButton.frame = CGRectMake(15 + index * (timeWidth + 15), y, timeWidth, 64);
        timeButton.backgroundColor = [WolFoxProTheme surfacePrimary];
        timeButton.layer.cornerRadius = 15;
        timeButton.titleLabel.numberOfLines = 2;
        timeButton.titleLabel.textAlignment = NSTextAlignmentCenter;
        timeButton.titleLabel.font = [WolFoxProTheme fontOfSize:15 weight:UIFontWeightBlack];
        timeButton.tintColor = [WolFoxProTheme accent];
        [timeButton addTarget:self action:@selector(selectScheduleTime:) forControlEvents:UIControlEventTouchUpInside];
        [scroll addSubview:timeButton];
    }
    y += 84;

    UIButton *save = [UIButton buttonWithType:UIButtonTypeSystem];
    save.frame = CGRectMake(15, y, w - 30, 54);
    save.backgroundColor = [WolFoxProTheme accent];
    save.layer.cornerRadius = 15;
    [save setTitle:@"حفظ وتطبيق الجدول" forState:UIControlStateNormal];
    [save setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    save.titleLabel.font = [WolFoxProTheme fontOfSize:16 weight:UIFontWeightBlack];
    save.accessibilityLabel = @"حفظ إعدادات جدولة التزييف";
    [save addTarget:self action:@selector(saveSpoofSchedule) forControlEvents:UIControlEventTouchUpInside];
    [scroll addSubview:save];
    y += 68;
    UILabel *note = [[UILabel alloc] initWithFrame:CGRectMake(22, y, w - 44, 52)];
    note.text = @"يعمل هذا الجدول عند تشغيل التطبيق فقط. عند نهاية الوقت المحدد، تعود حالة الموقع إلى الوضع الحقيقي.";
    note.textColor = [WolFoxProTheme textSecondary];
    note.font = [WolFoxProTheme fontOfSize:11 weight:UIFontWeightSemibold];
    note.numberOfLines = 0;
    note.textAlignment = NSTextAlignmentCenter;
    [scroll addSubview:note];
    scroll.contentSize = CGSizeMake(w, y + 72);
    [self refreshSpoofSchedulePage];
    page.alpha = 0;
    [UIView animateWithDuration:[WolFoxProTheme transitionDuration] animations:^{ page.alpha = 1; }];
}

- (void)closeSpoofSchedulePage {
    [_schedulePage removeFromSuperview];
    _schedulePage = nil;
    [[WFSpoofScheduleManager shared] updateTimerState];
    [self refreshSpoofHeaderStatus];
}

- (void)refreshSpoofSchedulePage {
    if (!_schedulePage) return;
    WolFoxProStore *store = [WolFoxProStore shared];
    UISwitch *enabled = (UISwitch *)[_schedulePage viewWithTag:9101];
    enabled.on = store.scheduleEnabled;
    UILabel *status = (UILabel *)[_schedulePage viewWithTag:9102];
    status.text = [[WFSpoofScheduleManager shared] statusDescription];
    status.textColor = [WFSpoofScheduleManager shared].isScheduleActiveNow ? [WolFoxProTheme success] : [WolFoxProTheme textSecondary];
    WolFoxProLocation *location = [self selectedScheduleLocation];
    UIButton *locationButton = (UIButton *)[_schedulePage viewWithTag:9103];
    [locationButton setTitle:(location ? [NSString stringWithFormat:@"  %@", location.name] : @"اختر موقعاً محفوظاً") forState:UIControlStateNormal];
    for (NSInteger day = 1; day <= 7; day++) {
        UIButton *button = (UIButton *)[_schedulePage viewWithTag:9300 + day];
        BOOL selected = [store.scheduleWeekdays containsObject:@(day)];
        button.backgroundColor = selected ? [WolFoxProTheme accent] : [WolFoxProTheme surfacePrimary];
        [button setTitleColor:(selected ? [UIColor whiteColor] : [WolFoxProTheme textSecondary]) forState:UIControlStateNormal];
    }
    UIButton *start = (UIButton *)[_schedulePage viewWithTag:9201];
    UIButton *end = (UIButton *)[_schedulePage viewWithTag:9202];
    [start setTitle:[NSString stringWithFormat:@"البداية\n%@", [self scheduleTimeText:store.scheduleStartMinutes]] forState:UIControlStateNormal];
    [end setTitle:[NSString stringWithFormat:@"النهاية\n%@", [self scheduleTimeText:store.scheduleEndMinutes]] forState:UIControlStateNormal];
}

- (void)scheduleEnabledChanged:(UISwitch *)sender {
    WolFoxProStore *store = [WolFoxProStore shared];
    store.scheduleEnabled = sender.on;
    store.scheduleDraftDirty = YES;
    [store saveSettings];
    [[WFSpoofScheduleManager shared] updateTimerState];
    [self refreshSpoofSchedulePage];
}

- (void)showScheduleLocationMissingNotice {
    [self refreshSpoofHeaderStatus];
    [self refreshSpoofSchedulePage];
    if (self.view.window && !self.view.hidden) {
        [self showToast:@"تم حذف موقع الجدول؛ اختر موقعاً محفوظاً جديداً"];
    }
}

- (void)scheduleDayPressed:(UIButton *)button {
    NSInteger day = button.tag - 9300;
    WolFoxProStore *store = [WolFoxProStore shared];
    NSMutableArray<NSNumber *> *days = [store.scheduleWeekdays mutableCopy] ?: [NSMutableArray new];
    NSNumber *value = @(day);
    if ([days containsObject:value]) [days removeObject:value]; else [days addObject:value];
    store.scheduleWeekdays = days;
    store.scheduleDraftDirty = YES;
    [store saveSettings];
    [[WFSpoofScheduleManager shared] updateTimerState];
    [self refreshSpoofSchedulePage];
}

- (void)selectScheduleLocation {
    NSArray<WolFoxProLocation *> *locations = [WolFoxProStore shared].locations;
    if (locations.count == 0) {
        [self showToast:@"احفظ موقعاً في المفضلة أولاً"];
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"اختر موقع الجدول" message:@"يُستخدم هذا الموقع عند دخول وقت التزييف." preferredStyle:UIAlertControllerStyleActionSheet];
    for (WolFoxProLocation *location in locations) {
        NSString *name = location.name.length ? location.name : @"موقع محفوظ";
        [alert addAction:[UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            WolFoxProStore *store = [WolFoxProStore shared];
            store.scheduleLocationID = location.ID;
            store.scheduleDraftDirty = YES;
            [store saveSettings];
            [[WFSpoofScheduleManager shared] updateTimerState];
            [self refreshSpoofSchedulePage];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = _schedulePage ?: self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(
            CGRectGetMidX((_schedulePage ?: self.view).bounds),
            CGRectGetMidY((_schedulePage ?: self.view).bounds), 1, 1);
    }
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)selectScheduleTime:(UIButton *)button {
    if (_scheduleTimePickerOverlay) return;
    _editingScheduleStartTime = button.tag == 9201;
    WolFoxProStore *store = [WolFoxProStore shared];
    NSInteger minutes = _editingScheduleStartTime ? store.scheduleStartMinutes : store.scheduleEndMinutes;
    NSCalendar *calendar = [NSCalendar autoupdatingCurrentCalendar];
    NSDateComponents *today = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:[NSDate date]];
    today.hour = minutes / 60;
    today.minute = minutes % 60;
    NSDate *date = [calendar dateFromComponents:today] ?: [NSDate date];
    UIView *overlay = [[UIView alloc] initWithFrame:_schedulePage.bounds];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlay.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.56];
    overlay.accessibilityViewIsModal = YES;
    _scheduleTimePickerOverlay = overlay;
    [_schedulePage addSubview:overlay];

    CGFloat width = MIN(340.0, MAX(280.0, overlay.bounds.size.width - 32.0));
    CGFloat height = 350.0;
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake((overlay.bounds.size.width - width) / 2.0, (overlay.bounds.size.height - height) / 2.0, width, height)];
    card.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    card.backgroundColor = [WolFoxProTheme surfacePrimary];
    card.layer.cornerRadius = 20;
    [overlay addSubview:card];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(54, 16, width - 108, 28)];
    title.text = _editingScheduleStartTime ? @"اختيار وقت البداية" : @"اختيار وقت النهاية";
    title.textColor = [WolFoxProTheme textPrimary];
    title.font = [WolFoxProTheme fontOfSize:17 weight:UIFontWeightBlack];
    title.textAlignment = NSTextAlignmentCenter;
    [card addSubview:title];
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(width - 50, 12, 38, 38);
    close.backgroundColor = [[WolFoxProTheme danger] colorWithAlphaComponent:0.14];
    close.layer.cornerRadius = 12;
    close.tintColor = [WolFoxProTheme danger];
    if (@available(iOS 13.0, *)) [close setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
    close.accessibilityLabel = @"إغلاق اختيار الوقت";
    [close addTarget:self action:@selector(closeScheduleTimePicker) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:close];

    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale autoupdatingCurrentLocale];
    formatter.timeZone = [NSTimeZone localTimeZone];
    formatter.dateStyle = NSDateFormatterNoStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    UILabel *deviceClock = [[UILabel alloc] initWithFrame:CGRectMake(18, 50, width - 36, 20)];
    deviceClock.text = [NSString stringWithFormat:@"وقت الجهاز الآن: %@", [formatter stringFromDate:[NSDate date]]];
    deviceClock.textColor = [WolFoxProTheme textSecondary];
    deviceClock.font = [WolFoxProTheme fontOfSize:11 weight:UIFontWeightSemibold];
    deviceClock.textAlignment = NSTextAlignmentCenter;
    [card addSubview:deviceClock];

    UIDatePicker *picker = [UIDatePicker new];
    picker.datePickerMode = UIDatePickerModeTime;
    picker.minuteInterval = 1;
    picker.locale = [NSLocale autoupdatingCurrentLocale];
    picker.timeZone = [NSTimeZone localTimeZone];
    picker.date = date;
    picker.frame = CGRectMake(22, 78, width - 44, 166);
    if (@available(iOS 13.4, *)) picker.preferredDatePickerStyle = UIDatePickerStyleWheels;
    picker.accessibilityLabel = @"اختيار ساعة ودقائق التزييف";
    [card addSubview:picker];
    _scheduleTimePicker = picker;

    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(18, 242, width - 36, 20)];
    hint.text = @"يمكن اختيار أي دقيقة من 00 إلى 59";
    hint.textColor = [WolFoxProTheme textSecondary];
    hint.font = [WolFoxProTheme fontOfSize:11 weight:UIFontWeightSemibold];
    hint.textAlignment = NSTextAlignmentCenter;
    [card addSubview:hint];

    CGFloat actionWidth = (width - 54) / 2.0;
    UIButton *cancel = [UIButton buttonWithType:UIButtonTypeSystem];
    cancel.frame = CGRectMake(18, 280, actionWidth, 52);
    cancel.backgroundColor = [[WolFoxProTheme danger] colorWithAlphaComponent:0.12];
    cancel.layer.cornerRadius = 14;
    [cancel setTitle:@"إلغاء" forState:UIControlStateNormal];
    [cancel setTitleColor:[WolFoxProTheme danger] forState:UIControlStateNormal];
    cancel.titleLabel.font = [WolFoxProTheme fontOfSize:15 weight:UIFontWeightBold];
    [cancel addTarget:self action:@selector(closeScheduleTimePicker) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:cancel];
    UIButton *confirm = [UIButton buttonWithType:UIButtonTypeSystem];
    confirm.frame = CGRectMake(36 + actionWidth, 280, actionWidth, 52);
    confirm.backgroundColor = [WolFoxProTheme accent];
    confirm.layer.cornerRadius = 14;
    [confirm setTitle:@"تأكيد الوقت" forState:UIControlStateNormal];
    [confirm setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    confirm.titleLabel.font = [WolFoxProTheme fontOfSize:15 weight:UIFontWeightBlack];
    [confirm addTarget:self action:@selector(confirmScheduleTimePicker) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:confirm];
    overlay.alpha = 0;
    [UIView animateWithDuration:[WolFoxProTheme transitionDuration] animations:^{ overlay.alpha = 1; }];
}

- (void)closeScheduleTimePicker {
    [_scheduleTimePickerOverlay removeFromSuperview];
    _scheduleTimePickerOverlay = nil;
    _scheduleTimePicker = nil;
}

- (void)confirmScheduleTimePicker {
    if (!_scheduleTimePicker) return;
    NSCalendar *calendar = [NSCalendar autoupdatingCurrentCalendar];
    NSDateComponents *components = [calendar components:(NSCalendarUnitHour | NSCalendarUnitMinute) fromDate:_scheduleTimePicker.date];
    NSInteger selectedMinutes = components.hour * 60 + components.minute;
    WolFoxProStore *store = [WolFoxProStore shared];
    if (_editingScheduleStartTime) store.scheduleStartMinutes = selectedMinutes;
    else store.scheduleEndMinutes = selectedMinutes;
    store.scheduleDraftDirty = YES;
    [store saveSettings];
    [[WFSpoofScheduleManager shared] updateTimerState];
    [self closeScheduleTimePicker];
    [self refreshSpoofSchedulePage];
}

- (void)saveSpoofSchedule {
    WolFoxProStore *store = [WolFoxProStore shared];
    if (store.scheduleEnabled && (![self selectedScheduleLocation] || store.scheduleWeekdays.count == 0 || store.scheduleStartMinutes == store.scheduleEndMinutes)) {
        [self showToast:@"اختر موقعاً وأياماً ووقت بداية/نهاية مختلفين"];
        return;
    }
    [store commitScheduleDraft];
    [store saveSettings];
    [[WFSpoofScheduleManager shared] updateTimerState];
    [self refreshSpoofSchedulePage];
    [self refreshSpoofHeaderStatus];
    [self showToast:store.scheduleEnabled ? @"تم حفظ الجدول" : @"تم إيقاف الجدولة"];
}

- (void)updateIntervalChanged:(UISlider *)sender {
    WolFoxProStore *store = [WolFoxProStore shared];
    store.updateIntervalSeconds = WFClampGPSUpdateInterval(sender.value);
    [store saveSettings];
    UILabel *label = objc_getAssociatedObject(self, "_interval_label");
    if (label) label.text = [NSString stringWithFormat:@"معدل التحديث: %.2f ث", store.updateIntervalSeconds];
    [self refreshLiveStatusCards];
    [[WolFoxProHookManager shared] restartActiveRouteTimer];
}

- (void)jitterChanged:(UISwitch *)sender {
    [WolFoxProStore shared].jitterActive = sender.on;
    [[WolFoxProStore shared] saveSettings];
}

- (UIButton *)mapCircleBtn:(NSString *)icon x:(CGFloat)x y:(CGFloat)y {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = CGRectMake(x, y, 44, 44);
    b.backgroundColor = [[WolFoxProTheme surfacePrimary] colorWithAlphaComponent:0.8];
    b.layer.cornerRadius = 22;
    if (@available(iOS 13.0, *)) [b setImage:[UIImage systemImageNamed:icon] forState:UIControlStateNormal];
    b.tintColor = [WolFoxProTheme accent]; return b;
}

- (void)expandMap {
    if (_mapExpanded || !self.mapView || !_mapCard) return;
    [self.searchBar resignFirstResponder];
    _mapExpanded = YES;

    UIView *container = [[UIView alloc] initWithFrame:self.view.bounds];
    container.backgroundColor = [WolFoxProTheme surfacePrimary];
    container.accessibilityViewIsModal = YES;
    _expandedMapContainer = container;

    [self.mapView removeFromSuperview];
    self.mapView.frame = container.bounds;
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [container addSubview:self.mapView];

    [self.searchBar removeFromSuperview];
    self.searchBar.tag = 6201;
    [container addSubview:self.searchBar];

    UIButton *closeButton = [self mapCircleBtn:@"xmark" x:0 y:0];
    closeButton.tag = 6202;
    closeButton.backgroundColor = [[WolFoxProTheme danger] colorWithAlphaComponent:0.94];
    closeButton.tintColor = [UIColor whiteColor];
    closeButton.accessibilityLabel = @"إغلاق الخريطة الموسعة";
    [closeButton addTarget:self action:@selector(closeExpandedMap) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:closeButton];
    _expandedMapCloseButton = closeButton;

    UIButton *styleButton = [self mapCircleBtn:@"map.fill" x:0 y:0];
    styleButton.tag = 6203;
    styleButton.tintColor = [WolFoxProTheme gold];
    styleButton.backgroundColor = [[WolFoxProTheme gold] colorWithAlphaComponent:0.14];
    styleButton.accessibilityLabel = @"تغيير نمط الخريطة";
    [styleButton addTarget:self action:@selector(toggleMapStyle) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:styleButton];

    UIButton *realButton = [self mapCircleBtn:@"person.fill" x:0 y:0];
    realButton.tag = 6204;
    realButton.tintColor = [WolFoxProTheme success];
    realButton.backgroundColor = [[WolFoxProTheme success] colorWithAlphaComponent:0.14];
    realButton.accessibilityLabel = @"عرض الموقع الحقيقي";
    [realButton addTarget:self action:@selector(showRealLocation) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:realButton];

    UIButton *pinButton = [self mapCircleBtn:@"location.fill" x:0 y:0];
    pinButton.tag = 6205;
    pinButton.tintColor = [WolFoxProTheme accent];
    pinButton.backgroundColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.14];
    pinButton.accessibilityLabel = @"التمركز على الموقع المحدد";
    [pinButton addTarget:self action:@selector(centerMapOnPin) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:pinButton];

    [self.view addSubview:container];
    [self layoutExpandedMap];
    container.alpha = 0;
    container.transform = CGAffineTransformMakeScale(0.985, 0.985);
    [UIView animateWithDuration:[WolFoxProTheme transitionDuration] animations:^{
        container.alpha = 1;
        container.transform = CGAffineTransformIdentity;
    } completion:^(__unused BOOL finished) {
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, self.searchBar);
    }];
}

- (void)layoutExpandedMap {
    if (!_mapExpanded || !_expandedMapContainer) return;
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    CGFloat safeTop = MAX(self.view.safeAreaInsets.top, 12.0);
    CGFloat safeBottom = MAX(self.view.safeAreaInsets.bottom, 12.0);
    _expandedMapContainer.frame = self.view.bounds;
    self.mapView.frame = _expandedMapContainer.bounds;
    self.searchBar.frame = CGRectMake(10, safeTop + 4, MAX(120, width - 78), 48);
    _expandedMapCloseButton.frame = CGRectMake(width - 56, safeTop + 6, 44, 44);
    CGFloat controlsY = height - safeBottom - 50;
    [_expandedMapContainer viewWithTag:6203].frame = CGRectMake(12, controlsY, 44, 44);
    [_expandedMapContainer viewWithTag:6204].frame = CGRectMake(64, controlsY, 44, 44);
    [_expandedMapContainer viewWithTag:6205].frame = CGRectMake(width - 56, controlsY, 44, 44);
}

- (void)closeExpandedMap {
    [self closeExpandedMapIfNeeded];
}

- (void)closeExpandedMapIfNeeded {
    if (!_mapExpanded) return;
    [self.searchBar resignFirstResponder];
    _mapExpanded = NO;

    [self.mapView removeFromSuperview];
    [self.searchBar removeFromSuperview];
    if (_mapCard) {
        self.mapView.autoresizingMask = UIViewAutoresizingNone;
        self.mapView.frame = _mapCard.bounds;
        [_mapCard insertSubview:self.mapView atIndex:0];
        self.searchBar.tag = 0;
        self.searchBar.frame = CGRectMake(10, 10, _mapCard.bounds.size.width - 20, 44);
        [_mapCard addSubview:self.searchBar];
    }
    [_expandedMapContainer removeFromSuperview];
    _expandedMapContainer = nil;
    _expandedMapCloseButton = nil;
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, _mapCard);
}

- (void)toggleMapStyle {
    NSInteger s = ([WolFoxProStore shared].mapStyle + 1) % 3;
    [WolFoxProStore shared].mapStyle = s;
    [[WolFoxProStore shared] saveSettings];
    self.mapView.mapType = (MKMapType)s;
    [self showToast:s == 0 ? @"نمط عادي" : (s == 1 ? @"نمط قمر صناعي" : @"نمط هجين")];
}

- (void)speedChanged:(UISlider *)s {
    [WolFoxProStore shared].simSpeed = s.value;
    [[WolFoxProStore shared] saveSettings];
    UILabel *l = objc_getAssociatedObject(self, "_speed_label");
    if (l) l.text = [NSString stringWithFormat:@"السرعة: %.0f كم/س", s.value];
}

- (void)saveCurrentRoute {
    WolFoxProStore *store = [WolFoxProStore shared];
    CLLocationCoordinate2D from = store.currentFakeCoords;
    CLLocationCoordinate2D to = store.targetRouteCoords;
    if (!CLLocationCoordinate2DIsValid(from) || !CLLocationCoordinate2DIsValid(to) || (from.latitude == to.latitude && from.longitude == to.longitude)) {
        [self showToast:@"حدد نقطة بداية وهدفاً مختلفين أولاً"]; return;
    }
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"حفظ مسار الحركة" message:@"أدخل اسماً للمسار" preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf){ tf.placeholder = @"اسم المسار"; tf.text = @"مسار جديد"; tf.textAlignment = NSTextAlignmentRight; }];
    [ac addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"حفظ" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action){
        NSString *name = ac.textFields.firstObject.text.length ? ac.textFields.firstObject.text : @"مسار جديد";
        NSMutableArray *routes = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"WF_PRO_SAVED_ROUTES"] mutableCopy] ?: [NSMutableArray new];
        [routes addObject:@{ @"name": name, @"fromLat": @(from.latitude), @"fromLon": @(from.longitude), @"toLat": @(to.latitude), @"toLon": @(to.longitude), @"speed": @(MAX(1.0, store.simSpeed)) }];
        [[NSUserDefaults standardUserDefaults] setObject:routes forKey:@"WF_PRO_SAVED_ROUTES"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self showToast:@"تم حفظ مسار الحركة في المفضلة"]; 
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)showSavedRoutes {
    NSArray *routes = [[NSUserDefaults standardUserDefaults] arrayForKey:@"WF_PRO_SAVED_ROUTES"] ?: @[];
    if (routes.count == 0) { [self showToast:@"لا توجد مسارات محفوظة"]; return; }

    // عرض قائمة المسارات مع تفاصيل واختيار الإجراء
    UIAlertController *list = [UIAlertController alertControllerWithTitle:@"المسارات المحفوظة"
                                                                  message:[NSString stringWithFormat:@"%lu مسار محفوظ", (unsigned long)routes.count]
                                                           preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSUInteger i = 0; i < routes.count; i++) {
        NSDictionary *route = routes[i];
        NSString *name = [route[@"name"] isKindOfClass:NSString.class] ? route[@"name"] : @"مسار";
        double speed = [route[@"speed"] doubleValue];
        double fromLat = [route[@"fromLat"] doubleValue], fromLon = [route[@"fromLon"] doubleValue];
        double toLat   = [route[@"toLat"]   doubleValue], toLon   = [route[@"toLon"]   doubleValue];
        NSString *detail = [NSString stringWithFormat:@"%.4f,%.4f → %.4f,%.4f @ %.0f كم/س", fromLat, fromLon, toLat, toLon, speed];

        // كل مسار: زر يُفتح منه actionsheet داخلي بخيارات تشغيل/تعديل/حذف
        NSUInteger capturedIndex = i;
        [list addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"▶ %@\n%@", name, detail]
                                                style:UIAlertActionStyleDefault
                                              handler:^(__unused UIAlertAction *a) {
            [self showRouteOptionsForIndex:capturedIndex];
        }]];
    }
    [list addAction:[UIAlertAction actionWithTitle:@"حذف كل المسارات" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *a) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"WF_PRO_SAVED_ROUTES"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self showToast:@"✅ تم حذف كل المسارات المحفوظة"];
    }]];
    [list addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    if (list.popoverPresentationController) { list.popoverPresentationController.sourceView = self.view; list.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1); }
    [self presentViewController:list animated:YES completion:nil];
}

- (void)showRouteOptionsForIndex:(NSUInteger)index {
    NSMutableArray *routes = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"WF_PRO_SAVED_ROUTES"] mutableCopy];
    if (!routes || index >= routes.count) return;
    NSDictionary *route = routes[index];
    NSString *name = [route[@"name"] isKindOfClass:NSString.class] ? route[@"name"] : @"مسار";
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:name
                                                                message:nil
                                                         preferredStyle:UIAlertControllerStyleActionSheet];
    [ac addAction:[UIAlertAction actionWithTitle:@"🚶 تشغيل" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
        [self applySavedRoute:route run:YES];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"✏️ تحميل للتعديل" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
        [self applySavedRoute:route run:NO];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"🗑 حذف هذا المسار" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *a) {
        NSMutableArray *updated = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"WF_PRO_SAVED_ROUTES"] mutableCopy] ?: [NSMutableArray new];
        if (index < updated.count) [updated removeObjectAtIndex:index];
        [[NSUserDefaults standardUserDefaults] setObject:updated forKey:@"WF_PRO_SAVED_ROUTES"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self showToast:[NSString stringWithFormat:@"✅ تم حذف: %@", name]];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    if (ac.popoverPresentationController) { ac.popoverPresentationController.sourceView = self.view; ac.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1); }
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)applySavedRoute:(NSDictionary *)route run:(BOOL)run {
    if (![route isKindOfClass:NSDictionary.class]) return;
    CLLocationCoordinate2D from = CLLocationCoordinate2DMake([route[@"fromLat"] doubleValue], [route[@"fromLon"] doubleValue]);
    CLLocationCoordinate2D to = CLLocationCoordinate2DMake([route[@"toLat"] doubleValue], [route[@"toLon"] doubleValue]);
    if (!CLLocationCoordinate2DIsValid(from) || !CLLocationCoordinate2DIsValid(to)) { [self showToast:@"المسار المحفوظ غير صالح"]; return; }
    WolFoxProStore *store = [WolFoxProStore shared];
    store.currentFakeCoords = from; store.targetRouteCoords = to; store.simSpeed = MAX(1.0, [route[@"speed"] doubleValue]);
    [store saveSettings]; [self updateMapPin:from];
    if (run) [self toggleRouteSimulation]; else [self showToast:@"تم تحميل المسار للتعديل من بطاقة الحركة"]; 
}

- (void)toggleRouteSimulation {
    if (![WFLicenseClient isRuntimeLicenseValid]) {
        [self showToast:@"يلزم تحقق اشتراك صالح قبل تشغيل المسار"];
        return;
    }
    if ([WolFoxProStore shared].routeActive) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"إيقاف محاكاة المسار؟" message:@"سيتوقف التحرك الآلي عند الموقع الحالي بعد التأكيد." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"متابعة المسار" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"إيقاف الآن" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
            [[WolFoxProHookManager shared] stopRoute];
            if (self->_currentPin) {
                [self.mapView removeAnnotation:self->_currentPin];
                [self.mapView addAnnotation:self->_currentPin];
            }
            // ADDED: امسح دبوس الهدف عند إيقاف المسار يدوياً
            MKPointAnnotation *tp = objc_getAssociatedObject(self, "_target_pin");
            if (tp) {
                [self.mapView removeAnnotation:tp];
                objc_setAssociatedObject(self, "_target_pin", nil, OBJC_ASSOCIATION_ASSIGN);
            }
            UIButton *b = objc_getAssociatedObject(self, "_route_btn");
            [b setTitle:@"بدء محاكاة المسار 🚶‍♂️" forState:UIControlStateNormal];
            b.backgroundColor = [WolFoxProTheme accent];
            b.accessibilityLabel = @"بدء محاكاة المسار";
            [self showToast:@"⚠️ توقفت محاكاة المسار"];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        [WolFoxProStore shared].spoofActive = YES;
        [[WolFoxProStore shared] saveSettings];
        // Build a simple straight-line route: current fake → target (5 intermediate steps)
        CLLocationCoordinate2D from = [WolFoxProStore shared].currentFakeCoords;
        CLLocationCoordinate2D to   = [WolFoxProStore shared].targetRouteCoords;
        // إذا لم يُحدَّد هدف بعد، استخدم هدفاً قريباً من الموقع الحالي (1 كم شمالاً)
        if (to.latitude == 0 && to.longitude == 0) {
            to = CLLocationCoordinate2DMake(from.latitude + 0.009, from.longitude);
            [WolFoxProStore shared].targetRouteCoords = to;
            [self showToast:@"⚡ لم يُحدَّد هدف — يتحرك شمالاً 1 كم تلقائياً"];
        }
        NSMutableArray *waypoints = [NSMutableArray new];
        for (int i = 0; i <= 10; i++) {
            double lat = from.latitude  + (to.latitude  - from.latitude)  * (i / 10.0);
            double lon = from.longitude + (to.longitude - from.longitude) * (i / 10.0);
            [waypoints addObject:[[CLLocation alloc] initWithLatitude:lat longitude:lon]];
        }
        [[WolFoxProHookManager shared] startRouteWithWaypoints:waypoints speedKmh:[WolFoxProStore shared].simSpeed];
        UIButton *b = objc_getAssociatedObject(self, "_route_btn");
        [b setTitle:@"إيقاف المحاكاة 🛑" forState:UIControlStateNormal];
        b.backgroundColor = [WolFoxProTheme danger];
        b.accessibilityLabel = @"إيقاف محاكاة المسار";
        [self refreshSpoofHeaderStatus];
        if (self->_currentPin) {
            [self.mapView removeAnnotation:self->_currentPin];
            [self.mapView addAnnotation:self->_currentPin];
        }
        [self showToast:@"🚶‍♂️ بدأت المحاكاة"];
    }
}

- (void)routeStepUpdated {
    [self refreshLiveStatusCards];
    // أثناء التزييف، حدّث دبوس الموقع الحقيقي دون إعادة تمركز الخريطة عليه.
    // يبقى الدبوس الأخضر والحقول على الإحداثية المزيّفة الحالية.
    if ([WolFoxProStore shared].spoofActive) {
        [self refreshRealLocationPinWithoutRecentering];
    } else {
        [self showRealLocation];
    }
    if (!self->_currentPin || !self.mapView) return;
    CLLocationCoordinate2D current = [WolFoxProStore shared].currentFakeCoords;
    self->_currentPin.coordinate = current;
    if (_latInput) _latInput.text = [NSString stringWithFormat:@"%.6f", current.latitude];
    if (_lonInput) _lonInput.text = [NSString stringWithFormat:@"%.6f", current.longitude];
    MKAnnotationView *view = [self.mapView viewForAnnotation:self->_currentPin];
    if (![view isKindOfClass:[MKMarkerAnnotationView class]]) return;
    CLLocationCoordinate2D target = [WolFoxProStore shared].targetRouteCoords;
    // FIX: bearing صحيح = atan2(dLon, dLat) بالـ radians (شمال=0، شرق=+π/2)
    // UIView يدور بعكس عقارب الساعة من الـ positive Y axis (أعلى الشاشة)
    // MapKit الشمال = أعلى → نطرح π/2 لتحويل bearing جغرافي إلى زاوية UIKit
    double dLat = target.latitude  - current.latitude;
    double dLon = target.longitude - current.longitude;
    CGFloat bearing = (CGFloat)atan2(dLon, dLat); // 0 = شمال، +π/2 = شرق
    [UIView animateWithDuration:0.25 animations:^{
        view.transform = CGAffineTransformMakeRotation(bearing);
        view.layer.borderWidth = 3.0;
        view.layer.borderColor = [WolFoxProTheme accent].CGColor;
        view.layer.cornerRadius = view.bounds.size.width * 0.5;
    }];
}

- (void)routeFinished {
    if (self->_currentPin) {
        [self.mapView removeAnnotation:self->_currentPin];
        [self.mapView addAnnotation:self->_currentPin];
    }
    // ADDED: أزل دبوس الهدف عند اكتمال المسار
    MKPointAnnotation *targetPin = objc_getAssociatedObject(self, "_target_pin");
    if (targetPin) {
        [self.mapView removeAnnotation:targetPin];
        objc_setAssociatedObject(self, "_target_pin", nil, OBJC_ASSOCIATION_ASSIGN);
    }
    UIButton *b = objc_getAssociatedObject(self, "_route_btn");
    [b setTitle:@"بدء محاكاة المسار 🚶‍♂️" forState:UIControlStateNormal];
    b.backgroundColor = [WolFoxProTheme accent];
    b.accessibilityLabel = @"بدء محاكاة المسار";
    [self showToast:@"✅ اكتملت المحاكاة"];
}

- (NSString *)normalizedMapSearchText:(NSString *)text {
    NSString *result = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSArray<NSString *> *from = @[@"٠",@"١",@"٢",@"٣",@"٤",@"٥",@"٦",@"٧",@"٨",@"٩",@"۰",@"۱",@"۲",@"۳",@"۴",@"۵",@"۶",@"۷",@"۸",@"۹",@"٫",@"،",@"−"];
    NSArray<NSString *> *to   = @[@"0",@"1",@"2",@"3",@"4",@"5",@"6",@"7",@"8",@"9",@"0",@"1",@"2",@"3",@"4",@"5",@"6",@"7",@"8",@"9",@".",@",",@"-"];
    for (NSUInteger index = 0; index < from.count; index++) {
        result = [result stringByReplacingOccurrencesOfString:from[index] withString:to[index]];
    }
    return result;
}

- (BOOL)parseCoordinateSearchText:(NSString *)text coordinate:(CLLocationCoordinate2D *)coordinate {
    NSString *normalized = [self normalizedMapSearchText:text];
    NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@",; \t\r\n"];
    NSArray<NSString *> *rawParts = [normalized componentsSeparatedByCharactersInSet:separators];
    NSMutableArray<NSString *> *parts = [NSMutableArray new];
    for (NSString *part in rawParts) {
        NSString *clean = [part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (clean.length) [parts addObject:clean];
    }
    if (parts.count != 2) return NO;

    double values[2] = {0, 0};
    for (NSUInteger index = 0; index < 2; index++) {
        NSScanner *scanner = [NSScanner scannerWithString:parts[index]];
        scanner.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        if (![scanner scanDouble:&values[index]] || !scanner.isAtEnd || !isfinite(values[index])) return NO;
    }
    CLLocationCoordinate2D parsed = CLLocationCoordinate2DMake(values[0], values[1]);
    if (!CLLocationCoordinate2DIsValid(parsed)) return NO;
    if (coordinate) *coordinate = parsed;
    return YES;
}

- (void)selectMapSearchCoordinate:(CLLocationCoordinate2D)coordinate title:(NSString *)title toast:(NSString *)toast {
    if (!CLLocationCoordinate2DIsValid(coordinate)) {
        [self showToast:@"الإحداثيات خارج النطاق المسموح ❌"];
        return;
    }
    [WolFoxProStore shared].currentFakeCoords = coordinate;
    [[WolFoxProStore shared] saveSettings];
    [self updateMapPin:coordinate];
    _currentPin.title = title.length ? title : @"الموقع المحدد";
    if (_latInput) _latInput.text = [NSString stringWithFormat:@"%.6f", coordinate.latitude];
    if (_lonInput) _lonInput.text = [NSString stringWithFormat:@"%.6f", coordinate.longitude];
    [[WolFoxProHookManager shared] deliverFakeUpdate];
    [[WolFoxProStore shared] recordLocationHistoryWithName:(title.length ? title : @"بحث الخريطة") coordinate:coordinate];
    [self showToast:toast];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [self hideInputKeyboard];
    NSString *query = [[self normalizedMapSearchText:searchBar.text ?: @""] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!query.length) {
        [self showToast:@"أدخل إحداثيات أو عنواناً للبحث"];
        return;
    }

    CLLocationCoordinate2D coordinate;
    if ([self parseCoordinateSearchText:query coordinate:&coordinate]) {
        searchBar.text = [NSString stringWithFormat:@"%.6f, %.6f", coordinate.latitude, coordinate.longitude];
        [self selectMapSearchCoordinate:coordinate title:@"إحداثيات محددة" toast:@"تم تحديد الإحداثيات على الخريطة ✅"];
        return;
    }

    [_activeMapSearch cancel];
    MKLocalSearchRequest *request = [MKLocalSearchRequest new];
    request.naturalLanguageQuery = query;
    if (self.mapView) request.region = self.mapView.region;
    MKLocalSearch *search = [[MKLocalSearch alloc] initWithRequest:request];
    _activeMapSearch = search;
    __weak typeof(self) weakSelf = self;
    [search startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self->_activeMapSearch != search) return;
            self->_activeMapSearch = nil;
            MKMapItem *item = response.mapItems.firstObject;
            CLLocation *location = item.placemark.location;
            if (!location || error) {
                [self showToast:@"لم يتم العثور على العنوان أو المكان ❌"];
                return;
            }
            NSString *title = item.name.length ? item.name : query;
            searchBar.text = title;
            [self selectMapSearchCoordinate:location.coordinate title:title toast:@"تم العثور على المكان وتحديده ✅"];
        });
    }];
}

- (UITextField *)royalInput:(NSString *)p frame:(CGRect)f {
    UITextField *tf = [[UITextField alloc] initWithFrame:f];
    tf.backgroundColor = [WolFoxProTheme surfaceSecondary];
    tf.layer.cornerRadius = 10;
    tf.textColor = [WolFoxProTheme textPrimary];
    tf.textAlignment = NSTextAlignmentCenter;
    tf.font = [WolFoxProTheme fontOfSize:13 weight:UIFontWeightBold];
    tf.placeholder = p;
    tf.layer.borderWidth = 1.0;
    tf.layer.borderColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.32].CGColor;
    tf.tintColor = [WolFoxProTheme accent];
    tf.delegate = self;
    return tf;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    textField.layer.borderWidth = 1.5;
    textField.layer.borderColor = [WolFoxProTheme accent].CGColor;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    textField.layer.borderWidth = 1.0;
    textField.layer.borderColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.32].CGColor;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == _latInput) {
        [_lonInput becomeFirstResponder];
        return NO;
    }
    [self applyCoordinatesFromKeyboard];
    return NO;
}

- (void)configureKeyboardToolbarForTextField:(UITextField *)textField searchMode:(BOOL)searchMode {
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    toolbar.barStyle = UIBarStyleBlack;
    toolbar.translucent = NO;
    toolbar.tintColor = [WolFoxProTheme accent];
    toolbar.barTintColor = [WolFoxProTheme surfacePrimary];

    UIBarButtonItem *paste = [[UIBarButtonItem alloc] initWithTitle:@"لصق" style:UIBarButtonItemStylePlain target:self action:(searchMode ? @selector(pasteSearchText) : @selector(pasteCoordinates))];
    paste.accessibilityLabel = searchMode ? @"لصق نص البحث" : @"لصق الإحداثيات";
    UIBarButtonItem *copy = [[UIBarButtonItem alloc] initWithTitle:@"نسخ" style:UIBarButtonItemStylePlain target:self action:(searchMode ? @selector(copySearchText) : @selector(copyCoordinates))];
    copy.accessibilityLabel = searchMode ? @"نسخ نص البحث" : @"نسخ الإحداثيات";
    UIBarButtonItem *next = [[UIBarButtonItem alloc] initWithTitle:@"إدخال" style:UIBarButtonItemStylePlain target:self action:@selector(keyboardNextPressed)];
    next.accessibilityLabel = @"الانتقال للحقل التالي أو التنفيذ";
    UIBarButtonItem *back = [[UIBarButtonItem alloc] initWithTitle:@"رجوع" style:UIBarButtonItemStylePlain target:self action:@selector(keyboardBackPressed)];
    back.accessibilityLabel = @"حذف آخر حرف";
    UIBarButtonItem *spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *action = [[UIBarButtonItem alloc] initWithTitle:(searchMode ? @"بحث" : @"تفعيل") style:UIBarButtonItemStyleDone target:self action:(searchMode ? @selector(searchFromKeyboard) : @selector(applyCoordinatesFromKeyboard))];
    action.accessibilityLabel = searchMode ? @"تنفيذ البحث" : @"تطبيق الإحداثيات وتفعيل التزييف";
    UIBarButtonItem *hide = [[UIBarButtonItem alloc] initWithTitle:@"طي" style:UIBarButtonItemStylePlain target:self action:@selector(hideInputKeyboard)];
    hide.accessibilityLabel = @"طي لوحة المفاتيح";
    toolbar.items = @[paste, copy, next, back, spacer, action, hide];
    textField.inputAccessoryView = toolbar;
}

- (void)hideInputKeyboard {
    [self.searchBar resignFirstResponder];
    [_latInput resignFirstResponder];
    [_lonInput resignFirstResponder];
    [self.view endEditing:YES];
}

- (void)keyboardBackPressed {
    UITextField *searchField = nil;
    if (@available(iOS 13.0, *)) searchField = self.searchBar.searchTextField;
    if (searchField.isFirstResponder) {
        [searchField deleteBackward];
    } else if (_latInput.isFirstResponder) {
        [_latInput deleteBackward];
    } else if (_lonInput.isFirstResponder) {
        [_lonInput deleteBackward];
    }
}

- (void)copySearchText {
    NSString *text = self.searchBar.text ?: @"";
    if (!text.length) { [self showToast:@"لا يوجد نص لنسخه"]; return; }
    UIPasteboard.generalPasteboard.string = text;
    [self showToast:@"تم نسخ نص البحث"];
}

- (void)copyCoordinates {
    NSString *latitude = _latInput.text ?: @"";
    NSString *longitude = _lonInput.text ?: @"";
    if (!latitude.length || !longitude.length) { [self showToast:@"أدخل الإحداثيات أولاً"]; return; }
    UIPasteboard.generalPasteboard.string = [NSString stringWithFormat:@"%@, %@", latitude, longitude];
    [self showToast:@"تم نسخ الإحداثيات"];
}

- (void)keyboardNextPressed {
    UITextField *searchField = nil;
    if (@available(iOS 13.0, *)) searchField = self.searchBar.searchTextField;
    if (searchField.isFirstResponder) { [self searchFromKeyboard]; return; }
    if (_latInput.isFirstResponder) { [_lonInput becomeFirstResponder]; return; }
    [self applyCoordinatesFromKeyboard];
}

- (void)pasteSearchText {
    NSString *text = [UIPasteboard generalPasteboard].string;
    if (!text.length) {
        [self showToast:@"الحافظة فارغة ❌"];
        return;
    }
    self.searchBar.text = text;
    [self showToast:@"تم لصق البحث؛ اضغط بحث للتنفيذ ✅"];
}

- (void)searchFromKeyboard {
    [self searchBarSearchButtonClicked:self.searchBar];
}

- (void)applyCoordinatesFromKeyboard {
    [self hideInputKeyboard];
    [self applyManualCoords];
}

- (UIView *)royalSwitch:(NSString *)t icon:(NSString *)i isOn:(BOOL)on y:(CGFloat)y action:(void(^)(UISwitch *))block {
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(15, y, _scrollDashboard.bounds.size.width - 30, 65)];
    v.backgroundColor = [WolFoxProTheme surfacePrimary]; v.layer.cornerRadius = 15;
    
    UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(v.bounds.size.width - 45, 17, 30, 30)];
    if (@available(iOS 13.0, *)) iv.image = [UIImage systemImageNamed:i];
    iv.tintColor = [WolFoxProTheme accent]; iv.contentMode = UIViewContentModeScaleAspectFit;
    [v addSubview:iv];
    
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(80, 0, v.bounds.size.width - 135, 65)];
    l.text = t; l.textColor = [WolFoxProTheme textPrimary]; l.font = [WolFoxProTheme fontOfSize:15 weight:UIFontWeightBold]; l.textAlignment = NSTextAlignmentRight;
    [v addSubview:l];
    
    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(15, 17, 50, 30)];
    sw.on = on; sw.onTintColor = [WolFoxProTheme accent];
    sw.accessibilityLabel = t;
    [sw addTarget:self action:@selector(handleSwitch:) forControlEvents:UIControlEventValueChanged];
    objc_setAssociatedObject(sw, "_sw_block", block, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [v addSubview:sw];
    return v;
}

- (void)handleSwitch:(UISwitch *)s {
    void(^block)(UISwitch *) = objc_getAssociatedObject(s, "_sw_block");
    if (block) block(s);
}

- (UIButton *)royalBtn:(NSString *)t icon:(NSString *)i color:(UIColor *)c y:(CGFloat)y {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = CGRectMake(15, y, _scrollDashboard.bounds.size.width - 30, 55);
    BOOL dangerous = CGColorEqualToColor(c.CGColor, [WolFoxProTheme danger].CGColor);
    b.backgroundColor = dangerous ? [WolFoxProTheme danger] : [WolFoxProTheme surfacePrimary]; b.layer.cornerRadius = 15;
    [b setTitle:t forState:UIControlStateNormal]; [b setTitleColor:dangerous ? UIColor.whiteColor : [WolFoxProTheme textPrimary] forState:UIControlStateNormal];
    b.titleLabel.font = [WolFoxProTheme fontOfSize:15 weight:UIFontWeightBold];
    if (@available(iOS 13.0, *)) [b setImage:[UIImage systemImageNamed:i] forState:UIControlStateNormal];
    b.tintColor = dangerous ? UIColor.whiteColor : c;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    b.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 15);
#pragma clang diagnostic pop
    return b;
}

#pragma mark - ID & Camera Pages (Stubs for linking)

- (void)setupIDPage {
    CGFloat w = _scrollDashboard.bounds.size.width;
    UIView *idCard = [[UIView alloc] initWithFrame:CGRectMake(15, 10, w - 30, 500)];
    idCard.backgroundColor = [WolFoxProTheme surfacePrimary]; idCard.layer.cornerRadius = 20;
    [_scrollDashboard addSubview:idCard];
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, idCard.bounds.size.width, 30)];
    title.text = @"الهوية الموحدة • IDFA • IDFV • Web"; title.textColor = [WolFoxProTheme textPrimary]; title.textAlignment = NSTextAlignmentCenter; title.font = [WolFoxProTheme fontOfSize:16 weight:UIFontWeightBold];
    [idCard addSubview:title];
    
    UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(15, 60, idCard.bounds.size.width - 30, 50)];
    tf.backgroundColor = [WolFoxProTheme surfaceSecondary]; tf.layer.cornerRadius = 12; tf.textColor = [WolFoxProTheme textPrimary]; tf.textAlignment = NSTextAlignmentCenter;
    tf.layer.borderWidth = 1.0; tf.layer.borderColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.32].CGColor; tf.tintColor = [WolFoxProTheme accent]; tf.delegate = self;
    tf.text = [WolFoxProStore shared].activeIdentifierUUID ?: [WFLicenseClient deviceIdentifier];
    tf.font = [WolFoxProTheme fontOfSize:11 weight:UIFontWeightBold];
    objc_setAssociatedObject(self, "_id_tf_page", tf, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [idCard addSubview:tf];
    
    UIView *layersCard = [[UIView alloc] initWithFrame:CGRectMake(15, 120, idCard.bounds.size.width - 30, 54)];
    layersCard.backgroundColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.10];
    layersCard.layer.cornerRadius = 12;
    [idCard addSubview:layersCard];
    UILabel *layersTitle = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, layersCard.bounds.size.width - 20, 17)];
    layersTitle.text = @"طبقات المعرّف الموحدة"; layersTitle.textAlignment = NSTextAlignmentRight;
    layersTitle.textColor = [WolFoxProTheme accent]; layersTitle.font = [WolFoxProTheme fontOfSize:11 weight:UIFontWeightBlack];
    [layersCard addSubview:layersTitle];
    UILabel *layersValue = [[UILabel alloc] initWithFrame:CGRectMake(10, 25, layersCard.bounds.size.width - 20, 22)];
    BOOL identifierEnabled = [WolFoxProStore shared].validatedActiveIdentifier != nil;
    layersValue.text = identifierEnabled ? @"IDFA  •  IDFV  •  WebView  •  UIDevice" : @"فعّل معرّفاً واحداً لتطبيقه على كل الطبقات";
    layersValue.textAlignment = NSTextAlignmentCenter; layersValue.textColor = identifierEnabled ? [WolFoxProTheme success] : [WolFoxProTheme textSecondary];
    layersValue.font = [WolFoxProTheme fontOfSize:11 weight:UIFontWeightBold];
    [layersCard addSubview:layersValue];

    UIButton *sav = [self royalBtnInside:idCard t:@"حفظ وتفعيل" i:@"checkmark" c:[WolFoxProTheme success] y:185];
    [sav addTarget:self action:@selector(saveIDProPage) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *imp = [self royalBtnInside:idCard t:@"استيراد" i:@"arrow.down" c:[WolFoxProTheme accent] y:250];
    [imp addTarget:self action:@selector(importIDProPage) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *exp = [self royalBtnInside:idCard t:@"تصدير" i:@"arrow.up" c:[WolFoxProTheme accent] y:315];
    [exp addTarget:self action:@selector(exportIDProPage) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *res = [self royalBtnInside:idCard t:@"إعادة تعيين للأصلي" i:@"arrow.clockwise" c:[WolFoxProTheme danger] y:380];
    [res addTarget:self action:@selector(resetIDProPage) forControlEvents:UIControlEventTouchUpInside];

    UILabel *idStatus = [[UILabel alloc] initWithFrame:CGRectMake(15, 440, idCard.bounds.size.width - 30, 28)];
    BOOL identifierActive = [WolFoxProStore shared].validatedActiveIdentifier != nil;
    idStatus.text = identifierActive ? @"حالة تزييف المعرّفات: مفعّل" : @"حالة تزييف المعرّفات: متوقف";
    idStatus.textColor = identifierActive ? [WolFoxProTheme success] : [WolFoxProTheme textSecondary];
    idStatus.backgroundColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.10];
    idStatus.layer.cornerRadius = 10; idStatus.clipsToBounds = YES;
    idStatus.font = [WolFoxProTheme fontOfSize:12 weight:UIFontWeightBold];
    idStatus.textAlignment = NSTextAlignmentCenter;
    [idCard addSubview:idStatus];
    objc_setAssociatedObject(self, "_id_status_label", idStatus, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // ── قائمة المعرّفات المحفوظة ──
    NSArray<WolFoxProIdentifier *> *savedIDs = [WolFoxProStore shared].identifiers;
    CGFloat cy = 530;
    if (savedIDs.count > 0) {
        UILabel *listTitle = [[UILabel alloc] initWithFrame:CGRectMake(15, cy, w - 30, 26)];
        listTitle.text = [NSString stringWithFormat:@"المعرّفات المحفوظة (%lu)", (unsigned long)savedIDs.count];
        listTitle.textColor = [WolFoxProTheme textSecondary];
        listTitle.font = [WolFoxProTheme fontOfSize:13 weight:UIFontWeightBold];
        [_scrollDashboard addSubview:listTitle];
        cy += 32;

        for (WolFoxProIdentifier *ident in savedIDs) {
            BOOL isActive = [ident.uuid isEqualToString:[WolFoxProStore shared].activeIdentifierUUID];
            UIView *row = [[UIView alloc] initWithFrame:CGRectMake(15, cy, w - 30, 60)];
            row.backgroundColor = isActive
                ? [[WolFoxProTheme accent] colorWithAlphaComponent:0.13]
                : [WolFoxProTheme surfacePrimary];
            row.layer.cornerRadius = 13;
            if (isActive) { row.layer.borderColor = [WolFoxProTheme accent].CGColor; row.layer.borderWidth = 1.5; }
            [_scrollDashboard addSubview:row];

            UILabel *nl = [[UILabel alloc] initWithFrame:CGRectMake(50, 8, row.bounds.size.width - 100, 20)];
            nl.text = ident.name ?: @"هوية موحدة";
            nl.textColor = [WolFoxProTheme textPrimary];
            nl.font = [WolFoxProTheme fontOfSize:13 weight:UIFontWeightBold];
            nl.textAlignment = NSTextAlignmentRight;
            [row addSubview:nl];

            UILabel *ul = [[UILabel alloc] initWithFrame:CGRectMake(50, 30, row.bounds.size.width - 100, 18)];
            NSString *shortUUID = ident.uuid.length > 18 ? [ident.uuid substringToIndex:18] : ident.uuid;
            ul.text = [shortUUID stringByAppendingString:@"…"];
            ul.textColor = [WolFoxProTheme textSecondary];
            ul.font = [WolFoxProTheme fontOfSize:10 weight:UIFontWeightMedium];
            ul.textAlignment = NSTextAlignmentRight;
            [row addSubview:ul];

            if (isActive) {
                UILabel *checkL = [[UILabel alloc] initWithFrame:CGRectMake(10, 18, 32, 24)];
                checkL.text = @"✓"; checkL.textColor = [WolFoxProTheme accent];
                checkL.font = [WolFoxProTheme fontOfSize:18 weight:UIFontWeightBlack];
                checkL.textAlignment = NSTextAlignmentCenter;
                [row addSubview:checkL];
            }

            // تفعيل الصف مع إبقاء أزرار التعديل والحذف مستقلة.
            UIButton *selB = [UIButton buttonWithType:UIButtonTypeCustom];
            selB.frame = CGRectMake(44, 0, row.bounds.size.width - 88, row.bounds.size.height);
            objc_setAssociatedObject(selB, "_id_uuid", ident.uuid, OBJC_ASSOCIATION_COPY_NONATOMIC);
            [selB addTarget:self action:@selector(selectSavedIdentifier:) forControlEvents:UIControlEventTouchUpInside];
            [row addSubview:selB];

            // زر تعديل الاسم أو UUID مع تحقق قبل استبدال السجل.
            UIButton *editB = [UIButton buttonWithType:UIButtonTypeSystem];
            editB.frame = CGRectMake(4, 8, 38, 44);
            if (@available(iOS 13.0, *)) [editB setImage:[UIImage systemImageNamed:@"pencil"] forState:UIControlStateNormal];
            editB.tintColor = [WolFoxProTheme accent];
            objc_setAssociatedObject(editB, "_id_uuid", ident.uuid, OBJC_ASSOCIATION_COPY_NONATOMIC);
            [editB addTarget:self action:@selector(editSavedIdentifier:) forControlEvents:UIControlEventTouchUpInside];
            editB.accessibilityLabel = @"تعديل المعرّف المحفوظ";
            [row addSubview:editB];

            // زر حذف
            UIButton *delB = [UIButton buttonWithType:UIButtonTypeSystem];
            delB.frame = CGRectMake(row.bounds.size.width - 44, 8, 38, 44);
            if (@available(iOS 13.0, *)) [delB setImage:[UIImage systemImageNamed:@"trash"] forState:UIControlStateNormal];
            delB.tintColor = [WolFoxProTheme danger];
            objc_setAssociatedObject(delB, "_id_uuid", ident.uuid, OBJC_ASSOCIATION_COPY_NONATOMIC);
            [delB addTarget:self action:@selector(deleteSavedIdentifier:) forControlEvents:UIControlEventTouchUpInside];
            delB.accessibilityLabel = @"حذف المعرّف المحفوظ";
            [row addSubview:delB];

            cy += 68;
        }
    }

    _scrollDashboard.contentSize = CGSizeMake(w, cy + 20);
}

- (void)selectSavedIdentifier:(UIButton *)btn {
    NSString *uuid = objc_getAssociatedObject(btn, "_id_uuid");
    if (!uuid.length) return;
    if ([[WolFoxProStore shared] activateIdentifierString:uuid]) {
        UITextField *tf = objc_getAssociatedObject(self, "_id_tf_page");
        tf.text = uuid;
        [self refreshSpoofHeaderStatus];
        [self showToast:@"✅ تم تفعيل المعرّف المحفوظ"];
        [self switchPage:1];
    }
}

- (void)deleteSavedIdentifier:(UIButton *)btn {
    NSString *uuid = objc_getAssociatedObject(btn, "_id_uuid");
    if (!uuid.length) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"حذف المعرّف؟"
                                                                   message:@"سيُحذف هذا المعرّف من القائمة نهائياً."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"حذف" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *a) {
        [[WolFoxProStore shared] deleteIdentifierUUID:uuid];
        [self refreshSpoofHeaderStatus];
        [self showToast:@"✅ تم حذف المعرّف"];
        [self switchPage:1];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)editSavedIdentifier:(UIButton *)btn {
    NSString *oldUUID = objc_getAssociatedObject(btn, "_id_uuid");
    WolFoxProIdentifier *original = nil;
    for (WolFoxProIdentifier *item in [WolFoxProStore shared].identifiers) {
        if ([item.uuid isEqualToString:oldUUID]) { original = item; break; }
    }
    if (!original) { [self showToast:@"تعذر العثور على المعرّف"]; return; }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"تعديل المعرّف"
                                                                   message:@"يمكنك تغيير الاسم أو UUID. يجب أن تكون الصيغة صالحة وفريدة."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"اسم المعرّف"; field.text = original.name ?: @"";
        field.textAlignment = NSTextAlignmentRight;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"UUID"; field.text = original.uuid;
        field.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
        field.textAlignment = NSTextAlignmentCenter;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"حفظ التعديل" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *name = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSString *rawUUID = [alert.textFields.lastObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSUUID *validatedUUID = [[NSUUID alloc] initWithUUIDString:rawUUID];
        if (!validatedUUID) { [self showToast:@"صيغة UUID غير صحيحة"]; return; }
        NSString *newUUID = validatedUUID.UUIDString;
        for (WolFoxProIdentifier *item in [WolFoxProStore shared].identifiers) {
            if (![item.uuid isEqualToString:oldUUID] && [item.uuid isEqualToString:newUUID]) {
                [self showToast:@"هذا المعرّف موجود مسبقاً"]; return;
            }
        }
        BOOL wasActive = [oldUUID isEqualToString:[WolFoxProStore shared].activeIdentifierUUID];
        WolFoxProIdentifier *updated = [WolFoxProIdentifier new];
        updated.uuid = newUUID;
        updated.name = name.length ? name : @"هوية موحدة";
        updated.createdAt = original.createdAt ?: [NSDate date];
        [[WolFoxProStore shared] deleteIdentifierUUID:oldUUID];
        [[WolFoxProStore shared] saveIdentifier:updated];
        if (wasActive) [[WolFoxProStore shared] activateIdentifierString:newUUID];
        [self refreshSpoofHeaderStatus];
        [self showToast:@"تم تعديل المعرّف بنجاح"];
        [self switchPage:1];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (UIButton *)royalBtnInside:(UIView *)p t:(NSString *)t i:(NSString *)i c:(UIColor *)c y:(CGFloat)y {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = CGRectMake(15, y, p.bounds.size.width - 30, 50);
    BOOL dangerous = CGColorEqualToColor(c.CGColor, [WolFoxProTheme danger].CGColor);
    b.backgroundColor = dangerous ? [WolFoxProTheme danger] : [c colorWithAlphaComponent:0.12]; b.layer.cornerRadius = 12;
    [b setTitle:t forState:UIControlStateNormal]; [b setTitleColor:dangerous ? UIColor.whiteColor : c forState:UIControlStateNormal];
    b.titleLabel.font = [WolFoxProTheme fontOfSize:14 weight:UIFontWeightBold];
    if (@available(iOS 13.0, *)) [b setImage:[UIImage systemImageNamed:i] forState:UIControlStateNormal];
    b.tintColor = dangerous ? UIColor.whiteColor : c;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    b.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 10);
#pragma clang diagnostic pop
    [p addSubview:b]; return b;
}

- (void)saveIDProPage {
    UITextField *tf = objc_getAssociatedObject(self, "_id_tf_page");
    if ([[WolFoxProStore shared] activateIdentifierString:tf.text ?: @""]) {
        tf.text = [WolFoxProStore shared].activeIdentifierUUID;
        [self refreshSpoofHeaderStatus];
        UILabel *status = objc_getAssociatedObject(self, "_id_status_label");
        status.text = @"حالة تزييف المعرّفات: مفعّل";
        status.textColor = [WolFoxProTheme success];
    } else {
        [self showToast:@"صيغة UUID غير صحيحة ❌"];
    }
}

- (void)importIDProPage {
    UIPasteboard *pb = [UIPasteboard generalPasteboard];
    if (pb.string.length > 0) {
        UITextField *tf = objc_getAssociatedObject(self, "_id_tf_page");
        tf.text = pb.string; [self showToast:@"تم الاستيراد من الحافظة 📋"];
    }
}

- (void)exportIDProPage {
    UITextField *tf = objc_getAssociatedObject(self, "_id_tf_page");
    UIPasteboard *pb = [UIPasteboard generalPasteboard];
    pb.string = tf.text; [self showToast:@"تم النسخ للحافظة 📤"];
}

- (void)resetIDProPage {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"إعادة المعرّف الأصلي؟" message:@"سيتم إيقاف المعرّف المخصص والعودة إلى معرّف الجهاز الأصلي." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"إعادة الآن" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        NSString *orig = [WFLicenseClient deviceIdentifier];
        UITextField *tf = objc_getAssociatedObject(self, "_id_tf_page");
        tf.text = orig; [[WolFoxProStore shared] deactivateIdentifier]; [self refreshSpoofHeaderStatus];
        UILabel *status = objc_getAssociatedObject(self, "_id_status_label");
        status.text = @"حالة تزييف المعرّفات: متوقف";
        status.textColor = [WolFoxProTheme textSecondary];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)setupCameraPage {
    CGFloat w = _scrollDashboard.bounds.size.width;
    [self setupVirtualCameraCardAtY:10.0 width:w];
    _scrollDashboard.backgroundColor = UIColor.clearColor;
    _scrollDashboard.contentSize = CGSizeMake(w, 490.0);
}


- (void)clearSpoofedImage {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"حذف الصورة وإيقاف التزييف؟" message:@"سيتم حذف الصورة المختارة والعودة إلى الكاميرا الحقيقية." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"حذف وإيقاف" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) { [self performClearSpoofedImage]; }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)performClearSpoofedImage {
    [[WFVirtualCameraManager shared] clearAllImageData];
    [self refreshSpoofHeaderStatus];
    [self switchPage:3];
}

- (UIView *)royalSwitchInside:(UIView *)p t:(NSString *)t i:(NSString *)i isOn:(BOOL)on y:(CGFloat)y action:(void(^)(UISwitch *))block {
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(15, y, p.bounds.size.width - 30, 65)];
    v.backgroundColor = [WolFoxProTheme surfaceSecondary]; v.layer.cornerRadius = 15;
    UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(v.bounds.size.width - 45, 17, 30, 30)];
    if (@available(iOS 13.0, *)) iv.image = [UIImage systemImageNamed:i];
    iv.tintColor = [WolFoxProTheme accent]; iv.contentMode = UIViewContentModeScaleAspectFit; [v addSubview:iv];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(80, 0, v.bounds.size.width - 135, 65)];
    l.text = t; l.textColor = [WolFoxProTheme textPrimary]; l.font = [WolFoxProTheme fontOfSize:15 weight:UIFontWeightBold]; l.textAlignment = NSTextAlignmentRight; [v addSubview:l];
    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(15, 17, 50, 30)];
    sw.on = on; sw.onTintColor = [WolFoxProTheme accent];
    sw.accessibilityLabel = t;
    [sw addTarget:self action:@selector(handleSwitch:) forControlEvents:UIControlEventValueChanged];
    objc_setAssociatedObject(sw, "_sw_block", block, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [v addSubview:sw]; return v;
}

- (void)volumePressCountChanged:(UISegmentedControl *)control {
    NSArray<NSNumber *> *values = @[@2, @3, @5];
    if (control.selectedSegmentIndex < 0 || control.selectedSegmentIndex >= (NSInteger)values.count) return;
    NSInteger count = values[control.selectedSegmentIndex].integerValue;
    [[NSUserDefaults standardUserDefaults] setInteger:count forKey:@"WF_VOLUME_PRESS_COUNT"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self showToast:[NSString stringWithFormat:@"سيتم إظهار الواجهة بعد %ld ضغطات صوت", (long)count]];
}

- (void)floatingIconSizeChanged:(UISegmentedControl *)control {
    [[NSUserDefaults standardUserDefaults] setInteger:control.selectedSegmentIndex forKey:@"WF_FLOATING_STATUS_SIZE_INDEX"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[WolFoxController shared] applyFloatingStatusPreferences];
}

- (void)floatingIconOpacityChanged:(UISlider *)slider {
    [[NSUserDefaults standardUserDefaults] setFloat:slider.value forKey:@"WF_FLOATING_STATUS_OPACITY"];
    [[WolFoxController shared] applyFloatingStatusPreferences];
}

- (void)resetFloatingIconPosition {
    [[WolFoxController shared] resetFloatingStatusPosition];
    [self showToast:@"تمت إعادة العلامة إلى مكانها الافتراضي"];
}

- (void)setupSettingsPage {
    CGFloat w = _scrollDashboard.bounds.size.width;
    CGFloat cy = 10;
    CGFloat cardW = w - 30;

    // ── عنوان قسم ────────────────────────────────────────────
    void (^secLabel)(NSString *, CGFloat) = ^(NSString *text, CGFloat y) {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, y, cardW - 10, 18)];
        label.text = [text uppercaseString];
        label.textAlignment = NSTextAlignmentRight;
        label.textColor = [WolFoxProTheme accent];
        label.font = [WolFoxProTheme fontOfSize:11 weight:UIFontWeightBlack];
        label.alpha = 0.85;
        [_scrollDashboard addSubview:label];
    };

    // ── بطاقة قسم ────────────────────────────────────────────
    UIView * __block (^newCard)(CGFloat, CGFloat) = ^UIView *(CGFloat y, CGFloat h) {
        UIView *c = [[UIView alloc] initWithFrame:CGRectMake(15, y, cardW, h)];
        c.backgroundColor = [WolFoxProTheme surfacePrimary];
        c.layer.cornerRadius = 18;
        c.layer.borderWidth  = 1.0;
        c.layer.borderColor  = [[WolFoxProTheme accent] colorWithAlphaComponent:0.12].CGColor;
        [_scrollDashboard addSubview:c];
        return c;
    };

    // ════════════════════════════════════════════════════════
    // 1. الظهور والإخفاء
    // ════════════════════════════════════════════════════════
    secLabel(@"الظهور والإخفاء", cy);
    cy += 24;
    UIView *visCard = newCard(cy, 210);
    NSInteger requiredPresses = [[NSUserDefaults standardUserDefaults] integerForKey:@"WF_VOLUME_PRESS_COUNT"];
    if (requiredPresses != 2 && requiredPresses != 3 && requiredPresses != 5) requiredPresses = 3;
    [visCard addSubview:[self royalSwitchInside:visCard
        t:[NSString stringWithFormat:@"إظهار الواجهة بـ %ld ضغطات على الصوت", (long)requiredPresses]
        i:@"speaker.wave.2.fill"
        isOn:[WolFoxProStore shared].volumeGestureEnabled
        y:0
        action:^(UISwitch *s){
            [WolFoxProStore shared].volumeGestureEnabled = s.on;
            [[WolFoxProStore shared] saveSettings];
            [self showToast:s.on
                ? [NSString stringWithFormat:@"اضغط زر الصوت %ld مرات سريعاً لإظهار الواجهة", (long)requiredPresses]
                : @"تم إيقاف زر الصوت"];
    }]];
    BOOL hiddenOnLaunch = [[NSUserDefaults standardUserDefaults] boolForKey:WFUIHiddenOnLaunchKey];
    [visCard addSubview:[self royalSwitchInside:visCard
        t:@"إخفاء الواجهة عند فتح التطبيق"
        i:@"eye.slash.fill"
        isOn:hiddenOnLaunch
        y:70
        action:^(UISwitch *s){
            [[NSUserDefaults standardUserDefaults] setBool:s.on forKey:WFUIHiddenOnLaunchKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self showToast:s.on
                ? @"ستختفي الواجهة — افتحها بزر الصوت"
                : @"الواجهة ستظهر عند كل فتح"];
    }]];
    BOOL iconVisible = ![[NSUserDefaults standardUserDefaults] objectForKey:@"WF_FLOATING_STATUS_VISIBLE"] ||
                       [[NSUserDefaults standardUserDefaults] boolForKey:@"WF_FLOATING_STATUS_VISIBLE"];
    [visCard addSubview:[self royalSwitchInside:visCard
        t:@"إظهار العلامة العائمة للحالة"
        i:@"location.circle.fill"
        isOn:iconVisible
        y:140
        action:^(UISwitch *s){
            if (!s.on && ![WolFoxProStore shared].volumeGestureEnabled) {
                [WolFoxProStore shared].volumeGestureEnabled = YES;
                [[WolFoxProStore shared] saveSettings];
                [self showToast:@"تم تفعيل اختصار الصوت لاستعادة العلامة"];
            }
            [[WolFoxController shared] setFloatingStatusIconVisible:s.on];
            [self showToast:s.on
                ? @"العلامة العائمة ظاهرة الآن"
                : [NSString stringWithFormat:@"تم إخفاء العلامة — اضغط زر الصوت %ld مرات لفتح الإعدادات", (long)requiredPresses]];
    }]];
    cy += 210 + 18;

    // ════════════════════════════════════════════════════════
    // تخصيص العلامة العائمة
    // ════════════════════════════════════════════════════════
    secLabel(@"تخصيص العلامة العائمة", cy);
    cy += 24;
    UIView *floatingCard = newCard(cy, 238);

    UILabel *pressLabel = [[UILabel alloc] initWithFrame:CGRectMake(150, 0, floatingCard.bounds.size.width - 165, 60)];
    pressLabel.text = @"عدد ضغطات الصوت";
    pressLabel.textAlignment = NSTextAlignmentRight;
    pressLabel.textColor = [WolFoxProTheme textPrimary];
    pressLabel.font = [WolFoxProTheme fontOfSize:13 weight:UIFontWeightBold];
    [floatingCard addSubview:pressLabel];
    UISegmentedControl *pressControl = [[UISegmentedControl alloc] initWithItems:@[@"2", @"3", @"5"]];
    pressControl.frame = CGRectMake(12, 14, 128, 32);
    pressControl.selectedSegmentIndex = requiredPresses == 2 ? 0 : (requiredPresses == 5 ? 2 : 1);
    [pressControl addTarget:self action:@selector(volumePressCountChanged:) forControlEvents:UIControlEventValueChanged];
    [floatingCard addSubview:pressControl];

    UILabel *sizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(150, 60, floatingCard.bounds.size.width - 165, 60)];
    sizeLabel.text = @"حجم العلامة";
    sizeLabel.textAlignment = NSTextAlignmentRight;
    sizeLabel.textColor = [WolFoxProTheme textPrimary];
    sizeLabel.font = [WolFoxProTheme fontOfSize:13 weight:UIFontWeightBold];
    [floatingCard addSubview:sizeLabel];
    UISegmentedControl *sizeControl = [[UISegmentedControl alloc] initWithItems:@[@"صغير", @"وسط", @"كبير"]];
    sizeControl.frame = CGRectMake(12, 74, 128, 32);
    NSInteger sizeIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"WF_FLOATING_STATUS_SIZE_INDEX"];
    sizeControl.selectedSegmentIndex = MIN(MAX(sizeIndex, 0), 2);
    [sizeControl addTarget:self action:@selector(floatingIconSizeChanged:) forControlEvents:UIControlEventValueChanged];
    [floatingCard addSubview:sizeControl];

    UILabel *opacityLabel = [[UILabel alloc] initWithFrame:CGRectMake(150, 120, floatingCard.bounds.size.width - 165, 60)];
    opacityLabel.text = @"شفافية العلامة";
    opacityLabel.textAlignment = NSTextAlignmentRight;
    opacityLabel.textColor = [WolFoxProTheme textPrimary];
    opacityLabel.font = [WolFoxProTheme fontOfSize:13 weight:UIFontWeightBold];
    [floatingCard addSubview:opacityLabel];
    UISlider *opacitySlider = [[UISlider alloc] initWithFrame:CGRectMake(12, 135, 128, 30)];
    opacitySlider.minimumValue = 0.45;
    opacitySlider.maximumValue = 1.0;
    opacitySlider.tintColor = [WolFoxProTheme accent];
    opacitySlider.value = [[NSUserDefaults standardUserDefaults] objectForKey:@"WF_FLOATING_STATUS_OPACITY"]
        ? [[NSUserDefaults standardUserDefaults] floatForKey:@"WF_FLOATING_STATUS_OPACITY"] : 0.92;
    [opacitySlider addTarget:self action:@selector(floatingIconOpacityChanged:) forControlEvents:UIControlEventValueChanged];
    [floatingCard addSubview:opacitySlider];

    UIButton *resetFloating = [UIButton buttonWithType:UIButtonTypeSystem];
    resetFloating.frame = CGRectMake(12, 183, floatingCard.bounds.size.width - 24, 43);
    resetFloating.backgroundColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.14];
    resetFloating.layer.cornerRadius = 12;
    [resetFloating setTitle:@"إعادة العلامة إلى مكانها الافتراضي" forState:UIControlStateNormal];
    [resetFloating setTitleColor:[WolFoxProTheme accent] forState:UIControlStateNormal];
    resetFloating.titleLabel.font = [WolFoxProTheme fontOfSize:13 weight:UIFontWeightBold];
    [resetFloating addTarget:self action:@selector(resetFloatingIconPosition) forControlEvents:UIControlEventTouchUpInside];
    [floatingCard addSubview:resetFloating];
    cy += 238 + 18;

// 4. التنبيهات
    // ════════════════════════════════════════════════════════
    secLabel(@"التنبيهات", cy);
    cy += 24;
    UIView *notifCard = newCard(cy, 70);
    BOOL expiryOn = [[NSUserDefaults standardUserDefaults] boolForKey:@"WF_EXPIRY_NOTIFICATIONS_ENABLED"];
    [notifCard addSubview:[self royalSwitchInside:notifCard
        t:@"تذكير قبل 3 أيام من انتهاء الاشتراك"
        i:@"bell.badge.fill"
        isOn:expiryOn
        y:0
        action:^(UISwitch *s){ [self expiryNotificationsChanged:s]; }]];
    cy += 70 + 18;

    // ════════════════════════════════════════════════════════
    

// 2. المظهر
    // ════════════════════════════════════════════════════════
    secLabel(@"المظهر", cy);
    cy += 24;
    BOOL isDark = [WolFoxProTheme isDark];
    UIView *themeCard = newCard(cy, 66);
    UIButton *themeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    themeBtn.frame = CGRectMake(12, 8, themeCard.bounds.size.width - 24, 50);
    themeBtn.backgroundColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.14];
    themeBtn.layer.cornerRadius = 14;
    [themeBtn setTitle:(isDark ? @"  الثيم الفاتح" : @"  الثيم الداكن") forState:UIControlStateNormal];
    [themeBtn setTitleColor:[WolFoxProTheme accent] forState:UIControlStateNormal];
    themeBtn.titleLabel.font = [WolFoxProTheme fontOfSize:15 weight:UIFontWeightBold];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightBold];
        [themeBtn setImage:[UIImage systemImageNamed:(isDark ? @"sun.max.fill" : @"moon.stars.fill") withConfiguration:cfg] forState:UIControlStateNormal];
    }
    themeBtn.tintColor = [WolFoxProTheme accent];
    themeBtn.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [themeBtn addTarget:self action:@selector(toggleTheme) forControlEvents:UIControlEventTouchUpInside];
    themeBtn.accessibilityLabel = @"تغيير ثيم الواجهة";
    objc_setAssociatedObject(self, "_theme_btn", themeBtn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [themeCard addSubview:themeBtn];
    cy += 66 + 18;

    // ════════════════════════════════════════════════════════
    

// 3. ألوان المؤشرات
    // ════════════════════════════════════════════════════════
    secLabel(@"ألوان المؤشرات على الخريطة", cy);
    cy += 24;
    UIView *colorCard = newCard(cy, 130);

    UIColor *realColor = [self markerColorForKey:@"WF_REAL_DOT_COLOR"
        defaultColor:[UIColor colorWithRed:0.26 green:0.56 blue:0.97 alpha:1.0]];
    UIButton *realColorBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    realColorBtn.frame = CGRectMake(12, 8, colorCard.bounds.size.width - 24, 50);
    realColorBtn.backgroundColor = [realColor colorWithAlphaComponent:0.18];
    realColorBtn.layer.cornerRadius = 14;
    realColorBtn.layer.borderWidth = 1.5;
    realColorBtn.layer.borderColor = [realColor colorWithAlphaComponent:0.55].CGColor;
    [realColorBtn setTitle:@"  الموقع الحقيقي — نقطة دائرية" forState:UIControlStateNormal];
    [realColorBtn setTitleColor:realColor forState:UIControlStateNormal];
    realColorBtn.titleLabel.font = [WolFoxProTheme fontOfSize:14 weight:UIFontWeightBold];
    if (@available(iOS 13.0, *)) [realColorBtn setImage:[UIImage systemImageNamed:@"circle.fill"] forState:UIControlStateNormal];
    realColorBtn.tintColor = realColor;
    realColorBtn.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [realColorBtn addTarget:self action:@selector(chooseRealMarkerColor) forControlEvents:UIControlEventTouchUpInside];
    [colorCard addSubview:realColorBtn];

    UIColor *fakeColor = [self markerColorForKey:@"WF_FAKE_DOT_COLOR"
        defaultColor:[WolFoxProTheme success]];
    UIButton *fakeColorBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    fakeColorBtn.frame = CGRectMake(12, 68, colorCard.bounds.size.width - 24, 50);
    fakeColorBtn.backgroundColor = [fakeColor colorWithAlphaComponent:0.18];
    fakeColorBtn.layer.cornerRadius = 14;
    fakeColorBtn.layer.borderWidth = 1.5;
    fakeColorBtn.layer.borderColor = [fakeColor colorWithAlphaComponent:0.55].CGColor;
    [fakeColorBtn setTitle:@"  الموقع الوهمي — دبوس" forState:UIControlStateNormal];
    [fakeColorBtn setTitleColor:fakeColor forState:UIControlStateNormal];
    fakeColorBtn.titleLabel.font = [WolFoxProTheme fontOfSize:14 weight:UIFontWeightBold];
    if (@available(iOS 13.0, *)) [fakeColorBtn setImage:[UIImage systemImageNamed:@"mappin.circle.fill"] forState:UIControlStateNormal];
    fakeColorBtn.tintColor = fakeColor;
    fakeColorBtn.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [fakeColorBtn addTarget:self action:@selector(chooseFakeMarkerColor) forControlEvents:UIControlEventTouchUpInside];
    [colorCard addSubview:fakeColorBtn];
    cy += 130 + 18;

    // ════════════════════════════════════════════════════════
    // إدارة بيانات المواقع
    // ════════════════════════════════════════════════════════
    secLabel(@"إدارة بيانات المواقع", cy);
    cy += 24;
    UIView *dataCard = newCard(cy, 192);

    UIButton *exportDataButton = [UIButton buttonWithType:UIButtonTypeSystem];
    exportDataButton.frame = CGRectMake(12, 8, dataCard.bounds.size.width - 24, 50);
    exportDataButton.backgroundColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.14];
    exportDataButton.layer.cornerRadius = 14;
    [exportDataButton setTitle:@"  نسخ ومشاركة نسخة احتياطية JSON" forState:UIControlStateNormal];
    [exportDataButton setTitleColor:[WolFoxProTheme accent] forState:UIControlStateNormal];
    exportDataButton.titleLabel.font = [WolFoxProTheme fontOfSize:13 weight:UIFontWeightBold];
    if (@available(iOS 13.0, *)) [exportDataButton setImage:[UIImage systemImageNamed:@"square.and.arrow.up.fill"] forState:UIControlStateNormal];
    exportDataButton.tintColor = [WolFoxProTheme accent];
    exportDataButton.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [exportDataButton addTarget:self action:@selector(exportLocationData) forControlEvents:UIControlEventTouchUpInside];
    exportDataButton.accessibilityLabel = @"نسخ ومشاركة نسخة احتياطية من المواقع";
    [dataCard addSubview:exportDataButton];

    UIButton *importDataButton = [UIButton buttonWithType:UIButtonTypeSystem];
    importDataButton.frame = CGRectMake(12, 69, dataCard.bounds.size.width - 24, 50);
    importDataButton.backgroundColor = [[WolFoxProTheme success] colorWithAlphaComponent:0.12];
    importDataButton.layer.cornerRadius = 14;
    [importDataButton setTitle:@"  استيراد نسخة JSON من الحافظة" forState:UIControlStateNormal];
    [importDataButton setTitleColor:[WolFoxProTheme success] forState:UIControlStateNormal];
    importDataButton.titleLabel.font = [WolFoxProTheme fontOfSize:13 weight:UIFontWeightBold];
    if (@available(iOS 13.0, *)) [importDataButton setImage:[UIImage systemImageNamed:@"doc.on.clipboard.fill"] forState:UIControlStateNormal];
    importDataButton.tintColor = [WolFoxProTheme success];
    importDataButton.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [importDataButton addTarget:self action:@selector(importLocationDataFromClipboard) forControlEvents:UIControlEventTouchUpInside];
    importDataButton.accessibilityLabel = @"استيراد مواقع من نص JSON في الحافظة";
    [dataCard addSubview:importDataButton];

    UIButton *resetDataButton = [UIButton buttonWithType:UIButtonTypeSystem];
    resetDataButton.frame = CGRectMake(12, 130, dataCard.bounds.size.width - 24, 50);
    resetDataButton.backgroundColor = [[WolFoxProTheme danger] colorWithAlphaComponent:0.12];
    resetDataButton.layer.cornerRadius = 14;
    [resetDataButton setTitle:@"  مسح المفضلة أو سجل المواقع" forState:UIControlStateNormal];
    [resetDataButton setTitleColor:[WolFoxProTheme danger] forState:UIControlStateNormal];
    resetDataButton.titleLabel.font = [WolFoxProTheme fontOfSize:13 weight:UIFontWeightBold];
    if (@available(iOS 13.0, *)) [resetDataButton setImage:[UIImage systemImageNamed:@"trash.fill"] forState:UIControlStateNormal];
    resetDataButton.tintColor = [WolFoxProTheme danger];
    resetDataButton.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [resetDataButton addTarget:self action:@selector(showLocationDataResetOptions) forControlEvents:UIControlEventTouchUpInside];
    resetDataButton.accessibilityLabel = @"فتح خيارات مسح بيانات المواقع";
    [dataCard addSubview:resetDataButton];
    cy += 192 + 18;

    // ════════════════════════════════════════════════════════
    // التشخيص
    // ════════════════════════════════════════════════════════
    secLabel(@"التشخيص", cy);
    cy += 24;
    UIView *diagnosticCard = newCard(cy, 66);
    UIButton *diagnosticButton = [UIButton buttonWithType:UIButtonTypeSystem];
    diagnosticButton.frame = CGRectMake(12, 8, diagnosticCard.bounds.size.width - 24, 50);
    diagnosticButton.backgroundColor = [[WolFoxProTheme gold] colorWithAlphaComponent:0.12];
    diagnosticButton.layer.cornerRadius = 14;
    [diagnosticButton setTitle:@"  نسخ تقرير تشخيص آمن" forState:UIControlStateNormal];
    [diagnosticButton setTitleColor:[WolFoxProTheme gold] forState:UIControlStateNormal];
    diagnosticButton.titleLabel.font = [WolFoxProTheme fontOfSize:13 weight:UIFontWeightBold];
    if (@available(iOS 13.0, *)) [diagnosticButton setImage:[UIImage systemImageNamed:@"stethoscope"] forState:UIControlStateNormal];
    diagnosticButton.tintColor = [WolFoxProTheme gold];
    diagnosticButton.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [diagnosticButton addTarget:self action:@selector(copyDiagnosticReport) forControlEvents:UIControlEventTouchUpInside];
    diagnosticButton.accessibilityLabel = @"نسخ تقرير تشخيص لا يحتوي على أسرار";
    [diagnosticCard addSubview:diagnosticButton];
    cy += 66 + 18;

    // ════════════════════════════════════════════════════════
    

// 6. الدعم والحساب
    // ════════════════════════════════════════════════════════
    secLabel(@"الدعم والحساب", cy);
    cy += 24;
    UIView *accountCard = newCard(cy, 70);

    // زر Telegram
    UIButton *tgBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    tgBtn.frame = CGRectMake(12, 8, accountCard.bounds.size.width - 24, 50);
    tgBtn.backgroundColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.16];
    tgBtn.layer.cornerRadius = 14;
    tgBtn.layer.borderWidth = 1.5;
    tgBtn.layer.borderColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.45].CGColor;
    [tgBtn setTitle:@"  قناة WolFox على Telegram" forState:UIControlStateNormal];
    [tgBtn setTitleColor:[WolFoxProTheme accent] forState:UIControlStateNormal];
    tgBtn.titleLabel.font = [WolFoxProTheme fontOfSize:15 weight:UIFontWeightBold];
    if (@available(iOS 13.0, *)) [tgBtn setImage:[UIImage systemImageNamed:@"paperplane.fill"] forState:UIControlStateNormal];
    tgBtn.tintColor = [WolFoxProTheme accent];
    tgBtn.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [tgBtn addTarget:self action:@selector(openTelegram) forControlEvents:UIControlEventTouchUpInside];
    tgBtn.accessibilityLabel = @"فتح قناة WolFox على Telegram";
        [accountCard addSubview:tgBtn];
    cy += 70 + 18;

// 5. دليل الاستخدام السريع
    // ════════════════════════════════════════════════════════
    secLabel(@"دليل الاستخدام السريع", cy);
    cy += 24;
    UIView *helpCard = newCard(cy, 162);
    helpCard.backgroundColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.08];
    helpCard.layer.borderColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.20].CGColor;
    NSArray *steps = @[
        @[@"speaker.wave.2",  @"اضغط زر الصوت 3 مرات سريعاً لإظهار الواجهة"],
        @[@"location.fill",   @"حدد موقعاً أو أدخل الإحداثيات ثم فعّل التزييف"],
        @[@"figure.walk",     @"اضغط طويلاً: أول ضغطة البداية، ثانية الهدف، ثم شغّل"],
        @[@"bell.badge",      @"فعّل التذكير لاستقبال إشعار قبل انتهاء الاشتراك"],
    ];
    for (NSUInteger i = 0; i < steps.count; i++) {
        CGFloat rowY = 10 + i * 36;
        if (@available(iOS 13.0, *)) {
            UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectMake(helpCard.bounds.size.width - 34, rowY + 7, 20, 20)];
            icon.image = [UIImage systemImageNamed:steps[i][0]];
            icon.tintColor = [WolFoxProTheme accent];
            icon.contentMode = UIViewContentModeScaleAspectFit;
            [helpCard addSubview:icon];
        }
        UILabel *stepLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, rowY, helpCard.bounds.size.width - 52, 32)];
        stepLabel.text = steps[i][1];
        stepLabel.textColor = [WolFoxProTheme textPrimary];
        stepLabel.font = [WolFoxProTheme fontOfSize:12 weight:UIFontWeightSemibold];
        stepLabel.textAlignment = NSTextAlignmentRight;
        stepLabel.numberOfLines = 2;
        [helpCard addSubview:stepLabel];
    }
    cy += 162 + 18;

        // ════════════════════════════════════════════════════════
    // 7. تسجيل الخروج — في نهاية صفحة الإعدادات
    // ════════════════════════════════════════════════════════
    secLabel(@"تسجيل الخروج", cy);
    cy += 24;
    UIView *logoutCard = newCard(cy, 66);
    UIButton *logoutBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    logoutBtn.frame = CGRectMake(12, 8, logoutCard.bounds.size.width - 24, 50);
    logoutBtn.backgroundColor = [WolFoxProTheme danger];
    logoutBtn.layer.cornerRadius = 14;
    [logoutBtn setTitle:@"  تسجيل الخروج" forState:UIControlStateNormal];
    [logoutBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    logoutBtn.titleLabel.font = [WolFoxProTheme fontOfSize:15 weight:UIFontWeightBold];
    if (@available(iOS 13.0, *)) [logoutBtn setImage:[UIImage systemImageNamed:@"rectangle.portrait.and.arrow.right"] forState:UIControlStateNormal];
    logoutBtn.tintColor = [UIColor whiteColor];
    logoutBtn.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [logoutBtn addTarget:self action:@selector(logoutPressed) forControlEvents:UIControlEventTouchUpInside];
    logoutBtn.accessibilityLabel = @"تسجيل الخروج وحذف الترخيص";
    [logoutCard addSubview:logoutBtn];
    cy += 66 + 20;

    _scrollDashboard.contentSize = CGSizeMake(w, cy);
}

- (NSDictionary *)locationBackupPayload {
    WolFoxProStore *store = [WolFoxProStore shared];
    NSMutableArray *locations = [NSMutableArray new];
    for (WolFoxProLocation *location in store.locations) {
        [locations addObject:@{
            @"name": location.name ?: @"موقع محفوظ",
            @"latitude": @(location.coordinate.latitude),
            @"longitude": @(location.coordinate.longitude),
            @"altitude": @(location.altitude)
        }];
    }

    NSMutableArray *history = [NSMutableArray new];
    for (WolFoxLocationHistoryEntry *entry in store.locationHistory) {
        [history addObject:@{
            @"name": entry.name ?: @"موقع مستخدم",
            @"latitude": @(entry.coordinate.latitude),
            @"longitude": @(entry.coordinate.longitude),
            @"used_at": @((entry.usedAt ?: [NSDate date]).timeIntervalSince1970)
        }];
    }

    NSMutableArray *profiles = [NSMutableArray new];
    for (WolFoxLocationProfile *profile in store.locationProfiles) {
        [profiles addObject:@{
            @"name": profile.name ?: @"ملف موقع",
            @"latitude": @(profile.coordinate.latitude),
            @"longitude": @(profile.coordinate.longitude),
            @"speed": @(profile.speed),
            @"update_interval": @(profile.updateIntervalSeconds),
            @"jitter": @(profile.jitterEnabled)
        }];
    }

    return @{
        @"format": @"wolfox-location-backup",
        @"schema_version": @1,
        @"app_version": [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.8.2",
        @"created_at": @([NSDate date].timeIntervalSince1970),
        @"locations": locations,
        @"history": history,
        @"profiles": profiles
    };
}

- (void)exportLocationData {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:[self locationBackupPayload] options:NSJSONWritingPrettyPrinted error:&error];
    if (!data || error) {
        [self showToast:@"تعذر إنشاء النسخة الاحتياطية ❌"];
        return;
    }
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [UIPasteboard generalPasteboard].string = json;

    NSString *fileName = [NSString stringWithFormat:@"WolFox-Locations-%@.json", @((long long)[NSDate date].timeIntervalSince1970)];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    if (![data writeToFile:path options:NSDataWritingAtomic error:&error]) {
        [self showToast:@"تم النسخ للحافظة، لكن تعذر إنشاء ملف المشاركة"];
        return;
    }

    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
    activity.popoverPresentationController.sourceView = self.view;
    activity.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
    [self presentViewController:activity animated:YES completion:^{
        [self showToast:@"تم نسخ النسخة الاحتياطية للحافظة ✅"];
    }];
}

- (void)importLocationDataFromClipboard {
    NSString *json = [UIPasteboard generalPasteboard].string;
    if (!json.length) {
        [self showToast:@"الحافظة لا تحتوي على نص JSON"];
        return;
    }
    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    id root = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error || ![root isKindOfClass:[NSDictionary class]]) {
        [self showToast:@"ملف JSON غير صالح أو غير مدعوم ❌"];
        return;
    }
    NSDictionary *payload = (NSDictionary *)root;
    if (![payload[@"format"] isEqual:@"wolfox-location-backup"]) {
        [self showToast:@"هذه ليست نسخة احتياطية معتمدة من WolFox"];
        return;
    }
    NSArray *rawLocations = [payload[@"locations"] isKindOfClass:[NSArray class]] ? payload[@"locations"] : @[];
    NSArray *rawProfiles = [payload[@"profiles"] isKindOfClass:[NSArray class]] ? payload[@"profiles"] : @[];
    if (rawLocations.count == 0 && rawProfiles.count == 0) {
        [self showToast:@"لا توجد مواقع أو ملفات قابلة للاستيراد"];
        return;
    }

    WolFoxProStore *store = [WolFoxProStore shared];
    NSUInteger imported = 0;
    NSUInteger importedProfiles = 0;
    NSUInteger skipped = 0;
    for (id rawItem in rawLocations) {
        if (![rawItem isKindOfClass:[NSDictionary class]]) { skipped++; continue; }
        NSDictionary *item = (NSDictionary *)rawItem;
        id latitudeValue = item[@"latitude"];
        id longitudeValue = item[@"longitude"];
        if (![latitudeValue respondsToSelector:@selector(doubleValue)] || ![longitudeValue respondsToSelector:@selector(doubleValue)]) {
            skipped++;
            continue;
        }
        double latitude = [latitudeValue doubleValue];
        double longitude = [longitudeValue doubleValue];
        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(latitude, longitude);
        if (!isfinite(latitude) || !isfinite(longitude) || !CLLocationCoordinate2DIsValid(coordinate)) {
            skipped++;
            continue;
        }
        NSString *rawName = [item[@"name"] isKindOfClass:[NSString class]] ? item[@"name"] : @"موقع مستورد";
        NSString *name = [rawName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!name.length) name = @"موقع مستورد";

        BOOL duplicate = NO;
        for (WolFoxProLocation *existing in store.locations) {
            if (fabs(existing.coordinate.latitude - coordinate.latitude) < 0.000001 &&
                fabs(existing.coordinate.longitude - coordinate.longitude) < 0.000001 &&
                [existing.name isEqualToString:name]) {
                duplicate = YES;
                break;
            }
        }
        if (duplicate) { skipped++; continue; }

        WolFoxProLocation *location = [WolFoxProLocation new];
        location.name = name;
        location.coordinate = coordinate;
        id altitudeValue = item[@"altitude"];
        location.altitude = [altitudeValue respondsToSelector:@selector(doubleValue)] ? [altitudeValue doubleValue] : 300.0;
        [store saveLocation:location];
        imported++;
    }

    for (id rawItem in rawProfiles) {
        if (![rawItem isKindOfClass:[NSDictionary class]]) { skipped++; continue; }
        NSDictionary *item = (NSDictionary *)rawItem;
        id latitudeValue = item[@"latitude"];
        id longitudeValue = item[@"longitude"];
        if (![latitudeValue respondsToSelector:@selector(doubleValue)] || ![longitudeValue respondsToSelector:@selector(doubleValue)]) {
            skipped++;
            continue;
        }
        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake([latitudeValue doubleValue], [longitudeValue doubleValue]);
        if (!CLLocationCoordinate2DIsValid(coordinate)) { skipped++; continue; }
        NSString *name = [item[@"name"] isKindOfClass:[NSString class]] ? item[@"name"] : @"ملف موقع مستورد";
        WolFoxLocationProfile *profile = [WolFoxLocationProfile new];
        profile.name = name;
        profile.coordinate = coordinate;
        profile.speed = [item[@"speed"] respondsToSelector:@selector(doubleValue)] ? [item[@"speed"] doubleValue] : store.simSpeed;
        profile.updateIntervalSeconds = [item[@"update_interval"] respondsToSelector:@selector(doubleValue)] ? [item[@"update_interval"] doubleValue] : store.updateIntervalSeconds;
        profile.jitterEnabled = [item[@"jitter"] respondsToSelector:@selector(boolValue)] ? [item[@"jitter"] boolValue] : store.jitterActive;
        [store saveLocationProfile:profile];
        importedProfiles++;
    }

    if (imported == 0 && importedProfiles == 0) {
        [self showToast:skipped ? @"لم تُضف بيانات؛ العناصر مكررة أو غير صالحة" : @"النسخة الاحتياطية فارغة"];
        return;
    }
    [self showToast:[NSString stringWithFormat:@"تم استيراد %lu موقعاً و%lu ملفاً وتجاوز %lu ✅", (unsigned long)imported, (unsigned long)importedProfiles, (unsigned long)skipped]];
}

- (void)showLocationDataResetOptions {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"مسح بيانات المواقع"
                                                                   message:@"اختر البيانات التي تريد مسحها. لن يتأثر الترخيص أو الإعدادات."
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    void (^confirmReset)(NSInteger, NSString *, NSString *) = ^(NSInteger mode, NSString *title, NSString *message) {
        UIAlertController *confirm = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        [confirm addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
        [confirm addAction:[UIAlertAction actionWithTitle:@"مسح نهائياً" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
            WolFoxProStore *store = [WolFoxProStore shared];
            if (mode == 1 || mode == 3 || mode == 5) {
                for (WolFoxProLocation *location in [store.locations copy]) [store deleteLocationID:location.ID];
            }
            if (mode == 2 || mode == 3 || mode == 5) [store clearLocationHistory];
            if (mode == 4 || mode == 5) [store clearLocationProfiles];
            [self showToast:@"تم مسح البيانات المحددة ✅"];
            if (self->_activePage == 4) [self switchPage:4];
        }]];
        [self presentViewController:confirm animated:YES completion:nil];
    };
    [sheet addAction:[UIAlertAction actionWithTitle:@"مسح المواقع المفضلة" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        confirmReset(1, @"مسح جميع المفضلة؟", @"سيتم حذف أسماء وإحداثيات المواقع المحفوظة نهائياً.");
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"مسح سجل المواقع" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        confirmReset(2, @"مسح سجل المواقع؟", @"ستبقى المواقع المفضلة محفوظة.");
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"مسح المفضلة والسجل" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        confirmReset(3, @"مسح المفضلة والسجل؟", @"سيتم حذف المفضلة وسجل الاستخدام نهائياً.");
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"مسح ملفات المواقع السريعة" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        confirmReset(4, @"مسح ملفات المواقع السريعة؟", @"سيتم حذف الملفات المحفوظة فقط.");
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"مسح جميع بيانات المواقع" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        confirmReset(5, @"مسح جميع بيانات المواقع؟", @"سيتم حذف المفضلة والسجل وملفات المواقع نهائياً.");
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = self.view;
    sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)copyDiagnosticReport {
    WolFoxProStore *store = [WolFoxProStore shared];
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier ?: @"unknown";
    NSString *appVersion = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"unknown";
    NSString *report = [NSString stringWithFormat:
        @"WolFox Diagnostic Report\n"
         "Version: %@\n"
         "iOS: %@\n"
         "Bundle: %@\n"
         "License valid: %@\n"
         "GPS spoof: %@\n"
         "Route: %@\n"
         "Coordinates: %.6f, %.6f\n"
         "Favorites: %lu\n"
         "History: %lu\n"
         "Quick profiles: %lu\n"
         "Identifier layer: %@\n"
         "Bluetooth spoof: %@\n"
         "Virtual camera: %@\n",
         appVersion,
         UIDevice.currentDevice.systemVersion ?: @"unknown",
         bundleID,
         [WFLicenseClient isRuntimeLicenseValid] ? @"yes" : @"no",
         store.spoofActive ? @"on" : @"off",
         store.routeActive ? @"on" : @"off",
         store.currentFakeCoords.latitude,
         store.currentFakeCoords.longitude,
         (unsigned long)store.locations.count,
         (unsigned long)store.locationHistory.count,
         (unsigned long)store.locationProfiles.count,
         store.validatedActiveIdentifier ? @"active" : @"inactive",
         store.bluetoothActive ? @"on" : @"off",
         store.mediaUploadActive ? @"on" : @"off"];
    [UIPasteboard generalPasteboard].string = report;
    [self showToast:@"تم نسخ تقرير التشخيص بدون مفاتيح أو أسرار ✅"];
}

- (NSArray<UIColor *> *)markerPalette {
    return @[[UIColor systemBlueColor], [UIColor colorWithRed:0.16 green:0.72 blue:0.34 alpha:1.0], [UIColor systemOrangeColor], [UIColor systemPurpleColor], [UIColor systemRedColor], [UIColor systemTealColor]];
}

- (UIColor *)markerColorForKey:(NSString *)key defaultColor:(UIColor *)fallback {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    // integerForKey: returns 0 for a missing key, so check presence first.
    id storedValue = [defaults objectForKey:key];
    if (!storedValue) return fallback;
    NSInteger index = [storedValue integerValue];
    NSArray *colors = [self markerPalette];
    if (index < 0 || index >= (NSInteger)colors.count) return fallback;
    return colors[index];
}

- (void)chooseMarkerColorForKey:(NSString *)key title:(NSString *)title {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:title message:@"اختر لون المؤشر" preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *names = @[@"أزرق", @"أخضر", @"برتقالي", @"بنفسجي", @"أحمر", @"فيروزي"];
    NSArray *colors = [self markerPalette];
    for (NSUInteger i = 0; i < colors.count; i++) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:names[i] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a){
            [[NSUserDefaults standardUserDefaults] setInteger:(NSInteger)i forKey:key];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self refreshMarkerColors];
            [self showToast:@"تم تحديث لون المؤشر"]; 
        }];
        [sheet addAction:action];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    if (sheet.popoverPresentationController) { sheet.popoverPresentationController.sourceView = self.view; sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1); }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)chooseRealMarkerColor { [self chooseMarkerColorForKey:@"WF_REAL_DOT_COLOR" title:@"لون الموقع الحقيقي"]; }
- (void)chooseFakeMarkerColor { [self chooseMarkerColorForKey:@"WF_FAKE_DOT_COLOR" title:@"لون الموقع المزيّف"]; }

- (void)refreshMarkerColors {
    if (!self.mapView) return;
    if (self.realLocPin) { MKAnnotationView *realView = [self.mapView viewForAnnotation:self.realLocPin]; realView.image = [self createDotImageWithColor:[self markerColorForKey:@"WF_REAL_DOT_COLOR" defaultColor:[UIColor systemBlueColor]]]; }
    if (self->_currentPin) { MKAnnotationView *fakeView = [self.mapView viewForAnnotation:self->_currentPin]; if ([fakeView isKindOfClass:[MKMarkerAnnotationView class]]) ((MKMarkerAnnotationView *)fakeView).markerTintColor = [self markerColorForKey:@"WF_FAKE_DOT_COLOR" defaultColor:[UIColor colorWithRed:0.16 green:0.72 blue:0.34 alpha:1.0]]; }
}

- (void)expiryNotificationsChanged:(UISwitch *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:sender.on forKey:@"WF_EXPIRY_NOTIFICATIONS_ENABLED"];
    [defaults synchronize];
    if (!sender.on) {
        [[UNUserNotificationCenter currentNotificationCenter] removePendingNotificationRequestsWithIdentifiers:@[@"wolfox.expiry.reminder"]];
        [self showToast:@"تم إيقاف تذكير انتهاء الاشتراك"];
        return;
    }
    __weak typeof(self) weakSelf = self;
    [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound) completionHandler:^(BOOL granted, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (!granted || error) { [defaults setBool:NO forKey:@"WF_EXPIRY_NOTIFICATIONS_ENABLED"]; [defaults synchronize]; sender.on = NO; [strongSelf showToast:@"لم يتم السماح بالإشعارات من إعدادات النظام"]; return; }
            [strongSelf scheduleExpiryReminderIfEnabled:[WFLicenseClient lastLicenseResult] ?: [WFLicenseClient storedLicenseInfo]];
            [strongSelf showToast:@"تم تفعيل تذكير انتهاء الاشتراك"];
        });
    }];
}

- (void)scheduleExpiryReminderIfEnabled:(WFLicenseResult *)result {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"WF_EXPIRY_NOTIFICATIONS_ENABLED"] || !result.expiresAt.length) return;
    NSDate *expiry = nil;
    if (@available(iOS 10.0, *)) expiry = [[NSISO8601DateFormatter new] dateFromString:result.expiresAt];
    if (!expiry) {
        // أنشئ NSDateFormatter مرة واحدة خارج الـ loop — الإنشاء المتكرر غالي
        NSDateFormatter *df = [NSDateFormatter new];
        df.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        df.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        for (NSString *format in @[@"yyyy-MM-dd HH:mm:ss", @"yyyy-MM-dd'T'HH:mm:ssZ", @"yyyy-MM-dd"]) {
            df.dateFormat = format;
            expiry = [df dateFromString:result.expiresAt];
            if (expiry) break;
        }
    }
    if (!expiry || [expiry timeIntervalSinceNow] <= 0) return;
    NSDate *fireDate = [expiry dateByAddingTimeInterval:-259200.0];
    if ([fireDate timeIntervalSinceNow] <= 0) return;
    [[UNUserNotificationCenter currentNotificationCenter] removePendingNotificationRequestsWithIdentifiers:@[@"wolfox.expiry.reminder"]];
    UNMutableNotificationContent *content = [UNMutableNotificationContent new]; content.title = @"تذكير انتهاء الاشتراك"; content.body = @"تبقى ثلاثة أيام أو أقل على انتهاء كود التفعيل. افتح التطبيق للتحقق والتجديد."; content.sound = [UNNotificationSound defaultSound];
    NSDateComponents *components = [[NSCalendar currentCalendar] components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute) fromDate:fireDate];
    UNCalendarNotificationTrigger *trigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:components repeats:NO];
    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:[UNNotificationRequest requestWithIdentifier:@"wolfox.expiry.reminder" content:content trigger:trigger] withCompletionHandler:nil];
}

- (void)showSubscriptionInfo {
    // Show cached first, then refresh from server
    WFLicenseResult *cached = [WFLicenseClient lastLicenseResult] ?: [WFLicenseClient storedLicenseInfo];
    [self _presentSubscriptionPopup:cached];

    __weak typeof(self) weakSelf = self;
    [WFLicenseClient verifySavedLicenseWithCompletion:^(WFLicenseResult *live) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            // لا تُحدِّث الـ popup إن أُغلق الـ VC أو انتقل المستخدم لصفحة أخرى
            if (!strongSelf || !strongSelf.view.window) return;
            [strongSelf hidePopup];
            if (live.success) [strongSelf _presentSubscriptionPopup:live];
        });
    }];
}

- (void)_presentSubscriptionPopup:(WFLicenseResult *)info {
    if (!info) info = [WFLicenseResult new]; // safe default
    NSString *deviceShort = [WFLicenseClient deviceIdentifier];
    if (deviceShort.length > 8) deviceShort = [deviceShort substringToIndex:8];
    NSString *code = [WFLicenseClient storedCode] ?: @"—";
    NSString *status = info.success ? @"✅ نشط" : @"❌ غير نشط";
    [self showPopupWithTitle:@"معلومات الاشتراك" icon:@"crown.fill" content:^{
        CGFloat contentWidth = MIN(300.0, self.view.bounds.size.width - 80.0);
        UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, contentWidth, 436)];
        [self addInfoRow:v t:@"الحالة" v:status y:0];
        [self addInfoRow:v t:@"إصدار النسخة" v:@"WolFox Full v1.8.2" y:72];
        [self addInfoRow:v t:@"نوع الباقة" v:info.planName ?: @"تجريبي" y:144];
        [self addInfoRow:v t:@"تاريخ الانتهاء" v:info.expiresAt ?: @"غير متوفر" y:216];
        [self addInfoRow:v t:@"كود التفعيل" v:code y:288];
        [self addInfoRow:v t:@"معرّف الجهاز" v:deviceShort y:360];
        return v;
    } btnTitle:@"موافق" btnColor:[WolFoxProTheme accent]];
}

- (void)addInfoRow:(UIView *)p t:(NSString *)t v:(NSString *)v y:(CGFloat)y {
    UILabel *tl = [[UILabel alloc] initWithFrame:CGRectMake(15, y, p.bounds.size.width - 30, 20)];
    tl.text = t; tl.textColor = [WolFoxProTheme textSecondary]; tl.font = [WolFoxProTheme fontOfSize:13 weight:UIFontWeightMedium]; tl.textAlignment = NSTextAlignmentRight;
    [p addSubview:tl];
    UILabel *vl = [[UILabel alloc] initWithFrame:CGRectMake(15, y + 25, p.bounds.size.width - 30, 40)];
    vl.backgroundColor = [WolFoxProTheme surfaceSecondary]; vl.layer.cornerRadius = 11; vl.text = v; vl.textColor = [WolFoxProTheme textPrimary]; vl.font = [WolFoxProTheme fontOfSize:13 weight:UIFontWeightBold]; vl.textAlignment = NSTextAlignmentCenter; vl.lineBreakMode = NSLineBreakByTruncatingMiddle; vl.adjustsFontSizeToFitWidth = YES; vl.minimumScaleFactor = 0.72;
    [p addSubview:vl];
}

// activateCodePressed removed - activation handled by WFActivationViewController

- (void)logoutPressed {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"تسجيل الخروج" message:@"هل أنت متأكد من رغبتك في حذف الترخيص من هذا الجهاز؟" preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"نعم، حذف" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a){
        [WFLicenseClient clearStoredLicense];
        [WolFoxProStore shared].spoofActive = NO;
        [WolFoxProStore shared].scheduleApplied = NO;
        [[WolFoxProStore shared] saveSettings];
        [[WolFoxProHookManager shared] stopRoute];
        // أغلق الـ UI وأظهر شاشة التفعيل بدلاً من exit() الذي يقتل العملية بلا تنظيف
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[WolFoxController shared] showActivationScreenWithResult:nil];
        });
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}


- (void)openTelegram { [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://t.me/WolFoxGPS"] options:@{} completionHandler:nil]; }


#pragma mark - Actions & Map

- (void)applyManualCoords {
    NSString *input = [NSString stringWithFormat:@"%@,%@", _latInput.text ?: @"", _lonInput.text ?: @""];
    CLLocationCoordinate2D c;
    if (![self parseCoordinateSearchText:input coordinate:&c]) {
        [self showToast:@"الإحداثيات غير صحيحة؛ خط العرض من -90 إلى 90 والطول من -180 إلى 180 ❌"];
        return;
    }
    // أوقف أي محاكاة مسار نشطة قبل تثبيت إحداثية جديدة
    if ([WolFoxProStore shared].routeActive) {
        [[WolFoxProHookManager shared] stopRoute];
        UIButton *routeBtn = objc_getAssociatedObject(self, "_route_btn");
        if (routeBtn) {
            [routeBtn setTitle:@"بدء محاكاة المسار" forState:UIControlStateNormal];
            routeBtn.backgroundColor = [WolFoxProTheme accent];
        }
    }
    // ADDED: امسح دبوس الهدف عند تغيير الإحداثيات يدوياً
    MKPointAnnotation *targetPin = objc_getAssociatedObject(self, "_target_pin");
    if (targetPin) {
        [self.mapView removeAnnotation:targetPin];
        objc_setAssociatedObject(self, "_target_pin", nil, OBJC_ASSOCIATION_ASSIGN);
    }
    [WolFoxProStore shared].spoofActive = YES;
    [WolFoxProStore shared].currentFakeCoords = c;
    [[WolFoxProStore shared] saveSettings];
    [self updateMapPin:c];
    [[WolFoxProHookManager shared] deliverFakeUpdate];
    [[WolFoxProStore shared] recordLocationHistoryWithName:@"إحداثيات يدوية" coordinate:c];
    [self showRealLocation];
    [self refreshSpoofHeaderStatus];
    [self showToast:@"✅ تم تطبيق الموقع وتشغيل التزييف"];
}

- (void)toggleTheme {
    [WolFoxProStore shared].themeIndex = ([WolFoxProStore shared].themeIndex == 0) ? 1 : 0;
    [[WolFoxProStore shared] saveSettings];

    // أعد تطبيق الثيم على كل عناصر الـ header و tabs — ليس فقط الـ dashboard
    self->_blurView.effect = [UIBlurEffect effectWithStyle:[WolFoxProTheme blurStyle]];
    self.view.backgroundColor = [WolFoxProTheme windowBackground];
    self->_dashboard.backgroundColor = [WolFoxProTheme windowBackground];
    self->_scrollDashboard.backgroundColor = [WolFoxProTheme windowBackground];
    self->_header.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.16];
    self->_tabsBar.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.10];
    self->_titleLabel.textColor = [WolFoxProTheme textPrimary];
    self->_spoofStatusLabel.textColor = [WolFoxProStore shared].spoofActive ? [WolFoxProTheme success] : [WolFoxProTheme textSecondary];

    // حدّث أيقونة زر الثيم وعنوانه — يتناسب مع التصميم الجديد
    UIButton *tb = objc_getAssociatedObject(self, "_theme_btn");
    BOOL isDark = [WolFoxProTheme isDark];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightBold];
        [tb setImage:[UIImage systemImageNamed:(isDark ? @"sun.max.fill" : @"moon.stars.fill") withConfiguration:cfg] forState:UIControlStateNormal];
    }
    [tb setTitle:(isDark ? @"  الثيم الفاتح" : @"  الثيم الداكن") forState:UIControlStateNormal];
    [tb setTitleColor:[WolFoxProTheme accent] forState:UIControlStateNormal];
    tb.tintColor = [WolFoxProTheme accent];
    tb.backgroundColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.14];

    // أعد بناء الصفحة الحالية لتطبيق الألوان الجديدة
    if (self->_tabBtns.count > 0) {
        [self switchPage:self->_activePage];
    }
}

- (void)dismiss { [[WolFoxController shared] dismissUI]; }

- (void)handleLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    // أوقف أي مسار نشط قبل تحديد إحداثية جديدة عبر الضغط الطويل
    if ([WolFoxProStore shared].routeActive) {
        [[WolFoxProHookManager shared] stopRoute];
        UIButton *routeBtn = objc_getAssociatedObject(self, "_route_btn");
        if (routeBtn) {
            [routeBtn setTitle:@"بدء محاكاة المسار" forState:UIControlStateNormal];
            routeBtn.backgroundColor = [WolFoxProTheme accent];
        }
    }
    CGPoint p = [g locationInView:self.mapView];
    CLLocationCoordinate2D c = [self.mapView convertPoint:p toCoordinateFromView:self.mapView];
    WolFoxProStore *store = [WolFoxProStore shared];

    // ADDED: ضغط طويل أول → يضع نقطة البداية؛ إذا كانت موجودة → يضع نقطة الهدف
    BOOL hasStartPin = _currentPin != nil && CLLocationCoordinate2DIsValid(store.currentFakeCoords);
    BOOL hasTargetPin = objc_getAssociatedObject(self, "_target_pin") != nil;
    if (hasStartPin && !hasTargetPin) {
        // ضع نقطة الهدف
        store.targetRouteCoords = c;
        [store saveSettings];
        MKPointAnnotation *targetPin = [MKPointAnnotation new];
        targetPin.coordinate = c;
        targetPin.title = @"نقطة الوصول";
        targetPin.subtitle = @"اضغط «بدء محاكاة المسار» للانطلاق";
        [self.mapView addAnnotation:targetPin];
        objc_setAssociatedObject(self, "_target_pin", targetPin, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self showToast:@"📍 تم تحديد نقطة الوصول — اضغط «بدء» للانطلاق"];
        return;
    }
    // ضع/أعد نقطة البداية وامسح الهدف السابق إن وجد
    MKPointAnnotation *oldTarget = objc_getAssociatedObject(self, "_target_pin");
    if (oldTarget) {
        [self.mapView removeAnnotation:oldTarget];
        objc_setAssociatedObject(self, "_target_pin", nil, OBJC_ASSOCIATION_ASSIGN);
    }
    store.currentFakeCoords = c;
    [store saveSettings];
    [self updateMapPin:c];
    [[WolFoxProHookManager shared] deliverFakeUpdate];
    if (_latInput) _latInput.text = [NSString stringWithFormat:@"%.6f", c.latitude];
    if (_lonInput) _lonInput.text = [NSString stringWithFormat:@"%.6f", c.longitude];
    [self showToast:@"📍 نقطة البداية — اضغط مجدداً لتحديد نقطة الوصول"];
}

- (void)updateMapPin:(CLLocationCoordinate2D)c {
    if (_currentPin) [self.mapView removeAnnotation:_currentPin];
    _currentPin = [MKPointAnnotation new]; _currentPin.coordinate = c;
    _currentPin.title = @"الدبوس الأحمر: الموقع المزيّف";
    _currentPin.subtitle = @"الإحداثيات التي تم اختيارها أو إدخالها";
    [self.mapView addAnnotation:_currentPin];
}

- (void)centerMapOnPin {
    if (!_currentPin || !self.mapView) return;

    CLLocationCoordinate2D coordinate = _currentPin.coordinate;
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(coordinate, 1400.0, 1400.0);
    [self.mapView setRegion:region animated:YES];
    [self showToast:@"تم التمركز على الموقع المزيّف 📍"];
}

- (void)refreshRealLocationPinWithoutRecentering {
    CLLocation *real = [WolFoxProHookManager shared].lastRealLocation;
    if (!real || !self.mapView) { [self refreshLocationModeNotice]; return; }
    if (!self.realLocPin) {
        self.realLocPin = [MKPointAnnotation new];
        [self.mapView addAnnotation:self.realLocPin];
    }
    self.realLocPin.title = @"النقطة الزرقاء: الموقع الحقيقي";
    self.realLocPin.subtitle = @"موقع الجهاز الفعلي";
    self.realLocPin.coordinate = real.coordinate;
    [self refreshLocationModeNotice];
}

- (void)showRealLocation {
    [self refreshRealLocationPinWithoutRecentering];
    CLLocation *real = [WolFoxProHookManager shared].lastRealLocation;
    if (real && self.mapView) [self.mapView setCenterCoordinate:real.coordinate animated:YES];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    CLLocation *location = locations.lastObject;
    if (!location) return;
    // While spoofing, the delegate proxy has already saved the real CLLocation
    // before forwarding the synthetic one. Do not overwrite that real value.
    if (![WolFoxProStore shared].spoofActive) {
        [WolFoxProHookManager shared].lastRealLocation = location;
        if (self.mapView) [self showRealLocation];
    }
}

- (void)confirmDisableSpoofForSwitch:(UISwitch *)sw {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"إيقاف تزييف الموقع؟" message:@"سيعود التطبيق لاستخدام موقع الجهاز الحقيقي. لن يتوقف التزييف إلا بعد التأكيد." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"متابعة التزييف" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *action) {
        [sw setOn:YES animated:YES];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"إيقاف الآن" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [[WolFoxProHookManager shared] stopRoute];
        [WolFoxProStore shared].spoofActive = NO;
        [WolFoxProStore shared].scheduleApplied = NO;
        [[WolFoxProStore shared] saveSettings];
        [self refreshSpoofHeaderStatus];
        [self showRealLocation];
        [self showToast:@"تم إيقاف تزييف الموقع وعرض الموقع الحقيقي"];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)copyActivationCode {
    NSString *code = [WFLicenseClient storedCode];
    if (code) {
        [UIPasteboard generalPasteboard].string = code;
        [self showToast:@"تم نسخ الكود للحافظة 📋"];
    } else {
        [self showToast:@"لا يوجد كود للنسخ ❌"];
    }
}

- (void)pasteCoordinates {
    NSString *str = [UIPasteboard generalPasteboard].string;
    if (!str.length) { [self showToast:@"الحافظة فارغة ❌"]; return; }

    // حاول تحليل الإحداثيات أولاً بالمحلل المعياري (يدعم lat,lon وlat lon والأرقام العربية)
    CLLocationCoordinate2D parsed;
    NSString *normalized = [self normalizedMapSearchText:str];
    if ([self parseCoordinateSearchText:normalized coordinate:&parsed]) {
        // إحداثيات صالحة — طبّقها مباشرة
        if (_latInput) _latInput.text = [NSString stringWithFormat:@"%.6f", parsed.latitude];
        if (_lonInput) _lonInput.text = [NSString stringWithFormat:@"%.6f", parsed.longitude];
        // أوقف أي مسار نشط قبل تثبيت الإحداثية الملصوقة
        if ([WolFoxProStore shared].routeActive) {
            [[WolFoxProHookManager shared] stopRoute];
            UIButton *routeBtn = objc_getAssociatedObject(self, "_route_btn");
            if (routeBtn) {
                [routeBtn setTitle:@"بدء محاكاة المسار" forState:UIControlStateNormal];
                routeBtn.backgroundColor = [WolFoxProTheme accent];
            }
        }
        // ADDED: امسح دبوس الهدف عند لصق إحداثيات جديدة
        MKPointAnnotation *targetPin = objc_getAssociatedObject(self, "_target_pin");
        if (targetPin) {
            [self.mapView removeAnnotation:targetPin];
            objc_setAssociatedObject(self, "_target_pin", nil, OBJC_ASSOCIATION_ASSIGN);
        }
        [WolFoxProStore shared].currentFakeCoords = parsed;
        [WolFoxProStore shared].spoofActive = YES;
        [[WolFoxProStore shared] saveSettings];
        [self updateMapPin:parsed];
        [[WolFoxProHookManager shared] deliverFakeUpdate];
        [self showRealLocation];
        [self refreshSpoofHeaderStatus];
        [self showToast:@"✅ تم لصق الإحداثيات وتفعيل الموقع"];
        return;
    }

    // fallback: ملء الحقلين فقط بدون تطبيق
    NSArray *parts = [normalized componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@", "]];
    NSMutableArray *cleanParts = [NSMutableArray new];
    for (NSString *p in parts) {
        NSString *c = [p stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (c.length > 0) [cleanParts addObject:c];
    }
    if (cleanParts.count >= 2) {
        if (_latInput) _latInput.text = cleanParts[0];
        if (_lonInput) _lonInput.text = cleanParts[1];
        [self showToast:@"تم اللصق — اضغط «إضافة وتفعيل» للتطبيق"];
    } else {
        [self showToast:@"تنسيق الإحداثيات غير صحيح ❌"];
    }
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    if ([annotation isKindOfClass:[MKPointAnnotation class]]) {
        // ADDED: دبوس نقطة الهدف (خط الوصول)
        MKPointAnnotation *targetPin = objc_getAssociatedObject(self, "_target_pin");
        if (annotation == targetPin) {
            MKMarkerAnnotationView *target = (MKMarkerAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"target_marker"];
            if (!target) target = [[MKMarkerAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"target_marker"];
            target.markerTintColor = [WolFoxProTheme danger];
            target.glyphText = @"🏁";
            target.glyphTintColor = [UIColor whiteColor];
            target.canShowCallout = YES;
            return target;
        }
        if (annotation == self.realLocPin) {
            MKAnnotationView *av = [mapView dequeueReusableAnnotationViewWithIdentifier:@"real_dot"];
            if (!av) av = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"real_dot"];
            av.image = [self createDotImageWithColor:[self markerColorForKey:@"WF_REAL_DOT_COLOR" defaultColor:[UIColor systemBlueColor]]];
            av.canShowCallout = YES;
            return av;
        }
        MKMarkerAnnotationView *marker = (MKMarkerAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"fake_marker"];
        if (!marker) marker = [[MKMarkerAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"fake_marker"];
        BOOL moving = [WolFoxProStore shared].routeActive;
        marker.markerTintColor = [self markerColorForKey:@"WF_FAKE_DOT_COLOR" defaultColor:[UIColor colorWithRed:0.16 green:0.72 blue:0.34 alpha:1.0]];
        marker.glyphText = moving ? @"➤" : @"●";
        marker.glyphTintColor = [UIColor whiteColor];
        marker.layer.borderWidth = moving ? 3.0 : 0.0;
        marker.layer.borderColor = [WolFoxProTheme accent].CGColor;
        marker.layer.cornerRadius = marker.bounds.size.width * 0.5;
        if (moving) {
            CLLocationCoordinate2D current = [WolFoxProStore shared].currentFakeCoords;
            CLLocationCoordinate2D target = [WolFoxProStore shared].targetRouteCoords;
            // FIX: نفس حساب البearing الجغرافي الصحيح
            double dLat = target.latitude  - current.latitude;
            double dLon = target.longitude - current.longitude;
            CGFloat bearing = (CGFloat)atan2(dLon, dLat);
            marker.transform = CGAffineTransformMakeRotation(bearing);
        } else {
            marker.transform = CGAffineTransformIdentity;
        }
        marker.canShowCallout = YES;
        return marker;
    }
    return nil;
}

- (UIImage *)createBlueDotImage {
    return [self createDotImageWithColor:[self markerColorForKey:@"WF_REAL_DOT_COLOR" defaultColor:[UIColor systemBlueColor]]];
}
- (UIImage *)createDotImageWithColor:(UIColor *)color {
    CGFloat s = 20;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(s, s), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [[UIColor whiteColor] setFill]; CGContextFillEllipseInRect(ctx, CGRectMake(0, 0, s, s));
    [color setFill]; CGContextFillEllipseInRect(ctx, CGRectMake(2, 2, s-4, s-4));
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (void)saveCurrentLocation {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"حفظ الموقع" message:@"أدخل اسماً لهذا الموقع" preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf){ tf.placeholder = @"اسم الموقع"; tf.textAlignment = NSTextAlignmentRight; }];
    [ac addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"حفظ" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        NSString *name = ac.textFields.firstObject.text ?: @"موقع جديد";
        WolFoxProStore *store = [WolFoxProStore shared];
        WolFoxProLocation *l = [WolFoxProLocation new];
        // لا تحفظ مركز الخريطة الحقيقي أثناء التزييف؛ احفظ الإحداثية المزيّفة الحالية.
        CLLocationCoordinate2D selected = store.spoofActive
            ? store.currentFakeCoords
            : (self.mapView ? self.mapView.centerCoordinate : store.currentFakeCoords);
        if (!CLLocationCoordinate2DIsValid(selected)) {
            [self showToast:@"تعذر حفظ إحداثية صالحة ❌"];
            return;
        }
        l.name = name; l.coordinate = selected; l.altitude = 300.0;
        [[WolFoxProStore shared] saveLocation:l];
        NSUInteger count = [WolFoxProStore shared].locations.count;
        [self showToast:[NSString stringWithFormat:@"تم الحفظ في المفضلة • %lu مواقع", (unsigned long)count]];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self->_activePage == 0) [self switchPage:0];
        });
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)showSavedLocations {
    NSArray *locs = [WolFoxProStore shared].locations;
    if (locs.count == 0) { [self showToast:@"لا توجد مواقع محفوظة 📋"]; return; }
    [self showPopupWithTitle:@"المواقع المحفوظة" icon:@"list.bullet" content:^{
        CGFloat ph = MIN((CGFloat)locs.count * 60.0 + 20.0, 400.0);
        UIScrollView *sv = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 300, ph)];
        sv.alwaysBounceVertical = YES;
        CGFloat cy = 10;
        for (NSUInteger i = 0; i < locs.count; i++) {
            WolFoxProLocation *l = locs[i];
            UIView *row = [[UIView alloc] initWithFrame:CGRectMake(10, cy, 280, 50)];
            row.backgroundColor = [WolFoxProTheme surfaceSecondary]; row.layer.cornerRadius = 12;
            [sv addSubview:row];
            UILabel *nl = [[UILabel alloc] initWithFrame:CGRectMake(94, 5, 176, 20)];
            nl.text = l.name; nl.textColor = [WolFoxProTheme textPrimary]; nl.textAlignment = NSTextAlignmentRight; nl.font = [WolFoxProTheme fontOfSize:14 weight:UIFontWeightBold];
            [row addSubview:nl];
            UILabel *cl = [[UILabel alloc] initWithFrame:CGRectMake(94, 25, 176, 20)];
            cl.text = [NSString stringWithFormat:@"%.6f, %.6f", l.coordinate.latitude, l.coordinate.longitude];
            cl.textColor = [WolFoxProTheme textSecondary]; cl.textAlignment = NSTextAlignmentRight; cl.font = [WolFoxProTheme fontOfSize:10 weight:UIFontWeightMedium];
            [row addSubview:cl];
            UIButton *selB = [UIButton buttonWithType:UIButtonTypeCustom]; selB.frame = row.bounds; selB.tag = i;
            [selB addTarget:self action:@selector(favSelected:) forControlEvents:UIControlEventTouchUpInside];
            [row addSubview:selB];
            UIButton *editB = [UIButton buttonWithType:UIButtonTypeSystem]; editB.frame = CGRectMake(50, 3, 40, 44);
            if (@available(iOS 13.0, *)) [editB setImage:[UIImage systemImageNamed:@"pencil"] forState:UIControlStateNormal];
            editB.tintColor = [WolFoxProTheme accent];
            objc_setAssociatedObject(editB, "loc_id", @(l.ID), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [editB addTarget:self action:@selector(editFav:) forControlEvents:UIControlEventTouchUpInside];
            editB.accessibilityLabel = [NSString stringWithFormat:@"تعديل الموقع %@", l.name ?: @""];
            [row addSubview:editB];
            UIButton *delB = [UIButton buttonWithType:UIButtonTypeSystem]; delB.frame = CGRectMake(6, 3, 40, 44);
            if (@available(iOS 13.0, *)) [delB setImage:[UIImage systemImageNamed:@"trash"] forState:UIControlStateNormal];
            delB.tintColor = [WolFoxProTheme danger];
            objc_setAssociatedObject(delB, "loc_id", @(l.ID), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [delB addTarget:self action:@selector(deleteFav:) forControlEvents:UIControlEventTouchUpInside];
            delB.accessibilityLabel = [NSString stringWithFormat:@"حذف الموقع %@", l.name ?: @""];
            [row addSubview:delB];
            cy += 60;
        }
        sv.contentSize = CGSizeMake(300, cy);
        return sv;
    } btnTitle:@"إغلاق" btnColor:[WolFoxProTheme accent]];
}

- (void)favSelected:(UIButton *)b {
    NSArray *locs = [WolFoxProStore shared].locations;
    if (b.tag < 0 || (NSUInteger)b.tag >= locs.count) return;
    WolFoxProLocation *l = locs[b.tag];
    WolFoxProStore *store = [WolFoxProStore shared];
    // Selecting a favorite is a fixed-location action, never a route start.
    if (store.routeActive) {
        [[WolFoxProHookManager shared] stopRoute];
        UIButton *routeButton = objc_getAssociatedObject(self, "_route_btn");
        [routeButton setTitle:@"بدء محاكاة المسار" forState:UIControlStateNormal];
        routeButton.backgroundColor = [WolFoxProTheme accent];
        routeButton.accessibilityLabel = @"بدء محاكاة المسار";
    }
    // اختيار موقع محفوظ هو إجراء تفعيل مباشر للموقع الوهمي، وليس مجرد تحديد على الخريطة.
    store.currentFakeCoords = l.coordinate;
    store.spoofActive = YES;
    [store saveSettings];
    [self updateMapPin:l.coordinate];
    [[WolFoxProHookManager shared] deliverFakeUpdate];
    [store recordLocationHistoryWithName:l.name coordinate:l.coordinate];
    // إبقاء الخريطة متمركزة على الموقع المفضل بدل إعادة تمركزها على الموقع الحقيقي.
    [self centerMapOnPin];
    [self refreshSpoofHeaderStatus];
    [self hidePopup];
    [self showToast:@"تم تثبيت الموقع المفضل وتشغيل التزييف 📍"];
}

- (void)editFav:(UIButton *)b {
    NSNumber *locID = objc_getAssociatedObject(b, "loc_id");
    if (!locID) return;
    WolFoxProStore *store = [WolFoxProStore shared];
    WolFoxProLocation *location = nil;
    for (WolFoxProLocation *candidate in store.locations) {
        if (candidate.ID == locID.longLongValue) { location = candidate; break; }
    }
    if (!location) {
        [self showToast:@"تعذر العثور على الموقع المحفوظ ❌"];
        return;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"تعديل الموقع" message:@"عدّل الاسم أو الإحداثيات ثم احفظ" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"اسم الموقع";
        field.text = location.name;
        field.textAlignment = NSTextAlignmentRight;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"خط العرض";
        field.text = [NSString stringWithFormat:@"%.6f", location.coordinate.latitude];
        field.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        field.textAlignment = NSTextAlignmentLeft;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"خط الطول";
        field.text = [NSString stringWithFormat:@"%.6f", location.coordinate.longitude];
        field.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        field.textAlignment = NSTextAlignmentLeft;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"حفظ التعديل" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *coordinateText = [NSString stringWithFormat:@"%@,%@", alert.textFields[1].text ?: @"", alert.textFields[2].text ?: @""];
        CLLocationCoordinate2D updatedCoordinate;
        if (![self parseCoordinateSearchText:coordinateText coordinate:&updatedCoordinate]) {
            [self showToast:@"الإحداثيات غير صحيحة؛ تحقق من خط العرض والطول ❌"];
            return;
        }
        WolFoxProLocation *updated = [location copy];
        NSString *updatedName = [alert.textFields[0].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        updated.name = updatedName.length ? updatedName : @"موقع محفوظ";
        CLLocationCoordinate2D previousCoordinate = location.coordinate;
        updated.coordinate = updatedCoordinate;
        if (![store updateLocation:updated]) {
            [self showToast:@"تعذر حفظ التعديل ❌"];
            return;
        }
        BOOL editingActiveCoordinate = store.spoofActive &&
            fabs(store.currentFakeCoords.latitude - previousCoordinate.latitude) < 0.000001 &&
            fabs(store.currentFakeCoords.longitude - previousCoordinate.longitude) < 0.000001;
        if (editingActiveCoordinate) {
            store.currentFakeCoords = updatedCoordinate;
            [store saveSettings];
            [self updateMapPin:updatedCoordinate];
            [[WolFoxProHookManager shared] deliverFakeUpdate];
        }
        [self hidePopup];
        [self showToast:@"✅ تم تحديث الموقع المحفوظ"];
        if (self->_activePage == 0) [self switchPage:0];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)deleteFav:(UIButton *)b {
    NSNumber *locID = objc_getAssociatedObject(b, "loc_id");
    if (!locID) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"حذف الموقع المحفوظ؟" message:@"سيُحذف هذا الموقع من المفضلة نهائياً." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"حذف" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [[WolFoxProStore shared] deleteLocationID:[locID longLongValue]];
        [self hidePopup];
        [self showToast:@"✅ تم حذف الموقع من المفضلة"];
        if (self->_activePage == 0) [self switchPage:0];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}


- (void)showLocationProfiles {
    NSArray<WolFoxLocationProfile *> *profiles = [WolFoxProStore shared].locationProfiles;
    [self showPopupWithTitle:@"ملفات المواقع السريعة" icon:@"slider.horizontal.3" content:^{
        CGFloat contentHeight = MIN(62.0 + MAX(1.0, (CGFloat)profiles.count) * 76.0, 430.0);
        UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 300, contentHeight)];
        scroll.alwaysBounceVertical = profiles.count > 4;

        UIButton *save = [UIButton buttonWithType:UIButtonTypeSystem];
        save.frame = CGRectMake(10, 8, 280, 44);
        save.backgroundColor = [[WolFoxProTheme gold] colorWithAlphaComponent:0.14];
        save.layer.cornerRadius = 12;
        [save setTitle:@"حفظ الإعداد الحالي كملف" forState:UIControlStateNormal];
        [save setTitleColor:[WolFoxProTheme gold] forState:UIControlStateNormal];
        save.titleLabel.font = [WolFoxProTheme fontOfSize:13 weight:UIFontWeightBold];
        if (@available(iOS 13.0, *)) [save setImage:[UIImage systemImageNamed:@"plus.circle.fill"] forState:UIControlStateNormal];
        save.tintColor = [WolFoxProTheme gold];
        [save addTarget:self action:@selector(saveCurrentLocationProfile) forControlEvents:UIControlEventTouchUpInside];
        save.accessibilityLabel = @"حفظ الإحداثية والسرعة والحركة والفاصل الزمني";
        [scroll addSubview:save];

        CGFloat y = 60.0;
        if (profiles.count == 0) {
            UILabel *empty = [[UILabel alloc] initWithFrame:CGRectMake(16, y + 8, 268, 44)];
            empty.text = @"لا توجد ملفات بعد\nاضغط حفظ الإعداد الحالي للبدء";
            empty.numberOfLines = 2;
            empty.textAlignment = NSTextAlignmentCenter;
            empty.textColor = [WolFoxProTheme textSecondary];
            empty.font = [WolFoxProTheme fontOfSize:12 weight:UIFontWeightSemibold];
            [scroll addSubview:empty];
            y += 70.0;
        }

        for (WolFoxLocationProfile *profile in profiles) {
            UIView *row = [[UIView alloc] initWithFrame:CGRectMake(10, y, 280, 68)];
            row.backgroundColor = [WolFoxProTheme surfaceSecondary];
            row.layer.cornerRadius = 12;
            [scroll addSubview:row];

            UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(46, 5, 222, 20)];
            name.text = profile.name;
            name.textAlignment = NSTextAlignmentRight;
            name.textColor = [WolFoxProTheme textPrimary];
            name.font = [WolFoxProTheme fontOfSize:13 weight:UIFontWeightBold];
            [row addSubview:name];

            UILabel *coords = [[UILabel alloc] initWithFrame:CGRectMake(46, 25, 222, 16)];
            coords.text = [NSString stringWithFormat:@"%.5f, %.5f", profile.coordinate.latitude, profile.coordinate.longitude];
            coords.textAlignment = NSTextAlignmentRight;
            coords.textColor = [WolFoxProTheme textSecondary];
            coords.font = [WolFoxProTheme fontOfSize:10 weight:UIFontWeightMedium];
            [row addSubview:coords];

            UILabel *details = [[UILabel alloc] initWithFrame:CGRectMake(46, 43, 222, 17)];
            details.text = [NSString stringWithFormat:@"%.0f كم/س • %.2f ث • حركة %@", profile.speed, profile.updateIntervalSeconds, profile.jitterEnabled ? @"مفعلة" : @"متوقفة"];
            details.textAlignment = NSTextAlignmentRight;
            details.textColor = [WolFoxProTheme accent];
            details.font = [WolFoxProTheme fontOfSize:9 weight:UIFontWeightSemibold];
            [row addSubview:details];

            UIButton *apply = [UIButton buttonWithType:UIButtonTypeCustom];
            apply.frame = CGRectMake(42, 0, 238, 68);
            objc_setAssociatedObject(apply, "profile_id", profile.profileID, OBJC_ASSOCIATION_COPY_NONATOMIC);
            [apply addTarget:self action:@selector(locationProfileSelected:) forControlEvents:UIControlEventTouchUpInside];
            apply.accessibilityLabel = [NSString stringWithFormat:@"تطبيق ملف %@", profile.name ?: @"الموقع"];
            [row addSubview:apply];

            UIButton *deleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
            deleteButton.frame = CGRectMake(3, 12, 40, 44);
            if (@available(iOS 13.0, *)) [deleteButton setImage:[UIImage systemImageNamed:@"trash"] forState:UIControlStateNormal];
            deleteButton.tintColor = [WolFoxProTheme danger];
            objc_setAssociatedObject(deleteButton, "profile_id", profile.profileID, OBJC_ASSOCIATION_COPY_NONATOMIC);
            [deleteButton addTarget:self action:@selector(deleteLocationProfile:) forControlEvents:UIControlEventTouchUpInside];
            deleteButton.accessibilityLabel = [NSString stringWithFormat:@"حذف ملف %@", profile.name ?: @"الموقع"];
            [row addSubview:deleteButton];
            y += 76.0;
        }
        scroll.contentSize = CGSizeMake(300, y);
        return scroll;
    } btnTitle:@"إغلاق" btnColor:[WolFoxProTheme accent]];
}

- (void)saveCurrentLocationProfile {
    WolFoxProStore *store = [WolFoxProStore shared];
    if (!CLLocationCoordinate2DIsValid(store.currentFakeCoords)) {
        [self showToast:@"حدد إحداثية صالحة أولاً"];
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"حفظ ملف موقع سريع"
                                                                   message:@"سيُحفظ الموقع والسرعة والفاصل الزمني وحالة الحركة."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"اسم الملف";
        field.text = [NSString stringWithFormat:@"موقع %.3f, %.3f", store.currentFakeCoords.latitude, store.currentFakeCoords.longitude];
        field.textAlignment = NSTextAlignmentRight;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"حفظ" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *name = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        WolFoxLocationProfile *profile = [WolFoxLocationProfile new];
        profile.name = name.length ? name : @"ملف موقع";
        profile.coordinate = store.currentFakeCoords;
        profile.speed = store.simSpeed;
        profile.updateIntervalSeconds = store.updateIntervalSeconds;
        profile.jitterEnabled = store.jitterActive;
        [store saveLocationProfile:profile];
        [self hidePopup];
        if (self->_activePage == 0) [self switchPage:0];
        [self showToast:@"تم حفظ ملف الموقع السريع ✅"];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)locationProfileSelected:(UIButton *)button {
    NSString *profileID = objc_getAssociatedObject(button, "profile_id");
    WolFoxLocationProfile *selected = nil;
    for (WolFoxLocationProfile *profile in [WolFoxProStore shared].locationProfiles) {
        if ([profile.profileID isEqualToString:profileID]) { selected = profile; break; }
    }
    if (!selected || !CLLocationCoordinate2DIsValid(selected.coordinate)) {
        [self showToast:@"تعذر تطبيق ملف الموقع ❌"];
        return;
    }

    WolFoxProStore *store = [WolFoxProStore shared];
    if (store.routeActive) {
        [[WolFoxProHookManager shared] stopRoute];
        UIButton *routeButton = objc_getAssociatedObject(self, "_route_btn");
        [routeButton setTitle:@"بدء محاكاة المسار" forState:UIControlStateNormal];
        routeButton.backgroundColor = [WolFoxProTheme accent];
    }
    store.currentFakeCoords = selected.coordinate;
    store.simSpeed = MAX(1.0, MIN(120.0, selected.speed));
    store.updateIntervalSeconds = WFClampGPSUpdateInterval(selected.updateIntervalSeconds);
    store.jitterActive = selected.jitterEnabled;
    store.spoofActive = YES;
    [store saveSettings];
    [store recordLocationHistoryWithName:selected.name coordinate:selected.coordinate];
    [self updateMapPin:selected.coordinate];
    [[WolFoxProHookManager shared] deliverFakeUpdate];
    [self centerMapOnPin];
    [self refreshSpoofHeaderStatus];
    [self hidePopup];
    if (self->_activePage == 0) [self switchPage:0];
    [self showToast:@"تم تطبيق ملف الموقع وتشغيل التزييف ✅"];
}

- (void)deleteLocationProfile:(UIButton *)button {
    NSString *profileID = objc_getAssociatedObject(button, "profile_id");
    if (!profileID.length) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"حذف ملف الموقع؟"
                                                                   message:@"سيُحذف الملف فقط ولن تتغير حالة الموقع الحالية."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"حذف" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [[WolFoxProStore shared] deleteLocationProfileID:profileID];
        [self hidePopup];
        if (self->_activePage == 0) [self switchPage:0];
        [self showToast:@"تم حذف ملف الموقع"];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showLocationHistory {
    NSArray<WolFoxLocationHistoryEntry *> *entries = [WolFoxProStore shared].locationHistory;
    if (entries.count == 0) {
        [self showToast:@"سجل المواقع فارغ"];
        return;
    }
    [self showPopupWithTitle:@"سجل المواقع" icon:@"clock.arrow.circlepath" content:^{
        CGFloat contentHeight = MIN(62.0 + (CGFloat)entries.count * 66.0, 430.0);
        UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 300, contentHeight)];
        scroll.alwaysBounceVertical = YES;

        UIButton *clear = [UIButton buttonWithType:UIButtonTypeSystem];
        clear.frame = CGRectMake(10, 8, 280, 42);
        clear.backgroundColor = [[WolFoxProTheme danger] colorWithAlphaComponent:0.12];
        clear.layer.cornerRadius = 12;
        [clear setTitle:@"مسح سجل المواقع" forState:UIControlStateNormal];
        [clear setTitleColor:[WolFoxProTheme danger] forState:UIControlStateNormal];
        clear.titleLabel.font = [WolFoxProTheme fontOfSize:13 weight:UIFontWeightBold];
        if (@available(iOS 13.0, *)) [clear setImage:[UIImage systemImageNamed:@"trash"] forState:UIControlStateNormal];
        clear.tintColor = [WolFoxProTheme danger];
        [clear addTarget:self action:@selector(clearLocationHistoryPressed) forControlEvents:UIControlEventTouchUpInside];
        [scroll addSubview:clear];

        NSDateFormatter *formatter = [NSDateFormatter new];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"ar_SA"];
        formatter.dateFormat = @"dd MMM، HH:mm";
        CGFloat y = 60.0;
        for (NSUInteger index = 0; index < entries.count; index++) {
            WolFoxLocationHistoryEntry *entry = entries[index];
            UIView *row = [[UIView alloc] initWithFrame:CGRectMake(10, y, 280, 58)];
            row.backgroundColor = [WolFoxProTheme surfaceSecondary];
            row.layer.cornerRadius = 12;
            [scroll addSubview:row];

            UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(42, 4, 226, 20)];
            nameLabel.text = entry.name;
            nameLabel.textColor = [WolFoxProTheme textPrimary];
            nameLabel.textAlignment = NSTextAlignmentRight;
            nameLabel.font = [WolFoxProTheme fontOfSize:13 weight:UIFontWeightBold];
            [row addSubview:nameLabel];

            UILabel *coordinateLabel = [[UILabel alloc] initWithFrame:CGRectMake(42, 23, 226, 16)];
            coordinateLabel.text = [NSString stringWithFormat:@"%.6f, %.6f", entry.coordinate.latitude, entry.coordinate.longitude];
            coordinateLabel.textColor = [WolFoxProTheme textSecondary];
            coordinateLabel.textAlignment = NSTextAlignmentRight;
            coordinateLabel.font = [WolFoxProTheme fontOfSize:10 weight:UIFontWeightMedium];
            [row addSubview:coordinateLabel];

            UILabel *dateLabel = [[UILabel alloc] initWithFrame:CGRectMake(42, 39, 226, 15)];
            dateLabel.text = [formatter stringFromDate:entry.usedAt ?: [NSDate date]];
            dateLabel.textColor = [WolFoxProTheme accent];
            dateLabel.textAlignment = NSTextAlignmentRight;
            dateLabel.font = [WolFoxProTheme fontOfSize:9 weight:UIFontWeightSemibold];
            [row addSubview:dateLabel];

            UIImageView *arrow = [[UIImageView alloc] initWithFrame:CGRectMake(12, 19, 20, 20)];
            if (@available(iOS 13.0, *)) arrow.image = [UIImage systemImageNamed:@"arrow.counterclockwise.circle.fill"];
            arrow.tintColor = [WolFoxProTheme accent];
            arrow.contentMode = UIViewContentModeScaleAspectFit;
            [row addSubview:arrow];

            UIButton *select = [UIButton buttonWithType:UIButtonTypeCustom];
            select.frame = row.bounds;
            select.tag = index;
            [select addTarget:self action:@selector(historySelected:) forControlEvents:UIControlEventTouchUpInside];
            select.accessibilityLabel = [NSString stringWithFormat:@"إعادة تفعيل %@", entry.name ?: @"الموقع"];
            [row addSubview:select];
            y += 66.0;
        }
        scroll.contentSize = CGSizeMake(300, y);
        return scroll;
    } btnTitle:@"إغلاق" btnColor:[WolFoxProTheme accent]];
}

- (void)historySelected:(UIButton *)button {
    NSArray<WolFoxLocationHistoryEntry *> *entries = [WolFoxProStore shared].locationHistory;
    if (button.tag < 0 || (NSUInteger)button.tag >= entries.count) return;
    WolFoxLocationHistoryEntry *entry = entries[button.tag];
    WolFoxProStore *store = [WolFoxProStore shared];
    if (store.routeActive) [[WolFoxProHookManager shared] stopRoute];
    store.currentFakeCoords = entry.coordinate;
    store.spoofActive = YES;
    [store saveSettings];
    [store recordLocationHistoryWithName:entry.name coordinate:entry.coordinate];
    [self updateMapPin:entry.coordinate];
    [[WolFoxProHookManager shared] deliverFakeUpdate];
    [self centerMapOnPin];
    [self refreshSpoofHeaderStatus];
    [self hidePopup];
    [self showToast:@"تمت إعادة تفعيل الموقع من السجل ✅"];
}

- (void)clearLocationHistoryPressed {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"مسح سجل المواقع؟" message:@"لن تُحذف المواقع المحفوظة في المفضلة." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"مسح" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [[WolFoxProStore shared] clearLocationHistory];
        [self hidePopup];
        [self showToast:@"تم مسح سجل المواقع"];
        if (self->_activePage == 0) [self switchPage:0];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showPopupWithTitle:(NSString *)title icon:(NSString *)iconName content:(UIView *(^)(void))contentBlock btnTitle:(NSString *)bt btnColor:(UIColor *)bc {
    [self hidePopup];
    UIView *overlay = [[UIView alloc] initWithFrame:self.view.bounds];
    overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.78]; overlay.tag = 999;
    [self.view addSubview:overlay];
    CGFloat pw = MIN(340.0, self.view.bounds.size.width - 32.0);
    UIView *content = contentBlock();
    CGFloat safeTop = self.view.safeAreaInsets.top;
    CGFloat safeBottom = self.view.safeAreaInsets.bottom;
    CGFloat maxHeight = self.view.bounds.size.height - safeTop - safeBottom - 32.0;
    CGFloat desiredHeight = 135.0 + content.frame.size.height + 90.0;
    CGFloat cardHeight = MIN(maxHeight, desiredHeight);
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake((self.view.bounds.size.width-pw)/2, safeTop + (maxHeight-cardHeight)/2.0 + 16.0, pw, cardHeight)];
    card.backgroundColor = [WolFoxProTheme royalCard]; card.layer.cornerRadius = 24; card.clipsToBounds = YES;
    card.layer.borderWidth = 1.0; card.layer.borderColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.28].CGColor;
    card.layer.shadowColor = [UIColor blackColor].CGColor; card.layer.shadowOpacity = 0.35; card.layer.shadowRadius = 20; card.layer.shadowOffset = CGSizeMake(0, 10);
    [overlay addSubview:card];
    UIImageView *topIcon = [[UIImageView alloc] initWithFrame:CGRectMake((pw-60)/2, 25, 60, 60)];
    if (@available(iOS 13.0, *)) topIcon.image = [UIImage systemImageNamed:iconName];
    topIcon.tintColor = [WolFoxProTheme accent]; topIcon.contentMode = UIViewContentModeScaleAspectFit;
    [card addSubview:topIcon];
    UILabel *tl = [[UILabel alloc] initWithFrame:CGRectMake(0, 95, pw, 30)];
    tl.text = title; tl.textColor = [WolFoxProTheme textPrimary]; tl.font = [WolFoxProTheme fontOfSize:20 weight:UIFontWeightBold]; tl.textAlignment = NSTextAlignmentCenter;
    [card addSubview:tl];
    UIScrollView *contentScroll = [[UIScrollView alloc] initWithFrame:CGRectMake(12, 130, pw - 24, cardHeight - 204)];
    contentScroll.alwaysBounceVertical = content.frame.size.height > contentScroll.bounds.size.height;
    content.frame = CGRectMake(0, 0, contentScroll.bounds.size.width, content.frame.size.height);
    contentScroll.contentSize = CGSizeMake(contentScroll.bounds.size.width, content.frame.size.height);
    [contentScroll addSubview:content];
    [card addSubview:contentScroll];
    UIButton *ok = [UIButton buttonWithType:UIButtonTypeSystem];
    ok.frame = CGRectMake(20, cardHeight - 64, pw - 40, 48);
    ok.backgroundColor = bc; ok.layer.cornerRadius = 15;
    [ok setTitle:bt forState:UIControlStateNormal]; [ok setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    ok.titleLabel.font = [WolFoxProTheme fontOfSize:17 weight:UIFontWeightBold];
    [ok addTarget:self action:@selector(hidePopup) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:ok];
}

- (void)hidePopup { [[self.view viewWithTag:999] removeFromSuperview]; }

- (void)updateRealLocationNotice:(NSString *)text available:(BOOL)available {
    if (!_realLocationNoticeLabel || !_realLocationNoticeIcon) return;
    UIColor *color = available ? [WolFoxProTheme success] : [WolFoxProTheme accent];
    _realLocationNoticeLabel.text = text;
    _realLocationNoticeLabel.textColor = color;
    if (@available(iOS 13.0, *)) _realLocationNoticeIcon.image = [UIImage systemImageNamed:(available ? @"checkmark.circle.fill" : @"location.circle.fill")];
    _realLocationNoticeIcon.tintColor = color;
    UIView *notice = _realLocationNoticeLabel.superview;
    notice.backgroundColor = [color colorWithAlphaComponent:0.12];
    notice.layer.borderColor = [color colorWithAlphaComponent:0.50].CGColor;
    [notice.layer setNeedsDisplay];
}

- (void)refreshLocationModeNotice {
    if (!_realLocationNoticeLabel) return;
    WolFoxProStore *store = [WolFoxProStore shared];
    if (store.spoofActive) {
        [self updateRealLocationNotice:@"الموقع المزيّف: مفعّل" available:NO];
        return;
    }
    BOOL hasRealLocation = [WolFoxProHookManager shared].lastRealLocation != nil;
    [self updateRealLocationNotice:(hasRealLocation ? @"الموقع الحقيقي: مفعّل" : @"الموقع الحقيقي: بانتظار التحديث") available:hasRealLocation];
}

- (void)showToast:(NSString *)text {
    NSString *title = @"WolFox";
    UIColor *stateColor = [WolFoxProTheme accent];
    NSString *stateIcon = @"info.circle.fill";
    if ([text containsString:@"موقعك الحقيقي"]) {
        title = @"الموقع الحقيقي";
        stateColor = [WolFoxProTheme success];
        stateIcon = @"checkmark.circle.fill";
    } else if ([text containsString:@"✅"] || [text containsString:@"تشغيل"] || [text containsString:@"تم التفعيل"] || [text containsString:@"تم الحفظ"] || [text containsString:@"تم تطبيق"]) {
        title = @"تم بنجاح";
        stateColor = [WolFoxProTheme success];
        stateIcon = [text containsString:@"تفعيل"] ? @"iphone.circle.fill" : @"checkmark.circle.fill";
    } else if ([text containsString:@"⚠"] || [text containsString:@"❌"] || [text containsString:@"إيقاف"] || [text containsString:@"توقفت"] || [text containsString:@"حذف"] || [text containsString:@"تعذر"] || [text containsString:@"خطأ"] || [text containsString:@"غير صحيحة"]) {
        title = @"تنبيه";
        stateColor = [WolFoxProTheme danger];
        stateIcon = @"exclamationmark.triangle.fill";
    }

    NSString *displayText = text ?: @"";
    for (NSString *emoji in @[@"✅", @"❌", @"⚠️", @"⚠︎", @"📍", @"🔄", @"📋", @"📤", @"⏳", @"🔵", @"🛑", @"🚶‍♂️", @"⚡", @"🔍"]) {
        displayText = [displayText stringByReplacingOccurrencesOfString:emoji withString:@""];
    }
    displayText = [displayText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *dedupeKey = [NSString stringWithFormat:@"%@|%@", title, displayText];
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    if ([_lastToastKey isEqualToString:dedupeKey] && now - _lastToastTime < 3.0) return;
    _lastToastKey = dedupeKey;
    _lastToastTime = now;
    [[self.view viewWithTag:998] removeFromSuperview];
    CGFloat width = self.view.bounds.size.width - 32;
    CGFloat top = MAX(CGRectGetMaxY(_tabsBar.frame) + 12.0, self.view.safeAreaInsets.top + 104.0);
    UIView *tv = [[UIView alloc] initWithFrame:CGRectMake(16, top, width, 64)];
    tv.tag = 998;
    tv.backgroundColor = [[WolFoxProTheme surfacePrimary] colorWithAlphaComponent:0.96]; tv.layer.cornerRadius = 18; tv.layer.borderWidth = 1; tv.layer.borderColor = [stateColor colorWithAlphaComponent:0.82].CGColor; tv.alpha = 0;
    tv.layer.shadowColor = [UIColor blackColor].CGColor; tv.layer.shadowOpacity = 0.30; tv.layer.shadowRadius = 10; tv.layer.shadowOffset = CGSizeMake(0, 5);
    UIView *accentRail = [[UIView alloc] initWithFrame:CGRectMake(width - 6, 10, 3, 44)];
    accentRail.backgroundColor = stateColor;
    accentRail.layer.cornerRadius = 1.5;
    [tv addSubview:accentRail];
    UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectMake(width - 49, 17, 28, 28)];
    if (@available(iOS 13.0, *)) icon.image = [UIImage systemImageNamed:stateIcon];
    icon.tintColor = stateColor; icon.contentMode = UIViewContentModeScaleAspectFit;
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 8, width - 76, 20)];
    titleLabel.text = title; titleLabel.textColor = stateColor; titleLabel.font = [WolFoxProTheme fontOfSize:13 weight:UIFontWeightBlack]; titleLabel.textAlignment = NSTextAlignmentRight;
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(16, 27, width - 76, 28)]; l.text = displayText; l.textColor = [WolFoxProTheme textPrimary]; l.font = [WolFoxProTheme fontOfSize:15 weight:UIFontWeightBold]; l.textAlignment = NSTextAlignmentRight; l.lineBreakMode = NSLineBreakByTruncatingTail;
    [tv addSubview:icon];
    [tv addSubview:titleLabel]; [tv addSubview:l]; [self.view addSubview:tv];
    tv.isAccessibilityElement = YES;
    tv.accessibilityLabel = [NSString stringWithFormat:@"%@، %@", title, displayText];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, tv.accessibilityLabel);
    tv.transform = CGAffineTransformMakeTranslation(0, -10);
    [UIView animateWithDuration:[WolFoxProTheme transitionDuration] delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{ tv.alpha = 1.0; tv.transform = CGAffineTransformIdentity; } completion:^(BOOL f) {
        [UIView animateWithDuration:[WolFoxProTheme transitionDuration] delay:2.50 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseIn animations:^{ tv.alpha = 0; tv.transform = CGAffineTransformMakeTranslation(0, -8); } completion:^(BOOL f2) { [tv removeFromSuperview]; }];
    }];
}

@end

@implementation WolFoxController
+ (instancetype)shared { static WolFoxController *s=nil; static dispatch_once_t o; dispatch_once(&o,^{s=[WolFoxController new];}); return s; }
- (instancetype)init { 
    if(self=[super init]){
#ifdef DEBUG
        WFLog(@"[WolFox][UI] controller_init");
#endif
        [self setupUI];
        [self setupVolumeObserver];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(licenseStateChanged:) name:@"WF_LICENSE_STATE_CHANGED" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(scheduleStateChanged:) name:@"WF_SCHEDULE_STATE_CHANGED" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(scheduleLocationMissing:) name:@"WF_SCHEDULE_LOCATION_MISSING" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(virtualCameraStateChangedForController:) name:WFVirtualCameraStateDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(virtualCameraImageSelectedForController:) name:WFVirtualCameraImageDidSelectNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(spoofStateChangedForController:) name:WFSpoofStateDidChangeNotification object:nil];
        [[WFSpoofScheduleManager shared] start];
    } 
    return self; 
}

- (void)dealloc {
    @try {
        if (self.volumeSession) {
            [self.volumeSession removeObserver:self forKeyPath:@"outputVolume" context:NULL];
        }
    } @catch (__unused NSException *exception) {
        // KVO قد لا يكون مسجلاً إذا فشل setupUI
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [WFLicenseClient stopHeartbeat]; // _WFHeartbeatTimer محدد في WFLicenseClient.m فقط
}

- (void)spoofStateChangedForController:(__unused NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshFloatingStatusIcon];
        [self refreshSpoofQuickPanel];
        [self.mainVC refreshSpoofHeaderStatus];
    });
}

- (void)scheduleStateChanged:(__unused NSNotification *)notification {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.mainVC) return;
        [strongSelf.mainVC refreshSpoofHeaderStatus];
        [strongSelf.mainVC refreshSpoofSchedulePage];
    });
}

- (void)scheduleLocationMissing:(__unused NSNotification *)notification {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.mainVC) return;
        [strongSelf.mainVC showScheduleLocationMissingNotice];
    });
}

- (void)virtualCameraSessionStarted:(__unused NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *host = self.previousKeyWindow;
        if (!host || host == self.overlayWindow || host.hidden) host = [self hostKeyWindow];
        if (!host || host == self.overlayWindow) return;
        if (self.virtualCameraGestureHostWindow == host && self.virtualCameraLongPressGesture.view == host) return;
        if (self.virtualCameraLongPressGesture.view) {
            [self.virtualCameraLongPressGesture.view removeGestureRecognizer:self.virtualCameraLongPressGesture];
        }
        self.virtualCameraLongPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                           action:@selector(handleVirtualCameraLongPress:)];
        self.virtualCameraLongPressGesture.minimumPressDuration = 0.8;
        self.virtualCameraLongPressGesture.cancelsTouchesInView = NO;
        self.virtualCameraLongPressGesture.delegate = self;
        [host addGestureRecognizer:self.virtualCameraLongPressGesture];
        self.virtualCameraGestureHostWindow = host;
#ifdef DEBUG
        WFLog(@"[WolFox][CAM] center_long_press_ready");
#endif
    });
}

- (void)prepareVirtualCameraLongPress {
    [self virtualCameraSessionStarted:nil];
}

- (void)handleVirtualCameraLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    UIView *host = gesture.view;
    if (!host) return;
    CGPoint point = [gesture locationInView:host];
    CGRect bounds = host.bounds;
    CGRect centerArea = CGRectInset(bounds, CGRectGetWidth(bounds) * 0.25, CGRectGetHeight(bounds) * 0.25);
    if (!CGRectContainsPoint(centerArea, point)) return;
    if (![WFLicenseClient isRuntimeLicenseValid]) {
        [self showActivationScreenWithResult:[WFLicenseClient lastLicenseResult]];
        return;
    }
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback impactOccurred];
    // نبقي مساحة ومدة التعليق كما هي، ونُظهر زر الاستديو فقط بلا لوحة وسيطة.
    [self toggleCameraIcon:YES];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
        shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return gestureRecognizer == self.virtualCameraLongPressGesture ||
           otherGestureRecognizer == self.virtualCameraLongPressGesture;
}

- (void)virtualCameraStateChangedForController:(__unused NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshFloatingControlPanel];
        BOOL shouldRestoreIcon = self.reopenCameraIconAfterPicker || [WFVirtualCameraManager shared].enabled;
        self.reopenCameraIconAfterPicker = NO;
        if (shouldRestoreIcon && [WFLicenseClient isRuntimeLicenseValid]) [self toggleCameraIcon:YES];
    });
}

- (void)virtualCameraImageSelectedForController:(__unused NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.reopenCameraIconAfterPicker = NO;
        [self prepareCleanVirtualPhotoCapture];
    });
}

- (void)licenseStateChanged:(NSNotification *)notification {
    WFLicenseResult *result = [notification.object isKindOfClass:WFLicenseResult.class] ? notification.object : nil;
    __weak typeof(self) weakSelf = self;
    if (result.success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf.mainVC scheduleExpiryReminderIfEnabled:result];
            [strongSelf.mainVC refreshSpoofHeaderStatus];
            if ([WolFoxProStore shared].spoofActive) {
                [[WolFoxProHookManager shared] deliverFakeUpdate];
#ifdef DEBUG
                WFLog(@"[WolFox][GPS] license_ready_fake_update_delivered");
#endif
            }
        });
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [[WolFoxProHookManager shared] stopRoute];
        [WFVirtualCameraManager shared].enabled = NO;
        [WolFoxProStore shared].spoofActive = NO;
        [WolFoxProStore shared].scheduleApplied = NO;
        [[WolFoxProStore shared] saveSettings];
        [strongSelf.mainVC refreshSpoofHeaderStatus];
        [strongSelf toggleCameraIcon:NO];
        [strongSelf closeFloatingControlPanel:nil];
        strongSelf.mainVC.view.hidden = YES;
        strongSelf.mainVC.view.alpha = 0;
        if ([[NSUserDefaults standardUserDefaults] boolForKey:WFUIHiddenOnLaunchKey]) {
            strongSelf.overlayWindow.hidden = YES;
            [strongSelf restoreHostKeyWindow];
            [strongSelf prepareHiddenVolumeListening];
#ifdef DEBUG
            WFLog(@"[WolFox][LICENSE] invalid_while_hidden_waiting_for_volume_request");
#endif
            return;
        }
        [strongSelf showActivationScreenWithResult:result];
    });
}

- (void)setupVolumeObserver {
    self.volumeSession = [AVAudioSession sharedInstance];
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(systemVolumeDidChange:) name:@"AVSystemController_SystemVolumeDidChangeNotification" object:nil];
    [center addObserver:self selector:@selector(applicationBecameActiveForVolume:) name:UIApplicationDidBecomeActiveNotification object:nil];
    @try {
        [self.volumeSession addObserver:self forKeyPath:@"outputVolume" options:NSKeyValueObservingOptionNew context:NULL];
#ifdef DEBUG
        WFLog(@"[WolFox][UI] volume_kvo_ready");
#endif
    } @catch (NSException *exception) {
#ifdef DEBUG
        WFLog(@"[WolFox][UI] volume_kvo_unavailable=%@", exception.name);
#endif
    }
    [self prepareHiddenVolumeListening];
}

- (void)prepareHiddenVolumeListening {
    if (![WolFoxProStore shared].volumeGestureEnabled || !self.volumeSession) return;
    NSError *error = nil;
    BOOL active = [self.volumeSession setActive:YES error:&error];
#ifndef DEBUG
    (void)active;
#endif
#ifdef DEBUG
    if (active) WFLog(@"[WolFox][UI] hidden_volume_listener_active");
#endif
#ifdef DEBUG
    else WFLog(@"[WolFox][UI] hidden_volume_listener_activation_failed=%@", error.localizedDescription ?: @"unknown");
#endif
}

- (void)applicationBecameActiveForVolume:(NSNotification *)notification {
    (void)notification;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:WFUIHiddenOnLaunchKey] || self.mainVC.view.hidden) {
        [self prepareHiddenVolumeListening];
    }
}

- (void)systemVolumeDidChange:(NSNotification *)notification {
    if (![WolFoxProStore shared].volumeGestureEnabled) return;
    NSString *reason = [notification.userInfo[@"AVSystemController_AudioVolumeChangeReasonNotificationParameter"] description];
    if (reason.length && [reason rangeOfString:@"explicit" options:NSCaseInsensitiveSearch].location == NSNotFound) return;

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSTimeInterval now = NSDate.timeIntervalSinceReferenceDate;
        if (now - strongSelf.lastSystemVolumeNotificationTime < 0.08) return;
        strongSelf.lastSystemVolumeNotificationTime = now;
        [strongSelf recordVolumeButtonPress];
    });
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"outputVolume"] && object == self.volumeSession) {
        [self handleVolumeGesturePulse];
        return;
    }
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)handleVolumeGesturePulse {
    if (![WolFoxProStore shared].volumeGestureEnabled) return;
    NSTimeInterval candidateTime = NSDate.timeIntervalSinceReferenceDate;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.18 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || ![WolFoxProStore shared].volumeGestureEnabled) return;
        if (strongSelf.lastSystemVolumeNotificationTime >= candidateTime - 0.03) return;
        NSTimeInterval now = NSDate.timeIntervalSinceReferenceDate;
        if (now - strongSelf.lastFallbackVolumePulseTime < 0.18) return;
        strongSelf.lastFallbackVolumePulseTime = now;
        [strongSelf recordVolumeButtonPress];
    });
}

- (void)recordVolumeButtonPress {
    if (![NSThread isMainThread]) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf recordVolumeButtonPress]; });
        return;
    }
    if (![WolFoxProStore shared].volumeGestureEnabled) return;
    NSTimeInterval now = NSDate.timeIntervalSinceReferenceDate;
    if (now - self.lastVolumePulseTime > 1.50) self.volumePulseCount = 0;
    self.lastVolumePulseTime = now;
    self.volumePulseCount++;
    NSInteger requiredPresses = [[NSUserDefaults standardUserDefaults] integerForKey:@"WF_VOLUME_PRESS_COUNT"];
    if (requiredPresses != 2 && requiredPresses != 3 && requiredPresses != 5) requiredPresses = 3;
#ifdef DEBUG
    WFLog(@"[WolFox][UI] volume_request_progress=%ld/%ld", (long)MIN(self.volumePulseCount, requiredPresses), (long)requiredPresses);
#endif
    if (self.volumePulseCount >= requiredPresses && now - self.lastVolumeToggleTime > 0.85) {
        self.volumePulseCount = 0;
        self.lastVolumeToggleTime = now;
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [feedback impactOccurred];
#ifdef DEBUG
        WFLog(@"[WolFox][UI] volume_toggle_confirmed");
#endif
        [self toggleUI];
    }
}

- (UIWindow *)hostKeyWindow {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (window != self.overlayWindow && window.isKeyWindow) return window;
            }
        }
    }
    // UIApplication.windows مُهمل في iOS 15+ — نقرأ من كل UIWindowScene
    if (@available(iOS 15.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (window != self.overlayWindow && window.isKeyWindow) return window;
            }
        }
        return nil;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        if (window != self.overlayWindow && window.isKeyWindow) return window;
    }
#pragma clang diagnostic pop
    return nil;
}

- (void)makeOverlayKey {
    UIWindow *host = [self hostKeyWindow];
    if (host) self.previousKeyWindow = host;
    self.overlayWindow.hidden = NO;
    [self.overlayWindow makeKeyAndVisible];
}

- (void)restoreHostKeyWindow {
    UIWindow *host = self.previousKeyWindow ?: [self hostKeyWindow];
    if (host) [host makeKeyWindow];
}

- (void)setupUI {
#ifdef DEBUG
    WFLog(@"[WolFox][UI] setup_overlay_begin");
#endif
    UIWindowScene *activeScene = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) { activeScene = (UIWindowScene *)scene; break; }
        }
        if (!activeScene) { for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) { if ([scene isKindOfClass:[UIWindowScene class]]) { activeScene = (UIWindowScene *)scene; break; } } }
    }
    
    if (activeScene) {
        self.overlayWindow = [[WolFoxOverlayWindow alloc] initWithWindowScene:activeScene];
    } else {
        self.overlayWindow = [[WolFoxOverlayWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }
    
    self.overlayWindow.windowLevel = UIWindowLevelAlert + 2;
    self.overlayWindow.backgroundColor = [UIColor clearColor];
    self.overlayWindow.hidden = YES;
    
    self.mainVC = [WolFoxMainViewController new];
    self.overlayWindow.rootViewController = self.mainVC;
    
    // Persistent floating status shortcut. Its color is driven by the actual spoof state.
    self.floatingIcon = [UIButton buttonWithType:UIButtonTypeCustom];
    CGFloat iconSize = 56.0;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    CGFloat defaultX = self.overlayWindow.bounds.size.width - iconSize - 18.0;
    CGFloat defaultY = MAX(96.0, self.overlayWindow.safeAreaInsets.top + 72.0);
    CGFloat savedX = [defaults objectForKey:@"WF_FLOATING_STATUS_X"] ? [defaults doubleForKey:@"WF_FLOATING_STATUS_X"] : defaultX;
    CGFloat savedY = [defaults objectForKey:@"WF_FLOATING_STATUS_Y"] ? [defaults doubleForKey:@"WF_FLOATING_STATUS_Y"] : defaultY;
    self.floatingIcon.frame = CGRectMake(savedX, savedY, iconSize, iconSize);
    self.floatingIcon.layer.cornerRadius = iconSize * 0.5;
    self.floatingIcon.layer.borderWidth = 2.0;
    self.floatingIcon.layer.shadowColor = UIColor.blackColor.CGColor;
    self.floatingIcon.layer.shadowOpacity = 0.35;
    self.floatingIcon.layer.shadowOffset = CGSizeMake(0, 4);
    self.floatingIcon.layer.shadowRadius = 8.0;
    if (@available(iOS 13.0, *)) {
        [self.floatingIcon setImage:[UIImage systemImageNamed:@"location.fill"
                                            withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightBold]]
                           forState:UIControlStateNormal];
    }
    self.floatingIcon.tintColor = UIColor.whiteColor;
    self.floatingIcon.accessibilityHint = @"اضغط لفتح لوحة WolFox أو اسحب لتحريك العلامة";
    [self.floatingIcon addTarget:self action:@selector(handleFloatingStatusTap:) forControlEvents:UIControlEventTouchUpInside];
    [self.floatingIcon addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleFloatingStatusPan:)]];
    UILongPressGestureRecognizer *hidePress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleFloatingStatusLongPress:)];
    hidePress.minimumPressDuration = 0.85;
    [self.floatingIcon addGestureRecognizer:hidePress];
    [self.overlayWindow addSubview:self.floatingIcon];
    [self applyFloatingStatusPreferences];
    BOOL iconVisible = ![[NSUserDefaults standardUserDefaults] objectForKey:@"WF_FLOATING_STATUS_VISIBLE"] ||
                       [[NSUserDefaults standardUserDefaults] boolForKey:@"WF_FLOATING_STATUS_VISIBLE"];
    self.floatingIcon.hidden = !iconVisible;
    [self refreshFloatingStatusIcon];
    
    self.mainVC.view.hidden = YES;
#ifdef DEBUG
    WFLog(@"[WolFox][UI] overlay_ready main_hidden=1");
#endif
    
    // إظهار الواجهة بثلاث نقرات متتابعة بإصبع واحد داخل منتصف الشاشة
    UITapGestureRecognizer *tripleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleThreeSequentialTaps:)];
    tripleTap.numberOfTapsRequired = 3;
    tripleTap.numberOfTouchesRequired = 1;
    tripleTap.cancelsTouchesInView = NO;
    [self.overlayWindow addGestureRecognizer:tripleTap];

    // لا نستخدم مؤقتاً متكرراً لإبقاء النافذة مرئية؛ مسارات العرض المخصصة
    // هي الوحيدة التي تغيّر حالة النافذة، لتفادي مورد واجهة دائم بلا إلغاء.
}

- (void)handleThreeSequentialTaps:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateEnded) return;
    CGPoint point = [gesture locationInView:self.overlayWindow];
    CGRect bounds = self.overlayWindow.bounds;
    CGRect centerArea = CGRectInset(bounds, CGRectGetWidth(bounds) * 0.25, CGRectGetHeight(bounds) * 0.25);
    if (CGRectContainsPoint(centerArea, point)) {
        [self toggleUI];
    }
}
- (void)toggleUI {
#ifdef DEBUG
    WFLog(@"[WolFox][UI] toggle_requested verified=%d main_hidden=%d", [WFLicenseClient isRuntimeLicenseValid], self.mainVC.view.hidden);
#endif
    if (![WFLicenseClient isRuntimeLicenseValid]) {
        [self showActivationScreenWithResult:[WFLicenseClient lastLicenseResult]];
        return;
    }
    
    if (self.mainVC.view.hidden) [self showUI];
    else [self dismissUI];
}

- (void)showActivationScreen {
    [self showActivationScreenWithResult:[WFLicenseClient lastLicenseResult]];
}

- (void)showActivationScreenWithResult:(WFLicenseResult *)result {
    if (!self.mainVC) return;
    if (self.mainVC.presentedViewController) return; // already showing
#ifdef DEBUG
    WFLog(@"[WolFox][ACT] presenting_activation");
#endif

    WFActivationViewController *avc = [WFActivationViewController new];
    avc.modalPresentationStyle = UIModalPresentationOverFullScreen;
    avc.noticeMessage = result.message;
    avc.updateURL = result.updateURL;
    avc.completion = ^(BOOL success) {
#ifdef DEBUG
        WFLog(@"[WolFox][ACT] completion success=%d", success);
#endif
        if (success) {
            [self showUI];
        }
    };

    // Make window visible and present
    [self makeOverlayKey];

    // mainVC must be in window hierarchy
    self.mainVC.view.hidden = NO;
    self.mainVC.view.alpha = 0; // invisible but present

    [self.mainVC presentViewController:avc animated:YES completion:^{
        // Keep mainVC invisible after activation VC appears
        self.mainVC.view.alpha = 0;
    }];
}
- (void)showUI { 
#ifdef DEBUG
    WFLog(@"[WolFox][UI] show_main_requested");
#endif
    if (![WFLicenseClient isRuntimeLicenseValid]) {
#ifdef DEBUG
        WFLog(@"[WolFox][UI] blocked_without_activation");
#endif
        [self showActivationScreen];
        return;
    }
    // امسح الـ flag حتى يعود للوضع الطبيعي بعد الظهور الناجح.
    // dismissUI يضعه من جديد عند إغلاق الواجهة، وإعداد "إخفاء عند الفتح" يتحكم فيه.
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:WFUIHiddenOnLaunchKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self makeOverlayKey];
        [self.mainVC refreshSpoofHeaderStatus];
        self.mainVC.view.hidden = NO; 
    self.mainVC.view.alpha = 0; 
    if ([WolFoxProStore shared].mediaUploadActive) [self toggleCameraIcon:YES];
    [UIView animateWithDuration:[WolFoxProTheme transitionDuration] animations:^{
        self.mainVC.view.alpha = 1.0;
    } completion:^(__unused BOOL finished) {
#ifdef DEBUG
        WFLog(@"[WolFox][UI] main_visible");
#endif
        [self.mainVC presentOnboardingIfNeeded];
    }]; 
}
- (void)dismissUI { 
#ifdef DEBUG
    WFLog(@"[WolFox][UI] dismiss_main_requested");
#endif
    [self.mainVC closeExpandedMapIfNeeded];
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];
    [WolFoxProStore shared].volumeGestureEnabled = YES;
    [[WolFoxProStore shared] saveSettings];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:WFUIHiddenOnLaunchKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self prepareHiddenVolumeListening];
    [self closeFloatingControlPanel:nil];
    [self.cameraIcon.layer removeAllAnimations];
    self.cameraIcon.alpha = 0;
    self.cameraIcon.hidden = YES;
    [UIView animateWithDuration:[WolFoxProTheme transitionDuration] animations:^{
        self.mainVC.view.alpha = 0;
    } completion:^(BOOL f){
        self.mainVC.view.hidden = YES;
        self.overlayWindow.hidden = NO;
        [self refreshFloatingStatusIcon];
        [self restoreHostKeyWindow];
#ifdef DEBUG
        WFLog(@"[WolFox][UI] dismiss_confirmed_volume_hook_stays_active");
#endif
    }]; 
}

- (void)setFloatingStatusIconVisible:(BOOL)visible {
    [[NSUserDefaults standardUserDefaults] setBool:visible forKey:@"WF_FLOATING_STATUS_VISIBLE"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    self.floatingIcon.hidden = !visible;
    if (!visible) [self closeSpoofQuickPanel:nil];
    if (visible) {
        self.overlayWindow.hidden = NO;
        [self refreshFloatingStatusIcon];
        [self.overlayWindow bringSubviewToFront:self.floatingIcon];
    }
}

- (void)applyFloatingStatusPreferences {
    if (!self.floatingIcon) return;
    NSInteger index = [[NSUserDefaults standardUserDefaults] integerForKey:@"WF_FLOATING_STATUS_SIZE_INDEX"];
    CGFloat size = index == 0 ? 48.0 : (index == 2 ? 64.0 : 56.0);
    CGFloat opacity = [[NSUserDefaults standardUserDefaults] objectForKey:@"WF_FLOATING_STATUS_OPACITY"]
        ? [[NSUserDefaults standardUserDefaults] doubleForKey:@"WF_FLOATING_STATUS_OPACITY"] : 0.92;
    opacity = MIN(MAX(opacity, 0.45), 1.0);
    CGPoint center = self.floatingIcon.center;
    self.floatingIcon.bounds = CGRectMake(0, 0, size, size);
    self.floatingIcon.center = center;
    self.floatingIcon.layer.cornerRadius = size * 0.5;
    self.floatingIcon.alpha = opacity;
    [self handleFloatingStatusPan:nil];
}

- (void)resetFloatingStatusPosition {
    if (!self.floatingIcon) return;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"WF_FLOATING_STATUS_X"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"WF_FLOATING_STATUS_Y"];
    CGFloat size = CGRectGetWidth(self.floatingIcon.bounds);
    CGFloat x = self.overlayWindow.bounds.size.width - size * 0.5 - 18.0;
    CGFloat y = MAX(96.0, self.overlayWindow.safeAreaInsets.top + 72.0) + size * 0.5;
    self.floatingIcon.center = CGPointMake(x, y);
    [self.overlayWindow bringSubviewToFront:self.floatingIcon];
}

- (void)refreshFloatingStatusIcon {
    if (!self.floatingIcon) return;
    BOOL active = [WolFoxProStore shared].spoofActive && [WFLicenseClient isRuntimeLicenseValid];
    UIColor *color = active ? [WolFoxProTheme success] : [WolFoxProTheme danger];
    self.floatingIcon.backgroundColor = color;
    self.floatingIcon.layer.borderColor = [UIColor.whiteColor colorWithAlphaComponent:0.75].CGColor;
    self.floatingIcon.accessibilityLabel = active ? @"WolFox: تزييف الموقع مفعّل" : @"WolFox: تزييف الموقع متوقف";
}

- (void)handleFloatingStatusTap:(UIButton *)sender {
    [self toggleSpoofQuickPanel:sender];
}

- (void)handleFloatingStatusLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback impactOccurred];
    [self setFloatingStatusIconVisible:NO];
}

- (void)toggleSpoofQuickPanel:(UIButton *)sender {
    (void)sender;
    if (self.spoofQuickPanel && !self.spoofQuickPanel.hidden) {
        [self closeSpoofQuickPanel:nil];
        return;
    }
    if (![WFLicenseClient isRuntimeLicenseValid]) {
        [self showActivationScreenWithResult:[WFLicenseClient lastLicenseResult]];
        return;
    }

    if (!self.spoofQuickPanel) {
        CGFloat width = MIN(292.0, self.overlayWindow.bounds.size.width - 28.0);
        self.spoofQuickPanel = [[UIView alloc] initWithFrame:CGRectMake(14, 120, width, 242)];
        self.spoofQuickPanel.backgroundColor = [WolFoxProTheme surfacePrimary];
        self.spoofQuickPanel.layer.cornerRadius = 22.0;
        self.spoofQuickPanel.layer.borderWidth = 1.5;
        self.spoofQuickPanel.layer.borderColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.72].CGColor;
        self.spoofQuickPanel.layer.shadowColor = UIColor.blackColor.CGColor;
        self.spoofQuickPanel.layer.shadowOpacity = 0.42;
        self.spoofQuickPanel.layer.shadowRadius = 16.0;
        self.spoofQuickPanel.layer.shadowOffset = CGSizeMake(0, 8);

        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(48, 12, width - 62, 24)];
        title.text = @"تحكم WolFox السريع";
        title.textAlignment = NSTextAlignmentRight;
        title.textColor = [WolFoxProTheme textPrimary];
        title.font = [WolFoxProTheme fontOfSize:16 weight:UIFontWeightBlack];
        [self.spoofQuickPanel addSubview:title];

        UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
        close.frame = CGRectMake(8, 7, 36, 36);
        if (@available(iOS 13.0, *)) [close setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
        close.tintColor = [WolFoxProTheme textSecondary];
        close.accessibilityLabel = @"إغلاق التحكم السريع";
        [close addTarget:self action:@selector(closeSpoofQuickPanel:) forControlEvents:UIControlEventTouchUpInside];
        [self.spoofQuickPanel addSubview:close];

        self.spoofQuickStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 42, width - 28, 25)];
        self.spoofQuickStatusLabel.textAlignment = NSTextAlignmentCenter;
        self.spoofQuickStatusLabel.font = [WolFoxProTheme fontOfSize:13 weight:UIFontWeightBold];
        [self.spoofQuickPanel addSubview:self.spoofQuickStatusLabel];

        UIButton *(^quickButton)(NSString *, NSString *, CGFloat) = ^UIButton *(NSString *text, NSString *symbol, CGFloat y) {
            UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
            button.frame = CGRectMake(14, y, width - 28, 46);
            button.layer.cornerRadius = 13.0;
            button.titleLabel.font = [WolFoxProTheme fontOfSize:14 weight:UIFontWeightBold];
            [button setTitle:text forState:UIControlStateNormal];
            [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
            if (@available(iOS 13.0, *)) [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
            button.tintColor = UIColor.whiteColor;
            button.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
            return button;
        };

        self.spoofQuickToggleButton = quickButton(@"تشغيل تزييف الموقع", @"location.fill", 72);
        [self.spoofQuickToggleButton addTarget:self action:@selector(toggleSpoofFromQuickPanel:) forControlEvents:UIControlEventTouchUpInside];
        [self.spoofQuickPanel addSubview:self.spoofQuickToggleButton];

        UIButton *mapButton = quickButton(@"فتح الخريطة والإحداثيات", @"map.fill", 124);
        mapButton.backgroundColor = [WolFoxProTheme accent];
        [mapButton addTarget:self action:@selector(openMapFromQuickPanel:) forControlEvents:UIControlEventTouchUpInside];
        [self.spoofQuickPanel addSubview:mapButton];

        self.spoofQuickFavoriteButton = quickButton(@"تشغيل آخر موقع محفوظ", @"star.fill", 176);
        self.spoofQuickFavoriteButton.backgroundColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.78];
        [self.spoofQuickFavoriteButton addTarget:self action:@selector(activateFavoriteFromQuickPanel:) forControlEvents:UIControlEventTouchUpInside];
        [self.spoofQuickPanel addSubview:self.spoofQuickFavoriteButton];

        [self.overlayWindow addSubview:self.spoofQuickPanel];
    }

    CGFloat panelWidth = CGRectGetWidth(self.spoofQuickPanel.bounds);
    CGFloat x = MIN(MAX(14.0, CGRectGetMidX(self.floatingIcon.frame) - panelWidth * 0.5),
                    CGRectGetWidth(self.overlayWindow.bounds) - panelWidth - 14.0);
    CGFloat below = CGRectGetMaxY(self.floatingIcon.frame) + 10.0;
    CGFloat maxY = CGRectGetHeight(self.overlayWindow.bounds) - CGRectGetHeight(self.spoofQuickPanel.bounds) - self.overlayWindow.safeAreaInsets.bottom - 12.0;
    CGFloat y = MIN(below, maxY);
    if (y < self.overlayWindow.safeAreaInsets.top + 10.0) y = self.overlayWindow.safeAreaInsets.top + 10.0;
    self.spoofQuickPanel.frame = CGRectMake(x, y, panelWidth, CGRectGetHeight(self.spoofQuickPanel.bounds));
    self.spoofQuickPanel.hidden = NO;
    self.spoofQuickPanel.alpha = 0.0;
    [self refreshSpoofQuickPanel];
    [self.overlayWindow bringSubviewToFront:self.spoofQuickPanel];
    [self.overlayWindow bringSubviewToFront:self.floatingIcon];
    [UIView animateWithDuration:[WolFoxProTheme transitionDuration] animations:^{ self.spoofQuickPanel.alpha = 1.0; }];
}

- (void)closeSpoofQuickPanel:(UIButton *)sender {
    (void)sender;
    if (!self.spoofQuickPanel || self.spoofQuickPanel.hidden) return;
    [UIView animateWithDuration:[WolFoxProTheme transitionDuration] animations:^{
        self.spoofQuickPanel.alpha = 0.0;
    } completion:^(__unused BOOL finished) {
        self.spoofQuickPanel.hidden = YES;
    }];
}

- (void)refreshSpoofQuickPanel {
    if (!self.spoofQuickPanel) return;
    WolFoxProStore *store = [WolFoxProStore shared];
    BOOL active = store.spoofActive && [WFLicenseClient isRuntimeLicenseValid];
    UIColor *stateColor = active ? [WolFoxProTheme success] : [WolFoxProTheme danger];
    self.spoofQuickStatusLabel.text = active ? @"الحالة: التزييف مفعّل" : @"الحالة: التزييف متوقف";
    self.spoofQuickStatusLabel.textColor = stateColor;
    [self.spoofQuickToggleButton setTitle:(active ? @"إيقاف التزييف والعودة للموقع الحقيقي" : @"تشغيل تزييف الموقع") forState:UIControlStateNormal];
    self.spoofQuickToggleButton.backgroundColor = stateColor;
    WolFoxProLocation *favorite = store.locations.firstObject;
    self.spoofQuickFavoriteButton.enabled = favorite != nil;
    self.spoofQuickFavoriteButton.alpha = favorite ? 1.0 : 0.45;
    [self.spoofQuickFavoriteButton setTitle:(favorite ? [NSString stringWithFormat:@"تشغيل: %@", favorite.name ?: @"آخر موقع محفوظ"] : @"لا توجد مواقع محفوظة") forState:UIControlStateNormal];
}

- (void)toggleSpoofFromQuickPanel:(UIButton *)sender {
    (void)sender;
    WolFoxProStore *store = [WolFoxProStore shared];
    if (store.spoofActive) {
        [[WolFoxProHookManager shared] stopRoute];
        store.scheduleApplied = NO;
        store.spoofActive = NO;
        [store saveSettings];
    } else {
        if (![WFLicenseClient isRuntimeLicenseValid]) {
            [self showActivationScreenWithResult:[WFLicenseClient lastLicenseResult]];
            return;
        }
        if (!CLLocationCoordinate2DIsValid(store.currentFakeCoords)) return;
        store.spoofActive = YES;
        [store saveSettings];
        [[WolFoxProHookManager shared] deliverFakeUpdate];
    }
    [self refreshFloatingStatusIcon];
    [self refreshSpoofQuickPanel];
    [self.mainVC refreshSpoofHeaderStatus];
}

- (void)openMapFromQuickPanel:(UIButton *)sender {
    (void)sender;
    [self closeSpoofQuickPanel:nil];
    [self showUI];
    [self.mainVC openGPSPage];
}

- (void)activateFavoriteFromQuickPanel:(UIButton *)sender {
    (void)sender;
    WolFoxProLocation *favorite = [WolFoxProStore shared].locations.firstObject;
    if (!favorite) return;
    WolFoxProStore *store = [WolFoxProStore shared];
    if (store.routeActive) [[WolFoxProHookManager shared] stopRoute];
    store.currentFakeCoords = favorite.coordinate;
    store.spoofActive = YES;
    [store saveSettings];
    [[WolFoxProHookManager shared] deliverFakeUpdate];
    [store recordLocationHistoryWithName:favorite.name coordinate:favorite.coordinate];
    [self refreshFloatingStatusIcon];
    [self refreshSpoofQuickPanel];
    [self.mainVC refreshSpoofHeaderStatus];
}

- (void)handleFloatingStatusPan:(UIPanGestureRecognizer *)gesture {
    UIView *icon = gesture ? gesture.view : self.floatingIcon;
    if (!icon) return;
    if (gesture && gesture.state == UIGestureRecognizerStateBegan) [self closeSpoofQuickPanel:nil];
    CGPoint translation = gesture ? [gesture translationInView:self.overlayWindow] : CGPointZero;
    icon.center = CGPointMake(icon.center.x + translation.x, icon.center.y + translation.y);
    if (gesture) [gesture setTranslation:CGPointZero inView:self.overlayWindow];

    CGRect bounds = self.overlayWindow.bounds;
    CGFloat radius = CGRectGetWidth(icon.bounds) * 0.5;
    CGFloat minX = radius + 10.0, maxX = MAX(minX, CGRectGetWidth(bounds) - radius - 10.0);
    CGFloat minY = radius + self.overlayWindow.safeAreaInsets.top + 10.0;
    CGFloat maxY = MAX(minY, CGRectGetHeight(bounds) - radius - self.overlayWindow.safeAreaInsets.bottom - 10.0);
    icon.center = CGPointMake(MIN(MAX(icon.center.x, minX), maxX), MIN(MAX(icon.center.y, minY), maxY));

    if (!gesture || gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        [[NSUserDefaults standardUserDefaults] setDouble:icon.frame.origin.x forKey:@"WF_FLOATING_STATUS_X"];
        [[NSUserDefaults standardUserDefaults] setDouble:icon.frame.origin.y forKey:@"WF_FLOATING_STATUS_Y"];
    }
}

- (void)toggleCameraIcon:(BOOL)show {
    if (show && ![WFLicenseClient isRuntimeLicenseValid]) show = NO;
    if (show) {
        self.overlayWindow.hidden = NO;
        if (!self.cameraIcon) {
            self.cameraIcon = [UIButton buttonWithType:UIButtonTypeCustom];
            self.cameraIcon.frame = CGRectMake(24, 120, 60, 60);
            self.cameraIcon.backgroundColor = [WolFoxProTheme accent];
            self.cameraIcon.layer.cornerRadius = 30;
            if (@available(iOS 14.0, *)) {
                // photo.badge.plus متاح من iOS 14
                [self.cameraIcon setImage:[UIImage systemImageNamed:@"photo.badge.plus" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
            } else if (@available(iOS 13.0, *)) {
                [self.cameraIcon setImage:[UIImage systemImageNamed:@"camera.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
            }
            self.cameraIcon.tintColor = [UIColor whiteColor];
            self.cameraIcon.accessibilityLabel = @"فتح الاستديو واختيار صورة للبث";
            self.cameraIcon.accessibilityHint = @"اضغط لفتح الصور مباشرة، اسحب لتحريكها، أو اسحب أكثر من ثانيتين للتبديل السريع";
            [self.cameraIcon addTarget:self action:@selector(openVirtualCameraImagePicker:) forControlEvents:UIControlEventTouchUpInside];
            UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleCameraIconPan:)];
            [self.cameraIcon addGestureRecognizer:pan];
            [self.overlayWindow addSubview:self.cameraIcon];
            
            // Shadow
            self.cameraIcon.layer.shadowColor = [UIColor blackColor].CGColor;
            self.cameraIcon.layer.shadowOffset = CGSizeMake(0, 4);
            self.cameraIcon.layer.shadowOpacity = 0.5;
            self.cameraIcon.layer.shadowRadius = 8;
        }
        self.cameraIcon.hidden = NO;
        [self.overlayWindow bringSubviewToFront:self.cameraIcon];
        self.cameraIcon.alpha = 0;
        [self.cameraIcon.layer removeAnimationForKey:@"wf_photo_pulse"];
        [UIView animateWithDuration:[WolFoxProTheme transitionDuration] animations:^{ self.cameraIcon.alpha = 0.90; }];
        if (![WolFoxProTheme reduceMotionEnabled]) {
            CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
            pulse.fromValue = @1.0; pulse.toValue = @1.12; pulse.duration = 0.75;
            pulse.autoreverses = YES; pulse.repeatCount = HUGE_VALF;
            pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [self.cameraIcon.layer addAnimation:pulse forKey:@"wf_photo_pulse"];
        }
    } else {
        [UIView animateWithDuration:[WolFoxProTheme transitionDuration] animations:^{ self.cameraIcon.alpha = 0; } completion:^(BOOL f){
            self.cameraIcon.hidden = YES;
            if (self.mainVC.view.hidden && !self.mainVC.presentedViewController) self.overlayWindow.hidden = YES;
        }];
    }
}

- (void)prepareCleanVirtualPhotoCapture {
    if (!NSThread.isMainThread) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf prepareCleanVirtualPhotoCapture]; });
        return;
    }
    [self closeFloatingControlPanel:nil];
    [self.cameraIcon.layer removeAllAnimations];
    self.cameraIcon.alpha = 0.0;
    self.cameraIcon.hidden = YES;
    if (self.mainVC.view.hidden && !self.mainVC.presentedViewController) {
        self.overlayWindow.hidden = YES;
        [self restoreHostKeyWindow];
    }
}

- (void)handleCameraIconPan:(UIPanGestureRecognizer *)gesture {
    if (!self.cameraIcon || !self.overlayWindow) return;
    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.cameraDragStartTime = CACurrentMediaTime();
        self.cameraIconDidDrag = NO;
        [self.cameraIcon.layer removeAnimationForKey:@"wf_photo_pulse"];
        [UIView animateWithDuration:0.12 animations:^{
            self.cameraIcon.transform = CGAffineTransformMakeScale(1.15, 1.15);
        }];
    }
    CGPoint translation = [gesture translationInView:self.overlayWindow];
    if (fabs(translation.x) > 0.5 || fabs(translation.y) > 0.5) self.cameraIconDidDrag = YES;
    CGPoint center = self.cameraIcon.center;
    center.x += translation.x;
    center.y += translation.y;
    CGFloat margin = 24.0;
    center.x = MAX(margin, MIN(CGRectGetWidth(self.overlayWindow.bounds) - margin, center.x));
    center.y = MAX(70.0, MIN(CGRectGetHeight(self.overlayWindow.bounds) - 70.0, center.y));
    self.cameraIcon.center = center;
    [gesture setTranslation:CGPointZero inView:self.overlayWindow];
    if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        CFTimeInterval duration = CACurrentMediaTime() - self.cameraDragStartTime;
        [UIView animateWithDuration:0.20 animations:^{ self.cameraIcon.transform = CGAffineTransformIdentity; }];
        if (gesture.state == UIGestureRecognizerStateEnded && self.cameraIconDidDrag && duration > 2.0) {
            WFVirtualCameraManager *manager = [WFVirtualCameraManager shared];
            BOOL changed = NO;
            if (manager.enabled) {
                manager.enabled = NO;
                changed = YES;
            } else {
                changed = [manager enableUsingAvailableImage];
            }
            UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc]
                                                    initWithStyle:(changed ? UIImpactFeedbackStyleHeavy : UIImpactFeedbackStyleMedium)];
            [feedback impactOccurred];
            UIColor *originalColor = self.cameraIcon.backgroundColor;
            self.cameraIcon.backgroundColor = changed
                ? (manager.enabled ? [WolFoxProTheme success] : [WolFoxProTheme danger])
                : [WolFoxProTheme gold];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                self.cameraIcon.backgroundColor = originalColor;
            });
            if (!changed) [self openVirtualCameraImagePicker:nil];
        }
        if (![WolFoxProTheme reduceMotionEnabled] && !self.cameraIcon.hidden) {
            CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
            pulse.fromValue = @1.0; pulse.toValue = @1.12; pulse.duration = 0.75;
            pulse.autoreverses = YES; pulse.repeatCount = HUGE_VALF;
            [self.cameraIcon.layer addAnimation:pulse forKey:@"wf_photo_pulse"];
        }
    }
}

- (UIButton *)floatingButtonWithTitle:(NSString *)title frame:(CGRect)frame color:(UIColor *)color action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = frame;
    button.backgroundColor = color;
    button.layer.cornerRadius = 12.0;
    button.clipsToBounds = YES;
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    button.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)openVirtualCameraImagePicker:(UIButton *)sender {
    (void)sender;
    if (![WFLicenseClient isRuntimeLicenseValid]) {
        [self showActivationScreenWithResult:[WFLicenseClient lastLicenseResult]];
        return;
    }

    UIViewController *presenter = nil;
    if (!self.mainVC.view.hidden && self.mainVC.view.window) {
        presenter = self.mainVC;
    } else {
        UIWindow *host = self.previousKeyWindow ?: [self hostKeyWindow];
        presenter = host.rootViewController;
    }

    // عند الإلغاء تعود الأيقونة، وعند نجاح الاختيار يخفيها إشعار الصورة الجديدة.
    self.reopenCameraIconAfterPicker = YES;
    [self prepareCleanVirtualPhotoCapture];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[WFVirtualCameraManager shared] presentImagePickerFromViewController:presenter];
    });
}

- (void)cameraIconPressed {
    if (![WFLicenseClient isRuntimeLicenseValid]) {
        [self showActivationScreenWithResult:[WFLicenseClient lastLicenseResult]];
        return;
    }
    if (self.floatingControlPanel) {
        [self closeFloatingControlPanel:nil];
        return;
    }
    CGFloat width = MIN(320.0, CGRectGetWidth(self.overlayWindow.bounds) - 32.0);
    CGFloat height = 362.0;
    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake((CGRectGetWidth(self.overlayWindow.bounds) - width) * 0.5,
                                                               (CGRectGetHeight(self.overlayWindow.bounds) - height) * 0.5,
                                                               width, height)];
    panel.backgroundColor = [UIColor colorWithRed:0.025 green:0.035 blue:0.055 alpha:0.97];
    panel.layer.cornerRadius = 18.0;
    panel.layer.borderWidth = 1.0;
    panel.layer.borderColor = [UIColor colorWithRed:0.10 green:0.50 blue:1.0 alpha:0.70].CGColor;
    panel.layer.shadowColor = UIColor.blackColor.CGColor;
    panel.layer.shadowOpacity = 0.45;
    panel.layer.shadowRadius = 14.0;
    panel.layer.shadowOffset = CGSizeMake(0, 6);
    panel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                             UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.floatingControlPanel = panel;
    [self.overlayWindow addSubview:panel];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(width - 44.0, 10.0, 32.0, 32.0);
    if (@available(iOS 13.0, *)) [close setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
    close.tintColor = UIColor.whiteColor;
    close.accessibilityLabel = @"إغلاق قائمة متحول";
    [close addTarget:self action:@selector(closeFloatingControlPanel:) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:close];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(18.0, 12.0, width - 64.0, 30.0)];
    title.text = @"Virtual Camera • WolFox";
    title.textColor = UIColor.whiteColor;
    title.textAlignment = NSTextAlignmentCenter;
    title.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightBold];
    [panel addSubview:title];

    self.floatingStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(18.0, 45.0, width - 36.0, 24.0)];
    self.floatingStatusLabel.textAlignment = NSTextAlignmentCenter;
    self.floatingStatusLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    [panel addSubview:self.floatingStatusLabel];

    UIButton *select = [self floatingButtonWithTitle:@"اختيار صورة وتشغيلها" frame:CGRectMake(18.0, 76.0, width - 36.0, 42.0) color:[UIColor colorWithRed:0.05 green:0.43 blue:0.95 alpha:1.0] action:@selector(floatingUploadPressed:)];
    select.accessibilityLabel = @"اختيار صورة واحدة وتشغيلها مكان بث الكاميرا";
    [panel addSubview:select];

    self.floatingToggleButton = [self floatingButtonWithTitle:@"تشغيل البث الافتراضي" frame:CGRectMake(18.0, 127.0, width - 36.0, 42.0) color:[UIColor colorWithRed:0.16 green:0.24 blue:0.34 alpha:1.0] action:@selector(floatingTogglePressed:)];
    [panel addSubview:self.floatingToggleButton];

    UIView *rememberRow = [[UIView alloc] initWithFrame:CGRectMake(18.0, 178.0, width - 36.0, 43.0)];
    rememberRow.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.95];
    rememberRow.layer.cornerRadius = 11.0;
    [panel addSubview:rememberRow];
    UILabel *rememberLabel = [[UILabel alloc] initWithFrame:CGRectMake(66.0, 0, rememberRow.bounds.size.width - 78.0, 43.0)];
    rememberLabel.text = @"حفظ آخر صورة";
    rememberLabel.textAlignment = NSTextAlignmentRight;
    rememberLabel.textColor = UIColor.whiteColor;
    rememberLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    [rememberRow addSubview:rememberLabel];
    self.floatingRememberSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(8.0, 6.0, 52.0, 32.0)];
    self.floatingRememberSwitch.onTintColor = [WolFoxProTheme accent];
    [self.floatingRememberSwitch addTarget:self action:@selector(floatingRememberChanged:) forControlEvents:UIControlEventValueChanged];
    [rememberRow addSubview:self.floatingRememberSwitch];

    self.floatingClearButton = [self floatingButtonWithTitle:@"مسح الصورة المحفوظة" frame:CGRectMake(18.0, 230.0, width - 36.0, 42.0) color:[[WolFoxProTheme danger] colorWithAlphaComponent:0.72] action:@selector(floatingClearPressed:)];
    [panel addSubview:self.floatingClearButton];

    UIButton *hide = [self floatingButtonWithTitle:@"إيقاف الأداة وإخفاؤها" frame:CGRectMake(18.0, 281.0, width - 36.0, 42.0) color:[UIColor colorWithRed:0.03 green:0.22 blue:0.45 alpha:1.0] action:@selector(floatingHidePressed:)];
    [panel addSubview:hide];

    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(18.0, 330.0, width - 36.0, 18.0)];
    hint.text = @"اسحب الأيقونة أكثر من ثانيتين للتبديل السريع";
    hint.textAlignment = NSTextAlignmentCenter;
    hint.textColor = [UIColor colorWithWhite:0.64 alpha:1.0];
    hint.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightMedium];
    [panel addSubview:hint];
    [self refreshFloatingControlPanel];

    panel.alpha = 0.0;
    panel.transform = CGAffineTransformMakeScale(0.88, 0.88);
    [UIView animateWithDuration:0.24 animations:^{
        panel.alpha = 1.0;
        panel.transform = CGAffineTransformIdentity;
    }];
}

- (void)refreshFloatingControlPanel {
    WFVirtualCameraManager *manager = [WFVirtualCameraManager shared];
    BOOL enabled = manager.enabled;
    self.floatingStatusLabel.text = enabled ? @"● البث الافتراضي يعمل" : (manager.hasCurrentImage ? @"○ الصورة جاهزة — البث متوقف" : @"○ لم يتم اختيار صورة");
    self.floatingStatusLabel.textColor = enabled ? [WolFoxProTheme success] : [UIColor colorWithWhite:0.78 alpha:1.0];
    [self.floatingToggleButton setTitle:(enabled ? @"إيقاف البث الافتراضي" : @"تشغيل البث الافتراضي") forState:UIControlStateNormal];
    self.floatingToggleButton.backgroundColor = enabled ? [WolFoxProTheme success] : [UIColor colorWithRed:0.16 green:0.24 blue:0.34 alpha:1.0];
    self.floatingRememberSwitch.on = manager.rememberLastImage;
    self.floatingClearButton.enabled = manager.hasCurrentImage || manager.hasStoredImage;
    self.floatingClearButton.alpha = self.floatingClearButton.enabled ? 1.0 : 0.45;
}

- (void)floatingUploadPressed:(UIButton *)sender {
    [self openVirtualCameraImagePicker:sender];
}

- (void)floatingTogglePressed:(UIButton *)sender {
    WFVirtualCameraManager *manager = [WFVirtualCameraManager shared];
    if (manager.enabled) manager.enabled = NO;
    else if (![manager enableUsingAvailableImage]) {
        [self floatingUploadPressed:sender];
        return;
    }
    [self refreshFloatingControlPanel];
}

- (void)floatingRememberChanged:(UISwitch *)sender {
    [WFVirtualCameraManager shared].rememberLastImage = sender.isOn;
    [self refreshFloatingControlPanel];
}

- (void)floatingClearPressed:(UIButton *)sender {
    [[WFVirtualCameraManager shared] clearAllImageData];
    [self refreshFloatingControlPanel];
}

- (void)floatingHidePressed:(UIButton *)sender {
    [[WFVirtualCameraManager shared] discardImageFromMemory];
    [self closeFloatingControlPanel:nil];
    [self toggleCameraIcon:NO];
}

- (void)closeFloatingControlPanel:(UIButton *)sender {
    [self.floatingControlPanel removeFromSuperview];
    self.floatingControlPanel = nil;
    self.floatingStatusLabel = nil;
    self.floatingToggleButton = nil;
    self.floatingClearButton = nil;
    self.floatingRememberSwitch = nil;
}
@end

static void __attribute__((constructor)) initialize() {
    if (!WFMasterProcessIsEligible()) return;
#ifdef DEBUG
    WFLog(@"[WolFox][BOOT] ui_constructor_loaded");
#endif
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        WolFoxController *controller = [WolFoxController shared];
#ifdef DEBUG
        WFLog(@"[WolFox][BOOT] startup_stored=%d verify_before_ui=1", [WFLicenseClient hasStoredLicense]);
#endif
        [WFLicenseClient validateStrictlyWithCompletion:^(WFLicenseResult *result) {
            BOOL stayHidden = [[NSUserDefaults standardUserDefaults] boolForKey:WFUIHiddenOnLaunchKey];
            if (!stayHidden) {
                if (result.success) {
                    if ([WolFoxProStore shared].mediaUploadActive) [controller toggleCameraIcon:YES];
                    [controller showUI];
                } else {
                    [controller showActivationScreenWithResult:result];
                }
            } else {
#ifdef DEBUG
                WFLog(@"[WolFox][BOOT] startup_ui_stays_hidden_until_volume_request");
#endif
            }
            [WFLicenseClient startHeartbeat];
        }];
    });
}
