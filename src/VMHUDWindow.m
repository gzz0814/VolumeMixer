//
//  VMHUDWindow.m
//

#import "VMHUDWindow.h"
#import "VMHUDRootViewController.h"

@implementation VMHUDWindow

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

// Keep the window from stealing the keyboard focus from the underlying app.
- (BOOL)canBecomeKeyWindow {
    return YES;
}

@end
