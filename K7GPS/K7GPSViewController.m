#import "K7GPSViewController.h"

@interface K7GPSViewController ()
@property(nonatomic,strong) UIScrollView *scroll;
@end

@implementation K7GPSViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.06 alpha:1.0];
    [self buildUI];
}

- (UILabel *)label:(NSString *)text frame:(CGRect)frame size:(CGFloat)size weight:(UIFontWeight)weight {
    UILabel *l = [[UILabel alloc] initWithFrame:frame];
    l.text = text;
    l.textColor = UIColor.whiteColor;
    l.textAlignment = NSTextAlignmentCenter;
    l.font = [UIFont systemFontOfSize:size weight:weight];
    return l;
}

- (UIButton *)button:(NSString *)title frame:(CGRect)frame selector:(SEL)selector {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = frame;
    b.layer.cornerRadius = 16;
    b.layer.borderWidth = 1;
    b.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12].CGColor;
    b.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    [b addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (void)buildUI {
    CGFloat w = self.view.bounds.size.width;
    self.scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.scroll];

    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(14, 20, w - 28, 980)];
    panel.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];
    panel.layer.cornerRadius = 28;
    [self.scroll addSubview:panel];

    UILabel *title = [self label:@"K7GPS" frame:CGRectMake(70, 22, 180, 42) size:28 weight:UIFontWeightBlack];
    title.textAlignment = NSTextAlignmentLeft;
    [panel addSubview:title];

    UITextField *search = [[UITextField alloc] initWithFrame:CGRectMake(24, 74, panel.bounds.size.width - 48, 48)];
    search.placeholder = @"إحداثيات / أو عنوان وظيفي";
    search.textAlignment = NSTextAlignmentRight;
    search.textColor = UIColor.whiteColor;
    search.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    search.layer.cornerRadius = 18;
    [panel addSubview:search];

    [panel addSubview:[self button:@"المحفوظات" frame:CGRectMake(24, 145, 108, 54) selector:@selector(savedPressed)]];
    [panel addSubview:[self button:@"حفظ" frame:CGRectMake(144, 145, 108, 54) selector:@selector(savePressed)]];
    [panel addSubview:[self button:@"استعادة" frame:CGRectMake(264, 145, 108, 54) selector:@selector(restorePressed)]];

    UIView *mapCard = [[UIView alloc] initWithFrame:CGRectMake(24, 220, panel.bounds.size.width - 48, 260)];
    mapCard.backgroundColor = [UIColor colorWithRed:0.08 green:0.15 blue:0.36 alpha:1.0];
    mapCard.layer.cornerRadius = 24;
    [panel addSubview:mapCard];
    UILabel *map = [self label:@"خريطة الموقع" frame:CGRectMake(0, 100, mapCard.bounds.size.width, 40) size:22 weight:UIFontWeightBold];
    [mapCard addSubview:map];

    UISegmentedControl *mode = [[UISegmentedControl alloc] initWithItems:@[@"عادي", @"قمر صناعي"]];
    mode.frame = CGRectMake(24, 500, 200, 46);
    mode.selectedSegmentIndex = 0;
    [panel addSubview:mode];

    [panel addSubview:[self button:@"موقعي" frame:CGRectMake(236, 500, 136, 46) selector:@selector(myLocationPressed)]];

    UIView *gpsCard = [[UIView alloc] initWithFrame:CGRectMake(24, 560, panel.bounds.size.width - 48, 72)];
    gpsCard.layer.cornerRadius = 18;
    gpsCard.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    [panel addSubview:gpsCard];
    UILabel *gpsLabel = [self label:@"تفعيل تغيير الموقع" frame:CGRectMake(20, 0, 230, 72) size:20 weight:UIFontWeightBold];
    gpsLabel.textAlignment = NSTextAlignmentRight;
    [gpsCard addSubview:gpsLabel];
    UISwitch *gpsSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(gpsCard.bounds.size.width - 74, 20, 50, 32)];
    [gpsCard addSubview:gpsSwitch];

    [panel addSubview:[self button:@"مسار" frame:CGRectMake(24, 650, 108, 54) selector:@selector(routePressed)]];
    [panel addSubview:[self button:@"عشوائي" frame:CGRectMake(144, 650, 108, 54) selector:@selector(randomPressed)]];
    [panel addSubview:[self button:@"الجدولة" frame:CGRectMake(264, 650, 108, 54) selector:@selector(schedulePressed)]];

    UIView *cameraCard = [[UIView alloc] initWithFrame:CGRectMake(24, 720, panel.bounds.size.width - 48, 118)];
    cameraCard.layer.cornerRadius = 20;
    cameraCard.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    [panel addSubview:cameraCard];
    UILabel *cam = [self label:@"صورة بديلة" frame:CGRectMake(22, 10, 180, 44) size:20 weight:UIFontWeightBold];
    cam.textAlignment = NSTextAlignmentRight;
    [cameraCard addSubview:cam];
    UISwitch *camSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(cameraCard.bounds.size.width - 74, 16, 50, 32)];
    [cameraCard addSubview:camSwitch];
    [cameraCard addSubview:[self button:@"عكس" frame:CGRectMake(20, 64, 92, 40) selector:@selector(flipPressed)]];
    [cameraCard addSubview:[self button:@"رفع" frame:CGRectMake(124, 64, 92, 40) selector:@selector(uploadPressed)]];
    [cameraCard addSubview:[self button:@"حذف" frame:CGRectMake(228, 64, 92, 40) selector:@selector(deletePressed)]];

    [panel addSubview:[self button:@"البلوتوث" frame:CGRectMake(24, 856, 168, 58) selector:@selector(bluetoothPressed)]];
    [panel addSubview:[self button:@"الواي فاي" frame:CGRectMake(204, 856, 168, 58) selector:@selector(wifiPressed)]];

    [panel addSubview:[self button:@"إيقاف الكل" frame:CGRectMake(24, 930, 108, 50) selector:@selector(stopAllPressed)]];
    [panel addSubview:[self button:@"إخفاء الأداة" frame:CGRectMake(144, 930, 108, 50) selector:@selector(hidePressed)]];
    [panel addSubview:[self button:@"تخصيص" frame:CGRectMake(264, 930, 108, 50) selector:@selector(customizePressed)]];

    self.scroll.contentSize = CGSizeMake(w, CGRectGetMaxY(panel.frame) + 30);
}

