//
//  VMHUDWindow.h
//

#import <UIKit/UIKit.h>

@interface VMHUDWindow : UIWindow

/// Singleton accessor used by the Control Center module (CCVolumeMixer), which
/// looks this class up at runtime via NSClassFromString and drives the panel
/// through these selectors. Kept name-compatible with the original package.
+ (instancetype)sharedWindow;
+ (instancetype)sharedInstance;

- (void)showWindow;
- (void)hideWindow;

/// Toggle the panel; invoked when the Control Center tile is tapped.
- (void)changeVisibility;
- (void)dismissAnimated:(BOOL)animated completion:(void (^)(void))completion;

@end
