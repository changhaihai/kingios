#import "SHSettings.h"

NSString * const SHReloadNotification = @"com.hai.sharedhud.reload";
NSString * const SHDismissNotification = @"com.hai.sharedhud.dismiss";
NSString * const SHLaunchedNotification = @"com.hai.sharedhud.launched";
NSString * const SHSpringBoardLaunchedNotification = @"SBSpringBoardDidLaunchNotification";
NSString * const SHPIDPath = @"/var/mobile/Library/Preferences/com.hai.sharedhud.pid";
static NSString * const SHSettingsPath = @"/var/mobile/Library/Preferences/com.hai.sharedhud.plist";

@implementation SHSettings
+ (instancetype)load {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:SHSettingsPath] ?: @{};
    SHSettings *s = [SHSettings new];
    s.room = [d[@"room"] isKindOfClass:NSString.class] ? d[@"room"] : @"";
    s.host = [d[@"host"] isKindOfClass:NSString.class] ? d[@"host"] : @"king.weilua.top";
    s.port = [d[@"port"] integerValue] ?: 8888;
    s.heroes = d[@"heroes"] ? [d[@"heroes"] boolValue] : YES;
    s.resources = d[@"resources"] ? [d[@"resources"] boolValue] : YES;
    s.minions = d[@"minions"] ? [d[@"minions"] boolValue] : YES;
    s.towers = d[@"towers"] ? [d[@"towers"] boolValue] : YES;
    s.hideOwnTeam = [d[@"hideOwnTeam"] boolValue];
    s.topInfo = d[@"topInfo"] ? [d[@"topInfo"] boolValue] : YES;
    s.secureOverlay = [d[@"secureOverlay"] boolValue];
    // new flags
    s.onlyAvatars = d[@"onlyAvatars"] ? [d[@"onlyAvatars"] boolValue] : NO;
    s.mockMode = d[@"mockMode"] ? [d[@"mockMode"] boolValue] : NO;

    s.offsetX = [d[@"offsetX"] doubleValue]; s.offsetY = [d[@"offsetY"] doubleValue];
    s.resourceX = [d[@"resourceX"] doubleValue]; s.resourceY = [d[@"resourceY"] doubleValue];
    s.minionX = [d[@"minionX"] doubleValue]; s.minionY = [d[@"minionY"] doubleValue];
    s.mapSpacing = [d[@"mapSpacing"] doubleValue];
    s.avatarScale = d[@"avatarScale"] ? [d[@"avatarScale"] doubleValue] : 1;
    s.topX = [d[@"topX"] doubleValue]; s.topY = [d[@"topY"] doubleValue];
    s.topScale = d[@"topScale"] ? [d[@"topScale"] doubleValue] : 1;
    return s;
}
- (BOOL)save {
    NSDictionary *d = @{
        @"room": self.room ?: @"", @"host": self.host ?: @"", @"port": @(self.port),
        @"heroes": @(self.heroes), @"resources": @(self.resources), @"minions": @(self.minions), @"towers": @(self.towers),
        @"hideOwnTeam": @(self.hideOwnTeam), @"topInfo": @(self.topInfo), @"secureOverlay": @(self.secureOverlay),
        @"onlyAvatars": @(self.onlyAvatars), @"mockMode": @(self.mockMode),
        @"offsetX": @(self.offsetX), @"offsetY": @(self.offsetY), @"resourceX": @(self.resourceX), @"resourceY": @(self.resourceY),
        @"minionX": @(self.minionX), @"minionY": @(self.minionY), @"mapSpacing": @(self.mapSpacing),
        @"avatarScale": @(self.avatarScale), @"topX": @(self.topX), @"topY": @(self.topY), @"topScale": @(self.topScale)
    };
    return [d writeToFile:SHSettingsPath atomically:YES];
}
@end
