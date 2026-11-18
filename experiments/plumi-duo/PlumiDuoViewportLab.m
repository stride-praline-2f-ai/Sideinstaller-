// PlumiDuoViewportLab.m
// Reversible, per-view user-initiated iPhone Duo layout experiment.
// No global traits, SwiftUI device spoofing or private API.
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

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
    }
    return self;
}
- (void)onNotice:(__unused NSNotification *)notice { [self registerWindows]; }
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
- (UIView *)findDashboardView:(UIView *)view inWindow:(UIWindow *)window depth:(NSUInteger)depth {
    if (!view || depth>15) return nil;
    @try {
        NSString *name=NSStringFromClass(view.class);
        CGRect rect=[view convertRect:view.bounds toView:window];
        if ([name containsString:@"HostingScrollView"] &&
            [name containsString:@"PlatformContainer"] &&
            CGRectGetMinY(rect)>130 &&
            rect.size.height>180 &&
            rect.size.width>window.bounds.size.width+20 &&
            rect.size.width<window.bounds.size.width*2.0) {
            return view;
        }
        for (UIView *child in view.subviews) {
            UIView *found=[self findDashboardView:child inWindow:window depth:depth+1];
            if (found) return found;
        }
    } @catch (NSException *e) {
        NSLog(@"[PlumiViewportLab] searching view failed: %@",e);
    }
    return nil;
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
- (NSString *)fitViewInWindow:(UIWindow *)window {
    [self restore];
    UIView *v=[self findDashboardView:window inWindow:window depth:0];
    if (!v) return @"No oversized dashboard container is visible. Navigate to Chemistry first.";
    @try {
        CGRect visible=[v convertRect:v.bounds toView:window];
        CGFloat usable=window.bounds.size.width-MAX(visible.origin.x,0);
        CGFloat ratio=usable/MAX(visible.size.width,1);
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
            message:@"Experimental, reversible visual fit for the oversized dashboard only. The original layout is unchanged until you choose Fit."
            preferredStyle:UIAlertControllerStyleActionSheet];
        __weak typeof(self) weakSelf=self;
        [a addAction:[UIAlertAction actionWithTitle:@"Fit dashboard to window"
            style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
                NSString *result=[weakSelf fitViewInWindow:window];
                [weakSelf message:result onWindow:window];
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
