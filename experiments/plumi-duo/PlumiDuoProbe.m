// PlumiDuoProbe.m - read-only, user-initiated UIKit geometry inspector.
// Does not modify layout, trait overrides, scene types, or app data.
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface PlumiDuoProbe : NSObject
@property(nonatomic, strong) NSHashTable<UIWindow *> *attachedWindows;
+ (instancetype)shared;
- (void)installInVisibleWindows;
- (void)onSceneChange:(NSNotification *)note;
- (void)shareDiagnostic:(UITapGestureRecognizer *)tap;
@end

static NSString *rectText(CGRect r) {
    return [NSString stringWithFormat:@"(%.1f, %.1f, %.1f, %.1f)",r.origin.x,r.origin.y,r.size.width,r.size.height];
}
static void walk(UIView *v, UIWindow *w, NSUInteger depth, NSUInteger *count, NSMutableString *out) {
    if (!v || depth > 11 || *count >= 250) return;
    ++(*count);
    @try {
        CGRect r=[v convertRect:v.bounds toView:w];
        [out appendFormat:@"%3lu depth=%lu %@ frame=%@ window=%@ %@\n",
            (unsigned long)*count,(unsigned long)depth,NSStringFromClass(v.class),
            rectText(v.frame),rectText(r),
            CGRectGetMaxX(r)>w.bounds.size.width+1?@"RIGHT-OVERFLOW":@""];
        if ([v isKindOfClass:UIScrollView.class]) {
            UIScrollView *scroll=(UIScrollView *)v;
            [out appendFormat:@"    scroll content size: %.1f x %.1f\n",
                scroll.contentSize.width,scroll.contentSize.height];
        }
    } @catch (NSException *e) {
        [out appendFormat:@"Geometry unavailable: %@\n",e.name];
    }
    for (UIView *child in v.subviews) {
        if (*count>=250) break;
        walk(child,w,depth+1,count,out);
    }
}

@implementation PlumiDuoProbe
+ (instancetype)shared {
    static PlumiDuoProbe *obj;
    static dispatch_once_t once;
    dispatch_once(&once, ^{obj=[self new];});
    return obj;
}
- (instancetype)init {
    if ((self=[super init])) {
        _attachedWindows=[NSHashTable weakObjectsHashTable];
        NSNotificationCenter *nc=[NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(onSceneChange:)
                   name:UISceneDidActivateNotification object:nil];
        [nc addObserver:self selector:@selector(onSceneChange:)
                   name:UIWindowDidBecomeVisibleNotification object:nil];
        [nc addObserver:self selector:@selector(onSceneChange:)
                   name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}
- (void)onSceneChange:(__unused NSNotification *)note {
    [self installInVisibleWindows];
}
- (void)installInVisibleWindows {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{[self installInVisibleWindows];});
        return;
    }
    if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"dev.plumi.app"]) return;
    if (UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPhone) return;
    @try {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (!window || window.hidden || [self.attachedWindows containsObject:window]) continue;
                UITapGestureRecognizer *tap=[[UITapGestureRecognizer alloc]
                    initWithTarget:self action:@selector(shareDiagnostic:)];
                tap.numberOfTouchesRequired=2;
                tap.numberOfTapsRequired=3;
                tap.cancelsTouchesInView=NO;
                [window addGestureRecognizer:tap];
                [self.attachedWindows addObject:window];
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[PlumiDuoProbe] install failed: %@",e);
    }
}
- (void)shareDiagnostic:(UITapGestureRecognizer *)tap {
    if (tap.state != UIGestureRecognizerStateRecognized) return;
    UIWindow *w=(UIWindow *)tap.view;
    if (![w isKindOfClass:UIWindow.class]) return;
    @try {
        NSMutableString *s=[NSMutableString stringWithString:
            @"Plumi Duo local layout report (no account or study content)\n"];
        [s appendFormat:@"OS: %@\nWindow bounds: %@\n",UIDevice.currentDevice.systemVersion,rectText(w.bounds)];
        [s appendFormat:@"Safe area: top %.1f left %.1f bottom %.1f right %.1f\n",
            w.safeAreaInsets.top,w.safeAreaInsets.left,w.safeAreaInsets.bottom,w.safeAreaInsets.right];
        [s appendFormat:@"Horizontal size class: %ld\n",(long)w.traitCollection.horizontalSizeClass];
        if (w.windowScene)
            [s appendFormat:@"Scene bounds: %@; orientation: %ld\n",
                rectText(w.windowScene.coordinateSpace.bounds),(long)w.windowScene.interfaceOrientation];
        NSUInteger count=0;
        walk(w,w,0,&count,s);
        NSURL *url=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"PlumiDuoGeometry.txt"]];
        NSError *error=nil;
        if (![s writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
            NSLog(@"[PlumiDuoProbe] export failed: %@",error);
            return;
        }
        UIViewController *presenter=w.rootViewController;
        while (presenter.presentedViewController) presenter=presenter.presentedViewController;
        if (!presenter) return;
        UIActivityViewController *share=[[UIActivityViewController alloc]
            initWithActivityItems:@[url] applicationActivities:nil];
        UIPopoverPresentationController *pop=share.popoverPresentationController;
        if (pop) {
            pop.sourceView=w;
            pop.sourceRect=CGRectMake(w.bounds.size.width/2,w.bounds.size.height/2,1,1);
        }
        [presenter presentViewController:share animated:YES completion:nil];
    } @catch (NSException *e) {
        NSLog(@"[PlumiDuoProbe] export exception: %@",e);
    }
}
@end

__attribute__((constructor))
static void PlumiDuoProbeStart(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"dev.plumi.app"]) return;
        [[PlumiDuoProbe shared] installInVisibleWindows];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2*NSEC_PER_SEC),
                       dispatch_get_main_queue(),
                       ^{[[PlumiDuoProbe shared] installInVisibleWindows];});
    });
}
