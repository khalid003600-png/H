// WFActivationViewController.m - WolFox v.1.0.0 "Royal Final"
#import "WFActivationViewController.h"

#ifndef WOLFOX_LITE
#define WOLFOX_LITE 0
#endif
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
@property (nonatomic, strong) UIButton *showToolButton;
@property (nonatomic, strong) UIButton *skipButton;
@property (nonatomic, strong) NSLayoutConstraint *showToolHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *skipHeightConstraint;
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
#if WOLFOX_LITE
    titleLabel.text = @"WolFox Lite";
#else
    titleLabel.text = @"WolFox Full";
#endif
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
#if WOLFOX_LITE
    subtitle.text = @"WolFox Lite";
#else
    subtitle.text = @"WolFox Full";
#endif
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
    self.codeField.font = [UIFont monospacedSystemFontOfSize:17 weight:UIFontWeightBold];
    self.codeField.adjustsFontSizeToFitWidth = YES;
    self.codeField.minimumFontSize = 11.0;
    self.codeField.delegate = self;
    self.codeField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.codeField.accessibilityLabel = @"كود تفعيل WolFox";
    self.codeField.accessibilityHint = @"اكتب الكود أو استخدم زر اللصق ثم اضغط تحقق وتفعيل";
    [self.codeField addTarget:self action:@selector(activationCodeEditingChanged:) forControlEvents:UIControlEventEditingChanged];
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
    [self.activateButton setTitle:@"تحقق من الكود وتفعيل الأداة" forState:UIControlStateNormal];
    [self.activateButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.activateButton.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBlack];
    
    // Add Shadow to Button
    self.activateButton.layer.shadowColor = [WolFoxProTheme royalBlue].CGColor;
    self.activateButton.layer.shadowOffset = CGSizeMake(0, 4);
    self.activateButton.layer.shadowOpacity = 0.8;
    self.activateButton.layer.shadowRadius = 10;
    self.activateButton.accessibilityLabel = @"تحقق من كود التفعيل";
    self.activateButton.accessibilityHint = @"يتحقق من صلاحية الكود ثم يعرض تفاصيل الاشتراك";
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
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.accessibilityTraits = UIAccessibilityTraitUpdatesFrequently;
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

    self.showToolButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.showToolButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.showToolButton.backgroundColor = [WolFoxProTheme royalBlue];
    self.showToolButton.layer.cornerRadius = 12.0;
    [self.showToolButton setTitle:@"فتح لوحة WolFox الآن" forState:UIControlStateNormal];
    [self.showToolButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.showToolButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    self.showToolButton.accessibilityLabel = @"فتح لوحة WolFox بعد نجاح التفعيل";
    [self.showToolButton addTarget:self action:@selector(showToolPressed) forControlEvents:UIControlEventTouchUpInside];
    self.showToolButton.hidden = YES;
    [card addSubview:self.showToolButton];

    self.skipButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.skipButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.skipButton.backgroundColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.16];
    self.skipButton.layer.cornerRadius = 12.0;
    [self.skipButton setTitle:@"البقاء في التطبيق وفتح اللوحة لاحقاً" forState:UIControlStateNormal];
    [self.skipButton setTitleColor:[WolFoxProTheme textPrimary] forState:UIControlStateNormal];
    self.skipButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    self.skipButton.accessibilityLabel = @"إغلاق نتيجة التفعيل وفتح اللوحة لاحقاً";
    [self.skipButton addTarget:self action:@selector(skipPressed) forControlEvents:UIControlEventTouchUpInside];
    self.skipButton.hidden = YES;
    [card addSubview:self.skipButton];

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

        [self.showToolButton.topAnchor constraintEqualToAnchor:self.updateButton.bottomAnchor constant:10],
        [self.showToolButton.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24],
        [self.showToolButton.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-24],
        self.showToolHeightConstraint = [self.showToolButton.heightAnchor constraintEqualToConstant:0],

        [self.skipButton.topAnchor constraintEqualToAnchor:self.showToolButton.bottomAnchor constant:8],
        [self.skipButton.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24],
        [self.skipButton.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-24],
        self.skipHeightConstraint = [self.skipButton.heightAnchor constraintEqualToConstant:0],

        [self.uuidLabel.topAnchor constraintEqualToAnchor:self.skipButton.bottomAnchor constant:12],
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
    [self activationCodeEditingChanged:self.codeField];
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
    self.codeField.text = [self normalizedActivationCode:text];
    self.statusLabel.hidden = YES;
    self.statusLabel.text = @"";
    [self activationCodeEditingChanged:self.codeField];
    [self.codeField becomeFirstResponder];
}

