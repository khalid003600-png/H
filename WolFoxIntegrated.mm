#import "WFRedactedLogger.h"
// WolFoxIntegrated.mm - WolFox Pro Hooks v1.7.5
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>
#import <WebKit/WebKit.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreLocation/CoreLocation.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import "WolFoxProHookManager.h"
#import "WolFoxProStore.h"
#import "WFLicenseClient.h"
#import "WFCompatibility.h"
#import "WFHookDefaults.h"
#import "WFVirtualCameraManager.h"

@interface WolFoxController : NSObject
+ (instancetype)shared;
- (void)toggleUI;
- (void)toggleCameraIcon:(BOOL)show;
- (void)handleVolumeGesturePulse;
- (void)prepareVirtualCameraLongPress;
- (void)prepareCleanVirtualPhotoCapture;
@end

static BOOL WFProcessIsEligible(void) {
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier.lowercaseString;
    NSString *process = NSProcessInfo.processInfo.processName.lowercaseString;
    if (!bundleID.length) return NO;
    if ([bundleID hasPrefix:@"com.apple."]) return NO;
    if ([process containsString:@"springboard"] || [process containsString:@"backboard"] || [process containsString:@"installd"]) return NO;
    return NSClassFromString(@"UIApplication") != nil;
}

static BOOL WFInstallInstanceHook(Class cls, SEL selector, IMP replacement, IMP *original) {
    if (!cls || !selector || !replacement || !original) return NO;
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) {
#ifdef DEBUG
        WFLog(@"[WolFox][HOOK] missing_instance_method class=%@ selector=%@", NSStringFromClass(cls), NSStringFromSelector(selector));
#endif
        return NO;
    }
    *original = method_getImplementation(method);
    const char *types = method_getTypeEncoding(method);
    if (!class_addMethod(cls, selector, replacement, types)) {
        Method ownedMethod = class_getInstanceMethod(cls, selector);
        method_setImplementation(ownedMethod, replacement);
    }
#ifdef DEBUG
    WFLog(@"[WolFox][HOOK] installed class=%@ selector=%@", NSStringFromClass(cls), NSStringFromSelector(selector));
#endif
    return YES;
}

static BOOL WFInstallClassHook(Class cls, SEL selector, IMP replacement, IMP *original) {
    return WFInstallInstanceHook(object_getClass(cls), selector, replacement, original);
}

static BOOL WFGate(BOOL featureEnabled) {
    return featureEnabled && [WFLicenseClient isRuntimeLicenseValid];
}

#pragma mark - Identifier hooks

static NSUUID *WFActivePublicIdentifier(void) {
    if (![WFLicenseClient isRuntimeLicenseValid]) return nil;
    return [[WolFoxProStore shared] validatedActiveIdentifier];
}

static IMP orig_advertisingIdentifier;
static NSUUID *hook_advertisingIdentifier(ASIdentifierManager *self, SEL _cmd) {
    NSUUID *uuid = WFActivePublicIdentifier();
    if (uuid) return uuid;
    return ((NSUUID *(*)(id, SEL))orig_advertisingIdentifier)(self, _cmd);
}

static IMP orig_identifierForVendor;
static NSUUID *hook_identifierForVendor(UIDevice *self, SEL _cmd) {
    NSUUID *uuid = WFActivePublicIdentifier();
    if (uuid) return uuid;
    return ((NSUUID *(*)(id, SEL))orig_identifierForVendor)(self, _cmd);
}

#pragma mark - Location hooks

