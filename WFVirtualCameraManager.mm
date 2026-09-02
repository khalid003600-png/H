#import "WFVirtualCameraManager.h"

#import <PhotosUI/PhotosUI.h>
#import <CoreVideo/CoreVideo.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#import "WolFoxProStore.h"
#import "WFLicenseClient.h"
#import "WFRedactedLogger.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

NSNotificationName const WFVirtualCameraStateDidChangeNotification = @"WF_VIRTUAL_CAMERA_STATE_DID_CHANGE";
NSNotificationName const WFVirtualCameraSessionDidStartNotification = @"WF_VIRTUAL_CAMERA_SESSION_DID_START";
NSNotificationName const WFVirtualCameraImageDidSelectNotification = @"WF_VIRTUAL_CAMERA_IMAGE_DID_SELECT";

#pragma mark - Window and image helpers

static UIViewController *WFVirtualCameraTopController(UIViewController *controller) {
    if (!controller) return nil;

    UIViewController *presented = controller.presentedViewController;
    if (presented && !presented.isBeingDismissed) {
        return WFVirtualCameraTopController(presented);
    }
    if ([controller isKindOfClass:UINavigationController.class]) {
        UINavigationController *navigation = (UINavigationController *)controller;
        return WFVirtualCameraTopController(navigation.visibleViewController ?: navigation.topViewController);
    }
    if ([controller isKindOfClass:UITabBarController.class]) {
        return WFVirtualCameraTopController(((UITabBarController *)controller).selectedViewController);
    }
    if ([controller isKindOfClass:UISplitViewController.class]) {
        return WFVirtualCameraTopController(((UISplitViewController *)controller).viewControllers.lastObject);
    }
    return controller;
}

static UIViewController *WFVirtualCameraBestPresenter(void) {
    UIApplication *application = UIApplication.sharedApplication;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in application.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class] ||
                scene.activationState != UISceneActivationStateForegroundActive) continue;
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow && !window.hidden && window.windowLevel == UIWindowLevelNormal) {
                    return WFVirtualCameraTopController(window.rootViewController);
                }
            }
            for (UIWindow *window in windowScene.windows) {
                if (!window.hidden && window.alpha > 0.01 && window.windowLevel == UIWindowLevelNormal) {
                    return WFVirtualCameraTopController(window.rootViewController);
                }
            }
        }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    for (UIWindow *window in application.windows) {
        if (window.isKeyWindow && !window.hidden && window.windowLevel == UIWindowLevelNormal) {
            return WFVirtualCameraTopController(window.rootViewController);
        }
    }
#pragma clang diagnostic pop
    return nil;
}

static UIImage *WFVirtualCameraNormalizedImage(UIImage *image) {
    if (!image || !image.CGImage) return nil;
    // UIImage.size reflects the displayed orientation, while raw CGImage dimensions do not.
    // Rendering with the oriented size bakes EXIF rotation into upright portrait pixels.
    CGFloat sourceScale = MAX(1.0, image.scale);
    CGFloat sourceWidth = image.size.width * sourceScale;
    CGFloat sourceHeight = image.size.height * sourceScale;
    if (sourceWidth < 1.0 || sourceHeight < 1.0) return nil;

    const CGFloat maximumDimension = 4096.0;
    CGFloat scale = MIN(1.0, maximumDimension / MAX(sourceWidth, sourceHeight));
    CGSize size = CGSizeMake(MAX(1.0, floor(sourceWidth * scale)),
                             MAX(1.0, floor(sourceHeight * scale)));
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = 1.0;
    format.opaque = YES;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        CGContextSetFillColorWithColor(context.CGContext, UIColor.blackColor.CGColor);
        CGContextFillRect(context.CGContext, CGRectMake(0.0, 0.0, size.width, size.height));
        [image drawInRect:CGRectMake(0.0, 0.0, size.width, size.height)];
    }];
}

#pragma mark - Pixel-buffer conversion

static inline uint8_t WFVirtualCameraClampByte(NSInteger value) {
    return (uint8_t)MIN(255, MAX(0, value));
}

static void WFVirtualCameraCopyDictionaryEntry(const void *key, const void *value, void *context) {
    if (key && value && context) CFDictionarySetValue((CFMutableDictionaryRef)context, key, value);
}

