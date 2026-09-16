#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@interface SHHUDWindow : UIWindow
@end
@interface SHSystemOverlay : NSObject
+ (instancetype)shared;
- (BOOL)hostWindow:(UIWindow *)window secure:(BOOL)secure error:(NSError **)error;
- (void)unhostWindow;
@end
NS_ASSUME_NONNULL_END
