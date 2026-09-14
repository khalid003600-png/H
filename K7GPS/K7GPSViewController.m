#import "K7GPSViewController.h"
#import "K7GPSStore.h"
#import <MapKit/MapKit.h>
#import <PhotosUI/PhotosUI.h>

@interface K7GPSViewController () <MKMapViewDelegate, CLLocationManagerDelegate, UITextFieldDelegate, PHPickerViewControllerDelegate>
@property(nonatomic,strong) UIScrollView *scroll;
@property(nonatomic,strong) MKMapView *mapView;
@property(nonatomic,strong) UITextField *searchField;
@property(nonatomic,strong) UISwitch *gpsSwitch;
@property(nonatomic,strong) UISwitch *cameraSwitch;
@property(nonatomic,strong) CLLocationManager *locationManager;
@property(nonatomic,strong) UIImage *selectedImage;
@end

@implementation K7GPSViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.06 alpha:1.0];
    self.locationManager = [CLLocationManager new];
    self.locationManager.delegate = self;
    [self buildUI];
    [self restoreUIState];
}

- (UILabel *)label:(NSString *)text frame:(CGRect)frame size:(CGFloat)size weight:(UIFontWeight)weight {
    UILabel *l = [[UILabel alloc] initWithFrame:frame];
    l.text = text; l.textColor = UIColor.whiteColor; l.textAlignment = NSTextAlignmentCenter;
    l.font = [UIFont systemFontOfSize:size weight:weight]; return l;
}

- (UIButton *)button:(NSString *)title frame:(CGRect)frame selector:(SEL)selector {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = frame; b.layer.cornerRadius = 16; b.layer.borderWidth = 1;
    b.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12].CGColor;
    b.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    [b setTitle:title forState:UIControlStateNormal]; [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    [b addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside]; return b;
}

