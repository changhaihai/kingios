#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SHHero : NSObject
@property(nonatomic, copy) NSString *heroID;
@property(nonatomic) CGFloat x, y, hp, ultimateCooldown, skillCooldown;
@property(nonatomic) BOOL blue, ownTeam, returning, ai;
@end

@interface SHResource : NSObject
@property(nonatomic) CGFloat x, y;
@property(nonatomic) NSInteger cooldown;
@end

@interface SHMinion : NSObject
@property(nonatomic) CGFloat x, y;
@property(nonatomic) BOOL blue;
@end

@interface SHTower : NSObject
@property(nonatomic) CGFloat x, y, hp, maxHP;
@property(nonatomic) BOOL blue;
@end

@interface SHBattleFrame : NSObject
@property(nonatomic, copy) NSArray<SHHero *> *heroes;
@property(nonatomic, copy) NSArray<SHResource *> *resources;
@property(nonatomic, copy) NSArray<SHMinion *> *minions;
@property(nonatomic, copy) NSArray<SHTower *> *towers;
+ (nullable instancetype)parse:(NSString *)raw;
@end

NS_ASSUME_NONNULL_END