- (NSString *)normalizedActivationCode:(NSString *)value {
    NSString *upper = [[value ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    NSArray<NSString *> *parts = [upper componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return [parts componentsJoinedByString:@""];
}

- (void)activationCodeEditingChanged:(UITextField *)field {
    NSString *normalized = [self normalizedActivationCode:field.text];
    if (![field.text isEqualToString:normalized]) field.text = normalized;
    BOOL hasCode = normalized.length > 0;
    self.activateButton.alpha = hasCode ? 1.0 : 0.55;
    self.activateButton.accessibilityValue = hasCode ? @"الكود جاهز للتحقق" : @"أدخل الكود أولاً";
    if (!self.activateButton.enabled && !self.loadingOverlay.hidden) return;
    self.activateButton.enabled = hasCode;
    if (!self.statusLabel.hidden) {
        self.statusLabel.hidden = YES;
        self.statusLabel.text = @"";
    }
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
    NSString *code = [self normalizedActivationCode:self.codeField.text];
    self.codeField.text = code;
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
    NSString *code = [self normalizedActivationCode:self.codeField.text];
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
            self.showToolHeightConstraint.constant = 44.0;
            self.skipHeightConstraint.constant = 40.0;
            self.timerLabel.hidden = YES;
            [self.lockIcon.layer removeAllAnimations];
            self.lockIcon.image = [UIImage systemImageNamed:@"checkmark.shield.fill"];
            self.lockIcon.tintColor = [WolFoxProTheme success];
            self.statusLabel.textColor = [UIColor colorWithRed:0.45 green:1.0 blue:0.62 alpha:1.0];
            self.statusLabel.backgroundColor = [UIColor colorWithRed:0.04 green:0.25 blue:0.14 alpha:0.82];
            self.statusLabel.layer.borderColor = [[WolFoxProTheme success] colorWithAlphaComponent:0.78].CGColor;
            self.statusLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightSemibold];
            self.statusLabel.text = [self successActivationMessage:result];
            self.statusLabel.hidden = NO;
            self.showToolButton.hidden = NO;
            self.skipButton.hidden = NO;
            self.activateButton.enabled = NO;
            [self.activateButton setTitle:@"✓ الكود صالح وتم التفعيل" forState:UIControlStateNormal];
            self.codeField.enabled = NO;
            self.exitButton.hidden = YES;
            [UIView animateWithDuration:[WolFoxProTheme transitionDuration] animations:^{ self.loadingOverlay.alpha = 0; } completion:^(BOOL finished) {
                self.loadingOverlay.hidden = YES;
            }];
            UINotificationFeedbackGenerator *feedback = [UINotificationFeedbackGenerator new];
            [feedback prepare];
            [feedback notificationOccurred:UINotificationFeedbackTypeSuccess];
            
            // يبقى ملخص التفعيل ظاهراً حتى يختار العميل عرض الأداة أو التخطي.
            [self showToastMessage:@"تم التفعيل. راجع تفاصيل الاشتراك ثم افتح لوحة WolFox."];
            UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, self.statusLabel);
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
                [self.activateButton setTitle:@"إعادة التحقق من الكود" forState:UIControlStateNormal];
                self.timerLabel.hidden = NO;
            }];
        }
    }];
}

- (NSString *)friendlyActivationMessage:(WFLicenseResult *)result {
    switch (result.status) {
        case WFLicenseStatusInvalid:
            return @"الكود غير صحيح أو غير مسجل. راجع الأحرف وحاول مرة أخرى.";
        case WFLicenseStatusDeviceRecovery:
            return @"هذا الكود مرتبط بجهاز آخر. استخدم كوداً مخصصاً لهذا الجهاز.";
        case WFLicenseStatusNetworkError:
            return @"تعذر الاتصال بخادم التفعيل. تحقق من الإنترنت ثم حاول مرة أخرى.";
        case WFLicenseStatusProjectDisabled:
            return @"تعذر التحقق من إعدادات المشروع. تواصل مع الدعم.";
        case WFLicenseStatusExpired:
            return @"انتهت صلاحية هذا الكود. اطلب كوداً جديداً.";
        case WFLicenseStatusBlocked:
            return @"تم إيقاف هذا الكود من لوحة الإدارة. تواصل مع الدعم.";
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
    return [NSString stringWithFormat:@"✅ تم التفعيل بنجاح\nالباقة: %@\nبداية الاشتراك: %@\nنهاية الاشتراك: %@\nالجهاز: مرتبط ومصرّح", plan, started, expires];
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
    self.statusLabel.layer.borderColor = [(deviceRecovery ? [UIColor systemOrangeColor] : [WolFoxProTheme danger]) colorWithAlphaComponent:0.75].CGColor;
}

- (void)showActivationError:(NSString *)message {
    self.statusLabel.textColor = [UIColor colorWithRed:1.0 green:0.50 blue:0.50 alpha:1.0];
    self.statusLabel.backgroundColor = [UIColor colorWithRed:0.35 green:0.08 blue:0.10 alpha:0.78];
    self.statusLabel.layer.borderColor = [[WolFoxProTheme danger] colorWithAlphaComponent:0.80].CGColor;
    self.showToolHeightConstraint.constant = 0.0;
    self.skipHeightConstraint.constant = 0.0;
    self.showToolButton.hidden = YES;
    self.skipButton.hidden = YES;
    self.lockIcon.image = [UIImage systemImageNamed:@"exclamationmark.triangle.fill"];
    self.lockIcon.tintColor = [WolFoxProTheme danger];
    self.statusLabel.text = [NSString stringWithFormat:@"❌ تعذّر تفعيل الكود\n%@\nتحقق من الكود ثم حاول مرة أخرى.", message ?: @"تعذر إكمال التفعيل"];
    self.statusLabel.hidden = NO;
    self.statusLabel.alpha = 0;
    // FIX: show exit button so user can dismiss after a failed attempt
    self.exitButton.hidden = NO;
    [UIView animateWithDuration:[WolFoxProTheme transitionDuration] animations:^{
        self.statusLabel.alpha = 1.0;
        self.exitButton.alpha = 1.0;
        [self.view layoutIfNeeded];
    }];
}

- (void)showToolPressed {
    [self.view endEditing:YES];
    [self dismissViewControllerAnimated:YES completion:^{
        WFLog(@"[WolFox][ACT] activation_view_dismissed_show_tool");
        if (self.completion) self.completion(YES);
    }];
}

- (void)skipPressed {
    [self.view endEditing:YES];
    [self dismissViewControllerAnimated:YES completion:^{
        WFLog(@"[WolFox][ACT] activation_view_dismissed_skip");
    }];
}

- (void)showToastMessage:(NSString *)message {
    // رسالة نجاح صغيرة داخل بطاقة التفعيل، بدون الاعتماد على نافذة خارجية.
    self.statusLabel.accessibilityValue = message;
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
