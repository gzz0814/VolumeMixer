//
//  Tweak.x
//  VolumeMixer — per-app volume control.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "VolumeMixer.h"
#import "VolumeControl.h"
#import "VolumeMixerLAListener.h"

// ---------------------------------------------------------------------------
// Cross-process "show panel" funnel.
//
// The URL scheme is delivered to SpringBoard, and the Activator / Control
// Center paths can fire from other processes, but the HUD must be drawn by the
// *frontmost* app. We therefore post a Darwin (system-wide) notification and,
// in every injected process, re-broadcast it locally so VolumeControl only
// reacts when it is the active UI.
// ---------------------------------------------------------------------------
static void VMPostShowPanel(void) {
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.brend0n.volumemixer/showPanel"),
        NULL, NULL, true);
}

static void VMDarwinShowObserver(CFNotificationCenterRef center,
                                 void *observer,
                                 CFStringRef name,
                                 const void *object,
                                 CFDictionaryRef userInfo) {
    [[NSNotificationCenter defaultCenter]
        postNotificationName:kVMShowPanelNotification object:nil];
}

// ---------------------------------------------------------------------------
// Feature #2: Shortcuts invocation via URL scheme.
//
//   volumemixer://show                          reveal / toggle the panel
//   volumemixer://hide                          hide it
//   volumemixer://set?app=<BID>&volume=<0..1>   direct per-app set (optional)
//
// The Shortcuts app's "Open URLs" action can target this scheme; because the
// scheme is not tied to an installed app we intercept it here and consume the
// open so Shortcuts reports success.
// ---------------------------------------------------------------------------
static BOOL VMHandledURL(NSURL *url) {
    if (![url.scheme.lowercaseString isEqualToString:kVMURLScheme]) {
        return NO;
    }

    NSString *host = url.host.lowercaseString;   // volumemixer://show  -> "show"
    NSString *path = url.path.lowercaseString;   // volumemixer:///show -> "/show"
    NSString *action = host.length ? host
                         : (path.length ? [path substringFromIndex:1] : @"show");

    if ([action isEqualToString:@"hide"]) {
        [[VolumeControl sharedInstance] hidePanel];
    } else if ([action isEqualToString:@"set"]) {
        NSURLComponents *comps = [NSURLComponents componentsWithURL:url
                                            resolvingAgainstBaseURL:NO];
        NSString *app = nil;
        float volume = -1;
        for (NSURLQueryItem *item in comps.queryItems) {
            if ([item.name isEqualToString:@"app"]) app = item.value;
            else if ([item.name isEqualToString:@"volume"]) volume = (float)item.value.floatValue;
        }
        if (app.length && volume >= 0) {
            [[VolumeControl sharedInstance] applyVolume:volume forBundleID:app];
        }
        VMPostShowPanel();
    } else { // "show" / "toggle" / anything else
        VMPostShowPanel();
    }
    return YES;
}

// SpringBoard is the URL-open delegate. Hooking every historical openURL
// variant means the scheme is caught regardless of how Shortcuts delivers it.
// These hooks live in a %group so they are only installed inside SpringBoard
// itself (the class does not exist in other injected processes).
%group VMSpringBoard

- (BOOL)application:(id)application openURL:(NSURL *)url options:(NSDictionary *)options {
    if (VMHandledURL(url)) return YES;
    return %orig;
}

- (BOOL)application:(id)application handleOpenURL:(NSURL *)url {
    if (VMHandledURL(url)) return YES;
    return %orig;
}

- (BOOL)application:(id)application
            openURL:(NSURL *)url
    sourceApplication:(NSString *)sourceApplication
           annotation:(id)annotation {
    if (VMHandledURL(url)) return YES;
    return %orig;
}

%end

%ctor {
    @autoreleasepool {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            VMDarwinShowObserver,
            CFSTR("com.brend0n.volumemixer/showPanel"),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);

        [VolumeControl sharedInstance];
        [VolumeMixerLAListener registerListeners];

        // Only install the URL hooks where the SpringBoard class exists.
        if (objc_getClass("SpringBoard")) {
            %init(VMSpringBoard);
        }
    }
}