static void WFVirtualCameraCopyPixelAttachments(CVBufferRef source, CVBufferRef destination) {
    if (!source || !destination) return;
    CVBufferRemoveAllAttachments(destination);
    CFDictionaryRef attachments = CVBufferCopyAttachments(source, kCVAttachmentMode_ShouldPropagate);
    if (attachments) {
        CVBufferSetAttachments(destination, attachments, kCVAttachmentMode_ShouldPropagate);
        CFRelease(attachments);
    }
}

static uint8_t *WFVirtualCameraCreateAspectFitBGRA(UIImage *image,
                                                    size_t width,
                                                    size_t height,
                                                    size_t *rowBytesOut) {
    if (!image.CGImage || width == 0 || height == 0) return NULL;
    size_t rowBytes = width * 4;
    uint8_t *bytes = (uint8_t *)calloc(height, rowBytes);
    if (!bytes) return NULL;

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(bytes,
                                                  width,
                                                  height,
                                                  8,
                                                  rowBytes,
                                                  colorSpace,
                                                  kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(colorSpace);
    if (!context) {
        free(bytes);
        return NULL;
    }

    CGContextSetRGBFillColor(context, 0.0, 0.0, 0.0, 1.0);
    CGContextFillRect(context, CGRectMake(0.0, 0.0, width, height));
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);

    CGFloat imageWidth = CGImageGetWidth(image.CGImage);
    CGFloat imageHeight = CGImageGetHeight(image.CGImage);
    // Aspect-fit keeps the complete portrait image visible and avoids cropping faces or edges.
    CGFloat scale = MIN((CGFloat)width / imageWidth, (CGFloat)height / imageHeight);
    CGFloat drawWidth = imageWidth * scale;
    CGFloat drawHeight = imageHeight * scale;
    CGRect drawRect = CGRectMake(((CGFloat)width - drawWidth) * 0.5,
                                 ((CGFloat)height - drawHeight) * 0.5,
                                 drawWidth,
                                 drawHeight);
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, 0.0, (CGFloat)height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextDrawImage(context, drawRect, image.CGImage);
    CGContextRestoreGState(context);
    CGContextRelease(context);

    if (rowBytesOut) *rowBytesOut = rowBytes;
    return bytes;
}

static BOOL WFVirtualCameraFillNV12(CVPixelBufferRef destination,
                                     const uint8_t *bgra,
                                     size_t sourceRowBytes,
                                     BOOL fullRange) {
    if (CVPixelBufferGetPlaneCount(destination) < 2) return NO;
    size_t width = CVPixelBufferGetWidth(destination);
    size_t height = CVPixelBufferGetHeight(destination);
    uint8_t *yPlane = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(destination, 0);
    uint8_t *uvPlane = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(destination, 1);
    size_t yRowBytes = CVPixelBufferGetBytesPerRowOfPlane(destination, 0);
    size_t uvRowBytes = CVPixelBufferGetBytesPerRowOfPlane(destination, 1);
    if (!yPlane || !uvPlane) return NO;

    for (size_t y = 0; y < height; y++) {
        const uint8_t *sourceRow = bgra + y * sourceRowBytes;
        uint8_t *destinationRow = yPlane + y * yRowBytes;
        for (size_t x = 0; x < width; x++) {
            NSInteger blue = sourceRow[x * 4 + 0];
            NSInteger green = sourceRow[x * 4 + 1];
            NSInteger red = sourceRow[x * 4 + 2];
            NSInteger luma = fullRange
                ? ((77 * red + 150 * green + 29 * blue + 128) >> 8)
                : (((66 * red + 129 * green + 25 * blue + 128) >> 8) + 16);
            destinationRow[x] = WFVirtualCameraClampByte(luma);
        }
    }

    size_t uvPlaneHeight = CVPixelBufferGetHeightOfPlane(destination, 1);
    size_t uvPlaneWidth = CVPixelBufferGetWidthOfPlane(destination, 1);
    for (size_t chromaY = 0; chromaY < uvPlaneHeight; chromaY++) {
        size_t sourceY = MIN(chromaY * 2, height - 1);
        uint8_t *destinationRow = uvPlane + chromaY * uvRowBytes;
        for (size_t chromaX = 0; chromaX < uvPlaneWidth; chromaX++) {
            size_t sourceX = MIN(chromaX * 2, width - 1);
            NSInteger red = 0, green = 0, blue = 0, sampleCount = 0;
            for (size_t offsetY = 0; offsetY < 2 && sourceY + offsetY < height; offsetY++) {
                const uint8_t *sourceRow = bgra + (sourceY + offsetY) * sourceRowBytes;
                for (size_t offsetX = 0; offsetX < 2 && sourceX + offsetX < width; offsetX++) {
                    const uint8_t *pixel = sourceRow + (sourceX + offsetX) * 4;
                    blue += pixel[0];
                    green += pixel[1];
                    red += pixel[2];
                    sampleCount++;
                }
            }
            red /= MAX(1, sampleCount);
            green /= MAX(1, sampleCount);
            blue /= MAX(1, sampleCount);
            NSInteger chromaBlue = fullRange
                ? (((-43 * red - 85 * green + 128 * blue + 128) >> 8) + 128)
                : (((-38 * red - 74 * green + 112 * blue + 128) >> 8) + 128);
            NSInteger chromaRed = fullRange
                ? (((128 * red - 107 * green - 21 * blue + 128) >> 8) + 128)
                : (((112 * red - 94 * green - 18 * blue + 128) >> 8) + 128);
            size_t byteIndex = chromaX * 2;
            if (byteIndex < uvRowBytes) destinationRow[byteIndex] = WFVirtualCameraClampByte(chromaBlue);
            if (byteIndex + 1 < uvRowBytes) destinationRow[byteIndex + 1] = WFVirtualCameraClampByte(chromaRed);
        }
    }
    return YES;
}

