#import "SHHUDAppDelegate.h"
#import "SHHUDCanvasView.h"
#import "SHSystemOverlay.h"
#import "SHSettings.h"
#import <unistd.h>

@implementation SHHUDApplication @end

@interface SHHUDAppDelegate ()
@property(nonatomic, strong) SHHUDCanvasView *canvas;
@property(nonatomic, strong) SHRoomSocket *socket;
@property(nonatomic, strong) NSTimer *mockTimer;
@property(nonatomic, strong) UIButton *dragHandle;
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

    // draggable handle for moving overlay (only this part will receive touches)
    self.dragHandle = [UIButton buttonWithType:UIButtonTypeCustom];
    self.dragHandle.frame = CGRectMake(12, 12, 44, 44);
    self.dragHandle.backgroundColor = [UIColor colorWithWhite:0 alpha:.18];
    self.dragHandle.layer.cornerRadius = 22; self.dragHandle.clipsToBounds = YES;
    self.dragHandle.tag = 9999; self.dragHandle.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.dragHandle setTitle:@"" forState:UIControlStateNormal];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDrag:)];
    [self.dragHandle addGestureRecognizer:pan];
    UITapGestureRecognizer *dbl = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleReset:)]; dbl.numberOfTapsRequired=2; [self.dragHandle addGestureRecognizer:dbl];
    [root.view addSubview:self.dragHandle];

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
- (BOOL)saveSettingsAndRefresh {
    SHSettings *s = SHSettings.load; [s save]; [self.canvas reloadSettings]; [self.canvas setNeedsDisplay]; return YES;
}
- (void)reloadHUD {
    SHSettings *s=SHSettings.load; [self.canvas reloadSettings]; [self.socket stop];
    // manage mock timer
    if (s.mockMode) {
        if (!self.mockTimer) self.mockTimer = [NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(_tickMock:) userInfo:nil repeats:YES];
    } else {
        [self.mockTimer invalidate]; self.mockTimer = nil;
    }
    if(!s.room.length||!s.host.length) return;
    self.socket=[[SHRoomSocket alloc] initWithHost:s.host port:s.port room:s.room]; self.socket.delegate=self; [self.socket start];
}
- (void)rehostHUD {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.2*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ NSError *error=nil; BOOL ok = [[SHSystemOverlay shared] hostWindow:self.window secure:SHSettings.load.secureOverlay error:&error];
        if (!ok) {
            NSLog(@"SharedHUD: hostWindow failed: %@", error);
            self.window.windowLevel = UIWindowLevelAlert + 1000; self.window.hidden = NO; [self.window.rootViewController.view setNeedsLayout]; [self.window.rootViewController.view layoutIfNeeded];
        } else { self.window.hidden = NO; }
    });
}
- (void)dismissHUD { [self.socket stop]; [[SHSystemOverlay shared] unhostWindow]; [self.window setHidden:YES]; unlink(SHPIDPath.fileSystemRepresentation); exit(0); }
- (void)roomSocketDidChangeState:(NSString *)state { self.canvas.connectionState=state; }
- (void)roomSocketDidReceiveFrame:(SHBattleFrame *)frame { // real frames override mock
    self.canvas.battleFrame=frame;
}
- (void)_tickMock:(NSTimer *)t {
    if (!SHSettings.load.mockMode) return;
    SHBattleFrame *frame = [SHBattleFrame mockFrame]; self.canvas.battleFrame = frame;
}
- (void)handleDrag:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:self.window];
    if (g.state == UIGestureRecognizerStateChanged || g.state == UIGestureRecognizerStateEnded) {
        SHSettings *s = SHSettings.load;
        CGFloat width = self.canvas.bounds.size.width, height = self.canvas.bounds.size.height;
        CGFloat scale = MIN(width / 2400.0, height / 1080.0);
        s.offsetX += t.x / scale; s.offsetY += t.y / scale; [s save]; self.canvas.settings = s; [self.canvas setNeedsDisplay];
        [g setTranslation:CGPointZero inView:self.window];
    }
}
- (void)handleReset:(UITapGestureRecognizer *)g {
    SHSettings *s = SHSettings.load; s.offsetX = 0; s.offsetY = 0; [s save]; self.canvas.settings = s; [self.canvas setNeedsDisplay];
}
- (void)applicationWillTerminate:(UIApplication *)application { [self.socket stop]; [[SHSystemOverlay shared] unhostWindow]; unlink(SHPIDPath.fileSystemRepresentation); }
- (void)dealloc { [self.mockTimer invalidate]; CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(),(__bridge const void *)self); }
@end
