#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <objc/runtime.h>

typedef void (*VoidFn)(void);
typedef void (*ClassFn)(Class);

static void callVoidSymbol(const char *name) {
    VoidFn fn = (VoidFn)dlsym(RTLD_DEFAULT, name);
    if (fn) fn();
}

void hai_prepare_hud_plugin(void) {
    // These symbols are exported by UIKit/GraphicsServices on TrollStore
    // supported iOS versions but are intentionally resolved at runtime.
    callVoidSymbol("UIScreenInitialize");
    callVoidSymbol("GSInitialize");
    callVoidSymbol("BKSDisplayServicesStart");
    callVoidSymbol("UIApplicationInitialize");

    ClassFn instantiate = (ClassFn)dlsym(RTLD_DEFAULT, "UIApplicationInstantiateSingleton");
    Class appClass = objc_getClass("HUDMainApplication");
    if (instantiate && appClass) instantiate(appClass);

    UIApplication *app = [UIApplication sharedApplication];
    SEL accessibilityInit = NSSelectorFromString(@"_accessibilityInit");
    if ([app respondsToSelector:accessibilityInit]) [app performSelector:accessibilityInit];
}
