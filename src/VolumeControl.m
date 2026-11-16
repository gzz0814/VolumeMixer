//
//  VolumeControl.m
//

#import "VolumeControl.h"
#import "VMHUDWindow.h"
#import "VMIPCCenter.h"
#import "VolumeMixer.h"
#import <UIKit/UIKit.h>

@interface VolumeControl ()
@property (nonatomic, strong) VMHUDWindow *hudWindow;
@property (nonatomic, strong) VMIPCCenter *ipcCenter;
@property (nonatomic, copy) NSSet<NSString *> *enabledApps;
@property (nonatomic, assign) BOOL showsOnLockScreen;
@property (nonatomic, readwrite) CGFloat iconSide;
@end

@implementation VolumeControl

+ (instancetype)sharedInstance {
    static VolumeControl *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[VolumeControl alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self loadPreferences];

        // Fan-out endpoint: when the HUD moves a slider, the process that owns
        // the target app receives this and applies the volume to its own audio
        // session (only an app can change its own output volume).
        NSString *me = [[NSBundle mainBundle] bundleIdentifier];
        self.ipcCenter = [VMIPCCenter centerWithName:me];
        __weak typeof(self) weakSelf = self;
        [self.ipcCenter registerMethod:@"setVolume"
                           withHandler:^id(NSDictionary *args) {
            NSString *bid = args[@"bundleID"];
            float v = [args[@"volume"] floatValue];
            [weakSelf applyVolume:v forBundleID:bid];
            return nil;
        }];

        // Single funnel that every invocation path posts through.
        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(_handleShowPanel:)
                   name:kVMShowPanelNotification
                 object:nil];
        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(loadPreferences)
                   name:kVMLoadPrefNotification
                 object:nil];
    }
    return self;
}

- (void)loadPreferences {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kVMPreferencesDomain];
    NSArray *apps = [defaults arrayForKey:kVMAppsKey];
    self.enabledApps = apps ? [NSSet setWithArray:apps] : [NSSet set];
    self.showsOnLockScreen = [defaults boolForKey:kVMShowsOnLockScreenKey];

    // Feature #1: honor the configured icon size, falling back to the default.
    NSNumber *iconSize = [defaults objectForKey:kVMIconSizeKey];
    self.iconSide = iconSize ? iconSize.doubleValue : kVMIconSidePoints;
}

- (void)_handleShowPanel:(NSNotification *)note {
    // Only the foreground UI process should draw the panel.
    dispatch_async(dispatch_get_main_queue(), ^{
        UIApplicationState state = [UIApplication sharedApplication].applicationState;
        if (state == UIApplicationStateActive) {
            [self showPanel];
        }
    });
}

- (void)showPanel {
    if (!self.hudWindow) {
        CGRect frame = [UIScreen mainScreen].bounds;
        self.hudWindow = [[VMHUDWindow alloc] initWithFrame:frame];
    }
    [self.hudWindow showWindow];
}

- (void)hidePanel {
    [self.hudWindow hideWindow];
}

- (void)togglePanel {
    if (self.hudWindow && !self.hudWindow.hidden) {
        [self hidePanel];
    } else {
        [self showPanel];
    }
}

- (void)applyVolume:(float)volume forBundleID:(NSString *)bundleID {
    NSString *me = [[NSBundle mainBundle] bundleIdentifier];
    if (bundleID && ![bundleID isEqualToString:me]) {
        return; // not our audio session
    }
    // The concrete per-app output volume is applied through the audio hooks in
    // Tweak.x (SystemVolume / AudioToolbox). This entry point is the fan-out
    // target; the actual setter lives there so it can tap the private volume.
    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"com.brend0n.volumemixer/applyVolume"
                      object:nil
                    userInfo:@{ @"bundleID": me ?: @"", @"volume": @(volume) }];
}

@end