- (void)buildUI {
    CGFloat w = self.view.bounds.size.width;
    self.scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.scroll];

    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(14, 20, w - 28, 1040)];
    panel.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0]; panel.layer.cornerRadius = 28;
    [self.scroll addSubview:panel];

    UILabel *title = [self label:@"K7GPS" frame:CGRectMake(70, 22, 180, 42) size:28 weight:UIFontWeightBlack];
    title.textAlignment = NSTextAlignmentLeft; [panel addSubview:title];

    self.searchField = [[UITextField alloc] initWithFrame:CGRectMake(24, 74, panel.bounds.size.width - 48, 48)];
    self.searchField.placeholder = @"إحداثيات أو عنوان"; self.searchField.textAlignment = NSTextAlignmentRight;
    self.searchField.textColor = UIColor.whiteColor; self.searchField.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    self.searchField.layer.cornerRadius = 18; self.searchField.delegate = self; self.searchField.returnKeyType = UIReturnKeySearch;
    [panel addSubview:self.searchField];

    [panel addSubview:[self button:@"المحفوظات" frame:CGRectMake(24,145,108,54) selector:@selector(savedPressed)]];
    [panel addSubview:[self button:@"حفظ" frame:CGRectMake(144,145,108,54) selector:@selector(savePressed)]];
    [panel addSubview:[self button:@"استعادة" frame:CGRectMake(264,145,108,54) selector:@selector(restorePressed)]];

    self.mapView = [[MKMapView alloc] initWithFrame:CGRectMake(24,220,panel.bounds.size.width-48,260)];
    self.mapView.layer.cornerRadius = 24; self.mapView.clipsToBounds = YES; self.mapView.delegate = self;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(mapTapped:)];
    [self.mapView addGestureRecognizer:tap]; [panel addSubview:self.mapView];

    UISegmentedControl *mode = [[UISegmentedControl alloc] initWithItems:@[@"عادي",@"قمر صناعي"]];
    mode.frame = CGRectMake(24,500,200,46); mode.selectedSegmentIndex = 0;
    [mode addTarget:self action:@selector(mapModeChanged:) forControlEvents:UIControlEventValueChanged]; [panel addSubview:mode];
    [panel addSubview:[self button:@"موقعي" frame:CGRectMake(236,500,136,46) selector:@selector(myLocationPressed)]];

    UIView *gpsCard = [[UIView alloc] initWithFrame:CGRectMake(24,560,panel.bounds.size.width-48,72)];
    gpsCard.layer.cornerRadius = 18; gpsCard.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08]; [panel addSubview:gpsCard];
    UILabel *gpsLabel = [self label:@"تفعيل تغيير الموقع" frame:CGRectMake(20,0,230,72) size:20 weight:UIFontWeightBold]; gpsLabel.textAlignment = NSTextAlignmentRight; [gpsCard addSubview:gpsLabel];
    self.gpsSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(gpsCard.bounds.size.width-74,20,50,32)];
    [self.gpsSwitch addTarget:self action:@selector(gpsSwitchChanged:) forControlEvents:UIControlEventValueChanged]; [gpsCard addSubview:self.gpsSwitch];

    [panel addSubview:[self button:@"مسار" frame:CGRectMake(24,650,108,54) selector:@selector(routePressed)]];
    [panel addSubview:[self button:@"عشوائي" frame:CGRectMake(144,650,108,54) selector:@selector(randomPressed)]];
    [panel addSubview:[self button:@"الجدولة" frame:CGRectMake(264,650,108,54) selector:@selector(schedulePressed)]];

    UIView *cameraCard = [[UIView alloc] initWithFrame:CGRectMake(24,720,panel.bounds.size.width-48,118)];
    cameraCard.layer.cornerRadius = 20; cameraCard.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08]; [panel addSubview:cameraCard];
    UILabel *cam = [self label:@"صورة بديلة" frame:CGRectMake(22,10,180,44) size:20 weight:UIFontWeightBold]; cam.textAlignment = NSTextAlignmentRight; [cameraCard addSubview:cam];
    self.cameraSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(cameraCard.bounds.size.width-74,16,50,32)];
    [self.cameraSwitch addTarget:self action:@selector(cameraSwitchChanged:) forControlEvents:UIControlEventValueChanged]; [cameraCard addSubview:self.cameraSwitch];
    [cameraCard addSubview:[self button:@"عكس" frame:CGRectMake(20,64,92,40) selector:@selector(flipPressed)]];
    [cameraCard addSubview:[self button:@"رفع" frame:CGRectMake(124,64,92,40) selector:@selector(uploadPressed)]];
    [cameraCard addSubview:[self button:@"حذف" frame:CGRectMake(228,64,92,40) selector:@selector(deletePressed)]];

    [panel addSubview:[self button:@"البلوتوث" frame:CGRectMake(24,856,168,58) selector:@selector(bluetoothPressed)]];
    [panel addSubview:[self button:@"الواي فاي" frame:CGRectMake(204,856,168,58) selector:@selector(wifiPressed)]];
    [panel addSubview:[self button:@"إيقاف الكل" frame:CGRectMake(24,930,108,50) selector:@selector(stopAllPressed)]];
    [panel addSubview:[self button:@"إخفاء الأداة" frame:CGRectMake(144,930,108,50) selector:@selector(hidePressed)]];
    [panel addSubview:[self button:@"تخصيص" frame:CGRectMake(264,930,108,50) selector:@selector(customizePressed)]];

    self.scroll.contentSize = CGSizeMake(w, CGRectGetMaxY(panel.frame)+30);
}

- (void)restoreUIState {
    K7GPSStore *s = [K7GPSStore shared];
    self.gpsSwitch.on = s.locationEnabled; self.cameraSwitch.on = s.cameraEnabled;
    if (CLLocationCoordinate2DIsValid(s.selectedCoordinate)) [self showCoordinate:s.selectedCoordinate title:s.selectedTitle.length ? s.selectedTitle : @"الموقع المحفوظ"];
}

