#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WGFeatureKind) {
    WGFeatureGhostMode,
    WGFeatureMessages,
    WGFeatureStatuses,
    WGFeatureVoiceChanger,
    WGFeatureCallRecordings,
    WGFeatureMultiAccount,
    WGFeatureCleaning,
    WGFeatureFakeContact,
    WGFeatureOnlineNotify,
    WGFeatureDriveBackup,
};

@interface WGFeatureDescriptor : NSObject
@property (nonatomic) WGFeatureKind kind;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *iconName;
@property (nonatomic) BOOL enabled;
@end

@interface WGFeatureRegistry : NSObject
+ (instancetype)shared;
- (NSArray<WGFeatureDescriptor *> *)allFeatures;
- (nullable WGFeatureDescriptor *)featureForIdentifier:(NSString *)identifier;
@end

NS_ASSUME_NONNULL_END
