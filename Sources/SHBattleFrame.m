#import "SHBattleFrame.h"

@implementation SHHero @end
@implementation SHResource @end
@implementation SHMinion @end
@implementation SHTower @end

static CGFloat SHNumber(NSArray<NSString *> *row, NSUInteger index) {
    return index < row.count ? row[index].doubleValue : 0;
}

static BOOL SHSame(NSString *left, NSString *right) {
    NSString *a = [left stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *b = [right stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!a.length || !b.length) return NO;
    NSScanner *as = [NSScanner scannerWithString:a], *bs = [NSScanner scannerWithString:b];
    long long av = 0, bv = 0;
    if ([as scanLongLong:&av] && as.isAtEnd && [bs scanLongLong:&bv] && bs.isAtEnd) return av == bv;
    return [a isEqualToString:b];
}

static NSArray<NSArray<NSString *> *> *SHRecords(NSString *section, NSUInteger limit) {
    NSMutableArray *result = [NSMutableArray array];
    for (NSString *record in [section componentsSeparatedByString:@"=="]) {
        if (!record.length) continue;
        [result addObject:[record componentsSeparatedByString:@","]];
        if (result.count >= limit) break;
    }
    return result;
}

@implementation SHBattleFrame

+ (instancetype)parse:(NSString *)raw {
    if (!raw.length || raw.length > 256 * 1024) return nil;
    NSString *body = [raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if ([body hasPrefix:@"##"]) body = [body substringFromIndex:2];
    NSArray<NSString *> *sections = [body componentsSeparatedByString:@"---"];
    if (sections.count < 3) return nil;

    NSArray *heroRows = SHRecords(sections[0], 20);
    NSString *foe = @"";
    for (NSArray *row in heroRows) if (row.count > 9 && [row[9] length]) { foe = row[9]; break; }

    NSMutableArray *heroes = [NSMutableArray array];
    for (NSArray<NSString *> *row in heroRows) {
        if (row.count < 9 || !row[0].length) continue;
        BOOL enemy = SHSame(row[8], row.count > 9 ? row[9] : foe);
        SHHero *hero = [SHHero new];
        hero.heroID = [row[0] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        hero.x = SHNumber(row, 5); hero.y = SHNumber(row, 6);
        hero.hp = MIN(100, MAX(0, SHNumber(row, 7)));
        hero.blue = !enemy; hero.ownTeam = !enemy;
        hero.ultimateCooldown = MAX(0, SHNumber(row, 3));
        hero.skillCooldown = MAX(0, SHNumber(row, 4));
        hero.returning = row.count > 10 && [row[10] isEqualToString:@"1"];
        hero.ai = row.count > 13 && [row[13] isEqualToString:@"1"];
        [heroes addObject:hero];
    }

    NSMutableArray *resources = [NSMutableArray array];
    for (NSArray *row in SHRecords(sections.count > 1 ? sections[1] : @"", 128)) {
        if (row.count < 5) continue;
        SHResource *item = [SHResource new]; item.x = SHNumber(row, 3); item.y = SHNumber(row, 4); item.cooldown = MAX(0, (NSInteger)SHNumber(row, 1));
        [resources addObject:item];
    }

    NSMutableArray *minions = [NSMutableArray array];
    for (NSArray *row in SHRecords(sections.count > 2 ? sections[2] : @"", 256)) {
        if (row.count < 3) continue;
        SHMinion *unit = [SHMinion new]; unit.x = SHNumber(row, 0); unit.y = SHNumber(row, 1); unit.blue = !SHSame(row[2], foe);
        [minions addObject:unit];
    }

    NSMutableArray *towers = [NSMutableArray array];
    for (NSArray *row in SHRecords(sections.count > 3 ? sections[3] : @"", 32)) {
        if (row.count < 7) continue;
        NSInteger towerID = (NSInteger)SHNumber(row, 0), camp = (NSInteger)SHNumber(row, 5);
        CGFloat hp = SHNumber(row, 1), maxHP = SHNumber(row, 2);
        if (towerID < 1690 || towerID > 1699 || hp <= 0 || maxHP <= 0 || camp < 1 || camp > 2 || ![row[6] isEqualToString:@"1"]) continue;
        SHTower *tower = [SHTower new]; tower.hp = hp; tower.maxHP = maxHP; tower.x = SHNumber(row, 3); tower.y = SHNumber(row, 4); tower.blue = camp == 1;
        [towers addObject:tower];
    }

    SHBattleFrame *frame = [SHBattleFrame new];
    frame.heroes = heroes; frame.resources = resources; frame.minions = minions; frame.towers = towers;
    return frame;
}

+ (instancetype)mockFrame {
    SHBattleFrame *f = [SHBattleFrame new];
    NSMutableArray *heroes = [NSMutableArray array];
    for (int i = 0; i < 3; i++) {
        SHHero *h = [SHHero new];
        h.heroID = [NSString stringWithFormat:@"H%d", i+1];
        h.x = 400 + arc4random_uniform(1600);
        h.y = 200 + arc4random_uniform(700);
        h.hp = 50 + arc4random_uniform(51);
        h.blue = (i % 2) == 0;
        h.ownTeam = !h.blue;
        [heroes addObject:h];
    }
    f.heroes = heroes; f.resources = @[]; f.minions = @[]; f.towers = @[];
    return f;
}

@end
