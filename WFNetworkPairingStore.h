// WFNetworkPairingStore.h - Secure pairing profiles for WolFox 1.8.4
#import <Foundation/Foundation.h>
#import <Security/Security.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WFNetworkProfileKind) {
    WFNetworkProfileKindRadar = 0,
    WFNetworkProfileKindWiFi = 1,
    WFNetworkProfileKindTLS = 2,
};

@interface WFNetworkPairingProfile : NSObject <NSCopying>
@property (nonatomic, copy) NSString *profileID;
@property (nonatomic, assign) WFNetworkProfileKind kind;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *host;
@property (nonatomic, assign) NSInteger port;
@property (nonatomic, copy) NSString *deviceIdentifier;
@property (nonatomic, copy) NSString *ssid;
@property (nonatomic, copy) NSString *certificateSHA256;
@property (nonatomic, assign) BOOL autoReconnect;
@property (nonatomic, strong) NSDate *updatedAt;
@end

@interface WFNetworkPairingStore : NSObject
+ (instancetype)shared;
@property (nonatomic, readonly, copy) NSArray<WFNetworkPairingProfile *> *profiles;
- (BOOL)saveProfile:(WFNetworkPairingProfile *)profile
             secret:(nullable NSString *)secret
              error:(NSError * _Nullable * _Nullable)error;
- (BOOL)deleteProfileID:(NSString *)profileID error:(NSError * _Nullable * _Nullable)error;
- (nullable WFNetworkPairingProfile *)profileWithID:(NSString *)profileID;
- (nullable NSString *)secretForProfileID:(NSString *)profileID
                                    error:(NSError * _Nullable * _Nullable)error;
/// Validates the leaf certificate against the saved SHA-256 pin. Never bypasses system trust.
- (BOOL)validateServerTrust:(SecTrustRef)trust
               forProfileID:(NSString *)profileID
                      error:(NSError * _Nullable * _Nullable)error;
/// Profiles eligible for user-authorized automatic reconnection.
- (NSArray<WFNetworkPairingProfile *> *)automaticReconnectProfiles;
@end

NS_ASSUME_NONNULL_END