static IMP orig_CLLocation_coordinate;
static CLLocationCoordinate2D hook_CLLocation_coordinate(CLLocation *self, SEL _cmd) {
    if (objc_getAssociatedObject(self, &WFSpoofedLocationAssociationKey)) {
        return ((CLLocationCoordinate2D (*)(id, SEL))orig_CLLocation_coordinate)(self, _cmd);
    }
    WolFoxProStore *store = [WolFoxProStore shared];
    if (WFGate(store.spoofActive)) {
        CLLocationCoordinate2D fake = store.currentFakeCoords;
        if (!CLLocationCoordinate2DIsValid(fake)) {
            return ((CLLocationCoordinate2D (*)(id, SEL))orig_CLLocation_coordinate)(self, _cmd);
        }
        if (store.jitterActive) {
            fake.latitude  += ((double)arc4random_uniform(100) - 50.0) / 2000000.0;
            fake.longitude += ((double)arc4random_uniform(100) - 50.0) / 2000000.0;
        }
        return fake;
    }
    return ((CLLocationCoordinate2D (*)(id, SEL))orig_CLLocation_coordinate)(self, _cmd);
}

static IMP orig_CLLocationManager_location;
static CLLocation *hook_CLLocationManager_location(CLLocationManager *self, SEL _cmd) {
    WolFoxProStore *store = [WolFoxProStore shared];
    if (WFGate(store.spoofActive)) {
        CLLocationCoordinate2D fake = store.currentFakeCoords;
        if (!CLLocationCoordinate2DIsValid(fake)) {
            return ((CLLocation *(*)(id, SEL))orig_CLLocationManager_location)(self, _cmd);
        }
        if (store.jitterActive) {
            fake.latitude  += ((double)arc4random_uniform(100) - 50.0) / 2000000.0;
            fake.longitude += ((double)arc4random_uniform(100) - 50.0) / 2000000.0;
        }
        double fakeAltitude = WFDefaultAltitudeMeters;
        if (store.jitterActive && WFDefaultAltitudeJitterEnabled) {
            fakeAltitude = WFApplyAltitudeJitter(fakeAltitude);
        }
        CLLocation *location = [[CLLocation alloc] initWithCoordinate:fake
                                                             altitude:fakeAltitude
                                                   horizontalAccuracy:5
                                                     verticalAccuracy:5
                                                            timestamp:NSDate.date];
        objc_setAssociatedObject(location, &WFSpoofedLocationAssociationKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return location;
    }
    return ((CLLocation *(*)(id, SEL))orig_CLLocationManager_location)(self, _cmd);
}

#pragma mark - JSON and WebView hooks

static id (*orig_WKWebView_init)(WKWebView *, SEL, CGRect, WKWebViewConfiguration *);
static id hook_WKWebView_init(WKWebView *self, SEL _cmd, CGRect frame, WKWebViewConfiguration *configuration) {
    if (!configuration) {
        return orig_WKWebView_init(self, _cmd, frame, configuration);
    }
    NSUUID *activeIdentifier = WFActivePublicIdentifier();
    if (activeIdentifier && configuration.userContentController) {
        NSString *identifier = activeIdentifier.UUIDString;
        NSString *safe = [identifier stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        safe = [safe stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
        NSString *source = [NSString stringWithFormat:
            @"window.device=window.device||{};window.device.uuid='%@';window.wolfoxIdentifier='%@';",
            safe, safe];
        WKUserScript *script = [[WKUserScript alloc] initWithSource:source
                                                     injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                  forMainFrameOnly:NO];
        [configuration.userContentController addUserScript:script];
    }
    return orig_WKWebView_init(self, _cmd, frame, configuration);
}

#pragma mark - Bluetooth scan identity hooks

// FIX: All const char keys must be initialized to 0 (was causing Clang error: uninitialized const)
static const char kWFCBProxyKey     = 0;
static const char kWFCBProfileIDKey = 0;
static const char kWFCBNameKey      = 0;
static const char kWFCBUUIDKey      = 0;

static WolFoxBleProfile *WFActiveBleProfile(void) {
    WolFoxProStore *store = [WolFoxProStore shared];
    return WFGate(store.bluetoothActive) ? [store activeBleProfile] : nil;
}

static IMP orig_CBPeripheral_name;
static NSString *hook_CBPeripheral_name(CBPeripheral *self, SEL _cmd) {
    WolFoxBleProfile *profile = WFActiveBleProfile();
    NSString *associatedID = objc_getAssociatedObject(self, &kWFCBProfileIDKey);
    if (profile && [associatedID isEqualToString:profile.profileID]) {
        NSString *name = objc_getAssociatedObject(self, &kWFCBNameKey);
        if (name.length) return name;
    }
    return ((NSString *(*)(id, SEL))orig_CBPeripheral_name)(self, _cmd);
}

static IMP orig_CBPeripheral_identifier;
static NSUUID *hook_CBPeripheral_identifier(CBPeripheral *self, SEL _cmd) {
    WolFoxBleProfile *profile = WFActiveBleProfile();
    NSString *associatedID = objc_getAssociatedObject(self, &kWFCBProfileIDKey);
    if (profile && [associatedID isEqualToString:profile.profileID]) {
        NSUUID *identifier = objc_getAssociatedObject(self, &kWFCBUUIDKey);
        if (identifier) return identifier;
    }
    return ((NSUUID *(*)(id, SEL))orig_CBPeripheral_identifier)(self, _cmd);
}

@interface WolFoxCBProxy : NSProxy <CBCentralManagerDelegate> {
    __weak id _delegate;
    __weak CBCentralManager *_manager;
    BOOL _deliveredProfile;
}
- (instancetype)initWithDelegate:(id)delegate;
- (void)setManager:(CBCentralManager *)manager;
- (void)resetScan;
@end

@implementation WolFoxCBProxy
- (instancetype)initWithDelegate:(id)delegate { _delegate = delegate; return self; }
- (void)setManager:(CBCentralManager *)manager { _manager = manager; }
- (void)resetScan { @synchronized(self) { _deliveredProfile = NO; } }

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    NSMethodSignature *signature = [(NSObject *)_delegate methodSignatureForSelector:selector];
    return signature ?: [NSObject instanceMethodSignatureForSelector:@selector(init)];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    if ([_delegate respondsToSelector:invocation.selector]) [invocation invokeWithTarget:_delegate];
}

- (BOOL)respondsToSelector:(SEL)selector {
    return selector == @selector(centralManager:didDiscoverPeripheral:advertisementData:RSSI:)
        || [_delegate respondsToSelector:selector];
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI
{
    id delegate = _delegate;
    if (![delegate respondsToSelector:_cmd]) return;

    WolFoxBleProfile *profile = WFActiveBleProfile();
    if (!profile) {
        [delegate centralManager:central didDiscoverPeripheral:peripheral advertisementData:advertisementData RSSI:RSSI];
        return;
    }
    @synchronized(self) {
        if (_deliveredProfile) return;
        _deliveredProfile = YES;
    }
    NSString *displayName    = profile.localName.length ? profile.localName : profile.name;
    NSString *identifierText = profile.uuid.length ? profile.uuid : profile.profileID;
    NSUUID *identifier = [[NSUUID alloc] initWithUUIDString:identifierText];
    if (!identifier) identifier = [[NSUUID alloc] initWithUUIDString:profile.profileID];

    objc_setAssociatedObject(peripheral, &kWFCBProfileIDKey, profile.profileID, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(peripheral, &kWFCBNameKey,      displayName,        OBJC_ASSOCIATION_COPY_NONATOMIC);
    if (identifier) objc_setAssociatedObject(peripheral, &kWFCBUUIDKey, identifier, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    NSMutableDictionary *spoofedAdvertisement = advertisementData ? [advertisementData mutableCopy] : [NSMutableDictionary new];
    if (displayName.length) spoofedAdvertisement[CBAdvertisementDataLocalNameKey] = displayName;
    NSNumber *spoofedRSSI = (profile.rssi == 0) ? RSSI : @(profile.rssi);

    [delegate centralManager:central
       didDiscoverPeripheral:peripheral
           advertisementData:spoofedAdvertisement
                        RSSI:spoofedRSSI ?: @(-55)];
}
@end

// FIX: hook signature must use (dispatch_queue_t _Nullable, NSDictionary * _Nullable) — matching actual Clang-visible prototype
static id (*orig_CBCentralManager_initWithDelegate)(CBCentralManager *, SEL, id, dispatch_queue_t, NSDictionary *);
static id hook_CBCentralManager_initWithDelegate(CBCentralManager *self, SEL _cmd,
                                                  id delegate,
                                                  dispatch_queue_t queue,
                                                  NSDictionary *options)
{
    Class wolfoxClass = NSClassFromString(@"WolFoxMainViewController");
    if (wolfoxClass && [delegate isKindOfClass:wolfoxClass]) {
        return orig_CBCentralManager_initWithDelegate(self, _cmd, delegate, queue, options);
    }
    WolFoxCBProxy *proxy = [[WolFoxCBProxy alloc] initWithDelegate:delegate];
    id manager = orig_CBCentralManager_initWithDelegate(self, _cmd, proxy, queue, options);
    [proxy setManager:manager];
    objc_setAssociatedObject(manager, &kWFCBProxyKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return manager;
}

// FIX: use IMP (not function-pointer typedef) for scanForPeripheralsWithServices:options:
static IMP orig_CBCentralManager_scan;
static void hook_CBCentralManager_scan(CBCentralManager *self, SEL _cmd,
                                        NSArray<CBUUID *> *services,
                                        NSDictionary *options)
{
    WolFoxCBProxy *proxy = objc_getAssociatedObject(self, &kWFCBProxyKey);
    [proxy resetScan];
    if (orig_CBCentralManager_scan) {
        ((void (*)(id, SEL, id, id))orig_CBCentralManager_scan)(self, _cmd, services, options);
    }
}

#pragma mark - AVCapture virtual camera hooks

static const char kWFVideoOutputProxyKey = 0;
static const char kWFPreviewOverlayLayerKey = 0;
static const char kWFPhotoPixelBufferKey = 0;
static const char kWFPhotoPreviewPixelBufferKey = 0;
static NSHashTable<AVCaptureVideoPreviewLayer *> *WFTrackedPreviewLayers;
static id WFVirtualPreviewStateObserver;

static void WFRefreshVirtualPreviewLayer(AVCaptureVideoPreviewLayer *previewLayer) {
    if (!previewLayer) return;
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ WFRefreshVirtualPreviewLayer(previewLayer); });
        return;
    }
    if (!WFTrackedPreviewLayers) WFTrackedPreviewLayers = [NSHashTable weakObjectsHashTable];
    [WFTrackedPreviewLayers addObject:previewLayer];

    CALayer *imageLayer = objc_getAssociatedObject(previewLayer, &kWFPreviewOverlayLayerKey);
    if (!imageLayer) {
        imageLayer = [CALayer layer];
        imageLayer.name = @"WFVirtualCameraPortraitPreview";
        imageLayer.contentsGravity = kCAGravityResizeAspect;
        imageLayer.backgroundColor = UIColor.blackColor.CGColor;
        imageLayer.zPosition = 1000000.0;
        objc_setAssociatedObject(previewLayer,
                                 &kWFPreviewOverlayLayerKey,
                                 imageLayer,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [previewLayer addSublayer:imageLayer];
    } else if (imageLayer.superlayer != previewLayer) {
        [previewLayer addSublayer:imageLayer];
    }

    WFVirtualCameraManager *manager = [WFVirtualCameraManager shared];
    UIImage *image = manager.enabled ? manager.currentImage : nil;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    imageLayer.frame = previewLayer.bounds;
    imageLayer.contentsScale = UIScreen.mainScreen.scale;
    imageLayer.contents = image.CGImage ? (__bridge id)image.CGImage : nil;
    imageLayer.hidden = image == nil;
    [CATransaction commit];
}

static void WFRefreshAllVirtualPreviewLayers(void) {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ WFRefreshAllVirtualPreviewLayers(); });
        return;
    }
    for (AVCaptureVideoPreviewLayer *layer in WFTrackedPreviewLayers.allObjects) {
        WFRefreshVirtualPreviewLayer(layer);
    }
}

static IMP orig_AVCaptureSession_startRunning;
static void hook_AVCaptureSession_startRunning(AVCaptureSession *self, SEL _cmd) {
    if (orig_AVCaptureSession_startRunning) {
        ((void (*)(id, SEL))orig_AVCaptureSession_startRunning)(self, _cmd);
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [[WolFoxController shared] prepareVirtualCameraLongPress];
        [[NSNotificationCenter defaultCenter]
            postNotificationName:WFVirtualCameraSessionDidStartNotification
                          object:self];
    });
}

