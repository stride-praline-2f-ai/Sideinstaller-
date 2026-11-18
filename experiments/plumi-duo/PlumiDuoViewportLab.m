// PlumiDuoViewportLab.m
// Reversible, per-view user-initiated iPhone Duo layout experiment.
// No global traits, SwiftUI device spoofing or private API.
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include <math.h>

@interface PlumiDuoViewportLab : NSObject
@property(nonatomic,strong) NSHashTable<UIWindow *> *observedWindows;
@property(nonatomic,weak) UIView *adjustedView;
@property(nonatomic,assign) CGAffineTransform savedTransform;
@property(nonatomic,assign) CGPoint savedCenter;
@property(nonatomic,assign) BOOL hasAdjustment;
+ (instancetype)shared;
- (void)registerWindows;
- (void)onNotice:(NSNotification *)notice;
- (void)presentMenu:(UITapGestureRecognizer *)gesture;
@end

@implementation PlumiDuoViewportLab

+ (instancetype)shared {
    static PlumiDuoViewportLab *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance=[self new]; });
    return instance;
}
- (instancetype)init {
    if ((self=[super init])) {
        _observedWindows=[NSHashTable weakObjectsHashTable];
        NSNotificationCenter *nc=NSNotificationCenter.defaultCenter;
        [nc addObserver:self selector:@selector(onNotice:)
                  name:UIApplicationDidBecomeActiveNotification object:nil];
        [nc addObserver:self selector:@selector(onNotice:)
                  name:UIWindowDidBecomeVisibleNotification object:nil];
        [nc addObserver:self selector:@selector(onNotice:)
                  name:UISceneDidActivateNotification object:nil];
        [nc addObserver:self selector:@selector(onNotice:)
                  name:UIDeviceOrientationDidChangeNotification object:nil];
        [UIDevice.currentDevice beginGeneratingDeviceOrientationNotifications];
    }
    return self;
}
- (void)onNotice:(__unused NSNotification *)notice {
    if (self.hasAdjustment) {
        UIWindow *window=self.adjustedView.window;
        if (!window || (window.windowScene &&
                        !UIInterfaceOrientationIsLandscape(window.windowScene.interfaceOrientation))) {
            [self restore];
        }
    }
    [self registerWindows];
}
- (void)registerWindows {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self registerWindows]; });
        return;
    }
    if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"dev.plumi.app"]) return;
    if (UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPhone) return;
    @try {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (!window || window.hidden || [self.observedWindows containsObject:window]) continue;
                UITapGestureRecognizer *tap=[[UITapGestureRecognizer alloc]
                    initWithTarget:self action:@selector(presentMenu:)];
                tap.numberOfTouchesRequired=2;
                tap.numberOfTapsRequired=3;
                tap.cancelsTouchesInView=NO;
                [window addGestureRecognizer:tap];
                [self.observedWindows addObject:window];
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[PlumiViewportLab] registration exception: %@", e);
    }
}
// Identify a dashboard scroll *container* from its actual geometry, rather than
// requiring one private class name and exact y/width thresholds. SwiftUI may use
// slightly different wrapper classes between individual screens.
- (UIView *)findDashboardView:(UIView *)root inWindow:(UIWindow *)window depth:(NSUInteger)depth {
    if (!root || depth>30) return nil;
    @try {
        CGRect rect=[root convertRect:root.bounds toView:window];
        NSString *className=NSStringFromClass(root.class);
        BOOL isHostingScroll=([className containsString:@"HostingScrollView"] ||
                              [className containsString:@"PlatformContainer"]);
        CGFloat limit=window.bounds.size.width;
        BOOL overflow=(CGRectGetMaxX(rect)>limit+12.0 || rect.size.width>limit+12.0);
        BOOL mainPane=(CGRectGetMinY(rect)>95.0 && rect.size.height>135.0 &&
                       rect.size.height<window.bounds.size.height*2.0);
        if (isHostingScroll && mainPane && overflow &&
            rect.size.width<limit*2.0) {
            return root;
        }
        // Search wrappers below a normally-sized SwiftUI scroll view as well.
        for (UIView *child in root.subviews) {
            UIView *match=[self findDashboardView:child inWindow:window depth:depth+1];
            if (match) return match;
        }
    } @catch (NSException *exception) {
        NSLog(@"[PlumiViewportLab] view search exception: %@",exception);
    }
    return nil;
}
// The diagnostic report deliberately excludes all view text and user data.
- (void)collectOverflows:(UIView *)view inWindow:(UIWindow *)window
                  depth:(NSUInteger)depth remaining:(NSUInteger *)remaining
                 output:(NSMutableString *)output {
    if (!view || depth>30 || *remaining==0) return;
    @try {
        CGRect rect=[view convertRect:view.bounds toView:window];
        NSString *name=NSStringFromClass(view.class);
        BOOL interesting=([name containsString:@"HostingScrollView"] ||
                          [name containsString:@"PlatformContainer"] ||
                          [view isKindOfClass:UIScrollView.class]);
        if (interesting && CGRectGetMinY(rect)>40) {
            CGSize content=CGSizeZero;
            if ([view isKindOfClass:UIScrollView.class])
                content=((UIScrollView *)view).contentSize;
            [output appendFormat:@"%lu %@ x=%.1f y=%.1f w=%.1f h=%.1f contentW=%.1f overflow=%.1f\n",
                (unsigned long)depth,name,rect.origin.x,rect.origin.y,
                rect.size.width,rect.size.height,content.width,
                MAX(CGRectGetMaxX(rect)-window.bounds.size.width,0.0)];
            --(*remaining);
        }
        for (UIView *child in view.subviews)
            [self collectOverflows:child inWindow:window depth:depth+1 remaining:remaining output:output];
    } @catch (NSException *e) {
        [output appendFormat:@"Inspect exception %@\n",e.name];
    }
}
- (void)exportGeometryInWindow:(UIWindow *)window {
    NSMutableString *out=[NSMutableString stringWithFormat:
        @"Plumi Duo v8 geometry only (no user text)\nWindow width %.1f height %.1f; safe area L %.1f R %.1f\n",
        window.bounds.size.width,window.bounds.size.height,
        window.safeAreaInsets.left,window.safeAreaInsets.right];
    NSUInteger remaining=80;
    [self collectOverflows:window inWindow:window depth:0 remaining:&remaining output:out];
    NSURL *url=[NSURL fileURLWithPath:
        [NSTemporaryDirectory() stringByAppendingPathComponent:@"PlumiDuo-v8-Geometry.txt"]];
    NSError *error=nil;
    if (![out writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        [self message:[NSString stringWithFormat:@"Report failed: %@",error.localizedDescription] onWindow:window];
        return;
    }
    UIViewController *p=[self presenter:window];
    if (!p) return;
    UIActivityViewController *share=[[UIActivityViewController alloc]
        initWithActivityItems:@[url] applicationActivities:nil];
    UIPopoverPresentationController *popover=share.popoverPresentationController;
    if (popover) {
        popover.sourceView=window;
        popover.sourceRect=CGRectMake(window.bounds.size.width/2,window.bounds.size.height/2,1,1);
    }
    [p presentViewController:share animated:YES completion:nil];
}

- (void)restore {
    if (!self.hasAdjustment) return;
    @try {
        UIView *v=self.adjustedView;
        if (v) {
            v.transform=self.savedTransform;
            v.center=self.savedCenter;
        }
    } @catch (NSException *e) {
        NSLog(@"[PlumiViewportLab] restore exception: %@",e);
    }
    self.adjustedView=nil;
    self.hasAdjustment=NO;
}
- (NSString *)fitViewInWindow:(UIWindow *)window maximumScale:(CGFloat)maximumScale {
    [self restore];
    UIView *v=[self findDashboardView:window inWindow:window depth:0];
    if (!v) return @"No oversized hosting container matched. The window may clip an internal SwiftUI child instead. Use Export geometry report from the menu to measure this exact screen.";
    if (!window.windowScene ||
        !UIInterfaceOrientationIsLandscape(window.windowScene.interfaceOrientation))
        return @"The experiment is only available in landscape.";
    @try {
        CGRect visible=[v convertRect:v.bounds toView:window];
        CGFloat usable=window.bounds.size.width-MAX(visible.origin.x,0);
        CGFloat ratio=MIN(usable/MAX(visible.size.width,1), maximumScale);
        if (!isfinite(ratio) || ratio<=0.60 || ratio>=1)
            return @"The detected width doesn't require a supported fit adjustment.";
        self.adjustedView=v;
        self.savedTransform=v.transform;
        self.savedCenter=v.center;
        self.hasAdjustment=YES;
        CGRect before=v.frame;
        v.transform=CGAffineTransformScale(v.transform,ratio,ratio);
        CGRect after=v.frame;
        v.center=CGPointMake(self.savedCenter.x+CGRectGetMinX(before)-CGRectGetMinX(after),
                             self.savedCenter.y+CGRectGetMinY(before)-CGRectGetMinY(after));
        return [NSString stringWithFormat:
            @"Applied a %.1f%% visual fit to the dashboard only. No global traits changed. Use Restore if the layout looks worse.",ratio*100];
    } @catch (NSException *e) {
        [self restore];
        return [NSString stringWithFormat:@"Fit failed and was rolled back: %@",e.name];
    }
}
- (UIViewController *)presenter:(UIWindow *)window {
    UIViewController *p=window.rootViewController;
    while (p.presentedViewController) p=p.presentedViewController;
    return p;
}
- (void)message:(NSString *)message onWindow:(UIWindow *)window {
    UIViewController *p=[self presenter:window];
    if (!p) return;
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Plumi Duo"
        message:message preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [p presentViewController:a animated:YES completion:nil];
}
- (void)presentMenu:(UITapGestureRecognizer *)gesture {
    if (gesture.state!=UIGestureRecognizerStateRecognized) return;
    UIWindow *window=(UIWindow *)gesture.view;
    if (![window isKindOfClass:UIWindow.class]) return;
    @try {
        UIViewController *p=[self presenter:window];
        if (!p) return;
        UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Plumi Duo · Dashboard Fit"
            message:@"Original layout stays unchanged until you choose a fit option. Tighter fit may reveal more of the right-side dashboard, but also makes text smaller."
            preferredStyle:UIAlertControllerStyleActionSheet];
        __weak typeof(self) weakSelf=self;
        [a addAction:[UIAlertAction actionWithTitle:@"Fit container to screen"
            style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.55*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    NSString *result=[weakSelf fitViewInWindow:window maximumScale:1.0];
                    [weakSelf message:result onWindow:window];
                });
            }]];
        [a addAction:[UIAlertAction actionWithTitle:@"Tighter fit (85%): show more of right panel"
            style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.55*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    NSString *result=[weakSelf fitViewInWindow:window maximumScale:0.85];
                    [weakSelf message:result onWindow:window];
                });
            }]];
        [a addAction:[UIAlertAction actionWithTitle:@"Export screen geometry report"
            style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [weakSelf exportGeometryInWindow:window];
                });
            }]];
        [a addAction:[UIAlertAction actionWithTitle:@"Restore original layout"
            style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
                [weakSelf restore];
                [weakSelf message:@"Original layout restored." onWindow:window];
            }]];
        [a addAction:[UIAlertAction actionWithTitle:@"Cancel"
            style:UIAlertActionStyleCancel handler:nil]];
        UIPopoverPresentationController *pop=a.popoverPresentationController;
        if (pop) {
            pop.sourceView=window;
            pop.sourceRect=CGRectMake(window.bounds.size.width/2,window.bounds.size.height/2,1,1);
        }
        [p presentViewController:a animated:YES completion:nil];
    } @catch (NSException *e) {
        NSLog(@"[PlumiViewportLab] menu failure: %@",e);
    }
}
@end

__attribute__((constructor))
static void PlumiDuoViewportLabStart(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([NSBundle.mainBundle.bundleIdentifier isEqualToString:@"dev.plumi.app"]) {
            [[PlumiDuoViewportLab shared] registerWindows];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),
                dispatch_get_main_queue(),^{ [[PlumiDuoViewportLab shared] registerWindows]; });
        }
    });
}
