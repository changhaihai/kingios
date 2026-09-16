#import "SHHUDCanvasView.h"
#import <math.h>

@interface SHHUDCanvasView ()
@property(nonatomic, strong) NSCache<NSString *, UIImage *> *avatars;
@property(nonatomic, strong) NSMutableSet<NSString *> *loading;
@end

@implementation SHHUDCanvasView
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.opaque = NO; self.backgroundColor = UIColor.clearColor; self.userInteractionEnabled = NO;
        _avatars = [NSCache new]; _loading = [NSMutableSet set]; _settings = SHSettings.load;
    }
    return self;
}
- (void)setBattleFrame:(SHBattleFrame *)battleFrame { _battleFrame = battleFrame; [self setNeedsDisplay]; }
- (void)reloadSettings { self.settings = SHSettings.load; [self setNeedsDisplay]; }

static UIColor *SHTeamColor(BOOL blue) { return blue ? [UIColor colorWithRed:.15 green:.55 blue:.95 alpha:1] : [UIColor colorWithRed:.94 green:.29 blue:.34 alpha:1]; }
static void SHFillCircle(CGContextRef c, CGPoint p, CGFloat radius, UIColor *color) { CGContextSetFillColorWithColor(c, color.CGColor); CGContextFillEllipseInRect(c, CGRectMake(p.x-radius,p.y-radius,radius*2,radius*2)); }
static void SHText(NSString *text, CGPoint center, UIFont *font, UIColor *color) {
    NSDictionary *a = @{NSFontAttributeName:font, NSForegroundColorAttributeName:color}; CGSize z = [text sizeWithAttributes:a];
    [text drawAtPoint:CGPointMake(center.x-z.width/2, center.y-z.height/2) withAttributes:a];
}
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext(); if (!c || !self.battleFrame) return;
    SHSettings *s = self.settings; CGFloat width = self.bounds.size.width, height = self.bounds.size.height;
    CGFloat scale = MIN(width / 2400.0, height / 1080.0), factor = MIN(2, MAX(.5, 1 + s.mapSpacing/100.0));
    CGFloat (^mx)(CGFloat) = ^CGFloat(CGFloat x){ return ((x-170)*factor+170+s.offsetX)*scale; };
    CGFloat (^my)(CGFloat) = ^CGFloat(CGFloat y){ return ((y-170)*factor+170+s.offsetY)*scale; };

    if (s.minions) for (SHMinion *m in self.battleFrame.minions) {
        CGPoint p = CGPointMake((((m.x-170)*factor+170+s.offsetX+s.minionX)*scale), (((m.y-170)*factor+170+s.offsetY+s.minionY)*scale));
        SHFillCircle(c,p,MAX(2,4*scale),SHTeamColor(m.blue));
    }
    if (s.resources) for (SHResource *r in self.battleFrame.resources) {
        CGPoint p = CGPointMake((((r.x-170)*factor+170+s.offsetX+s.resourceX)*scale), (((r.y-170)*factor+170+s.offsetY+s.resourceY)*scale));
        BOOL ready = r.cooldown==0||r.cooldown==60||r.cooldown==70||r.cooldown==90||r.cooldown==120||r.cooldown==240;
        if (ready) SHFillCircle(c,p,MAX(3,5*scale),[UIColor colorWithRed:.94 green:.74 blue:.33 alpha:1]);
        else SHText([NSString stringWithFormat:@"%lds",(long)r.cooldown],CGPointMake(p.x,p.y-12*scale),[UIFont boldSystemFontOfSize:MAX(8,18*scale)],[UIColor colorWithRed:.94 green:.74 blue:.33 alpha:1]);
    }
    if (s.towers) for (SHTower *t in self.battleFrame.towers) {
        CGFloat x=mx(t.x), y=my(t.y), w=MAX(7,14*scale), h=MAX(8,16*scale); CGRect box=CGRectMake(x-w/2,y-h/2,w,h);
        CGContextSetFillColorWithColor(c,[UIColor colorWithWhite:.07 alpha:.82].CGColor); CGContextFillRect(c,box);
        CGContextSetStrokeColorWithColor(c,SHTeamColor(t.blue).CGColor); CGContextSetLineWidth(c,MAX(1,2*scale)); CGContextStrokeRect(c,box);
        CGFloat ratio=MIN(1,MAX(0,t.hp/t.maxHP)); CGContextSetFillColorWithColor(c,SHTeamColor(t.blue).CGColor); CGContextFillRect(c,CGRectMake(box.origin.x+1,CGRectGetMaxY(box)-3,(w-2)*ratio,2));
    }
    if (s.heroes) for (SHHero *h in self.battleFrame.heroes) {
        if (s.hideOwnTeam && h.ownTeam) continue;
        CGFloat radius=MAX(9,20*s.avatarScale*scale), x=MIN(width-radius,MAX(radius,mx(h.x)+radius)), y=MIN(height-radius-4,MAX(radius,my(h.y)+radius));
        CGPoint p=CGPointMake(x,y); SHFillCircle(c,p,radius,[UIColor colorWithWhite:.08 alpha:.9]);
        [self drawAvatar:h.heroID center:p radius:radius context:c];
        CGContextSetStrokeColorWithColor(c,SHTeamColor(h.blue).CGColor); CGContextSetLineWidth(c,MAX(1.5,3*s.avatarScale*scale)); CGContextStrokeEllipseInRect(c,CGRectMake(x-radius,y-radius,radius*2,radius*2));
        CGRect hp=CGRectMake(x-radius,y+radius,radius*2,MAX(3,7*s.avatarScale*scale)); CGContextSetFillColorWithColor(c,[UIColor colorWithWhite:1 alpha:.35].CGColor); CGContextFillRect(c,hp);
        CGContextSetFillColorWithColor(c,SHTeamColor(h.blue).CGColor); CGContextFillRect(c,CGRectMake(hp.origin.x,hp.origin.y,hp.size.width*h.hp/100.0,hp.size.height));
        if (h.ai) SHFillCircle(c,CGPointMake(x,y-radius-5),3,[UIColor colorWithRed:.94 green:.74 blue:.33 alpha:1]);
    }
    if (s.topInfo) [self drawTopInfo:c];
}
- (void)drawTopInfo:(CGContextRef)c {
    NSArray<SHHero *> *enemies = [self.battleFrame.heroes filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(SHHero *h, NSDictionary *_) { return !h.ownTeam; }]];
    if (enemies.count > 5) enemies = [enemies subarrayWithRange:NSMakeRange(0,5)]; if (!enemies.count) return;
    CGFloat q=MAX(.6,MIN(1.8,self.settings.topScale)), cell=52*q, gap=3*q, total=cell*enemies.count+gap*(enemies.count-1);
    CGFloat left=(self.bounds.size.width-total)/2+self.settings.topX, top=MAX(0,self.settings.topY), avatar=28*q;
    for (NSUInteger i=0;i<enemies.count;i++) {
        SHHero *h=enemies[i]; CGFloat x=left+i*(cell+gap); CGRect bg=CGRectMake(x,top,cell,52*q);
        CGContextSetFillColorWithColor(c,[UIColor colorWithWhite:.04 alpha:.72].CGColor); UIBezierPath *path=[UIBezierPath bezierPathWithRoundedRect:bg cornerRadius:6*q]; [path fill];
        CGPoint p=CGPointMake(CGRectGetMidX(bg),top+4*q+avatar/2); SHFillCircle(c,p,avatar/2,[UIColor colorWithWhite:.12 alpha:1]); [self drawAvatar:h.heroID center:p radius:avatar/2 context:c];
        CGContextSetStrokeColorWithColor(c,SHTeamColor(h.blue).CGColor); CGContextSetLineWidth(c,2*q); CGContextStrokeEllipseInRect(c,CGRectMake(p.x-avatar/2,p.y-avatar/2,avatar,avatar));
        [self drawBadge:@"大" cooldown:h.ultimateCooldown rect:CGRectMake(x+1*q,top+34*q,24*q,12*q) color:[UIColor colorWithRed:.94 green:.74 blue:.33 alpha:1]];
        [self drawBadge:@"技" cooldown:h.skillCooldown rect:CGRectMake(x+27*q,top+34*q,24*q,12*q) color:[UIColor colorWithRed:.27 green:.86 blue:.61 alpha:1]];
    }
}
- (void)drawBadge:(NSString *)title cooldown:(CGFloat)cooldown rect:(CGRect)rect color:(UIColor *)color {
    [[UIColor colorWithWhite:.03 alpha:.9] setFill]; [[UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:3] fill];
    NSString *value=cooldown>0?[NSString stringWithFormat:@"%@ %lds",title,(long)ceil(cooldown)]:[NSString stringWithFormat:@"%@ •",title];
    SHText(value,CGPointMake(CGRectGetMidX(rect),CGRectGetMidY(rect)),[UIFont boldSystemFontOfSize:7],cooldown>0?UIColor.whiteColor:color);
}
- (void)drawAvatar:(NSString *)heroID center:(CGPoint)p radius:(CGFloat)radius context:(CGContextRef)c {
    UIImage *image=[self.avatars objectForKey:heroID];
    if (!image) { SHText(heroID.length>3?[heroID substringFromIndex:heroID.length-3]:heroID,p,[UIFont boldSystemFontOfSize:MAX(7,radius*.55)],UIColor.whiteColor); [self requestAvatar:heroID]; return; }
    CGContextSaveGState(c); CGContextAddEllipseInRect(c,CGRectMake(p.x-radius+2,p.y-radius+2,radius*2-4,radius*2-4)); CGContextClip(c); [image drawInRect:CGRectMake(p.x-radius,p.y-radius,radius*2,radius*2)]; CGContextRestoreGState(c);
}
- (void)requestAvatar:(NSString *)heroID {
    if (!heroID.length || [self.loading containsObject:heroID]) return; [self.loading addObject:heroID];
    NSURL *url=[NSURL URLWithString:[NSString stringWithFormat:@"https://game.gtimg.cn/images/yxzj/img201606/heroimg/%@/%@.jpg",heroID,heroID]];
    __weak typeof(self) weakSelf=self;
    [[NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){ dispatch_async(dispatch_get_main_queue(),^{ typeof(self) self=weakSelf; if(!self)return; UIImage *img=data?[UIImage imageWithData:data]:nil; if(img)[self.avatars setObject:img forKey:heroID]; [self.loading removeObject:heroID]; [self setNeedsDisplay]; }); }] resume];
}
@end
