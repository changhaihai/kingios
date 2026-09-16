#import "SHHUDAppDelegate.h"
#import "SHHUDCanvasView.h"
#import "SHSystemOverlay.h"
#import "SHSettings.h"
#import <unistd.h>

@implementation SHHUDApplication @end

@interface SHHUDAppDelegate ()
@property(nonatomic, strong) SHHUDCanvasView *canvas;
@property(nonatomic, strong) SHRoomSocket *socket;
@end

static void SHHUDNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef info) {
    SHHUDAppDelegate *delegate=(__bridge SHHUDAppDelegate *)observer; NSString *value=(__bridge NSString *)name;
    dispatch_async(dispatch_get_main_queue(),^{
        if([value isEqualToString:SHReloadNotification])[delegate reloadHUD];
        else if([value isEqualToString:SHDismissNotification])[delegate dismissHUD];
        else if([value isEqualToString:SHSpringBoardLaunchedNotification])[delegate rehostHUD];
    });
}

@implementation SHHUDAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    application.idleTimerDisabled=YES;
    [@(getpid()).stringValue writeToFile:SHPIDPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    self.canvas=[[SHHUDCanvasView alloc] initWithFrame:UIScreen.mainScreen.bounds]; self.canvas.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    UIViewController *root=[UIViewController new]; root.view.backgroundColor=UIColor.clearColor; [root.view addSubview:self.canvas]; self.canvas.frame=root.view.bounds;
    SHHUDWindow *window=[[SHHUDWindow alloc] initWithFrame:UIScreen.mainScreen.bounds]; window.backgroundColor=UIColor.clearColor; window.rootViewController=root; self.window=window;
    [self rehostHUD]; [self reloadHUD];
    CFNotificationCenterRef c=CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(c,(__bridge const void *)self,SHHUDNotification,(__bridge CFStringRef)SHReloadNotification,NULL,CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(c,(__bridge const void *)self,SHHUDNotification,(__bridge CFStringRef)SHDismissNotification,NULL,CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(c,(__bridge const void *)self,SHHUDNotification,(__bridge CFStringRef)SHSpringBoardLaunchedNotification,NULL,CFNotificationSuspensionBehaviorDeliverImmediately);
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged) name:UIDeviceOrientationDidChangeNotification object:nil]; [UIDevice.currentDevice beginGeneratingDeviceOrientationNotifications];
    CFNotificationCenterPostNotification(c,(__bridge CFStringRef)SHLaunchedNotification,NULL,NULL,YES);
    return YES;
}
- (void)orientationChanged { self.window.frame=UIScreen.mainScreen.bounds; self.canvas.frame=self.window.bounds; [self.canvas setNeedsDisplay]; [self rehostHUD]; }
- (void)reloadHUD {
    SHSettings *s=SHSettings.load; [self.canvas reloadSettings]; [self.socket stop];
    if(!s.room.length||!s.host.length)return;
    self.socket=[[SHRoomSocket alloc] initWithHost:s.host port:s.port room:s.room]; self.socket.delegate=self; [self.socket start];
}
- (void)rehostHUD {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.2*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ NSError *error=nil; [[SHSystemOverlay shared] hostWindow:self.window secure:SHSettings.load.secureOverlay error:&error]; if(error)self.canvas.connectionState=error.localizedDescription; });
}
- (void)dismissHUD { [self.socket stop]; [[SHSystemOverlay shared] unhostWindow]; [self.window setHidden:YES]; unlink(SHPIDPath.fileSystemRepresentation); exit(0); }
- (void)roomSocketDidChangeState:(NSString *)state { self.canvas.connectionState=state; }
- (void)roomSocketDidReceiveFrame:(SHBattleFrame *)frame { self.canvas.battleFrame=frame; }
- (void)applicationWillTerminate:(UIApplication *)application { [self.socket stop]; [[SHSystemOverlay shared] unhostWindow]; unlink(SHPIDPath.fileSystemRepresentation); }
- (void)dealloc { CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(),(__bridge const void *)self); }
@end
