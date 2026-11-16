//
//  VolumeMixer.h
//  Shared constants for the VolumeMixer tweak.
//

#import <UIKit/UIKit.h>

#define kVMPreferencesDomain @"com.apple.UIKit"

// Preference keys (stored in the com.apple.UIKit domain, matching the original).
#define kVMAppsKey                @"com.brend0n.volumemixer_apps"
#define kVMEnableKey              @"com.brend0n.volumemixer_webEnabled"
#define kVMAudioMixEnabledKey     @"com.brend0n.volumemixer_audioMixEnabled"
#define kVMByVolumeButtonKey      @"com.brend0n.volumemixer_byVolumeButton"
#define kVMHideInactiveKey        @"com.brend0n.volumemixer_isHideInactiveApps"
#define kVMHideBackgroundKey      @"com.brend0n.volumemixer_isHideBackground"
#define kVMShowsOnLockScreenKey   @"com.brend0n.volumemixer_showsOnLockScreen"
#define kVMPanelPortraitYKey      @"com.brend0n.volumemixer_panelPortraitY"
#define kVMPanelLandscapeYKey     @"com.brend0n.volumemixer_panelLandScapeY"
// Feature #1: user-adjustable on-screen icon side (points).
#define kVMIconSizeKey            @"com.brend0n.volumemixer_iconSize"

// Notifications.
#define kVMLoadPrefNotification   @"com.brend0n.volumemixer/loadPref"
// Posted (as a Darwin notification) whenever the panel should be revealed. Any
// foreground process that receives it shows its HUD. This is the single funnel
// used by Activator, the CC widget, the volume buttons and the new URL scheme.
#define kVMShowPanelNotification  @"com.brend0n.volumemixer/showPanel"

// URL scheme exposed for the Shortcuts app ("Open URLs" action).
#define kVMURLScheme              @"volumemixer"

// Icon geometry used to normalize every app icon to the same on-screen size.
#define kVMIconSidePoints         44.0
// iOS super-ellipse corner radius is ~0.2237 * side.
#define kVMIconCornerRatio        0.2237
