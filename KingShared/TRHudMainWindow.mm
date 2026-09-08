#import "TRHudMainWindow.h"
@implementation TRHudMainWindow
+ (BOOL)_isSecure { return YES; }
+ (BOOL)_isSystemWindow { return YES; }
- (BOOL)_windowServerHostingManaged { return NO; }
- (BOOL)_isWindowServerHostingManaged { return NO; }
- (BOOL)_ignoresHitTest { return YES; }
- (BOOL)_isSecure { return YES; }
- (BOOL)_shouldCreateContextAsSecure { return YES; }
@end
