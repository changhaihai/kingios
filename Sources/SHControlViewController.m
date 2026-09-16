#import "SHControlViewController.h"
#import "SHSettings.h"
#import "SHProcessController.h"

@interface SHControlViewController () <UITextFieldDelegate>
@property(nonatomic, strong) UITextField *roomField,*hostField,*portField;
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) NSMutableDictionary<NSString *,UISwitch *> *switches;
@property(nonatomic, strong) NSMutableDictionary<NSString *,UISlider *> *sliders;
@property(nonatomic, strong) NSTimer *statusTimer;
@end

@implementation SHControlViewController
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=@"共享绘制"; self.view.backgroundColor=[UIColor colorWithRed:.027 green:.055 blue:.075 alpha:1];
    self.switches=[NSMutableDictionary dictionary]; self.sliders=[NSMutableDictionary dictionary]; SHSettings *s=SHSettings.load;
    UIScrollView *scroll=[UIScrollView new]; scroll.translatesAutoresizingMaskIntoConstraints=NO; [self.view addSubview:scroll];
    UIStackView *stack=[[UIStackView alloc] init]; stack.axis=UILayoutConstraintAxisVertical; stack.spacing=12; stack.translatesAutoresizingMaskIntoConstraints=NO; [scroll addSubview:stack];
    UILayoutGuide *safe=self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[[scroll.topAnchor constraintEqualToAnchor:safe.topAnchor],[scroll.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],[scroll.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],[scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],[stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:18],[stack.leadingAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.leadingAnchor constant:18],[stack.trailingAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.trailingAnchor constant:-18],[stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-24]]];

    UILabel *intro=[self label:@"TrollStore 全局 HUD" size:22 weight:UIFontWeightBold color:UIColor.whiteColor]; [stack addArrangedSubview:intro];
    UILabel *sub=[self label:@"控制端只保存参数；绘制由独立 HUD 进程完成。" size:13 weight:UIFontWeightRegular color:[UIColor colorWithWhite:.68 alpha:1]]; sub.numberOfLines=0; [stack addArrangedSubview:sub];
    self.statusLabel=[self label:@"正在检查" size:13 weight:UIFontWeightSemibold color:[UIColor colorWithRed:.94 green:.74 blue:.33 alpha:1]]; [stack addArrangedSubview:self.statusLabel];
    [stack addArrangedSubview:[self section:@"连接"]];
    self.roomField=[self field:@"房间号" value:s.room keyboard:UIKeyboardTypeDefault]; [stack addArrangedSubview:self.roomField];
    self.hostField=[self field:@"服务器 IP 或域名" value:s.host keyboard:UIKeyboardTypeURL]; [stack addArrangedSubview:self.hostField];
    self.portField=[self field:@"端口" value:[NSString stringWithFormat:@"%ld",(long)s.port] keyboard:UIKeyboardTypeNumberPad]; [stack addArrangedSubview:self.portField];
    [stack addArrangedSubview:[self section:@"显示"]];
    [stack addArrangedSubview:[self switchRow:@"英雄头像与血条" key:@"heroes" value:s.heroes]];
    [stack addArrangedSubview:[self switchRow:@"野怪与资源" key:@"resources" value:s.resources]];
    [stack addArrangedSubview:[self switchRow:@"兵线" key:@"minions" value:s.minions]];
    [stack addArrangedSubview:[self switchRow:@"防御塔血量" key:@"towers" value:s.towers]];
    [stack addArrangedSubview:[self switchRow:@"隐藏己方英雄" key:@"hideOwnTeam" value:s.hideOwnTeam]];
    [stack addArrangedSubview:[self switchRow:@"顶部敌方信息" key:@"topInfo" value:s.topInfo]];
    [stack addArrangedSubview:[self switchRow:@"安全绘制层" key:@"secureOverlay" value:s.secureOverlay]];
    [stack addArrangedSubview:[self section:@"位置与尺寸"]];
    [stack addArrangedSubview:[self sliderRow:@"整体 X" key:@"offsetX" min:-600 max:600 value:s.offsetX]];
    [stack addArrangedSubview:[self sliderRow:@"整体 Y" key:@"offsetY" min:-600 max:600 value:s.offsetY]];
    [stack addArrangedSubview:[self sliderRow:@"野怪 X" key:@"resourceX" min:-600 max:600 value:s.resourceX]];
    [stack addArrangedSubview:[self sliderRow:@"野怪 Y" key:@"resourceY" min:-600 max:600 value:s.resourceY]];
    [stack addArrangedSubview:[self sliderRow:@"兵线 X" key:@"minionX" min:-600 max:600 value:s.minionX]];
    [stack addArrangedSubview:[self sliderRow:@"兵线 Y" key:@"minionY" min:-600 max:600 value:s.minionY]];
    [stack addArrangedSubview:[self sliderRow:@"地图间距" key:@"mapSpacing" min:-50 max:100 value:s.mapSpacing]];
    [stack addArrangedSubview:[self sliderRow:@"头像大小" key:@"avatarScale" min:.6 max:1.8 value:s.avatarScale]];
    [stack addArrangedSubview:[self sliderRow:@"顶栏 X" key:@"topX" min:-600 max:600 value:s.topX]];
    [stack addArrangedSubview:[self sliderRow:@"顶栏 Y" key:@"topY" min:0 max:300 value:s.topY]];
    [stack addArrangedSubview:[self sliderRow:@"顶栏大小" key:@"topScale" min:.6 max:1.8 value:s.topScale]];

    UIStackView *buttons=[[UIStackView alloc] init]; buttons.axis=UILayoutConstraintAxisHorizontal; buttons.spacing=10; buttons.distribution=UIStackViewDistributionFillEqually;
    UIButton *start=[self button:@"启动 / 重载" color:[UIColor colorWithRed:.94 green:.64 blue:.20 alpha:1] action:@selector(startHUD)];
    UIButton *stop=[self button:@"停止" color:[UIColor colorWithRed:.75 green:.20 blue:.24 alpha:1] action:@selector(stopHUD)];
    [buttons addArrangedSubview:start]; [buttons addArrangedSubview:stop]; [stack addArrangedSubview:buttons];
    self.statusTimer=[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(refreshStatus) userInfo:nil repeats:YES]; [self refreshStatus];
}
- (UILabel *)label:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight color:(UIColor *)color { UILabel *v=[UILabel new]; v.text=text; v.font=[UIFont systemFontOfSize:size weight:weight]; v.textColor=color; return v; }
- (UILabel *)section:(NSString *)title { UILabel *v=[self label:title size:12 weight:UIFontWeightBold color:[UIColor colorWithRed:.94 green:.74 blue:.33 alpha:1]]; v.text=title.uppercaseString; return v; }
- (UITextField *)field:(NSString *)placeholder value:(NSString *)value keyboard:(UIKeyboardType)keyboard {
    UITextField *v=[UITextField new]; v.placeholder=placeholder; v.text=value; v.keyboardType=keyboard; v.delegate=self; v.textColor=UIColor.whiteColor; v.backgroundColor=[UIColor colorWithWhite:.10 alpha:1]; v.layer.cornerRadius=7; v.layer.borderWidth=1; v.layer.borderColor=[UIColor colorWithWhite:.24 alpha:1].CGColor; v.leftView=[[UIView alloc] initWithFrame:CGRectMake(0,0,10,1)]; v.leftViewMode=UITextFieldViewModeAlways; [v.heightAnchor constraintEqualToConstant:44].active=YES; return v;
}
- (UIView *)switchRow:(NSString *)title key:(NSString *)key value:(BOOL)value {
    UIView *row=[UIView new]; UILabel *label=[self label:title size:14 weight:UIFontWeightRegular color:UIColor.whiteColor]; UISwitch *toggle=[UISwitch new]; toggle.on=value; toggle.onTintColor=[UIColor colorWithRed:.27 green:.86 blue:.61 alpha:1]; self.switches[key]=toggle;
    label.translatesAutoresizingMaskIntoConstraints=toggle.translatesAutoresizingMaskIntoConstraints=NO; [row addSubview:label]; [row addSubview:toggle]; [NSLayoutConstraint activateConstraints:@[[row.heightAnchor constraintEqualToConstant:42],[label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],[label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],[toggle.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],[toggle.centerYAnchor constraintEqualToAnchor:row.centerYAnchor]]]; return row;
}
- (UIView *)sliderRow:(NSString *)title key:(NSString *)key min:(float)min max:(float)max value:(float)value {
    UIStackView *row=[UIStackView new]; row.axis=UILayoutConstraintAxisVertical; row.spacing=3; UILabel *caption=[self label:[NSString stringWithFormat:@"%@  %.1f",title,value] size:12 weight:UIFontWeightRegular color:[UIColor colorWithWhite:.75 alpha:1]];
    UISlider *slider=[UISlider new]; slider.minimumValue=min; slider.maximumValue=max; slider.value=value; slider.minimumTrackTintColor=[UIColor colorWithRed:.94 green:.74 blue:.33 alpha:1]; self.sliders[key]=slider;
    [slider addAction:[UIAction actionWithHandler:^(__kindof UIAction *action){ caption.text=[NSString stringWithFormat:@"%@  %.1f",title,slider.value]; }] forControlEvents:UIControlEventValueChanged]; [row addArrangedSubview:caption]; [row addArrangedSubview:slider]; return row;
}
- (UIButton *)button:(NSString *)title color:(UIColor *)color action:(SEL)action { UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem]; [b setTitle:title forState:UIControlStateNormal]; [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal]; b.backgroundColor=color; b.layer.cornerRadius=7; b.titleLabel.font=[UIFont systemFontOfSize:14 weight:UIFontWeightBold]; [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside]; [b.heightAnchor constraintEqualToConstant:46].active=YES; return b; }
- (BOOL)saveSettings {
    NSString *room=[self.roomField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]; NSString *host=[self.hostField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]; NSInteger port=self.portField.text.integerValue;
    if(!room.length||room.length>128||[room containsString:@"[==]"]||[room containsString:@"#"]){[self showError:@"房间号格式不正确"];return NO;} if(!host.length||port<1||port>65535){[self showError:@"服务器或端口无效"];return NO;}
    SHSettings *s=SHSettings.load; s.room=room; s.host=host; s.port=port;
    s.heroes=self.switches[@"heroes"].on; s.resources=self.switches[@"resources"].on; s.minions=self.switches[@"minions"].on; s.towers=self.switches[@"towers"].on; s.hideOwnTeam=self.switches[@"hideOwnTeam"].on; s.topInfo=self.switches[@"topInfo"].on; s.secureOverlay=self.switches[@"secureOverlay"].on;
    s.offsetX=self.sliders[@"offsetX"].value; s.offsetY=self.sliders[@"offsetY"].value; s.resourceX=self.sliders[@"resourceX"].value; s.resourceY=self.sliders[@"resourceY"].value; s.minionX=self.sliders[@"minionX"].value; s.minionY=self.sliders[@"minionY"].value; s.mapSpacing=self.sliders[@"mapSpacing"].value; s.avatarScale=self.sliders[@"avatarScale"].value; s.topX=self.sliders[@"topX"].value; s.topY=self.sliders[@"topY"].value; s.topScale=self.sliders[@"topScale"].value;
    if(![s save]){[self showError:@"配置写入失败，请确认 TrollStore 权限"];return NO;} return YES;
}
- (void)startHUD { [self.view endEditing:YES]; if(![self saveSettings])return; NSError *error=nil; if(![SHProcessController startHUD:&error]){[self showError:error.localizedDescription?:@"HUD 启动失败"];return;} [SHProcessController reloadHUD]; self.statusLabel.text=@"HUD 已启动，可以返回游戏"; [self refreshStatus]; }
- (void)stopHUD { [SHProcessController stopHUD]; self.statusLabel.text=@"正在停止"; dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[self refreshStatus];}); }
- (void)refreshStatus { BOOL running=SHProcessController.isHUDRunning; self.statusLabel.text=running?@"状态：HUD 运行中":@"状态：已停止"; self.statusLabel.textColor=running?[UIColor colorWithRed:.27 green:.86 blue:.61 alpha:1]:[UIColor colorWithWhite:.55 alpha:1]; }
- (void)showError:(NSString *)message { UIAlertController *a=[UIAlertController alertControllerWithTitle:@"提示" message:message preferredStyle:UIAlertControllerStyleAlert]; [a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]]; [self presentViewController:a animated:YES completion:nil]; }
- (BOOL)textFieldShouldReturn:(UITextField *)textField { [textField resignFirstResponder]; return YES; }
- (void)dealloc { [self.statusTimer invalidate]; }
@end
