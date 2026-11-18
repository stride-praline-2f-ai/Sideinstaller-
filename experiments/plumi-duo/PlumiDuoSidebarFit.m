// PlumiDuoSidebarFit.m
// User-invoked, reversible visual fit for an oversized right-side scroll-content view.
// Deliberately does not spoof iPad idiom, override UIWindowScene traits, or modify Plumi logic.
// Based on reported 951pt window, 304.3pt right scroll viewport, 376pt scroll content.
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include <math.h>

@interface PlumiDuoSidebarFit : NSObject
@property(nonatomic,strong) NSHashTable<UIWindow *> *observedWindows;
@property(nonatomic,weak) UIView *scaledView;
@property(nonatomic,weak) UIScrollView *selectedScroll;
// Capture the matching scroll view while Plumi is unobstructed.
// Its content geometry may change as UIKit presents an action sheet.
@property(nonatomic,weak) UIScrollView *menuTarget;
@property(nonatomic,assign) CGFloat menuContentWidth;
@property(nonatomic,assign) CGFloat menuViewportWidth;
@property(nonatomic,assign) CGAffineTransform originalTransform;
@property(nonatomic,assign) CGPoint originalCenter;
@property(nonatomic,assign) BOOL isFitted;
@property(nonatomic,assign) BOOL oldScrollEnabled;
@property(nonatomic,assign) BOOL oldAlwaysBounceHorizontal;
@property(nonatomic,assign) BOOL oldShowsHorizontalScrollIndicator;
@property(nonatomic,assign) BOOL horizontalPanChanged;
+ (instancetype)shared;
- (void)registerWindows;
- (void)onNotification:(NSNotification *)notification;
- (void)showMenu:(UITapGestureRecognizer *)gesture;
@end

