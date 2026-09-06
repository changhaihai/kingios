#import <UIKit/UIKit.h>
#import <objc/message.h>

// Runtime-only bridge for the SpringBoard accessibility window host. This
// keeps private framework symbols out of the link table while matching the
// registration sequence used by TrollSpeed.
void hai_register_global_window(UIWindow *window) {
    Class hostClass = NSClassFromString(@"SBSAccessibilityWindowHostingController");
    if (!hostClass || !window) return;
    id host = [[hostClass alloc] init];
    SEL contextSel = NSSelectorFromString(@"_contextId");
    SEL registerSel = NSSelectorFromString(@"registerWindowWithContextID:atLevel:");
    if (![window respondsToSelector:contextSel] || ![host respondsToSelector:registerSel]) return;
    unsigned int contextId = ((unsigned int (*)(id, SEL))objc_msgSend)(window, contextSel);
    double level = window.windowLevel;
    NSMethodSignature *sig = [host methodSignatureForSelector:registerSel];
    if (!sig) return;
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = host;
    inv.selector = registerSel;
    [inv setArgument:&contextId atIndex:2];
    [inv setArgument:&level atIndex:3];
    [inv invoke];
}
