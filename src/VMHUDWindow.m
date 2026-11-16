//
//  VMHUDWindow.m
//

#import "VMHUDWindow.h"
#import "VMHUDRootViewController.h"

@implementation VMHUDWindow

+ (instancetype)sharedWindow {
    static VMHUDWindow *window;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        window = [[VMHUDWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    });
    return window;
}

// The Control Center module may call either accessor; both return the panel.
+ (instancetype)sharedInstance {
    return [self sharedWindow];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Above the normal app content but below system alerts; the original
        // uses a passthrough-style window so gestures still reach the app.
        self.windowLevel = UIWindowLevelAlert + 1;
        self.backgroundColor = [UIColor clearColor];
        self.hidden = YES;
        self.layer.masksToBounds = YES;

        VMHUDRootViewController *root = [[VMHUDRootViewController alloc] init];
        self.rootViewController = root;
    }
    return self;
}

- (void)showWindow {
    self.hidden = NO;
    [self makeKeyAndVisible];
    [(VMHUDRootViewController *)self.rootViewController reloadRunningApp];
}

- (void)hideWindow {
    self.hidden = YES;
    [self.rootViewController dismissViewControllerAnimated:YES completion:nil];
}

// Toggle used by the CCVolumeMixer Control Center tile.
- (void)changeVisibility {
    if (self.hidden) {
        [self showWindow];
    } else {
        [self hideWindow];
    }
}

- (void)dismissAnimated:(BOOL)animated completion:(void (^)(void))completion {
    [self hideWindow];
    if (completion) completion();
}

// Keep the window from stealing the keyboard focus from the underlying app.
- (BOOL)canBecomeKeyWindow {
    return YES;
}

@end
