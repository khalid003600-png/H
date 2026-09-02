// WFActivationViewController.m - WolFox v.1.0.0 "Royal Final"
#import "WFActivationViewController.h"
#import "WFLicenseClient.h"
#import "WolFoxProTheme.h"
#import "WFRedactedLogger.h"

@interface WFActivationViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) NSLayoutConstraint *cardCenterY;
@property (nonatomic, strong) UITextField *codeField;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *uuidLabel;
@property (nonatomic, strong) UIButton *activateButton;
@property (nonatomic, strong) UIButton *updateButton;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UIView *loadingOverlay;
@property (nonatomic, strong) UILabel *timerLabel;
@property (nonatomic, strong) UILabel *waitLabel;
@property (nonatomic, strong) UIImageView *lockIcon;
@end

@implementation WFActivationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [[WolFoxProTheme royalBackground] colorWithAlphaComponent:0.98];
    
    // Tap to dismiss keyboard
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];
    
    // Notifications for keyboard
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];

    self.card = [[UIView alloc] initWithFrame:CGRectZero];
    self.card.translatesAutoresizingMaskIntoConstraints = NO;
    self.card.backgroundColor = [WolFoxProTheme royalCard];
    self.card.layer.cornerRadius = 26.0;
    self.card.layer.borderWidth = 1.0;
    self.card.layer.borderColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.78].CGColor;
    self.card.layer.shadowColor = UIColor.blackColor.CGColor;
    self.card.layer.shadowOpacity = 0.42;
    self.card.layer.shadowRadius = 18.0;
    self.card.layer.shadowOffset = CGSizeMake(0, 8);
    self.card.clipsToBounds = NO;
    [self.view addSubview:self.card];
    
    UIView *card = self.card;

    self.headerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.headerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerView.backgroundColor = [WolFoxProTheme surfaceSecondary];
    self.headerView.layer.cornerRadius = 26.0;
    self.headerView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    [card addSubview:self.headerView];

    UIButton *exitBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    exitBtn.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *exitConfig = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightBold];
        [exitBtn setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:exitConfig] forState:UIControlStateNormal];
    }
    [exitBtn setTitleColor:[UIColor colorWithRed:0.96 green:0.30 blue:0.30 alpha:1.0] forState:UIControlStateNormal];
    exitBtn.tintColor = [UIColor colorWithRed:0.96 green:0.30 blue:0.30 alpha:1.0];
    exitBtn.hidden = YES; // shown after first failed attempt
    [exitBtn addTarget:self action:@selector(closePressed) forControlEvents:UIControlEventTouchUpInside];
    [self.headerView addSubview:exitBtn];
    self.exitButton = exitBtn;

    UILabel *titleLabel = [UILabel new];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"Wolfox";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.headerView addSubview:titleLabel];

    UIImageView *crownIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"crown.fill"]];
    crownIcon.translatesAutoresizingMaskIntoConstraints = NO;
    crownIcon.tintColor = [WolFoxProTheme royalBlue];
    crownIcon.contentMode = UIViewContentModeScaleAspectFit;
    [self.headerView addSubview:crownIcon];

    [NSLayoutConstraint activateConstraints:@[
        [exitBtn.leadingAnchor constraintEqualToAnchor:self.headerView.leadingAnchor constant:20],
        [exitBtn.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor],
        [titleLabel.centerXAnchor constraintEqualToAnchor:self.headerView.centerXAnchor],
        [titleLabel.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor],
        [crownIcon.trailingAnchor constraintEqualToAnchor:self.headerView.trailingAnchor constant:-20],
        [crownIcon.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor],
        [crownIcon.widthAnchor constraintEqualToConstant:24],
        [crownIcon.heightAnchor constraintEqualToConstant:24]
    ]];

    self.lockIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"lock.shield.fill"]];
    self.lockIcon.translatesAutoresizingMaskIntoConstraints = NO;
    self.lockIcon.tintColor = [WolFoxProTheme royalBlue];
    self.lockIcon.contentMode = UIViewContentModeScaleAspectFit;
    [card addSubview:self.lockIcon];

    UILabel *subtitle = [UILabel new];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = @"Wolfox";
    subtitle.textColor = [WolFoxProTheme textPrimary];
    subtitle.font = [UIFont systemFontOfSize:23 weight:UIFontWeightBlack];
    subtitle.textAlignment = NSTextAlignmentCenter;
    [card addSubview:subtitle];

    UILabel *desc = [UILabel new];
    desc.translatesAutoresizingMaskIntoConstraints = NO;
    desc.text = @"أدخل كود التفعيل للمتابعة بأمان";
    desc.textColor = [UIColor colorWithWhite:0.73 alpha:1.0];
    desc.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    desc.textAlignment = NSTextAlignmentCenter;
    [card addSubview:desc];

    self.codeField = [UITextField new];
    self.codeField.translatesAutoresizingMaskIntoConstraints = NO;
    self.codeField.backgroundColor = [WolFoxProTheme royalField];
    self.codeField.textColor = [UIColor whiteColor];
    self.codeField.tintColor = [WolFoxProTheme royalBlue];
    self.codeField.layer.cornerRadius = 16.0;
    self.codeField.layer.borderWidth = 1.5;
    self.codeField.layer.borderColor = [[WolFoxProTheme royalBlue] colorWithAlphaComponent:0.62].CGColor;
    self.codeField.placeholder = @"GPS-XXXX-XXXX-XXXX";
    self.codeField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:self.codeField.placeholder attributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:0.40 alpha:1.0]}];
    self.codeField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.codeField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.codeField.keyboardType = UIKeyboardTypeASCIICapable;
    self.codeField.smartDashesType = UITextSmartDashesTypeNo;
    self.codeField.smartQuotesType = UITextSmartQuotesTypeNo;
    self.codeField.textContentType = UITextContentTypeOneTimeCode;
    self.codeField.textAlignment = NSTextAlignmentCenter;
    self.codeField.font = [UIFont monospacedSystemFontOfSize:18 weight:UIFontWeightBlack];
    self.codeField.delegate = self;
    self.codeField.text = [WFLicenseClient storedCode] ?: @"";
    UIButton *pasteCodeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    pasteCodeButton.frame = CGRectMake(0, 0, 48, 56);
    if (@available(iOS 13.0, *)) {
        [pasteCodeButton setImage:[UIImage systemImageNamed:@"doc.on.clipboard.fill"] forState:UIControlStateNormal];
    }
    pasteCodeButton.backgroundColor = [WolFoxProTheme accent];
    pasteCodeButton.layer.cornerRadius = 12.0;
    pasteCodeButton.layer.borderWidth = 1.0;
    pasteCodeButton.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.35].CGColor;
    pasteCodeButton.tintColor = [UIColor whiteColor];
    pasteCodeButton.adjustsImageWhenHighlighted = YES;
    pasteCodeButton.accessibilityLabel = @"لصق كود التفعيل من الحافظة";
    [pasteCodeButton addTarget:self action:@selector(pasteActivationCode) forControlEvents:UIControlEventTouchUpInside];
    self.codeField.rightView = pasteCodeButton;
    self.codeField.rightViewMode = UITextFieldViewModeAlways;
    [card addSubview:self.codeField];

    self.activateButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.activateButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.activateButton.backgroundColor = [WolFoxProTheme royalBlue];
    self.activateButton.layer.cornerRadius = 16.0;
    self.activateButton.layer.borderWidth = 1.0;
    self.activateButton.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.38].CGColor;
    self.activateButton.adjustsImageWhenHighlighted = YES;
    [self.activateButton setTitle:@"تفعيل الآن" forState:UIControlStateNormal];
    [self.activateButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.activateButton.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBlack];
    
    // Add Shadow to Button
    self.activateButton.layer.shadowColor = [WolFoxProTheme royalBlue].CGColor;
    self.activateButton.layer.shadowOffset = CGSizeMake(0, 4);
    self.activateButton.layer.shadowOpacity = 0.8;
    self.activateButton.layer.shadowRadius = 10;
    [self.activateButton addTarget:self action:@selector(activatePressed) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:self.activateButton];

    self.statusLabel = [UILabel new];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.textColor = [UIColor colorWithRed:1.0 green:0.50 blue:0.50 alpha:1.0];
    self.statusLabel.backgroundColor = [UIColor colorWithRed:0.35 green:0.08 blue:0.10 alpha:0.40];
    self.statusLabel.layer.cornerRadius = 10.0;
    self.statusLabel.clipsToBounds = YES;
    self.statusLabel.layer.borderWidth = 1.0;
    self.statusLabel.layer.borderColor = [[WolFoxProTheme danger] colorWithAlphaComponent:0.65].CGColor;
    self.statusLabel.hidden = YES;
    self.statusLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 4;
    [card addSubview:self.statusLabel];

    self.updateButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.updateButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.updateButton.backgroundColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.24];
    self.updateButton.layer.cornerRadius = 12;
    self.updateButton.layer.borderWidth = 1;
    self.updateButton.layer.borderColor = [[WolFoxProTheme royalBlue] colorWithAlphaComponent:0.7].CGColor;
    [self.updateButton setTitle:@"تنزيل التحديث المطلوب" forState:UIControlStateNormal];
    [self.updateButton setTitleColor:[WolFoxProTheme textPrimary] forState:UIControlStateNormal];
    self.updateButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [self.updateButton addTarget:self action:@selector(openUpdateURL) forControlEvents:UIControlEventTouchUpInside];
    self.updateButton.hidden = !self.updateURL.length;
    [card addSubview:self.updateButton];

    self.uuidLabel = [UILabel new];
    self.uuidLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.uuidLabel.textColor = [UIColor colorWithWhite:0.48 alpha:1.0];
    self.uuidLabel.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightMedium];
    self.uuidLabel.textAlignment = NSTextAlignmentCenter;
    self.uuidLabel.numberOfLines = 0;
    self.uuidLabel.text = [NSString stringWithFormat:@"معرّف الجهاز • %@", [WFLicenseClient deviceIdentifier]];
    [card addSubview:self.uuidLabel];

    self.loadingOverlay = [[UIView alloc] initWithFrame:CGRectZero];
    self.loadingOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingOverlay.backgroundColor = [WolFoxProTheme royalCard];
    self.loadingOverlay.hidden = YES;
    self.loadingOverlay.alpha = 0;
    [card addSubview:self.loadingOverlay];

    self.waitLabel = [UILabel new];
    self.waitLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.waitLabel.text = @"جارٍ التحقق من الكود";
    self.waitLabel.textColor = [UIColor whiteColor];
    self.waitLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBlack];
    self.waitLabel.textAlignment = NSTextAlignmentCenter;
    [self.loadingOverlay addSubview:self.waitLabel];

    self.timerLabel = [UILabel new];
    self.timerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.timerLabel.textColor = [UIColor colorWithRed:0.08 green:0.45 blue:0.98 alpha:1.0];
    self.timerLabel.font = [UIFont systemFontOfSize:38 weight:UIFontWeightBlack];
    self.timerLabel.textAlignment = NSTextAlignmentCenter;
    self.timerLabel.text = @"•••";
    [self.loadingOverlay addSubview:self.timerLabel];

    self.cardCenterY = [card.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor];
    [NSLayoutConstraint activateConstraints:@[
        [card.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        self.cardCenterY,
        [card.widthAnchor constraintEqualToAnchor:self.view.widthAnchor multiplier:0.90],
        [card.widthAnchor constraintLessThanOrEqualToConstant:400],

        [self.headerView.topAnchor constraintEqualToAnchor:card.topAnchor],
        [self.headerView.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [self.headerView.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [self.headerView.heightAnchor constraintEqualToConstant:64],

        [titleLabel.centerXAnchor constraintEqualToAnchor:self.headerView.centerXAnchor],
        [titleLabel.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor],

        [self.lockIcon.topAnchor constraintEqualToAnchor:self.headerView.bottomAnchor constant:26],
        [self.lockIcon.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [self.lockIcon.widthAnchor constraintEqualToConstant:60],
        [self.lockIcon.heightAnchor constraintEqualToConstant:60],

        [subtitle.topAnchor constraintEqualToAnchor:self.lockIcon.bottomAnchor constant:15],
        [subtitle.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        
        [desc.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:10],
        [desc.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],

        [self.codeField.topAnchor constraintEqualToAnchor:desc.bottomAnchor constant:22],
        [self.codeField.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24],
        [self.codeField.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-24],
        [self.codeField.heightAnchor constraintEqualToConstant:56],

        [self.activateButton.topAnchor constraintEqualToAnchor:self.codeField.bottomAnchor constant:18],
        [self.activateButton.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24],
        [self.activateButton.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-24],
        [self.activateButton.heightAnchor constraintEqualToConstant:56],

        [self.statusLabel.topAnchor constraintEqualToAnchor:self.activateButton.bottomAnchor constant:14],
        [self.statusLabel.heightAnchor constraintGreaterThanOrEqualToConstant:38],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-24],
        
        [self.updateButton.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:10],
        [self.updateButton.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24],
        [self.updateButton.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-24],
        [self.updateButton.heightAnchor constraintEqualToConstant:self.updateURL.length ? 44 : 0],

        [self.uuidLabel.topAnchor constraintEqualToAnchor:self.updateButton.bottomAnchor constant:12],
        [self.uuidLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24],
        [self.uuidLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-24],
        [self.uuidLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-30],

        [self.loadingOverlay.topAnchor constraintEqualToAnchor:card.topAnchor],
        [self.loadingOverlay.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [self.loadingOverlay.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [self.loadingOverlay.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],

        [self.waitLabel.centerXAnchor constraintEqualToAnchor:self.loadingOverlay.centerXAnchor],
        [self.waitLabel.centerYAnchor constraintEqualToAnchor:self.loadingOverlay.centerYAnchor constant:-50],

        [self.timerLabel.centerXAnchor constraintEqualToAnchor:self.loadingOverlay.centerXAnchor],
        [self.timerLabel.topAnchor constraintEqualToAnchor:self.waitLabel.bottomAnchor constant:15]
    ]];
    if (self.noticeMessage.length) [self showActivationError:self.noticeMessage];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)closePressed {
    [self.view endEditing:YES];
    self.statusLabel.hidden = YES;
    self.statusLabel.text = @"";
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

- (void)pasteActivationCode {
    NSString *text = [UIPasteboard generalPasteboard].string;
    if (!text.length) {
        [self showActivationError:@"الحافظة فارغة؛ انسخ كود التفعيل ثم حاول مرة أخرى."];
        return;
    }
    self.codeField.text = [[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    self.statusLabel.hidden = YES;
    self.statusLabel.text = @"";
    [self.codeField becomeFirstResponder];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary* userInfo = [notification userInfo];
    CGRect keyboardFrame = [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat keyboardHeight = keyboardFrame.size.height;
    
    [UIView animateWithDuration:[WolFoxProTheme transitionDuration] animations:^{
        self.cardCenterY.constant = -(keyboardHeight / 2.0) + 40;
        [self.view layoutIfNeeded];
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    [UIView animateWithDuration:[WolFoxProTheme transitionDuration] animations:^{
        self.cardCenterY.constant = 0;
        [self.view layoutIfNeeded];
    }];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self activatePressed];
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    textField.layer.borderColor = [WolFoxProTheme royalBlue].CGColor;
    textField.layer.borderWidth = 2.0;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    textField.layer.borderColor = [[WolFoxProTheme royalBlue] colorWithAlphaComponent:0.62].CGColor;
    textField.layer.borderWidth = 1.5;
}

- (void)activatePressed {
    if (!self.activateButton.enabled) return;
    NSString *code = [self.codeField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    WFLog(@"[WolFox][ACT] activation_submitted length=%lu", (unsigned long)code.length);
    if (code.length == 0) {
        [self showActivationError:@"أدخل كود التفعيل أولاً ثم حاول مرة أخرى."];
        return;
    }

    self.activateButton.enabled = NO;
    [self.activateButton setTitle:@"جارٍ الاتصال…" forState:UIControlStateNormal];
    self.waitLabel.text = @"جارٍ الاتصال بلوحة الإدارة";
    self.timerLabel.hidden = NO;
    self.timerLabel.text = @"•••";
    self.loadingOverlay.hidden = NO;
    [UIView animateWithDuration:[WolFoxProTheme transitionDuration] animations:^{ self.loadingOverlay.alpha = 1.0; }];
    // ابدأ الطلب فوراً؛ لا يوجد عدّ تنازلي مصطنع قبل الاتصال بالخادم.
    [self finalizeActivation];
}

- (void)finalizeActivation {
    NSString *code = [self.codeField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    WFLog(@"[WolFox][ACT] server_activation_begin length=%lu", (unsigned long)code.length);
    __weak typeof(self) weakSelf = self;
    [WFLicenseClient activateCode:code completion:^(WFLicenseResult *result) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        
        self.updateURL = result.updateURL;
        self.updateButton.hidden = !self.updateURL.length;
        if (result.success) {
            WFLog(@"[WolFox][ACT] server_activation_ok status=%ld", (long)result.status);
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"WF_ACT_SHOWN"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            self.waitLabel.text = @"تم تفعيل الكود بنجاح";
            self.timerLabel.hidden = YES;
            [self.lockIcon.layer removeAllAnimations];
            self.lockIcon.image = [UIImage systemImageNamed:@"iphone.circle.fill"];
            self.lockIcon.tintColor = [UIColor systemGreenColor];
            self.statusLabel.textColor = [UIColor colorWithRed:0.45 green:1.0 blue:0.62 alpha:1.0];
            self.statusLabel.backgroundColor = [UIColor colorWithRed:0.05 green:0.30 blue:0.16 alpha:0.72];
            self.statusLabel.text = [self successActivationMessage:result];
            self.statusLabel.hidden = NO;
            self.activateButton.enabled = NO;
            [self.activateButton setTitle:@"تم التفعيل بنجاح" forState:UIControlStateNormal];
            [UIView animateWithDuration:[WolFoxProTheme transitionDuration] animations:^{ self.loadingOverlay.alpha = 0; } completion:^(BOOL finished) {
                self.loadingOverlay.hidden = YES;
            }];
            UINotificationFeedbackGenerator *feedback = [UINotificationFeedbackGenerator new];
            [feedback prepare];
            [feedback notificationOccurred:UINotificationFeedbackTypeSuccess];
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self dismissViewControllerAnimated:YES completion:^{
                    WFLog(@"[WolFox][ACT] activation_view_dismissed");
                    if (self.completion) self.completion(YES);
                }];
            });
        } else {
            WFLog(@"[WolFox][ACT] server_activation_failed status=%ld", (long)result.status);
            [UIView animateWithDuration:[WolFoxProTheme transitionDuration] animations:^{ self.loadingOverlay.alpha = 0; } completion:^(BOOL f){
                self.loadingOverlay.hidden = YES;
                [self showActivationError:[self friendlyActivationMessage:result]];
                [self applyStatusStyleForResult:result];
                [self.lockIcon.layer removeAllAnimations];
                self.lockIcon.image = [UIImage systemImageNamed:@"iphone.circle.fill"];
                self.lockIcon.tintColor = [self statusColorForResult:result];
                UINotificationFeedbackGenerator *feedback = [UINotificationFeedbackGenerator new];
                [feedback prepare];
                [feedback notificationOccurred:UINotificationFeedbackTypeError];
                self.activateButton.enabled = YES;
                [self.activateButton setTitle:@"تفعيل الآن" forState:UIControlStateNormal];
                self.timerLabel.hidden = NO;
            }];
        }
    }];
}

- (NSString *)friendlyActivationMessage:(WFLicenseResult *)result {
    switch (result.status) {
        case WFLicenseStatusInvalid:
            return @"هذا الكود غير صحيح";
        case WFLicenseStatusDeviceRecovery:
            return @"هذا الكود المستخدم على جهاز آخر";
        case WFLicenseStatusNetworkError:
            return @"تعذر الوصول إلى الخادم الآن؛ تحقق من الإنترنت وسيُعاد الاتصال تلقائياً";
        case WFLicenseStatusProjectDisabled:
            return @"تعذر مطابقة إعدادات المشروع مع لوحة الإدارة";
        case WFLicenseStatusExpired:
            return @"هذا الكود منتهي الصلاحية";
        case WFLicenseStatusBlocked:
            return @"هذا الكود موقوف من لوحة التحكم";
        case WFLicenseStatusInvalidToken:
            return @"انتهت جلسة التفعيل؛ أعد المحاولة بالكود نفسه";
        case WFLicenseStatusUpdateRequired:
            return @"يجب تثبيت الإصدار المطلوب قبل المتابعة";
        case WFLicenseStatusRateLimited:
            return @"طلبات كثيرة خلال وقت قصير؛ حاول لاحقاً";
        default:
            return @"تعذر إكمال التفعيل حالياً";
    }
}

- (NSString *)successActivationMessage:(WFLicenseResult *)result {
    NSString *plan = result.planName.length ? result.planName : @"غير محددة";
    NSString *started = result.startedAt.length ? result.startedAt : @"غير متوفر";
    NSString *expires = result.expiresAt.length ? result.expiresAt : @"غير متوفر";
    return [NSString stringWithFormat:@"تم تفعيل بنجاح\nالمدة: %@\nتاريخ البداية: %@\nتاريخ النهاية: %@", plan, started, expires];
}

- (UIColor *)statusColorForResult:(WFLicenseResult *)result {
    return result.status == WFLicenseStatusDeviceRecovery
        ? [UIColor colorWithRed:1.0 green:0.62 blue:0.12 alpha:1.0]
        : [WolFoxProTheme danger];
}

- (void)applyStatusStyleForResult:(WFLicenseResult *)result {
    BOOL deviceRecovery = result.status == WFLicenseStatusDeviceRecovery;
    self.statusLabel.textColor = deviceRecovery
        ? [UIColor colorWithRed:1.0 green:0.72 blue:0.25 alpha:1.0]
        : [UIColor colorWithRed:1.0 green:0.50 blue:0.50 alpha:1.0];
    self.statusLabel.backgroundColor = deviceRecovery
        ? [UIColor colorWithRed:0.42 green:0.22 blue:0.03 alpha:0.72]
        : [UIColor colorWithRed:0.35 green:0.08 blue:0.10 alpha:0.72];
}

- (void)showActivationError:(NSString *)message {
    self.statusLabel.textColor = [UIColor colorWithRed:1.0 green:0.50 blue:0.50 alpha:1.0];
    self.statusLabel.backgroundColor = [UIColor colorWithRed:0.35 green:0.08 blue:0.10 alpha:0.72];
    self.statusLabel.text = [NSString stringWithFormat:@"فشل تفعيل الكود\n%@", message ?: @"تعذر إكمال التفعيل"];
    self.statusLabel.hidden = NO;
    self.statusLabel.alpha = 0;
    // FIX: show exit button so user can dismiss after a failed attempt
    self.exitButton.hidden = NO;
    [UIView animateWithDuration:[WolFoxProTheme transitionDuration] animations:^{
        self.statusLabel.alpha = 1.0;
        self.exitButton.alpha = 1.0;
    }];
}

- (void)openUpdateURL {
    NSString *rawURL = [self.updateURL stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSURLComponents *components = rawURL.length ? [NSURLComponents componentsWithString:rawURL] : nil;
    NSString *scheme = components.scheme.lowercaseString;
    BOOL secureHTTPS = [scheme isEqualToString:@"https"] && components.host.length > 0 && !components.user.length && !components.password.length;
    NSURL *url = secureHTTPS ? components.URL : nil;
    if (!url) {
        WFLog(@"[WolFox][ACT] blocked_insecure_update_url");
        [self showActivationError:@"رابط التحديث غير آمن أو غير صالح"];
        [self applyStatusStyleForResult:nil];
        return;
    }
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

@end