- (void)showMessage:(NSString *)message {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"K7GPS" message:message preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)savedPressed { [self showMessage:@"المحفوظات"]; }
- (void)savePressed { [self showMessage:@"تم طلب الحفظ"]; }
- (void)restorePressed { [self showMessage:@"تم طلب الاستعادة"]; }
- (void)myLocationPressed { [self showMessage:@"موقعي"]; }
- (void)routePressed { [self showMessage:@"المسار"]; }
- (void)randomPressed { [self showMessage:@"الوضع العشوائي"]; }
- (void)schedulePressed { [self showMessage:@"الجدولة"]; }
- (void)flipPressed { [self showMessage:@"عكس الصورة"]; }
- (void)uploadPressed { [self showMessage:@"رفع صورة"]; }
- (void)deletePressed { [self showMessage:@"حذف الصورة"]; }
- (void)bluetoothPressed { [self showMessage:@"البلوتوث"]; }
- (void)wifiPressed { [self showMessage:@"الواي فاي"]; }
- (void)stopAllPressed { [self showMessage:@"إيقاف الكل"]; }
- (void)hidePressed { [self showHideOptions]; }
- (void)customizePressed { [self showMessage:@"التخصيص"]; }

- (void)showHideOptions {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"إخفاء الأداة" message:@"اختر طريقة الإظهار بعد الإخفاء" preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *items = @[@"هز الجهاز", @"3 ضغطات", @"5 ضغطات", @"7 ضغطات", @"ضغط مطوّل"];
    for (NSString *item in items) {
        [a addAction:[UIAlertAction actionWithTitle:item style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [self showMessage:[NSString stringWithFormat:@"تم اختيار: %@", item]];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    if (a.popoverPresentationController) {
        a.popoverPresentationController.sourceView = self.view;
        a.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
    }
    [self presentViewController:a animated:YES completion:nil];
}

@end
