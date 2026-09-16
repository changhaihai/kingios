#import <Foundation/Foundation.h>
#import "SHBattleFrame.h"

NS_ASSUME_NONNULL_BEGIN

@protocol SHRoomSocketDelegate <NSObject>
- (void)roomSocketDidChangeState:(NSString *)state;
- (void)roomSocketDidReceiveFrame:(SHBattleFrame *)frame;
@end

@interface SHRoomSocket : NSObject <NSURLSessionWebSocketDelegate>
@property(nonatomic, weak) id<SHRoomSocketDelegate> delegate;
- (instancetype)initWithHost:(NSString *)host port:(NSInteger)port room:(NSString *)room;
- (void)start;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
