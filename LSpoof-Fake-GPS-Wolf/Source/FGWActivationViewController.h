#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FGWActivationViewController : UIViewController
@property (nonatomic, copy, nullable) void (^activationCompleted)(void);
+ (BOOL)isLocallyActivated;
@end

NS_ASSUME_NONNULL_END