static CVPixelBufferRef WFVirtualCameraCreatePixelBuffer(UIImage *image,
                                                          size_t width,
                                                          size_t height,
                                                          OSType pixelFormat) CF_RETURNS_RETAINED {
    if (!image || width == 0 || height == 0) return NULL;
    if (pixelFormat != kCVPixelFormatType_32BGRA &&
        pixelFormat != kCVPixelFormatType_420YpCbCr8BiPlanarFullRange &&
        pixelFormat != kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) return NULL;

    NSMutableDictionary *attributes = [@{(id)kCVPixelBufferIOSurfacePropertiesKey: @{}} mutableCopy];
    if (pixelFormat == kCVPixelFormatType_32BGRA) {
        attributes[(id)kCVPixelBufferCGImageCompatibilityKey] = @YES;
        attributes[(id)kCVPixelBufferCGBitmapContextCompatibilityKey] = @YES;
    }
    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                           width,
                                           height,
                                           pixelFormat,
                                           (__bridge CFDictionaryRef)attributes,
                                           &pixelBuffer);
    if (status != kCVReturnSuccess || !pixelBuffer) return NULL;

    size_t sourceRowBytes = 0;
    uint8_t *bgra = WFVirtualCameraCreateAspectFitBGRA(image, width, height, &sourceRowBytes);
    if (!bgra) {
        CVPixelBufferRelease(pixelBuffer);
        return NULL;
    }
    if (CVPixelBufferLockBaseAddress(pixelBuffer, 0) != kCVReturnSuccess) {
        free(bgra);
        CVPixelBufferRelease(pixelBuffer);
        return NULL;
    }

    BOOL filled = NO;
    if (pixelFormat == kCVPixelFormatType_32BGRA && !CVPixelBufferIsPlanar(pixelBuffer)) {
        uint8_t *destination = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
        size_t destinationRowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer);
        if (destination) {
            size_t bytesToCopy = MIN(sourceRowBytes, destinationRowBytes);
            for (size_t row = 0; row < height; row++) {
                memcpy(destination + row * destinationRowBytes,
                       bgra + row * sourceRowBytes,
                       bytesToCopy);
            }
            filled = YES;
        }
    } else if (pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
        filled = WFVirtualCameraFillNV12(pixelBuffer, bgra, sourceRowBytes, YES);
    } else if (pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
        filled = WFVirtualCameraFillNV12(pixelBuffer, bgra, sourceRowBytes, NO);
    }

    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    free(bgra);
    if (!filled) {
        CVPixelBufferRelease(pixelBuffer);
        return NULL;
    }
    return pixelBuffer;
}

#pragma mark - State, persistence and picker

