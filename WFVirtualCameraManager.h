#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN

/// تتغير عند اختيار صورة أو تشغيل/إيقاف/مسح الكاميرا الافتراضية.
FOUNDATION_EXPORT NSNotificationName const WFVirtualCameraStateDidChangeNotification;

/// يرسلها هوك AVCaptureSession على الخيط الرئيسي بعد بدء جلسة كاميرا.
FOUNDATION_EXPORT NSNotificationName const WFVirtualCameraSessionDidStartNotification;

/// تُرسل بعد اكتمال اختيار صورة جديدة، كي تُخفى أدوات WolFox قبل الالتقاط.
FOUNDATION_EXPORT NSNotificationName const WFVirtualCameraImageDidSelectNotification;

@interface WFVirtualCameraManager : NSObject

@property (nonatomic, assign, getter=isEnabled) BOOL enabled;
@property (nonatomic, assign) BOOL rememberLastImage;
@property (nonatomic, readonly) BOOL hasCurrentImage;
@property (nonatomic, readonly) BOOL hasStoredImage;
@property (nonatomic, strong, readonly, nullable) UIImage *currentImage;

+ (instancetype)shared;

/// يشغّل البث إذا كانت هناك صورة في الذاكرة أو صورة محفوظة صالحة.
- (BOOL)enableUsingAvailableImage;

/// يفتح PHPicker لاختيار صورة واحدة؛ nil يعني اختيار أفضل متحكم ظاهر.
- (void)presentImagePickerFromViewController:(nullable UIViewController *)viewController;

/// يوقف البث ويمسح نسخة الذاكرة فقط، مع إبقاء الصورة المحفوظة إن فُعّل التذكر.
- (void)discardImageFromMemory;

/// يوقف البث ويحذف الصورة من الذاكرة والتخزين ويلغي خيار التذكر.
- (void)clearAllImageData;

/// يُرجع إطاراً جديداً يطابق أبعاد وصيغة وتوقيت الإطار الأصلي، أو NULL عند عدم الاستبدال.
- (nullable CMSampleBufferRef)copyReplacementForSampleBuffer:(CMSampleBufferRef)sampleBuffer
    CF_RETURNS_RETAINED;

/// ينشئ Pixel Buffer للصورة المختارة مطابقاً لبنية خرج الصورة الثابتة.
- (nullable CVPixelBufferRef)copyPhotoPixelBufferMatching:(CVPixelBufferRef)sourceBuffer
    CF_RETURNS_RETAINED;

/// تمثيل JPEG نظيف للصورة المختارة، لا يحتوي على أزرار أو طبقات واجهة.
- (nullable NSData *)photoDataRepresentation;

@end

/// وكيل يحتفظ به AVCaptureVideoDataOutput عبر associated object ويعيد توجيه بقية رسائل delegate.
@interface WFVirtualCameraOutputProxy : NSProxy <AVCaptureVideoDataOutputSampleBufferDelegate>
- (instancetype)initWithTarget:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)target;
- (nullable id<AVCaptureVideoDataOutputSampleBufferDelegate>)target;
@end

NS_ASSUME_NONNULL_END