- (void)showCoordinate:(CLLocationCoordinate2D)c title:(NSString *)title {
    [self.mapView removeAnnotations:self.mapView.annotations];
    MKPointAnnotation *a = [MKPointAnnotation new]; a.coordinate = c; a.title = title; [self.mapView addAnnotation:a];
    [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(c,2500,2500) animated:YES];
    K7GPSStore *s = [K7GPSStore shared]; s.selectedCoordinate = c; s.selectedTitle = title ?: @""; [s save];
}

- (void)mapTapped:(UITapGestureRecognizer *)tap {
    CGPoint p = [tap locationInView:self.mapView]; CLLocationCoordinate2D c = [self.mapView convertPoint:p toCoordinateFromView:self.mapView];
    [self showCoordinate:c title:@"موقع محدد"];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField { [textField resignFirstResponder]; [self performSearch:textField.text]; return YES; }

- (void)performSearch:(NSString *)query {
    NSString *q = [query stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]; if (!q.length) return;
    NSArray *parts = [q componentsSeparatedByString:@","];
    if (parts.count == 2) {
        double lat = [parts[0] doubleValue], lon = [parts[1] doubleValue];
        CLLocationCoordinate2D c = CLLocationCoordinate2DMake(lat,lon);
        if (CLLocationCoordinate2DIsValid(c)) { [self showCoordinate:c title:@"إحداثيات"]; return; }
    }
    MKLocalSearchRequest *r = [MKLocalSearchRequest new]; r.naturalLanguageQuery = q;
    [[[MKLocalSearch alloc] initWithRequest:r] startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || response.mapItems.count == 0) { [self showMessage:@"لم يتم العثور على نتيجة"]; return; }
            MKMapItem *item = response.mapItems.firstObject;
            [self showCoordinate:item.placemark.coordinate title:item.name ?: q];
        });
    }];
}

- (void)mapModeChanged:(UISegmentedControl *)sender { self.mapView.mapType = sender.selectedSegmentIndex == 1 ? MKMapTypeSatellite : MKMapTypeStandard; }
- (void)gpsSwitchChanged:(UISwitch *)sender { K7GPSStore.shared.locationEnabled = sender.on; [K7GPSStore.shared save]; }
- (void)cameraSwitchChanged:(UISwitch *)sender { K7GPSStore.shared.cameraEnabled = sender.on; [K7GPSStore.shared save]; }

- (void)savePressed {
    CLLocationCoordinate2D c = K7GPSStore.shared.selectedCoordinate;
    if (!CLLocationCoordinate2DIsValid(c)) { [self showMessage:@"حدد موقعاً أولاً"]; return; }
    [K7GPSStore.shared addSavedLocationWithTitle:K7GPSStore.shared.selectedTitle coordinate:c]; [self showMessage:@"تم حفظ الموقع"];
}

- (void)savedPressed {
    NSArray *items = K7GPSStore.shared.savedLocations;
    if (!items.count) { [self showMessage:@"لا توجد مواقع محفوظة"]; return; }
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"المحفوظات" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *item in items) {
        NSString *title = item[@"title"] ?: @"موقع محفوظ";
        [a addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            CLLocationCoordinate2D c = CLLocationCoordinate2DMake([item[@"lat"] doubleValue],[item[@"lon"] doubleValue]); [self showCoordinate:c title:title];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]]; [self presentSheet:a];
}

- (void)restorePressed { [self restoreUIState]; [self showMessage:@"تمت استعادة آخر إعدادات محفوظة"]; }
- (void)myLocationPressed { [self.locationManager requestWhenInUseAuthorization]; [self.locationManager requestLocation]; }
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations { CLLocation *l = locations.lastObject; if (l) [self showCoordinate:l.coordinate title:@"موقعي الحالي"]; }
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error { [self showMessage:@"تعذر قراءة الموقع الحالي"]; }