static IMP orig_AVCaptureVideoDataOutput_setDelegate;
static void hook_AVCaptureVideoDataOutput_setDelegate(AVCaptureVideoDataOutput *self,
                                                       SEL _cmd,
                                                       id<AVCaptureVideoDataOutputSampleBufferDelegate> delegate,
                                                       dispatch_queue_t queue) {
    if (!orig_AVCaptureVideoDataOutput_setDelegate) return;
    if (!delegate) {
        objc_setAssociatedObject(self, &kWFVideoOutputProxyKey, nil, OBJC_ASSOCIATION_ASSIGN);
        ((void (*)(id, SEL, id, dispatch_queue_t))orig_AVCaptureVideoDataOutput_setDelegate)(self, _cmd, nil, queue);
        return;
    }
    id existingProxy = objc_getAssociatedObject(self, &kWFVideoOutputProxyKey);
    if (delegate == existingProxy) {
        ((void (*)(id, SEL, id, dispatch_queue_t))orig_AVCaptureVideoDataOutput_setDelegate)(self, _cmd, delegate, queue);
        return;
    }
    WFVirtualCameraOutputProxy *proxy = [[WFVirtualCameraOutputProxy alloc] initWithTarget:delegate];
    objc_setAssociatedObject(self, &kWFVideoOutputProxyKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL, id, dispatch_queue_t))orig_AVCaptureVideoDataOutput_setDelegate)(self, _cmd, proxy, queue);
}

