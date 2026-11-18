// PlumiDuoLayout.m
// Experimental in-process UIKit trait override; does not touch MobileGestalt or system files.
// Copyright (c) 2026. MIT.
//
// On an iPhone in landscape, request compact-width SwiftUI layout inside Plumi.
// Portrait, other apps and system configuration remain untouched.
// Note: SwiftUI code that uses pixel widths or hardcoded positions may ignore this entirely.

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface PlumiDuoLayoutController : NSObject
@property (nonatomic, assign) BOOL disabledAfterException;
@property (nonatomic, strong) NSHashTable<UIWindowScene *> *activeOverrides;
@property (nonatomic, strong) NSTimer *timer;
+ (instancetype)shared;
- (void)refresh;
@end

@implementation PlumiDuoLayoutController

+ (instancetype)shared {
    static PlumiDuoLayoutController *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [self new]; });
    return instance;
}

- (instancetype)init {
    if ((self = [super init])) {
        _activeOverrides = [NSHashTable weakObjectsHashTable];
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(refresh) name:UIApplicationDidBecomeActiveNotification object:nil];
        [center addObserver:self selector:@selector(refresh) name:UISceneDidActivateNotification object:nil];
        [center addObserver:self selector:@selector(refresh) name:UIWindowDidBecomeVisibleNotification object:nil];
        [center addObserver:self selector:@selector(refresh) name:UIApplicationWillEnterForegroundNotification object:nil];
        // Coordinate-space changes are not guaranteed to issue a public notification.
        // Polling reads state only, and changes traits only on transition.
        _timer = [NSTimer scheduledTimerWithTimeInterval:1.2 repeats:YES block:^(__unused NSTimer *timer) {
            [self refresh];
        }];
    }
    return self;
}

- (void)refresh {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self refresh]; });
        return;
    }
    if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"dev.plumi.app"]) return;
    if (UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPhone) return;

    // v3: Do NOT read traitOverrides.horizontalSizeClass to detect the original
    // value. On iOS 27.2.1 this getter threw an NSException on iPhone Duo.
    // Check only whether a trait is explicitly overridden, and remove only
    // overrides installed by *this* shim. Never overwrite an app-owned value.
    if (self.disabledAfterException) return;
    @try {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (@available(iOS 17.0, *)) {
                id<UITraitOverrides> overrides = windowScene.traitOverrides;
                BOOL isLandscape = UIInterfaceOrientationIsLandscape(windowScene.interfaceOrientation);
                BOOL applied = [self.activeOverrides containsObject:windowScene];
                if (isLandscape && !applied) {
                    // Leave Plumi's own override completely alone if present.
                    if ([overrides containsTrait:UITraitHorizontalSizeClass.class]) continue;
                    overrides.horizontalSizeClass = UIUserInterfaceSizeClassCompact;
                    [self.activeOverrides addObject:windowScene];
                } else if (!isLandscape && applied) {
                    [overrides removeTrait:UITraitHorizontalSizeClass.class];
                    [self.activeOverrides removeObject:windowScene];
                }
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"[PlumiDuoLayout] Disabled after UIKit trait exception: %@", exception);
        self.disabledAfterException = YES;
        // Best effort: undo only this shim's overrides. Never rethrow.
        for (UIWindowScene *windowScene in self.activeOverrides.allObjects) {
            @try {
                [windowScene.traitOverrides removeTrait:UITraitHorizontalSizeClass.class];
            } @catch (__unused NSException *restoreException) {}
        }
        [self.activeOverrides removeAllObjects];
        [self.timer invalidate];
        self.timer = nil;
    }
}

@end

__attribute__((constructor))
static void PlumiDuoLayoutBoot(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([NSBundle.mainBundle.bundleIdentifier isEqualToString:@"dev.plumi.app"]) {
            [[PlumiDuoLayoutController shared] refresh];
        }
    });
}