- (void)uploadPressed {
    if (@available(iOS 14.0,*)) { PHPickerConfiguration *c=[PHPickerConfiguration new]; c.filter=[PHPickerFilter imagesFilter]; c.selectionLimit=1; PHPickerViewController *p=[[PHPickerViewController alloc] initWithConfiguration:c]; p.delegate=self; [self presentViewController:p animated:YES completion:nil]; }
}
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results { [picker dismissViewControllerAnimated:YES completion:nil]; NSItemProvider *provider=results.firstObject.itemProvider; if ([provider canLoadObjectOfClass:UIImage.class]) [provider loadObjectOfClass:UIImage.class completionHandler:^(UIImage *image,NSError *error){ self.selectedImage=image; }]; }
- (void)flipPressed { if (!self.selectedImage) { [self showMessage:@"ارفع صورة أولاً"]; return; } UIImage *img=[UIImage imageWithCGImage:self.selectedImage.CGImage scale:self.selectedImage.scale orientation:UIImageOrientationUpMirrored]; self.selectedImage=img; [self showMessage:@"تم عكس الصورة"]; }
- (void)deletePressed { self.selectedImage=nil; self.cameraSwitch.on=NO; K7GPSStore.shared.cameraEnabled=NO; [K7GPSStore.shared save]; [self showMessage:@"تم حذف الصورة البديلة"]; }

- (void)routePressed { [self showMessage:@"تم تجهيز زر المسار؛ ربط محرك الحركة يتم في طبقة التنفيذ."]; }
- (void)randomPressed { [self showMessage:@"تم تجهيز الوضع العشوائي؛ إعداد النطاق والمدة في الخطوة التالية."]; }
- (void)schedulePressed { [self showMessage:@"تم تجهيز الجدولة؛ سيتم ربط الوقت بالمواقع المحفوظة."]; }
- (void)bluetoothPressed { [self showMessage:@"قسم البلوتوث جاهز للربط مع إعدادات التطبيق."]; }
- (void)wifiPressed { [self showMessage:@"قسم الواي فاي جاهز للربط مع إعدادات التطبيق."]; }
- (void)customizePressed { [self showHideOptions]; }

- (void)stopAllPressed {
    self.gpsSwitch.on=NO; self.cameraSwitch.on=NO; K7GPSStore.shared.locationEnabled=NO; K7GPSStore.shared.cameraEnabled=NO; [K7GPSStore.shared save]; [self showMessage:@"تم إيقاف جميع الوظائف"];
}
- (void)hidePressed { [self showHideOptions]; }

- (void)showHideOptions {
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"إخفاء الأداة" message:@"اختر طريقة الإظهار بعد الإخفاء" preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *items=@[@"هز الجهاز",@"3 ضغطات",@"5 ضغطات",@"7 ضغطات",@"ضغط مطوّل"];
    [items enumerateObjectsUsingBlock:^(NSString *item,NSUInteger idx,BOOL *stop){ [a addAction:[UIAlertAction actionWithTitle:item style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action){ K7GPSStore.shared.revealMode=(NSInteger)idx; [K7GPSStore.shared save]; [self showMessage:[NSString stringWithFormat:@"تم اختيار: %@",item]]; }]]; }];
    [a addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]]; [self presentSheet:a];
}

- (void)presentSheet:(UIAlertController *)a { if (a.popoverPresentationController) { a.popoverPresentationController.sourceView=self.view; a.popoverPresentationController.sourceRect=CGRectMake(CGRectGetMidX(self.view.bounds),CGRectGetMidY(self.view.bounds),1,1); } [self presentViewController:a animated:YES completion:nil]; }
- (void)showMessage:(NSString *)message { UIAlertController *a=[UIAlertController alertControllerWithTitle:@"K7GPS" message:message preferredStyle:UIAlertControllerStyleAlert]; [a addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]]; [self presentViewController:a animated:YES completion:nil]; }

@end