static IMP orig_AVCaptureVideoPreviewLayer_setSession;
static void hook_AVCaptureVideoPreviewLayer_setSession(AVCaptureVideoPreviewLayer *self,
                                                        SEL _cmd,
                                                        AVCaptureSession *session) {
    if (orig_AVCaptureVideoPreviewLayer_setSession) {
        ((void (*)(id, SEL, id))orig_AVCaptureVideoPreviewLayer_setSession)(self, _cmd, session);
    }
    WFRefreshVirtualPreviewLayer(self);
}

static IMP orig_AVCaptureVideoPreviewLayer_layoutSublayers;
static void hook_AVCaptureVideoPreviewLayer_layoutSublayers(AVCaptureVideoPreviewLayer *self, SEL _cmd) {
    if (orig_AVCaptureVideoPreviewLayer_layoutSublayers) {
        ((void (*)(id, SEL))orig_AVCaptureVideoPreviewLayer_layoutSublayers)(self, _cmd);
    }
    WFRefreshVirtualPreviewLayer(self);
}

static IMP orig_AVCapturePhotoOutput_capturePhoto;
static void hook_AVCapturePhotoOutput_capturePhoto(AVCapturePhotoOutput *self,
                                                    SEL _cmd,
                                                    AVCapturePhotoSettings *settings,
                                                    id<AVCapturePhotoCaptureDelegate> delegate) {
    if ([WFVirtualCameraManager shared].enabled) {
        void (^hideControls)(void) = ^{
            [[WolFoxController shared] prepareCleanVirtualPhotoCapture];
        };
        if (NSThread.isMainThread) hideControls();
        else dispatch_async(dispatch_get_main_queue(), hideControls);
    }
    if (orig_AVCapturePhotoOutput_capturePhoto) {
        ((void (*)(id, SEL, id, id))orig_AVCapturePhotoOutput_capturePhoto)(self, _cmd, settings, delegate);
    }
}

