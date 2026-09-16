#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface SHProcessController : NSObject
+ (BOOL)isHUDRunning;
+ (BOOL)startHUD:(NSError **)error;
+ (void)reloadHUD;
+ (void)stopHUD;
@end
NS_ASSUME_NONNULL_END
