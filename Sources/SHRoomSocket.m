#import "SHRoomSocket.h"
#import <math.h>

@interface SHRoomSocket ()
@property(nonatomic, copy) NSString *host;
@property(nonatomic, copy) NSString *room;
@property(nonatomic) NSInteger port, retry;
@property(nonatomic) BOOL stopped;
@property(nonatomic, strong) NSURLSession *session;
@property(nonatomic, strong) NSURLSessionWebSocketTask *task;
@property(nonatomic, strong) NSTimer *pingTimer;
@property(nonatomic) NSTimeInterval lastFrameAt;
@end

@implementation SHRoomSocket
- (instancetype)initWithHost:(NSString *)host port:(NSInteger)port room:(NSString *)room {
    if ((self = [super init])) { _host = host.copy; _port = port; _room = room.copy; }
    return self;
}
- (void)start { self.stopped = NO; self.retry = 0; [self connect]; }
- (void)stop {
    self.stopped = YES; [self.pingTimer invalidate]; self.pingTimer = nil;
    [self.task cancelWithCloseCode:NSURLSessionWebSocketCloseCodeGoingAway reason:nil];
    [self.session invalidateAndCancel]; self.task = nil; self.session = nil;
}
- (void)connect {
    if (self.stopped) return;
    [self.delegate roomSocketDidChangeState:@"正在连接"];
    NSString *host = [self.host containsString:@":"] && ![self.host hasPrefix:@"["] ? [NSString stringWithFormat:@"[%@]", self.host] : self.host;
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"ws://%@:%ld/ws", host, (long)self.port]];
    if (!url) { [self scheduleReconnect:@"服务器地址无效"]; return; }
    NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    configuration.timeoutIntervalForRequest = 8;
    self.session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:NSOperationQueue.mainQueue];
    self.task = [self.session webSocketTaskWithURL:url];
    [self.task resume];
}
- (void)URLSession:(NSURLSession *)session webSocketTask:(NSURLSessionWebSocketTask *)webSocketTask didOpenWithProtocol:(NSString *)protocol {
    if (self.stopped) return;
    self.retry = 0; [self.delegate roomSocketDidChangeState:@"已连接"];
    [self sendText:[NSString stringWithFormat:@"subscribe[==]%@", self.room]];
    [self receiveNext];
    [self.pingTimer invalidate];
    self.pingTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(sendPing) userInfo:nil repeats:YES];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (!self.stopped) [self scheduleReconnect:error.localizedDescription ?: @"连接已关闭"];
}
- (void)receiveNext {
    if (self.stopped || !self.task) return;
    __weak typeof(self) weakSelf = self;
    [self.task receiveMessageWithCompletionHandler:^(NSURLSessionWebSocketMessage *message, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) self = weakSelf; if (!self || self.stopped) return;
            if (error) { [self scheduleReconnect:error.localizedDescription]; return; }
            NSString *text = message.type == NSURLSessionWebSocketMessageTypeString ? message.string : nil;
            if ([text hasPrefix:@"gameData##"]) {
                NSTimeInterval now = NSDate.date.timeIntervalSince1970;
                if (now - self.lastFrameAt >= 0.033) {
                    self.lastFrameAt = now;
                    SHBattleFrame *frame = [SHBattleFrame parse:[text substringFromIndex:@"gameData##".length]];
                    if (frame) [self.delegate roomSocketDidReceiveFrame:frame];
                }
            }
            [self receiveNext];
        });
    }];
}
- (void)sendPing {
    long long ms = (long long)(NSDate.date.timeIntervalSince1970 * 1000.0);
    [self sendText:[NSString stringWithFormat:@"ping##%lld", ms]];
}
- (void)sendText:(NSString *)text {
    if (!self.task || self.stopped) return;
    [self.task sendMessage:[[NSURLSessionWebSocketMessage alloc] initWithString:text] completionHandler:^(NSError *error) {}];
}
- (void)scheduleReconnect:(NSString *)reason {
    if (self.stopped) return;
    [self.pingTimer invalidate]; self.pingTimer = nil;
    [self.task cancel]; [self.session invalidateAndCancel]; self.task = nil; self.session = nil;
    [self.delegate roomSocketDidChangeState:[NSString stringWithFormat:@"%@，正在重试", reason ?: @"连接断开"]];
    NSTimeInterval delay = MIN(8, pow(2, self.retry++));
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self connect]; });
}
@end