static IMP orig_AVCapturePhoto_fileDataRepresentation;
static NSData *hook_AVCapturePhoto_fileDataRepresentation(AVCapturePhoto *self, SEL _cmd) {
    NSData *replacement = [[WFVirtualCameraManager shared] photoDataRepresentation];
    if (replacement.length) return replacement;
    if (!orig_AVCapturePhoto_fileDataRepresentation) return nil;
    return ((NSData *(*)(id, SEL))orig_AVCapturePhoto_fileDataRepresentation)(self, _cmd);
}

static IMP orig_AVCapturePhoto_CGImageRepresentation;
static CGImageRef hook_AVCapturePhoto_CGImageRepresentation(AVCapturePhoto *self, SEL _cmd) {
    WFVirtualCameraManager *manager = [WFVirtualCameraManager shared];
    UIImage *replacement = manager.enabled ? manager.currentImage : nil;
    if (replacement.CGImage) return replacement.CGImage;
    if (!orig_AVCapturePhoto_CGImageRepresentation) return NULL;
    return ((CGImageRef (*)(id, SEL))orig_AVCapturePhoto_CGImageRepresentation)(self, _cmd);
}

static CVPixelBufferRef WFReplacementPhotoPixelBuffer(AVCapturePhoto *photo,
                                                       CVPixelBufferRef sourceBuffer,
                                                       const void *associationKey) {
    if (!sourceBuffer || ![WFVirtualCameraManager shared].enabled) return sourceBuffer;
    CVPixelBufferRef replacement = [[WFVirtualCameraManager shared]
                                     copyPhotoPixelBufferMatching:sourceBuffer];
    if (!replacement) return sourceBuffer;
    id retainedReplacement = CFBridgingRelease(replacement);
    objc_setAssociatedObject(photo,
                             associationKey,
                             retainedReplacement,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return (__bridge CVPixelBufferRef)retainedReplacement;
}

static IMP orig_AVCapturePhoto_pixelBuffer;
static CVPixelBufferRef hook_AVCapturePhoto_pixelBuffer(AVCapturePhoto *self, SEL _cmd) {
    CVPixelBufferRef source = orig_AVCapturePhoto_pixelBuffer
        ? ((CVPixelBufferRef (*)(id, SEL))orig_AVCapturePhoto_pixelBuffer)(self, _cmd)
        : NULL;
    return WFReplacementPhotoPixelBuffer(self, source, &kWFPhotoPixelBufferKey);
}

static IMP orig_AVCapturePhoto_previewPixelBuffer;
static CVPixelBufferRef hook_AVCapturePhoto_previewPixelBuffer(AVCapturePhoto *self, SEL _cmd) {
    CVPixelBufferRef source = orig_AVCapturePhoto_previewPixelBuffer
        ? ((CVPixelBufferRef (*)(id, SEL))orig_AVCapturePhoto_previewPixelBuffer)(self, _cmd)
        : NULL;
    return WFReplacementPhotoPixelBuffer(self, source, &kWFPhotoPreviewPixelBufferKey);
}

#pragma mark - UDID spoofing hook

// UIDevice.uniqueIdentifier مُهمل لكن بعض التطبيقات القديمة لا تزال تستدعيه.
// نُسكّت التحذير عمداً — الهوك مقصود للتوافق مع التطبيقات التي تستهدف iOS 15 فأقل.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
static IMP orig_uniqueIdentifier;
static NSString *hook_uniqueIdentifier(UIDevice *self, SEL _cmd) {
    NSUUID *uuid = WFActivePublicIdentifier();
    if (uuid) return uuid.UUIDString;
    if (orig_uniqueIdentifier) {
        return ((NSString *(*)(id, SEL))orig_uniqueIdentifier)(self, _cmd);
    }
    return nil;
}
#pragma clang diagnostic pop

#pragma mark - Volume button hook

static IMP orig_UIApplication_pressesBegan;
static void hook_UIApplication_pressesBegan(UIApplication *self, SEL _cmd,
                                              NSSet<UIPress *> *presses,
                                              UIPressesEvent *event)
{
    if (orig_UIApplication_pressesBegan) {
        ((void (*)(id, SEL, id, id))orig_UIApplication_pressesBegan)(self, _cmd, presses, event);
    }
    if (![WolFoxProStore shared].volumeGestureEnabled) return;
    BOOL containsVolumePress = NO;
    for (UIPress *press in presses) {
        // UIPress.h في SDK iOS لا يعرّف ثوابت Volume؛ القيم 102/103 هي VolumeUp/VolumeDown.
        if ((NSInteger)press.type == 102 || (NSInteger)press.type == 103) {
            containsVolumePress = YES;
            break;
        }
    }
    if (!containsVolumePress) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[WolFoxController shared] handleVolumeGesturePulse];
    });
}