@interface WFVirtualCameraManager () <PHPickerViewControllerDelegate> {
    BOOL _enabled;
    BOOL _rememberLastImage;
    UIImage *_currentImage;
    NSUInteger _imageGeneration;
    CVPixelBufferRef _cachedPixelBuffer;
    size_t _cachedWidth;
    size_t _cachedHeight;
    OSType _cachedPixelFormat;
    NSUInteger _cachedGeneration;
    NSData *_cachedPhotoData;
    BOOL _pickerPresented;
}
@end

@implementation WFVirtualCameraManager

+ (instancetype)shared {
    static WFVirtualCameraManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ manager = [[self alloc] init]; });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    _imageGeneration = 1;
    WolFoxProStore *store = [WolFoxProStore shared];
    BOOL repairedStoredState = NO;
    _rememberLastImage = store.rememberCameraImage;
    if (_rememberLastImage && store.spoofedImagePath.length) {
        _currentImage = WFVirtualCameraNormalizedImage([UIImage imageWithContentsOfFile:store.spoofedImagePath]);
        if (!_currentImage) {
            [[NSFileManager defaultManager] removeItemAtPath:store.spoofedImagePath error:nil];
            store.spoofedImagePath = nil;
            repairedStoredState = YES;
        }
    } else if (!_rememberLastImage && store.spoofedImagePath.length) {
        [[NSFileManager defaultManager] removeItemAtPath:store.spoofedImagePath error:nil];
        store.spoofedImagePath = nil;
        repairedStoredState = YES;
    }
    _enabled = store.mediaUploadActive && _currentImage != nil;
    if (store.mediaUploadActive != _enabled || repairedStoredState) {
        store.mediaUploadActive = _enabled;
        [store saveSettings];
    }
    return self;
}

- (void)dealloc {
    if (_cachedPixelBuffer) CVPixelBufferRelease(_cachedPixelBuffer);
}

- (void)postStateChange {
    void (^postBlock)(void) = ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:WFVirtualCameraStateDidChangeNotification
                                                            object:self];
    };
    if (NSThread.isMainThread) postBlock();
    else dispatch_async(dispatch_get_main_queue(), postBlock);
}

- (void)invalidatePixelBufferCacheLocked {
    if (_cachedPixelBuffer) {
        CVPixelBufferRelease(_cachedPixelBuffer);
        _cachedPixelBuffer = NULL;
    }
    _cachedWidth = 0;
    _cachedHeight = 0;
    _cachedPixelFormat = 0;
    _cachedGeneration = 0;
}

- (BOOL)isEnabled {
    @synchronized (self) { return _enabled; }
}

- (void)setEnabled:(BOOL)enabled {
    BOOL finalValue;
    @synchronized (self) {
        finalValue = enabled && _currentImage != nil && [WFLicenseClient isRuntimeLicenseValid];
        _enabled = finalValue;
    }
    WolFoxProStore *store = [WolFoxProStore shared];
    store.mediaUploadActive = finalValue;
    [store saveSettings];
    [self postStateChange];
}

- (BOOL)rememberLastImage {
    @synchronized (self) { return _rememberLastImage; }
}

