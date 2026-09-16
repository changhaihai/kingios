#import <UIKit/UIKit.h>
#import "SHAppDelegate.h"
#import "SHHUDAppDelegate.h"
#import "SHSettings.h"
#import <signal.h>
#import <unistd.h>

static pid_t SHReadPID(void) { return (pid_t)[[NSString stringWithContentsOfFile:SHPIDPath encoding:NSUTF8StringEncoding error:nil] intValue]; }

int main(int argc, char *argv[]) {
    @autoreleasepool {
        NSString *mode=argc>1?[NSString stringWithUTF8String:argv[1]]:@"";
        if([mode isEqualToString:@"-check"]){ pid_t pid=SHReadPID(); return pid>1&&kill(pid,0)==0?0:1; }
        if([mode isEqualToString:@"-exit"]){ pid_t pid=SHReadPID(); if(pid>1)kill(pid,SIGTERM); unlink(SHPIDPath.fileSystemRepresentation); return 0; }
        if([mode isEqualToString:@"-hud"]) return UIApplicationMain(argc,argv,NSStringFromClass(SHHUDApplication.class),NSStringFromClass(SHHUDAppDelegate.class));
        return UIApplicationMain(argc,argv,nil,NSStringFromClass(SHAppDelegate.class));
    }
}
