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
@property (nonatomic, strong) NSMapTable<UIWindowScene *, NSNumber *> *previousOverrides;
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
        _previousOverrides = [NSMapTable weakToStrongObjectsMapTable];
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

    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        if (@available(iOS 17.0, *)) {
            id<UITraitOverrides> overrides = windowScene.traitOverrides;
            BOOL isLandscape = UIInterfaceOrientationIsLandscape(windowScene.interfaceOrientation);
            BOOL applied = [self.activeOverrides containsObject:windowScene];
            if (isLandscape && !applied) {
                // Preserve Plumi's prior override (including .unspecified), if any.
                [self.previousOverrides setObject:@(overrides.horizontalSizeClass) forKey:windowScene];
                overrides.horizontalSizeClass = UIUserInterfaceSizeClassCompact;
                [self.activeOverrides addObject:windowScene];
            } else if (!isLandscape && applied) {
                NSNumber *previous = [self.previousOverrides objectForKey:windowScene];
                if (overrides.horizontalSizeClass == UIUserInterfaceSizeClassCompact) {
                    overrides.horizontalSizeClass =
                        previous ? (UIUserInterfaceSizeClass)previous.integerValue : UIUserInterfaceSizeClassUnspecified;
                }
                [self.previousOverrides removeObjectForKey:windowScene];
                [self.activeOverrides removeObject:windowScene];
            }
        }
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