- (void)setRememberLastImage:(BOOL)rememberLastImage {
    UIImage *image;
    @synchronized (self) {
        _rememberLastImage = rememberLastImage;
        image = _currentImage;
    }
    WolFoxProStore *store = [WolFoxProStore shared];
    store.rememberCameraImage = rememberLastImage;
    if (rememberLastImage && image) {
        [self writeImageToStorage:image];
    } else if (!rememberLastImage) {
        NSString *path = store.spoofedImagePath ?: [store mediaStoragePath];
        if (path.length) [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        store.spoofedImagePath = nil;
    }
    [store saveSettings];
    [self postStateChange];
}

- (BOOL)hasCurrentImage {
    @synchronized (self) { return _currentImage != nil; }
}

- (UIImage *)currentImage {
    @synchronized (self) { return _currentImage; }
}

- (BOOL)hasStoredImage {
    NSString *path = [WolFoxProStore shared].spoofedImagePath;
    return path.length && [[NSFileManager defaultManager] fileExistsAtPath:path];
}

- (BOOL)writeImageToStorage:(UIImage *)image {
    if (!image) return NO;
    WolFoxProStore *store = [WolFoxProStore shared];
    NSString *path = [store mediaStoragePath];
    NSData *data = UIImageJPEGRepresentation(image, 0.92);
    NSError *error = nil;
    BOOL written = [data writeToFile:path options:NSDataWritingAtomic error:&error];
    if (!written) {
#ifdef DEBUG
        WFLog(@"[WolFox][CAM] image_write_failed=%@", error.localizedDescription);
#endif
        return NO;
    }
    NSDictionary *attributes = @{NSFileProtectionKey: NSFileProtectionCompleteUntilFirstUserAuthentication};
    [[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:path error:nil];
    store.spoofedImagePath = path;
    return YES;
}

- (void)setSelectedImage:(UIImage *)image {
    UIImage *normalized = WFVirtualCameraNormalizedImage(image);
    if (!normalized) return;
    @synchronized (self) {
        _currentImage = normalized;
        _cachedPhotoData = nil;
        _imageGeneration++;
        [self invalidatePixelBufferCacheLocked];
        _enabled = [WFLicenseClient isRuntimeLicenseValid];
    }
    WolFoxProStore *store = [WolFoxProStore shared];
    store.mediaUploadActive = self.enabled;
    if ([self rememberLastImage]) {
        [self writeImageToStorage:normalized];
    } else {
        NSString *oldPath = store.spoofedImagePath;
        if (oldPath.length) [[NSFileManager defaultManager] removeItemAtPath:oldPath error:nil];
        store.spoofedImagePath = nil;
    }
    [store saveSettings];
    [self postStateChange];
}

- (BOOL)loadStoredImageIfNeeded {
    @synchronized (self) { if (_currentImage) return YES; }
    NSString *path = [WolFoxProStore shared].spoofedImagePath;
    UIImage *image = path.length ? WFVirtualCameraNormalizedImage([UIImage imageWithContentsOfFile:path]) : nil;
    if (!image) return NO;
    @synchronized (self) {
        _currentImage = image;
        _cachedPhotoData = nil;
        _imageGeneration++;
        [self invalidatePixelBufferCacheLocked];
    }
    return YES;
}

- (BOOL)enableUsingAvailableImage {
    BOOL available = self.hasCurrentImage || [self loadStoredImageIfNeeded];
    self.enabled = available;
    return self.enabled;
}

- (void)discardImageFromMemory {
    @synchronized (self) {
        _enabled = NO;
        _currentImage = nil;
        _cachedPhotoData = nil;
        _imageGeneration++;
        [self invalidatePixelBufferCacheLocked];
    }
    WolFoxProStore *store = [WolFoxProStore shared];
    store.mediaUploadActive = NO;
    [store saveSettings];
    [self postStateChange];
}

- (void)clearAllImageData {
    WolFoxProStore *store = [WolFoxProStore shared];
    NSString *path = store.spoofedImagePath ?: [store mediaStoragePath];
    @synchronized (self) {
        _enabled = NO;
        _rememberLastImage = NO;
        _currentImage = nil;
        _cachedPhotoData = nil;
        _imageGeneration++;
        [self invalidatePixelBufferCacheLocked];
    }
    if (path.length) [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    store.mediaUploadActive = NO;
    store.rememberCameraImage = NO;
    store.spoofedImagePath = nil;
    [store saveSettings];
    [self postStateChange];
}

- (void)presentImagePickerFromViewController:(UIViewController *)viewController {
    @synchronized (self) {
        if (_pickerPresented) return;
        _pickerPresented = YES;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *presenter = WFVirtualCameraTopController(viewController) ?: WFVirtualCameraBestPresenter();
        if (!presenter || presenter.presentedViewController || !presenter.view.window) {
            @synchronized (self) { self->_pickerPresented = NO; }
#ifdef DEBUG
            WFLog(@"[WolFox][CAM] picker_presenter_unavailable");
#endif
            [self postStateChange];
            return;
        }
        PHPickerConfiguration *configuration = [[PHPickerConfiguration alloc] init];
        configuration.filter = PHPickerFilter.imagesFilter;
        configuration.selectionLimit = 1;
        configuration.preferredAssetRepresentationMode = PHPickerConfigurationAssetRepresentationModeCurrent;
        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:configuration];
        picker.delegate = self;
        picker.modalPresentationStyle = UIModalPresentationFullScreen;
        [presenter presentViewController:picker animated:YES completion:nil];
    });
}

- (void)picker:(PHPickerViewController *)picker
didFinishPicking:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14.0)) {
    @synchronized (self) { _pickerPresented = NO; }
    PHPickerResult *result = results.firstObject;
    if (!result || ![result.itemProvider canLoadObjectOfClass:UIImage.class]) {
        [picker dismissViewControllerAnimated:YES completion:^{ [self postStateChange]; }];
        return;
    }

    // اختيار واحد يكفي: نغلق المنتقي فوراً، ثم نطبّق الصورة ونشغّل البث تلقائياً.
    [picker dismissViewControllerAnimated:YES completion:nil];
    __weak typeof(self) weakSelf = self;
    [result.itemProvider loadObjectOfClass:UIImage.class completionHandler:^(id<NSItemProviderReading> object,
                                                                              NSError *error) {
        if (error || ![object isKindOfClass:UIImage.class]) {
            [weakSelf postStateChange];
            return;
        }
        UIImage *selectedImage = (UIImage *)object;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf setSelectedImage:selectedImage];
            UINotificationFeedbackGenerator *feedback = [UINotificationFeedbackGenerator new];
            [feedback notificationOccurred:UINotificationFeedbackTypeSuccess];
            [[NSNotificationCenter defaultCenter]
                postNotificationName:WFVirtualCameraImageDidSelectNotification
                              object:strongSelf];
        });
    }];
}

