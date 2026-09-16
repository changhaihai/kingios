#import "SHAppDelegate.h"
#import "SHControlViewController.h"

@implementation SHAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController=[[UINavigationController alloc] initWithRootViewController:[SHControlViewController new]];
    [self.window makeKeyAndVisible]; return YES;
}
@end
