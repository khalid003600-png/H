#import "FGWActivationViewController.h"

static NSString * const kFGWDefaultsSuite = @"com.locationspoofer.dylib";
static NSString * const kFGWActivatedKey = @"FGWActivationValidated";
static NSString * const kFGWActivationBaseURL = @"https://gps.p3nd.fun/api/v1";

@interface FGWActivationViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UIView *dimmingView;
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UITextField *codeField;
@property (nonatomic, strong) UIButton *activateButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation FGWActivationViewController

+ (BOOL)isLocallyActivated {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kFGWDefaultsSuite];
    return [defaults boolForKey:kFGWActivatedKey];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;

    self.dimmingView = [[UIView alloc] init];
    self.dimmingView.translatesAutoresizingMaskIntoConstraints = NO;
    self.dimmingView.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.68];
    [self.view addSubview:self.dimmingView];

    self.cardView = [[UIView alloc] init];
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cardView.backgroundColor = [UIColor colorWithRed:0.025 green:0.055 blue:0.09 alpha:0.98];
    self.cardView.layer.cornerRadius = 24.0;
    self.cardView.layer.cornerCurve = kCACornerCurveContinuous;
    self.cardView.layer.borderWidth = 1.0;
    self.cardView.layer.borderColor = [UIColor colorWithRed:0.18 green:0.48 blue:1.0 alpha:0.65].CGColor;
    self.cardView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.cardView.layer.shadowOpacity = 0.45;
    self.cardView.layer.shadowRadius = 24.0;
    self.cardView.layer.shadowOffset = CGSizeMake(0, 12);
    [self.view addSubview:self.cardView];

    UIView *header = [[UIView alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.backgroundColor = [UIColor colorWithRed:0.018 green:0.035 blue:0.06 alpha:1.0];
    header.layer.cornerRadius = 24.0;
    header.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    [self.cardView addSubview:header];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.translatesAutoresizingMaskIntoConstraints = NO;
    close.backgroundColor = [UIColor colorWithRed:0.82 green:0.06 blue:0.10 alpha:1.0];
    close.tintColor = UIColor.whiteColor;
    close.layer.cornerRadius = 20.0;
    [close setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
    [close addTarget:self action:@selector(closePressed) forControlEvents:UIControlEventTouchUpInside];
    close.accessibilityLabel = @"إغلاق";
    [header addSubview:close];

    UIImageView *crown = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"crown.fill"]];
    crown.translatesAutoresizingMaskIntoConstraints = NO;
    crown.tintColor = [UIColor colorWithRed:0.08 green:0.47 blue:1.0 alpha:1.0];
    crown.contentMode = UIViewContentModeScaleAspectFit;
    [header addSubview:crown];

    UILabel *name = [[UILabel alloc] init];
    name.translatesAutoresizingMaskIntoConstraints = NO;
    name.text = @"Fake GPS Wolf";
    name.font = [UIFont systemFontOfSize:21.0 weight:UIFontWeightBold];
    name.textColor = UIColor.whiteColor;
    name.textAlignment = NSTextAlignmentCenter;
    [header addSubview:name];

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = @"تفعيل آمن وسريع";
    subtitle.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    subtitle.textColor = [UIColor colorWithWhite:0.68 alpha:1.0];
    subtitle.textAlignment = NSTextAlignmentCenter;
    [header addSubview:subtitle];

    UIImageView *lock = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"lock.fill"]];
    lock.translatesAutoresizingMaskIntoConstraints = NO;
    lock.tintColor = [UIColor colorWithRed:0.30 green:0.55 blue:1.0 alpha:1.0];
    lock.contentMode = UIViewContentModeScaleAspectFit;
    [self.cardView addSubview:lock];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"أدخل كود التفعيل";
    title.font = [UIFont systemFontOfSize:27.0 weight:UIFontWeightBold];
    title.textColor = UIColor.whiteColor;
    title.textAlignment = NSTextAlignmentCenter;
    [self.cardView addSubview:title];

    UILabel *message = [[UILabel alloc] init];
    message.translatesAutoresizingMaskIntoConstraints = NO;
    message.text = @"أدخل الكود للاستفادة من التفعيل، ويمكنك إغلاق النافذة بدون فقد بياناتك.";
    message.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightRegular];
    message.textColor = [UIColor colorWithWhite:0.67 alpha:1.0];
    message.textAlignment = NSTextAlignmentCenter;
    message.numberOfLines = 2;
    [self.cardView addSubview:message];

    self.codeField = [[UITextField alloc] init];
    self.codeField.translatesAutoresizingMaskIntoConstraints = NO;
    self.codeField.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.055];
    self.codeField.layer.cornerRadius = 14.0;
    self.codeField.layer.cornerCurve = kCACornerCurveContinuous;
    self.codeField.layer.borderWidth = 1.0;
    self.codeField.layer.borderColor = [UIColor colorWithRed:0.25 green:0.45 blue:0.72 alpha:0.75].CGColor;
    self.codeField.textColor = UIColor.whiteColor;
    self.codeField.tintColor = [UIColor colorWithRed:0.15 green:0.5 blue:1.0 alpha:1.0];
    self.codeField.font = [UIFont monospacedSystemFontOfSize:15.0 weight:UIFontWeightSemibold];
    self.codeField.textAlignment = NSTextAlignmentCenter;
    self.codeField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.codeField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.codeField.spellCheckingType = UITextSpellCheckingTypeNo;
    self.codeField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.codeField.placeholder = @"مثال: WOLF-2026-ABCD-1234";
    self.codeField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:self.codeField.placeholder attributes:@{NSForegroundColorAttributeName:[UIColor colorWithWhite:0.48 alpha:1.0]}];
    self.codeField.delegate = self;

    UIButton *paste = [UIButton buttonWithType:UIButtonTypeSystem];
    paste.frame = CGRectMake(0, 0, 46, 46);
    paste.tintColor = UIColor.whiteColor;
    [paste setImage:[UIImage systemImageNamed:@"doc.on.clipboard"] forState:UIControlStateNormal];
    [paste addTarget:self action:@selector(pastePressed) forControlEvents:UIControlEventTouchUpInside];
    self.codeField.leftView = paste;
    self.codeField.leftViewMode = UITextFieldViewModeAlways;
    [self.cardView addSubview:self.codeField];

    self.activateButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.activateButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.activateButton.backgroundColor = [UIColor colorWithRed:0.04 green:0.42 blue:1.0 alpha:1.0];
    self.activateButton.layer.cornerRadius = 14.0;
    self.activateButton.layer.cornerCurve = kCACornerCurveContinuous;
    [self.activateButton setTitle:@"تفعيل" forState:UIControlStateNormal];
    [self.activateButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.activateButton.titleLabel.font = [UIFont systemFontOfSize:19.0 weight:UIFontWeightBold];
    [self.activateButton addTarget:self action:@selector(activatePressed) forControlEvents:UIControlEventTouchUpInside];
    [self.cardView addSubview:self.activateButton];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.spinner.hidesWhenStopped = YES;
    self.spinner.color = UIColor.whiteColor;
    [self.activateButton addSubview:self.spinner];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 3;
    self.statusLabel.textColor = [UIColor colorWithWhite:0.68 alpha:1.0];
    self.statusLabel.text = @"لن يتم حذف مواقعك المحفوظة أو إعداداتك عند الإغلاق.";
    [self.cardView addSubview:self.statusLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.dimmingView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.dimmingView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.dimmingView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.dimmingView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.cardView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.cardView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.cardView.widthAnchor constraintEqualToAnchor:self.view.widthAnchor multiplier:0.86],
        [header.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor],
        [header.topAnchor constraintEqualToAnchor:self.cardView.topAnchor],
        [header.heightAnchor constraintEqualToConstant:94.0],
        [close.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:14.0],
        [close.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [close.widthAnchor constraintEqualToConstant:40.0],
        [close.heightAnchor constraintEqualToConstant:40.0],
        [crown.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-17.0],
        [crown.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [crown.widthAnchor constraintEqualToConstant:31.0],
        [crown.heightAnchor constraintEqualToConstant:31.0],
        [name.centerXAnchor constraintEqualToAnchor:header.centerXAnchor],
        [name.topAnchor constraintEqualToAnchor:header.topAnchor constant:20.0],
        [subtitle.centerXAnchor constraintEqualToAnchor:header.centerXAnchor],
        [subtitle.topAnchor constraintEqualToAnchor:name.bottomAnchor constant:4.0],
        [lock.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:28.0],
        [lock.centerXAnchor constraintEqualToAnchor:self.cardView.centerXAnchor],
        [lock.widthAnchor constraintEqualToConstant:50.0],
        [lock.heightAnchor constraintEqualToConstant:50.0],
        [title.topAnchor constraintEqualToAnchor:lock.bottomAnchor constant:18.0],
        [title.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:20.0],
        [title.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-20.0],
        [message.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8.0],
        [message.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:24.0],
        [message.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-24.0],
        [self.codeField.topAnchor constraintEqualToAnchor:message.bottomAnchor constant:22.0],
        [self.codeField.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:20.0],
        [self.codeField.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-20.0],
        [self.codeField.heightAnchor constraintEqualToConstant:58.0],
        [self.activateButton.topAnchor constraintEqualToAnchor:self.codeField.bottomAnchor constant:16.0],
        [self.activateButton.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:20.0],
        [self.activateButton.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-20.0],
        [self.activateButton.heightAnchor constraintEqualToConstant:56.0],
        [self.spinner.centerYAnchor constraintEqualToAnchor:self.activateButton.centerYAnchor],
        [self.spinner.centerXAnchor constraintEqualToAnchor:self.activateButton.centerXAnchor constant:-54.0],
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.activateButton.bottomAnchor constant:18.0],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:22.0],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-22.0],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor constant:-22.0]
    ]];
}