- (NSData *)photoDataRepresentation {
    @synchronized (self) {
        if (!_enabled || !_currentImage) return nil;
        if (!_cachedPhotoData) _cachedPhotoData = UIImageJPEGRepresentation(_currentImage, 0.96);
        return _cachedPhotoData;
    }
}

#pragma mark - Sample-buffer replacement

- (CVPixelBufferRef)copyPhotoPixelBufferMatching:(CVPixelBufferRef)sourceBuffer CF_RETURNS_RETAINED {
    if (!sourceBuffer) return NULL;
    size_t width = CVPixelBufferGetWidth(sourceBuffer);
    size_t height = CVPixelBufferGetHeight(sourceBuffer);
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(sourceBuffer);

    @synchronized (self) {
        if (!_enabled || !_currentImage) return NULL;
        if (_cachedPixelBuffer && _cachedWidth == width && _cachedHeight == height &&
            _cachedPixelFormat == pixelFormat && _cachedGeneration == _imageGeneration) {
            WFVirtualCameraCopyPixelAttachments(sourceBuffer, _cachedPixelBuffer);
            CVPixelBufferRetain(_cachedPixelBuffer);
            return _cachedPixelBuffer;
        }
        CVPixelBufferRef newBuffer = WFVirtualCameraCreatePixelBuffer(_currentImage,
                                                                       width,
                                                                       height,
                                                                       pixelFormat);
        if (!newBuffer) return NULL;
        WFVirtualCameraCopyPixelAttachments(sourceBuffer, newBuffer);
        [self invalidatePixelBufferCacheLocked];
        _cachedPixelBuffer = newBuffer;
        _cachedWidth = width;
        _cachedHeight = height;
        _cachedPixelFormat = pixelFormat;
        _cachedGeneration = _imageGeneration;
        CVPixelBufferRetain(_cachedPixelBuffer);
        return _cachedPixelBuffer;
    }
}

