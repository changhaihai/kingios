#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const SHReloadNotification;
FOUNDATION_EXPORT NSString * const SHDismissNotification;
FOUNDATION_EXPORT NSString * const SHLaunchedNotification;
FOUNDATION_EXPORT NSString * const SHSpringBoardLaunchedNotification;
FOUNDATION_EXPORT NSString * const SHPIDPath;

@interface SHSettings : NSObject
@property(nonatomic, copy) NSString *room;
@property(nonatomic, copy) NSString *host;
@property(nonatomic) NSInteger port;
@property(nonatomic) BOOL heroes, resources, minions, towers, hideOwnTeam, topInfo, secureOverlay;
@property(nonatomic) CGFloat offsetX, offsetY, resourceX, resourceY, minionX, minionY;
@property(nonatomic) CGFloat mapSpacing, avatarScale, topX, topY, topScale;
+ (instancetype)load;
- (BOOL)save;
@end

NS_ASSUME_NONNULL_END
