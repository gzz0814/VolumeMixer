//
//  VolumeControl.h
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@interface VolumeControl : NSObject
+ (instancetype)sharedInstance;

/// Reveal the mixer panel over the current process. Safe to call from the
/// Activator listener, the volume-button hook or the new URL scheme handler.
- (void)showPanel;
- (void)hidePanel;
- (void)togglePanel;

/// Apply a per-app volume (0.0 - 1.0) locally in this process. Invoked by the
/// IPC fan-out in whichever process owns `bundleID`.
- (void)applyVolume:(float)volume forBundleID:(NSString *)bundleID;

/// Fixed on-screen icon side (points) used to normalize every app icon.
@property (nonatomic, readonly) CGFloat iconSide;

- (void)loadPreferences;
@end