#pragma mark - Initialization

__attribute__((constructor)) static void WolFox_Pro_Hooks_Init(void) {
    if (!WFIsSupportedRuntime()) {
#ifdef DEBUG
        WFLog(@"[WolFox][BOOT] unsupported_ios_runtime");
#endif
        return;
    }
    if (!WFProcessIsEligible()) return;
#ifdef DEBUG
    WFLog(@"[WolFox][BOOT] dylib_loaded process=%@", NSProcessInfo.processInfo.processName);
#endif
    [[WolFoxProHookManager shared] installHooks];

    static dispatch_once_t once;
    dispatch_once(&once, ^{
        WFInstallInstanceHook(ASIdentifierManager.class,
                              @selector(advertisingIdentifier),
                              (IMP)hook_advertisingIdentifier,
                              &orig_advertisingIdentifier);

        WFInstallInstanceHook(UIDevice.class,
                              @selector(identifierForVendor),
                              (IMP)hook_identifierForVendor,
                              &orig_identifierForVendor);

        WFInstallInstanceHook(AVCaptureSession.class,
                              @selector(startRunning),
                              (IMP)hook_AVCaptureSession_startRunning,
                              &orig_AVCaptureSession_startRunning);

        WFInstallInstanceHook(AVCaptureVideoDataOutput.class,
                              @selector(setSampleBufferDelegate:queue:),
                              (IMP)hook_AVCaptureVideoDataOutput_setDelegate,
                              &orig_AVCaptureVideoDataOutput_setDelegate);

        WFInstallInstanceHook(AVCaptureVideoPreviewLayer.class,
                              @selector(setSession:),
                              (IMP)hook_AVCaptureVideoPreviewLayer_setSession,
                              &orig_AVCaptureVideoPreviewLayer_setSession);

        WFInstallInstanceHook(AVCaptureVideoPreviewLayer.class,
                              @selector(layoutSublayers),
                              (IMP)hook_AVCaptureVideoPreviewLayer_layoutSublayers,
                              &orig_AVCaptureVideoPreviewLayer_layoutSublayers);

        WFInstallInstanceHook(AVCapturePhotoOutput.class,
                              @selector(capturePhotoWithSettings:delegate:),
                              (IMP)hook_AVCapturePhotoOutput_capturePhoto,
                              &orig_AVCapturePhotoOutput_capturePhoto);

        WFInstallInstanceHook(AVCapturePhoto.class,
                              @selector(fileDataRepresentation),
                              (IMP)hook_AVCapturePhoto_fileDataRepresentation,
                              &orig_AVCapturePhoto_fileDataRepresentation);

        if ([AVCapturePhoto instancesRespondToSelector:@selector(CGImageRepresentation)]) {
            WFInstallInstanceHook(AVCapturePhoto.class,
                                  @selector(CGImageRepresentation),
                                  (IMP)hook_AVCapturePhoto_CGImageRepresentation,
                                  &orig_AVCapturePhoto_CGImageRepresentation);
        }

        SEL photoPixelBufferSelector = NSSelectorFromString(@"pixelBuffer");
        if ([AVCapturePhoto instancesRespondToSelector:photoPixelBufferSelector]) {
            WFInstallInstanceHook(AVCapturePhoto.class,
                                  photoPixelBufferSelector,
                                  (IMP)hook_AVCapturePhoto_pixelBuffer,
                                  &orig_AVCapturePhoto_pixelBuffer);
        }

        SEL photoPreviewPixelBufferSelector = NSSelectorFromString(@"previewPixelBuffer");
        if ([AVCapturePhoto instancesRespondToSelector:photoPreviewPixelBufferSelector]) {
            WFInstallInstanceHook(AVCapturePhoto.class,
                                  photoPreviewPixelBufferSelector,
                                  (IMP)hook_AVCapturePhoto_previewPixelBuffer,
                                  &orig_AVCapturePhoto_previewPixelBuffer);
        }

        if (!WFVirtualPreviewStateObserver) {
            WFVirtualPreviewStateObserver = [[NSNotificationCenter defaultCenter]
                addObserverForName:WFVirtualCameraStateDidChangeNotification
                            object:nil
                             queue:NSOperationQueue.mainQueue
                        usingBlock:^(__unused NSNotification *notification) {
                            WFRefreshAllVirtualPreviewLayers();
                        }];
        }

        WFInstallInstanceHook(CLLocationManager.class,
                              @selector(location),
                              (IMP)hook_CLLocationManager_location,
                              &orig_CLLocationManager_location);

        WFInstallInstanceHook(CLLocation.class,
                              @selector(coordinate),
                              (IMP)hook_CLLocation_coordinate,
                              &orig_CLLocation_coordinate);

        // WKWebView (instance method)
        IMP original = NULL;
        if (WFInstallInstanceHook(NSClassFromString(@"WKWebView"),
                                  @selector(initWithFrame:configuration:),
                                  (IMP)hook_WKWebView_init,
                                  &original)) {
            orig_WKWebView_init = (id (*)(WKWebView *, SEL, CGRect, WKWebViewConfiguration *))original;
        }

        // CBCentralManager — initWithDelegate:queue:options:
        original = NULL;
        if (WFInstallInstanceHook(CBCentralManager.class,
                                  @selector(initWithDelegate:queue:options:),
                                  (IMP)hook_CBCentralManager_initWithDelegate,
                                  &original)) {
            orig_CBCentralManager_initWithDelegate =
                (id (*)(CBCentralManager *, SEL, id, dispatch_queue_t, NSDictionary *))original;
        }

        WFInstallInstanceHook(CBCentralManager.class,
                              @selector(scanForPeripheralsWithServices:options:),
                              (IMP)hook_CBCentralManager_scan,
                              &orig_CBCentralManager_scan);

        WFInstallInstanceHook(CBPeripheral.class,
                              @selector(name),
                              (IMP)hook_CBPeripheral_name,
                              &orig_CBPeripheral_name);

        WFInstallInstanceHook(CBPeripheral.class,
                              @selector(identifier),
                              (IMP)hook_CBPeripheral_identifier,
                              &orig_CBPeripheral_identifier);

        WFInstallInstanceHook(UIApplication.class,
                              @selector(pressesBegan:withEvent:),
                              (IMP)hook_UIApplication_pressesBegan,
                              &orig_UIApplication_pressesBegan);

        // UDID spoofing (deprecated API, still used by some apps)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        if ([UIDevice instancesRespondToSelector:@selector(uniqueIdentifier)]) {
            WFInstallInstanceHook(UIDevice.class,
                                  @selector(uniqueIdentifier),
                                  (IMP)hook_uniqueIdentifier,
                                  &orig_uniqueIdentifier);
        }
#pragma clang diagnostic pop

#ifdef DEBUG
        WFLog(@"[WolFox][BOOT] hooks_install_complete");
#endif
    });
}