- (void)pastePressed {
    NSString *text = UIPasteboard.generalPasteboard.string;
    if (text.length) self.codeField.text = [self normalizedCode:text];
}

- (NSString *)normalizedCode:(NSString *)value {
    NSString *trimmed = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return trimmed.uppercaseString;
}

- (void)setBusy:(BOOL)busy {
    self.activateButton.enabled = !busy;
    self.codeField.enabled = !busy;
    if (busy) {
        [self.spinner startAnimating];
        [self.activateButton setTitle:@"جاري التحقق…" forState:UIControlStateNormal];
    } else {
        [self.spinner stopAnimating];
        [self.activateButton setTitle:@"تفعيل" forState:UIControlStateNormal];
    }
}

- (void)activatePressed {
    NSString *code = [self normalizedCode:self.codeField.text ?: @""];
    self.codeField.text = code;
    if (!code.length) {
        self.statusLabel.textColor = UIColor.systemRedColor;
        self.statusLabel.text = @"أدخل كود التفعيل أولاً.";
        return;
    }

    [self.view endEditing:YES];
    [self setBusy:YES];
    self.statusLabel.textColor = [UIColor colorWithWhite:0.72 alpha:1.0];
    self.statusLabel.text = @"جاري التحقق من الكود…";

    NSURL *url = [NSURL URLWithString:[kFGWActivationBaseURL stringByAppendingString:@"/activate.php"]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSString *deviceID = UIDevice.currentDevice.identifierForVendor.UUIDString ?: @"unknown-device";
    NSDictionary *payload = @{
        @"code": code,
        @"license_code": code,
        @"device_id": deviceID,
        @"device_uuid": deviceID,
        @"bundle_id": NSBundle.mainBundle.bundleIdentifier ?: @"",
        @"target_bundle_id": NSBundle.mainBundle.bundleIdentifier ?: @"",
        @"app_version": @"1.8.6-Lite",
        @"app_name": @"Fake GPS Wolf"
    };
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    request.timeoutInterval = 15.0;

    __weak typeof(self) weakSelf = self;
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self setBusy:NO];
            if (error || !data.length) {
                self.statusLabel.textColor = UIColor.systemOrangeColor;
                self.statusLabel.text = @"المعذرة، لا يوجد اتصال بالخادم. حاول مرة أخرى.";
                return;
            }

            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            BOOL success = [json[@"success"] respondsToSelector:@selector(boolValue)] && [json[@"success"] boolValue];
            NSDictionary *nested = [json[@"data"] isKindOfClass:NSDictionary.class] ? json[@"data"] : nil;
            if (!success && [nested[@"success"] respondsToSelector:@selector(boolValue)]) success = [nested[@"success"] boolValue];

            NSString *serverMessage = [json[@"message"] isKindOfClass:NSString.class] ? json[@"message"] : nil;
            if (!serverMessage.length && [nested[@"message"] isKindOfClass:NSString.class]) serverMessage = nested[@"message"];

            if (success) {
                NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kFGWDefaultsSuite];
                [defaults setBool:YES forKey:kFGWActivatedKey];
                self.statusLabel.textColor = UIColor.systemGreenColor;
                self.statusLabel.text = @"تم تفعيل الكود بنجاح";
                [self dismissViewControllerAnimated:YES completion:self.activationCompleted];
            } else {
                self.statusLabel.textColor = UIColor.systemRedColor;
                self.statusLabel.text = serverMessage.length ? serverMessage : @"هذا الكود غير صحيح. تواصل مع الدعم.";
            }
        });
    }] resume];
}

- (void)closePressed {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self activatePressed];
    return NO;
}

@end
