#import <UIKit/UIKit.h>
#import "SHRoomSocket.h"

@interface SHHUDApplication : UIApplication @end
@interface SHHUDAppDelegate : UIResponder <UIApplicationDelegate, SHRoomSocketDelegate>
@property(nonatomic, strong) UIWindow *window;
- (void)reloadHUD;
- (void)dismissHUD;
- (void)rehostHUD;
@end