- (CMSampleBufferRef)copyReplacementForSampleBuffer:(CMSampleBufferRef)sampleBuffer CF_RETURNS_RETAINED {
    if (!sampleBuffer || ![WFLicenseClient isRuntimeLicenseValid] || !self.enabled) return NULL;
    CVImageBufferRef sourceImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!sourceImageBuffer) return NULL;
    CVPixelBufferRef replacementPixelBuffer = [self copyPhotoPixelBufferMatching:(CVPixelBufferRef)sourceImageBuffer];
    if (!replacementPixelBuffer) return NULL;

    CMVideoFormatDescriptionRef formatDescription = NULL;
    OSStatus formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault,
                                                                          replacementPixelBuffer,
                                                                          &formatDescription);
    if (formatStatus != noErr || !formatDescription) {
        CVPixelBufferRelease(replacementPixelBuffer);
        return NULL;
    }
    CMSampleTimingInfo timingInfo = kCMTimingInfoInvalid;
    if (CMSampleBufferGetSampleTimingInfo(sampleBuffer, 0, &timingInfo) != noErr) {
        timingInfo.duration = CMSampleBufferGetDuration(sampleBuffer);
        timingInfo.presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        timingInfo.decodeTimeStamp = CMSampleBufferGetDecodeTimeStamp(sampleBuffer);
    }
    CMSampleBufferRef replacement = NULL;
    OSStatus sampleStatus = CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault,
                                                                     replacementPixelBuffer,
                                                                     formatDescription,
                                                                     &timingInfo,
                                                                     &replacement);
    if (sampleStatus == noErr && replacement) {
        CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault,
                                                                     sampleBuffer,
                                                                     kCMAttachmentMode_ShouldPropagate);
        if (attachments) {
            CMSetAttachments(replacement, attachments, kCMAttachmentMode_ShouldPropagate);
            CFRelease(attachments);
        }
        CFArrayRef sourceSampleAttachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false);
        CFArrayRef destinationSampleAttachments = CMSampleBufferGetSampleAttachmentsArray(replacement, true);
        if (sourceSampleAttachments && destinationSampleAttachments &&
            CFArrayGetCount(sourceSampleAttachments) > 0 && CFArrayGetCount(destinationSampleAttachments) > 0) {
            CFDictionaryRef sourceDictionary = (CFDictionaryRef)CFArrayGetValueAtIndex(sourceSampleAttachments, 0);
            CFMutableDictionaryRef destinationDictionary =
                (CFMutableDictionaryRef)CFArrayGetValueAtIndex(destinationSampleAttachments, 0);
            CFDictionaryRemoveAllValues(destinationDictionary);
            if (sourceDictionary) CFDictionaryApplyFunction(sourceDictionary,
                                                             WFVirtualCameraCopyDictionaryEntry,
                                                             destinationDictionary);
        }
    }
    CFRelease(formatDescription);
    CVPixelBufferRelease(replacementPixelBuffer);
    return replacement;
}

@end

#pragma mark - Capture output delegate proxy

@interface WFVirtualCameraOutputProxy () {
    __weak id<AVCaptureVideoDataOutputSampleBufferDelegate> _target;
}
@end

@implementation WFVirtualCameraOutputProxy

- (instancetype)initWithTarget:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)target {
    _target = target;
    return self;
}

- (id<AVCaptureVideoDataOutputSampleBufferDelegate>)target { return _target; }

- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    id<AVCaptureVideoDataOutputSampleBufferDelegate> target = _target;
    if (!target || ![target respondsToSelector:_cmd]) return;
    CMSampleBufferRef replacement = [[WFVirtualCameraManager shared]
                                      copyReplacementForSampleBuffer:sampleBuffer];
    [target captureOutput:output
    didOutputSampleBuffer:(replacement ?: sampleBuffer)
           fromConnection:connection];
    if (replacement) CFRelease(replacement);
}

- (void)captureOutput:(AVCaptureOutput *)output
 didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    id<AVCaptureVideoDataOutputSampleBufferDelegate> target = _target;
    if ([target respondsToSelector:_cmd]) {
        [target captureOutput:output didDropSampleBuffer:sampleBuffer fromConnection:connection];
    }
}

- (BOOL)respondsToSelector:(SEL)selector {
    if (selector == @selector(captureOutput:didOutputSampleBuffer:fromConnection:) ||
        selector == @selector(captureOutput:didDropSampleBuffer:fromConnection:)) {
        return [_target respondsToSelector:selector];
    }
    return [_target respondsToSelector:selector] || [super respondsToSelector:selector];
}

- (BOOL)conformsToProtocol:(Protocol *)protocol {
    return protocol == @protocol(AVCaptureVideoDataOutputSampleBufferDelegate) ||
           [_target conformsToProtocol:protocol];
}

- (Class)class { return [_target class]; }
- (BOOL)isKindOfClass:(Class)aClass { return [_target isKindOfClass:aClass]; }
- (NSString *)description { return [_target description]; }

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    NSMethodSignature *signature = [(NSObject *)_target methodSignatureForSelector:selector];
    return signature ?: [NSObject instanceMethodSignatureForSelector:@selector(description)];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    id target = _target;
    if (target && [target respondsToSelector:invocation.selector]) {
        [invocation invokeWithTarget:target];
        return;
    }
    [NSException raise:NSInvalidArgumentException
                format:@"WFVirtualCameraOutputProxy cannot forward selector %@",
                       NSStringFromSelector(invocation.selector)];
}

@end
