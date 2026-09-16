#import <UIKit/UIKit.h>
#import "SHBattleFrame.h"
#import "SHSettings.h"

NS_ASSUME_NONNULL_BEGIN
@interface SHHUDCanvasView : UIView
@property(nonatomic, strong) SHBattleFrame *battleFrame;
@property(nonatomic, strong) SHSettings *settings;
@property(nonatomic, copy) NSString *connectionState;
- (void)reloadSettings;
@end
NS_ASSUME_NONNULL_END
