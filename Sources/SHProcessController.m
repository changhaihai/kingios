#import "SHProcessController.h"
#import "SHSettings.h"
#import <spawn.h>
#import <signal.h>
#import <unistd.h>
#import <dlfcn.h>

extern char **environ;

static void SHPostDarwin(NSString *name) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),(__bridge CFStringRef)name,NULL,NULL,YES);
}

@implementation SHProcessController
+ (pid_t)storedPID { return (pid_t)[[NSString stringWithContentsOfFile:SHPIDPath encoding:NSUTF8StringEncoding error:nil] intValue]; }
+ (BOOL)isHUDRunning { pid_t pid=[self storedPID]; return pid>1 && kill(pid,0)==0; }
+ (BOOL)startHUD:(NSError **)error {
    if ([self isHUDRunning]) { [self reloadHUD]; return YES; }
    NSString *executable=NSBundle.mainBundle.executablePath; if(!executable.length)return NO;
    const char *path=executable.fileSystemRepresentation; char *const argv[]={(char *)path,(char *)"-hud",NULL};
    posix_spawnattr_t attr; posix_spawnattr_init(&attr); short flags=POSIX_SPAWN_SETPGROUP; posix_spawnattr_setflags(&attr,flags); posix_spawnattr_setpgroup(&attr,0);
    typedef int (*PersonaFn)(posix_spawnattr_t *, uid_t, uint32_t);
    typedef int (*PersonaIDFn)(posix_spawnattr_t *, uid_t);
    PersonaFn setPersona=(PersonaFn)dlsym(RTLD_DEFAULT,"posix_spawnattr_set_persona_np");
    PersonaIDFn setUID=(PersonaIDFn)dlsym(RTLD_DEFAULT,"posix_spawnattr_set_persona_uid_np");
    PersonaIDFn setGID=(PersonaIDFn)dlsym(RTLD_DEFAULT,"posix_spawnattr_set_persona_gid_np");
    if(setPersona&&setUID&&setGID){ setPersona(&attr,99,1); setUID(&attr,501); setGID(&attr,501); }
    pid_t pid=0; int result=posix_spawn(&pid,path,NULL,&attr,argv,environ); posix_spawnattr_destroy(&attr);
    if(result!=0){ if(error)*error=[NSError errorWithDomain:NSPOSIXErrorDomain code:result userInfo:nil]; return NO; }
    [@(pid).stringValue writeToFile:SHPIDPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    return YES;
}
+ (void)reloadHUD { SHPostDarwin(SHReloadNotification); }
+ (void)stopHUD {
    SHPostDarwin(SHDismissNotification); pid_t pid=[self storedPID];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.6*NSEC_PER_SEC)),dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{ if(pid>1&&kill(pid,0)==0)kill(pid,SIGTERM); unlink(SHPIDPath.fileSystemRepresentation); });
}
@end
