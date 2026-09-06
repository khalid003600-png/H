#import "WFWhatsAppLocationViewController.h"
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import "WFLicenseClient.h"
#import "WolFoxProStore.h"
#import "WolFoxProHookManager.h"
#import "WFActivationViewController.h"

@interface WFWhatsAppLocationViewController () <UISearchBarDelegate, MKMapViewDelegate>
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) UIButton *toggleButton;
@property (nonatomic, strong) UIButton *settingsButton;
@property (nonatomic, strong) MKPointAnnotation *pin;
@end

@implementation WFWhatsAppLocationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [self buildUI];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (![WFLicenseClient isRuntimeLicenseValid]) {
        WFActivationViewController *activation = [WFActivationViewController new];
        activation.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:activation animated:YES completion:nil];
    }
}

- (void)buildUI {
    CGFloat w = self.view.bounds.size.width;
    CGFloat top = 56.0;

    UIView *searchWrap = [[UIView alloc] initWithFrame:CGRectMake(14, top, w - 28, 48)];
    searchWrap.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:searchWrap];

    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, searchWrap.bounds.size.width, 48)];
    self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"ابحث بعنوان، إحداثيات أو رابط موقع";
    self.searchBar.searchTextField.accessibilityLabel = @"خانة بحث الموقع";
    [searchWrap addSubview:self.searchBar];

    UIButton *paste = [UIButton buttonWithType:UIButtonTypeSystem];
    paste.frame = CGRectMake(searchWrap.bounds.size.width - 70, 7, 62, 34);
    paste.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [paste setTitle:@"لصق" forState:UIControlStateNormal];
    paste.accessibilityLabel = @"لصق والبحث";
    [paste addTarget:self action:@selector(pastePressed) forControlEvents:UIControlEventTouchUpInside];
    [searchWrap addSubview:paste];

    CGFloat mapY = CGRectGetMaxY(searchWrap.frame) + 10;
    CGFloat bottomSpace = 170.0;
    self.mapView = [[MKMapView alloc] initWithFrame:CGRectMake(14, mapY, w - 28, self.view.bounds.size.height - mapY - bottomSpace)];
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.mapView.delegate = self;
    self.mapView.layer.cornerRadius = 18.0;
    self.mapView.clipsToBounds = YES;
    [self.view addSubview:self.mapView];

    self.toggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.toggleButton.frame = CGRectMake(14, CGRectGetMaxY(self.mapView.frame) + 14, w - 28, 52);
    self.toggleButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.toggleButton.layer.cornerRadius = 14.0;
    [self.toggleButton setTitle:@"تشغيل التزييف" forState:UIControlStateNormal];
    self.toggleButton.accessibilityLabel = @"تشغيل أو إيقاف تزييف الموقع";
    [self.toggleButton addTarget:self action:@selector(toggleSpoof) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.toggleButton];

    self.settingsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.settingsButton.frame = CGRectMake(14, CGRectGetMaxY(self.toggleButton.frame) + 10, w - 28, 46);
    self.settingsButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.settingsButton.layer.cornerRadius = 12.0;
    [self.settingsButton setTitle:@"الإعدادات" forState:UIControlStateNormal];
    self.settingsButton.accessibilityLabel = @"إعدادات WolFox WhatsApp Location";
    [self.settingsButton addTarget:self action:@selector(openSettings) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.settingsButton];
}

- (void)pastePressed {
    NSString *text = [UIPasteboard generalPasteboard].string ?: @"";
    if (!text.length) return;
    self.searchBar.text = text;
    [self searchBarSearchButtonClicked:self.searchBar];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    NSString *q = [searchBar.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!q.length) return;

    CLLocationCoordinate2D parsed;
    if ([self parseCoordinate:q out:&parsed]) {
        [self applySearchCoordinate:parsed];
        [searchBar resignFirstResponder];
        return;
    }

    MKLocalSearchRequest *request = [MKLocalSearchRequest new];
    request.naturalLanguageQuery = q;
    request.region = self.mapView.region;
    MKLocalSearch *search = [[MKLocalSearch alloc] initWithRequest:request];
    [search startWithCompletionHandler:^(MKLocalSearchResponse * _Nullable response, NSError * _Nullable error) {
        if (error || response.mapItems.count == 0) return;
        MKMapItem *item = response.mapItems.firstObject;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self applySearchCoordinate:item.placemark.coordinate];
        });
    }];
}

- (BOOL)parseCoordinate:(NSString *)text out:(CLLocationCoordinate2D *)outCoord {
    NSString *probe = text;
    NSURLComponents *c = [NSURLComponents componentsWithString:text];
    if (c && c.scheme.length) {
        for (NSURLQueryItem *item in c.queryItems) {
            NSString *name = item.name.lowercaseString;
            if ([name isEqualToString:@"q"] || [name isEqualToString:@"query"] || [name isEqualToString:@"ll"]) {
                probe = item.value ?: probe;
                break;
            }
        }
    }

    NSRegularExpression *rx = [NSRegularExpression regularExpressionWithPattern:@"@?(-?\\d{1,3}(?:\\.\\d+)?)\\s*[, ]\\s*(-?\\d{1,3}(?:\\.\\d+)?)" options:0 error:nil];
    NSTextCheckingResult *m = [rx firstMatchInString:probe options:0 range:NSMakeRange(0, probe.length)];
    if (m.numberOfRanges < 3) return NO;
    double lat = [[probe substringWithRange:[m rangeAtIndex:1]] doubleValue];
    double lon = [[probe substringWithRange:[m rangeAtIndex:2]] doubleValue];
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return NO;
    if (outCoord) *outCoord = CLLocationCoordinate2DMake(lat, lon);
    return YES;
}

- (void)applySearchCoordinate:(CLLocationCoordinate2D)c {
    if (self.pin) [self.mapView removeAnnotation:self.pin];
    self.pin = [MKPointAnnotation new];
    self.pin.coordinate = c;
    self.pin.title = @"الموقع المحدد";
    [self.mapView addAnnotation:self.pin];
    [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(c, 1200, 1200) animated:YES];
    [WolFoxProStore shared].currentFakeCoords = c;
}

- (void)toggleSpoof {
    WolFoxProStore *store = [WolFoxProStore shared];
    BOOL next = !store.spoofActive;
    store.spoofActive = next;
    [store saveSettings];
    if (next) {
        [[WolFoxProHookManager shared] deliverFakeUpdate];
        [self.toggleButton setTitle:@"إيقاف التزييف" forState:UIControlStateNormal];
    } else {
        [[WolFoxProHookManager shared] stopRoute];
        [self.toggleButton setTitle:@"تشغيل التزييف" forState:UIControlStateNormal];
    }
}

- (void)openSettings {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"الإعدادات" message:@"نسخة WhatsApp Location مخصصة للموقع المباشر فقط." preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"إغلاق" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

@end
