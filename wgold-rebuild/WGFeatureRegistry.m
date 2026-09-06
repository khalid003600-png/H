#import "WGFeatureRegistry.h"

@implementation WGFeatureDescriptor
@end

@implementation WGFeatureRegistry

+ (instancetype)shared {
    static WGFeatureRegistry *obj;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ obj = [WGFeatureRegistry new]; });
    return obj;
}

- (WGFeatureDescriptor *)item:(WGFeatureKind)kind id:(NSString *)identifier title:(NSString *)title icon:(NSString *)icon {
    WGFeatureDescriptor *d = [WGFeatureDescriptor new];
    d.kind = kind;
    d.identifier = identifier;
    d.title = title;
    d.iconName = icon;
    d.enabled = YES;
    return d;
}

- (NSArray<WGFeatureDescriptor *> *)allFeatures {
    return @[
        [self item:WGFeatureGhostMode id:@"ghost" title:@"Ghost Mode" icon:@"MessageGhostIcon"],
        [self item:WGFeatureMessages id:@"messages" title:@"Messages" icon:@"MessagesIcon"],
        [self item:WGFeatureStatuses id:@"statuses" title:@"Statuses" icon:@"StatusesIcon"],
        [self item:WGFeatureVoiceChanger id:@"voice" title:@"Voice Changer" icon:@"VoiceChangerIcon"],
        [self item:WGFeatureCallRecordings id:@"calls" title:@"Call Recordings" icon:@"CallRecordingsIcon"],
        [self item:WGFeatureMultiAccount id:@"multi-account" title:@"Multi Account" icon:@"MultiAccountIcon"],
        [self item:WGFeatureCleaning id:@"cleaning" title:@"Cleaning" icon:@"CleaningIcon"],
        [self item:WGFeatureFakeContact id:@"fake-contact" title:@"Fake Contact" icon:@"ContactsIcon24x24"],
        [self item:WGFeatureOnlineNotify id:@"online-notify" title:@"Online Activity" icon:@"ActivityNotifyIcon"],
        [self item:WGFeatureDriveBackup id:@"drive" title:@"Google Drive Backup" icon:@"DriveBackupIcon"],
    ];
}

- (WGFeatureDescriptor *)featureForIdentifier:(NSString *)identifier {
    for (WGFeatureDescriptor *item in [self allFeatures]) {
        if ([item.identifier isEqualToString:identifier]) return item;
    }
    return nil;
}

@end