@implementation PlumiDuoSidebarFit
+ (instancetype)shared {
    static PlumiDuoSidebarFit *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{instance=[self new];});
    return instance;
}
- (instancetype)init {
    if ((self=[super init])) {
        _observedWindows=[NSHashTable weakObjectsHashTable];
        NSNotificationCenter *nc=NSNotificationCenter.defaultCenter;
        [nc addObserver:self selector:@selector(onNotification:)
                   name:UIApplicationDidBecomeActiveNotification object:nil];
        [nc addObserver:self selector:@selector(onNotification:)
                   name:UIWindowDidBecomeVisibleNotification object:nil];
        [nc addObserver:self selector:@selector(onNotification:)
                   name:UISceneDidActivateNotification object:nil];
        [nc addObserver:self selector:@selector(onNotification:)
                   name:UIDeviceOrientationDidChangeNotification object:nil];
        [UIDevice.currentDevice beginGeneratingDeviceOrientationNotifications];
    }
    return self;
}
- (void)onNotification:(__unused NSNotification *)notification {
    if (self.isFitted || self.horizontalPanChanged) {
        UIScrollView *s=self.selectedScroll;
        UIWindowScene *scene=s.window.windowScene;
        if (!s.window || (scene && !UIInterfaceOrientationIsLandscape(scene.interfaceOrientation)))
            [self restore];
    }
    [self registerWindows];
}
- (void)registerWindows {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(),^{[self registerWindows];});
        return;
    }
    if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"dev.plumi.app"]) return;
    if (UIDevice.currentDevice.userInterfaceIdiom!=UIUserInterfaceIdiomPhone) return;
    @try {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                if (!w || w.hidden || [self.observedWindows containsObject:w]) continue;
                UITapGestureRecognizer *tap=[[UITapGestureRecognizer alloc]
                    initWithTarget:self action:@selector(showMenu:)];
                tap.numberOfTouchesRequired=2;
                tap.numberOfTapsRequired=3;
                tap.cancelsTouchesInView=NO;
                [w addGestureRecognizer:tap];
                [self.observedWindows addObject:w];
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[PlumiDuoSidebarFit] registration issue: %@",e.name);
    }
}
- (void)scan:(UIView *)view window:(UIWindow *)window depth:(NSUInteger)depth
         best:(UIScrollView * __strong *)best bestDelta:(CGFloat *)bestDelta {
    if (!view || depth>28) return;
    @try {
        if ([view isKindOfClass:UIScrollView.class]) {
            UIScrollView *s=(UIScrollView *)view;
            CGRect r=[s convertRect:s.bounds toView:window];
            CGFloat delta=s.contentSize.width-s.bounds.size.width;
            if (CGRectGetMinX(r) > window.bounds.size.width*0.53 &&
                CGRectGetMinY(r)>125 && CGRectGetMinY(r)<window.bounds.size.height-30 &&
                r.size.width>190 && r.size.width<window.bounds.size.width*0.50 &&
                r.size.height>120 && r.size.height<window.bounds.size.height*1.8 &&
                delta>20 && delta<window.bounds.size.width && delta>*bestDelta) {
                *best=s; *bestDelta=delta;
            }
        }
        for (UIView *child in view.subviews)
            [self scan:child window:window depth:depth+1 best:best bestDelta:bestDelta];
    } @catch (NSException *e) {
        NSLog(@"[PlumiDuoSidebarFit] scan issue: %@",e.name);
    }
}
- (UIScrollView *)target:(UIWindow *)window {
    if (!window.windowScene ||
        !UIInterfaceOrientationIsLandscape(window.windowScene.interfaceOrientation)) return nil;
    // Prefer the valid scroll view captured BEFORE opening a pop-up.
    // Without this, modal presentation can temporarily alter SwiftUI contentSize.
    UIScrollView *cached=self.menuTarget;
    if (cached && cached.window && cached.window.windowScene==window.windowScene)
        return cached;
    UIScrollView *best=nil;
    CGFloat bestDelta=0;
    for (UIWindow *candidate in window.windowScene.windows) {
        if (!candidate || candidate.hidden) continue;
        [self scan:candidate window:candidate depth:0 best:&best bestDelta:&bestDelta];
    }
    return best;
}
- (UIView *)visualContent:(UIScrollView *)scroll {
    UIView *best=nil;
    CGFloat maxArea=0;
    for (UIView *v in scroll.subviews) {
        if ([v isKindOfClass:UIImageView.class] || [v isKindOfClass:UIScrollView.class])
            continue;
        NSString *name=NSStringFromClass(v.class);
        CGFloat area=v.bounds.size.width*v.bounds.size.height;
        if ([name containsString:@"PlatformGroupContainer"]) return v;
        if (area>maxArea && area>10000) {best=v; maxArea=area;}
    }
    return best;
}
- (void)restore {
    @try {
        UIView *v=self.scaledView;
        if (self.isFitted && v) {
            v.transform=self.originalTransform;
            v.center=self.originalCenter;
        }
        UIScrollView *s=self.selectedScroll;
        if (self.horizontalPanChanged && s) {
            s.scrollEnabled=self.oldScrollEnabled;
            s.alwaysBounceHorizontal=self.oldAlwaysBounceHorizontal;
            s.showsHorizontalScrollIndicator=self.oldShowsHorizontalScrollIndicator;
        }
    } @catch (NSException *e) {
        NSLog(@"[PlumiDuoSidebarFit] restore issue: %@",e.name);
    }
    self.isFitted=NO;
    self.horizontalPanChanged=NO;
    self.scaledView=nil;
    self.selectedScroll=nil;
}
- (NSString *)fit:(UIWindow *)window {
    [self restore];
    UIScrollView *scroll=[self target:window];
    if (!scroll) return @"No overflowing right-hand scroll content found on this screen.";
    UIView *content=[self visualContent:scroll];
    if (!content) return @"The right-hand scroll content is not accessible as a separate UIKit view.";
    CGFloat contentWidth=(scroll==self.menuTarget && self.menuContentWidth>0)
        ? self.menuContentWidth : scroll.contentSize.width;
    CGFloat viewport=(scroll==self.menuTarget && self.menuViewportWidth>0)
        ? self.menuViewportWidth : scroll.bounds.size.width;
    CGFloat scale=viewport/MAX(contentWidth,1);
    if (!isfinite(scale) || scale<=0.60 || scale>=0.99)
        return @"The right-hand pane does not need a supported visual scale.";
    @try {
        self.selectedScroll=scroll;
        self.scaledView=content;
        self.originalTransform=content.transform;
        self.originalCenter=content.center;
        self.isFitted=YES;
        CGRect initial=content.frame;
        content.transform=CGAffineTransformScale(content.transform,scale,scale);
        CGRect changed=content.frame;
        content.center=CGPointMake(self.originalCenter.x+CGRectGetMinX(initial)-CGRectGetMinX(changed),
                                   self.originalCenter.y+CGRectGetMinY(initial)-CGRectGetMinY(changed));
        return [NSString stringWithFormat:
            @"Scaled only the right-hand content to %.1f%% (%.0f to %.0f pt). Restore if touch targets or text become awkward.",
            scale*100,contentWidth,viewport];
    } @catch (NSException *e) {
        [self restore];
        return [NSString stringWithFormat:@"Fit failed; rolled back: %@",e.name];
    }
}
- (NSString *)enablePan:(UIWindow *)window {
    [self restore];
    UIScrollView *scroll=[self target:window];
    if (!scroll) return @"No overflowing right-hand scroll view found.";
    @try {
        self.selectedScroll=scroll;
        self.oldScrollEnabled=scroll.scrollEnabled;
        self.oldAlwaysBounceHorizontal=scroll.alwaysBounceHorizontal;
        self.oldShowsHorizontalScrollIndicator=scroll.showsHorizontalScrollIndicator;
        self.horizontalPanChanged=YES;
        scroll.scrollEnabled=YES;
        scroll.alwaysBounceHorizontal=YES;
        scroll.showsHorizontalScrollIndicator=YES;
        return [NSString stringWithFormat:
            @"Enabled horizontal panning for the right pane (%.0f pt content inside %.0f pt viewport). Swipe within that pane to see the hidden section.",
            scroll.contentSize.width,scroll.bounds.size.width];
    } @catch (NSException *e) {
        [self restore];
        return [NSString stringWithFormat:@"Pan failed; rolled back: %@",e.name];
    }
}
- (UIViewController *)presenter:(UIWindow *)window {
    UIViewController *p=window.rootViewController;
    while (p.presentedViewController) p=p.presentedViewController;
    return p;
}
- (void)feedback:(NSString *)text window:(UIWindow *)window {
    // Non-modal feedback: never present a second UIAlertController over the
    // still-dismissing action sheet. v9 accidentally did precisely that.
    if (!window || !text.length) return;
    @try {
        for (UIView *v in window.subviews)
            if (v.tag==0x504c55) [v removeFromSuperview];
        CGFloat width=MIN(window.bounds.size.width-48,610.0);
        UILabel *label=[[UILabel alloc] initWithFrame:CGRectMake(
            (window.bounds.size.width-width)/2.0, 105, width, 72)];
        label.tag=0x504c55;
        label.backgroundColor=[[UIColor blackColor] colorWithAlphaComponent:0.87];
        label.textColor=UIColor.whiteColor;
        label.font=[UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
        label.textAlignment=NSTextAlignmentCenter;
        label.numberOfLines=3;
        label.layer.cornerRadius=15;
        label.clipsToBounds=YES;
        label.userInteractionEnabled=NO;
        label.text=text;
        [window addSubview:label];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(4*NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{[label removeFromSuperview];});
    } @catch (NSException *e) {
        NSLog(@"[PlumiDuoSidebarFit] feedback failed: %@",e.name);
    }
}
- (void)showMenu:(UITapGestureRecognizer *)gesture {
    if (gesture.state!=UIGestureRecognizerStateRecognized) return;
    UIWindow *window=(UIWindow *)gesture.view;
    if (![window isKindOfClass:UIWindow.class]) return;
    @try {
        // Capture the right-hand scroll view and its width BEFORE any modal.
        self.menuTarget=nil;
        self.menuContentWidth=0;
        self.menuViewportWidth=0;
        UIScrollView *captured=[self target:window];
        self.menuTarget=captured;
        if (captured) {
            self.menuContentWidth=captured.contentSize.width;
            self.menuViewportWidth=captured.bounds.size.width;
        }
        UIViewController *p=[self presenter:window];
        if (!p) return;
        NSString *summary=captured ?
            [NSString stringWithFormat:@"Right panel detected before opening menu: %.1f pt content / %.1f pt viewport (%.1f pt overflow). No changes until you select an option.",
                self.menuContentWidth,self.menuViewportWidth,
                self.menuContentWidth-self.menuViewportWidth] :
            @"No matching right-hand scroll view before opening the menu. No changes will be applied.";
        UIAlertController *menu=[UIAlertController alertControllerWithTitle:@"Plumi Duo · Right Panel"
            message:summary
            preferredStyle:UIAlertControllerStyleActionSheet];
        __weak typeof(self) weakSelf=self;
        [menu addAction:[UIAlertAction actionWithTitle:@"Fit right panel content"
            style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.55*NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{
                    NSString *result=[weakSelf fit:window];
                    [weakSelf feedback:result window:window];
                });
            }]];
        [menu addAction:[UIAlertAction actionWithTitle:@"Allow right panel horizontal scrolling"
            style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.55*NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{
                    NSString *result=[weakSelf enablePan:window];
                    [weakSelf feedback:result window:window];
                });
            }]];
        [menu addAction:[UIAlertAction actionWithTitle:@"Restore original"
            style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
                [weakSelf restore];
                [weakSelf feedback:@"Original sidebar view restored." window:window];
            }]];
        [menu addAction:[UIAlertAction actionWithTitle:@"Cancel"
            style:UIAlertActionStyleCancel handler:nil]];
        UIPopoverPresentationController *pop=menu.popoverPresentationController;
        if (pop) {
            pop.sourceView=window;
            pop.sourceRect=CGRectMake(CGRectGetMidX(window.bounds),CGRectGetMidY(window.bounds),1,1);
        }
        [p presentViewController:menu animated:YES completion:nil];
    } @catch (NSException *e) {
        NSLog(@"[PlumiDuoSidebarFit] action menu error: %@",e.name);
    }
}
@end

__attribute__((constructor))
static void PlumiDuoSidebarFitStart(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([NSBundle.mainBundle.bundleIdentifier isEqualToString:@"dev.plumi.app"]) {
            [[PlumiDuoSidebarFit shared] registerWindows];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2*NSEC_PER_SEC),
               dispatch_get_main_queue(),^{[[PlumiDuoSidebarFit shared] registerWindows];});
        }
    });
}
