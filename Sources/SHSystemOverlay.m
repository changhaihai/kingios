#import "SHSystemOverlay.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <dlfcn.h>

@implementation SHHUDWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event { return nil; }
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event { return NO; }
@end

@interface SHSystemOverlay ()
@property(nonatomic, strong) id hostingController;
@property(nonatomic) uint32_t contextID;
@end

@implementation SHSystemOverlay
+ (instancetype)shared { static SHSystemOverlay *v; static dispatch_once_t once; dispatch_once(&once,^{v=[self new];}); return v; }
- (BOOL)hostWindow:(UIWindow *)window secure:(BOOL)secure error:(NSError **)error {
    dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_NOW);
    @try {
        [window setValue:@YES forKey:@"_isSystemWindow"];
        [window setValue:@YES forKey:@"_isWindowServerHostingManaged"];
        [window setValue:@YES forKey:@"_ignoresHitTest"];
        [window setValue:@(secure) forKey:@"_shouldCreateContextAsSecure"];
    } @catch (__unused NSException *exception) {}
    window.windowLevel = UIWindowLevelAlert + 1000;
    window.hidden = NO;
    [window.rootViewController.view setNeedsLayout];
    [window.rootViewController.view layoutIfNeeded];

    id context = nil;
    @try { context = [window.layer valueForKey:@"context"]; } @catch (__unused NSException *exception) {}
    NSNumber *identifier = nil;
    @try { identifier = [context valueForKey:@"contextId"]; } @catch (__unused NSException *exception) {}
    if (!identifier) @try { identifier = [context valueForKey:@"_contextId"]; } @catch (__unused NSException *exception) {}
    self.contextID = identifier.unsignedIntValue;
    if (!self.contextID) {
        if (error) *error=[NSError errorWithDomain:@"SharedHUD" code:1 userInfo:@{NSLocalizedDescriptionKey:@"无法获取 QuartzCore context ID"}];
        NSLog(@"SharedHUD: failed to get context id from window.layer.context (context=%@)", context);
        return NO;
    }

    Class cls = NSClassFromString(@"SBSAccessibilityWindowHostingController");
    if (!cls) {
        if (error) *error=[NSError errorWithDomain:@"SharedHUD" code:2 userInfo:@{NSLocalizedDescriptionKey:@"缺少 SpringBoard 窗口托管权限"}];
        NSLog(@"SharedHUD: SBSAccessibilityWindowHostingController class not found");
        return NO;
    }
    SEL shared = NSSelectorFromString(@"sharedInstance");
    self.hostingController = [cls respondsToSelector:shared] ? ((id(*)(id,SEL))objc_msgSend)(cls,shared) : [cls new];
    SEL registerSelector = NSSelectorFromString(@"registerWindowWithContextID:atLevel:");
    if (![self.hostingController respondsToSelector:registerSelector]) {
        if (error) *error=[NSError errorWithDomain:@"SharedHUD" code:3 userInfo:@{NSLocalizedDescriptionKey:@"系统版本不支持窗口注册接口"}];
        NSLog(@"SharedHUD: hostingController does not respond to registerWindowWithContextID:atLevel:");
        return NO;
    }
    ((void(*)(id,SEL,uint32_t,double))objc_msgSend)(self.hostingController,registerSelector,self.contextID,100000.0);
    return YES;
}
- (void)unhostWindow {
    SEL selector=NSSelectorFromString(@"unregisterWindowWithContextID:");
    if (self.contextID && [self.hostingController respondsToSelector:selector]) ((void(*)(id,SEL,uint32_t))objc_msgSend)(self.hostingController,selector,self.contextID);
    self.contextID=0; self.hostingController=nil;
}
@end
