#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

@interface K7GPSStore : NSObject
@property(nonatomic, assign) BOOL locationEnabled;
@property(nonatomic, assign) BOOL cameraEnabled;
@property(nonatomic, assign) NSInteger revealMode;
@property(nonatomic, assign) CLLocationCoordinate2D selectedCoordinate;
@property(nonatomic, copy) NSString *selectedTitle;
@property(nonatomic, strong) NSArray<NSDictionary *> *savedLocations;
+ (instancetype)shared;
- (void)save;
- (void)addSavedLocationWithTitle:(NSString *)title coordinate:(CLLocationCoordinate2D)coordinate;
- (void)removeSavedLocationAtIndex:(NSUInteger)index;
@end

NS_ASSUME_NONNULL_END
