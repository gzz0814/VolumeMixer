#import "VMHUDWindow.h"
#import "VMHUDRootViewController.h"
#import <notify.h>
#import <theos/IOSMacros.h>
#import "TweakSB.h"

@interface AXPassthroughWindow : UIWindow
+ (id)sharedInstance;
@end

NSUserDefaults *g_defaults = nil;

VMHUDWindow *hudWindow = nil;
VMHUDRootViewController *rootViewController = nil;
static BOOL byVolumeButton = NO;

static void loadPref(){
    byVolumeButton = [g_defaults objectForKey:kPrefByVolumeButtonKey] ? [g_defaults boolForKey:kPrefByVolumeButtonKey] : NO;

    [rootViewController loadPref];
}

static void showHUDWindowSB(){
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        hudWindow = VMHUDWindow.sharedWindow;
        rootViewController = [VMHUDRootViewController new];
        hudWindow.rootViewController = rootViewController;
    });
}

// Feature #2: handle the "volumemixer://" URL scheme so the Shortcuts
// "Open URL" action (and any other caller) can reveal / dismiss the panel.
//   volumemixer://show  -> reveal the mixer panel
//   volumemixer://hide  -> dismiss the mixer panel
static BOOL VMHandleVolumeMixerURL(NSURL *url){
    if(!url || ![url.scheme isEqualToString:@"volumemixer"]){
        return NO;
    }
    NSString *action = url.host.lowercaseString;
    if(!action.length){
        action = [[url.path stringByReplacingOccurrencesOfString:@"/" withString:@""] lowercaseString];
    }
    BOOL hide = [action isEqualToString:@"hide"];
    dispatch_async(dispatch_get_main_queue(), ^{
        showHUDWindowSB();
        if(hide){
            [hudWindow hideWindow];
        }
        else{
            [hudWindow showWindow];
        }
    });
    return YES;
}

// Translate a volumemixer:// URL into the matching Darwin notification.
static void VMPostSchemeNotify(NSURL *url){
    NSString *action = url.host.lowercaseString;
    if(!action.length){
        action = [[url.path stringByReplacingOccurrencesOfString:@"/" withString:@""] lowercaseString];
    }
    const char *name = "com.brend0n.volumemixer/toggle";
    if([action isEqualToString:@"show"]){
        name = "com.brend0n.volumemixer/show";
    }
    else if([action isEqualToString:@"hide"]){
        name = "com.brend0n.volumemixer/hide";
    }
    notify_post(name);
}

// The Shortcuts "Open URL" action runs inside the caller process. A custom
// scheme with no owning app is rejected by LaunchServices there, before it can
// ever reach SpringBoard, so we intercept UIApplication's openURL: entry points
// in every process the tweak loads and turn volumemixer:// into a Darwin notify
// that SpringBoard listens for.
%group url
%hook UIApplication
- (BOOL)openURL:(NSURL *)url{
    if([url.scheme isEqualToString:@"volumemixer"]){
        VMPostSchemeNotify(url);
        return YES;
    }
    return %orig;
}
- (BOOL)openURL:(NSURL *)url options:(NSDictionary *)options{
    if([url.scheme isEqualToString:@"volumemixer"]){
        VMPostSchemeNotify(url);
        return YES;
    }
    return %orig;
}
- (void)openURL:(NSURL *)url completionHandler:(void(^)(BOOL success))completion{
    if([url.scheme isEqualToString:@"volumemixer"]){
        VMPostSchemeNotify(url);
        if(completion) completion(YES);
        return;
    }
    %orig;
}
- (void)openURL:(NSURL *)url options:(NSDictionary *)options completionHandler:(void(^)(BOOL success))completion{
    if([url.scheme isEqualToString:@"volumemixer"]){
        VMPostSchemeNotify(url);
        if(completion) completion(YES);
        return;
    }
    %orig;
}
%end //UIApplication
%end //url

%group SB
%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application{
    %orig;
    NSLog(@"applicationDidFinishLaunching");
    showHUDWindowSB();    
    dispatch_async(dispatch_get_main_queue(), ^{
        AXPassthroughWindow *axPassthroughWindow = [objc_getClass("AXPassthroughWindow") sharedInstance];
        if(axPassthroughWindow){
            hudWindow.windowLevel = axPassthroughWindow.windowLevel + 1;
        }
    });
}

// Feature #2: intercept the volumemixer:// scheme across the SpringBoard URL
// opening entry points used on different iOS versions.
- (BOOL)application:(id)application openURL:(NSURL *)url options:(NSDictionary *)options{
    if(VMHandleVolumeMixerURL(url)){
        return YES;
    }
    return %orig;
}
- (BOOL)application:(id)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation{
    if(VMHandleVolumeMixerURL(url)){
        return YES;
    }
    return %orig;
}
- (BOOL)application:(id)application handleOpenURL:(NSURL *)url{
    if(VMHandleVolumeMixerURL(url)){
        return YES;
    }
    return %orig;
}
%end //SpringBoard

%hook VolumeControlClass
- (void)increaseVolume{
    %orig;
    if(byVolumeButton){
        showHUDWindowSB();
        [hudWindow showWindow];
    }
}
- (void)decreaseVolume{
    %orig;
    if(byVolumeButton){
        showHUDWindowSB();
        [hudWindow showWindow];
    }
}
%end //VolumeControlClass
%end //SB

%ctor{
    %init(url);
    if(!IN_SPRINGBOARD){
        return;
    }
    // Credit: Polyfills — com.apple.UIKit usage
    g_defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.apple.UIKit"];

    %init(SB, VolumeControlClass = objc_getClass("SBVolumeControl") ?: objc_getClass("VolumeControl"));

    loadPref();
    int token;
    notify_register_dispatch("com.brend0n.volumemixer/loadPref", &token, dispatch_get_main_queue(), ^(int token) {
        loadPref();
    });

    // The Control Center toggle lives in the ControlCenter process and cannot
    // reach VMHUDWindow here; it posts this notification instead, and SpringBoard
    // performs the actual show/hide.
    int toggleToken;
    notify_register_dispatch("com.brend0n.volumemixer/toggle", &toggleToken, dispatch_get_main_queue(), ^(int t) {
        showHUDWindowSB();
        [hudWindow changeVisibility];
    });

    // Explicit reveal / dismiss from the volumemixer://show and :hide URL scheme.
    int showToken;
    notify_register_dispatch("com.brend0n.volumemixer/show", &showToken, dispatch_get_main_queue(), ^(int t) {
        showHUDWindowSB();
        [hudWindow showWindow];
    });
    int hideToken;
    notify_register_dispatch("com.brend0n.volumemixer/hide", &hideToken, dispatch_get_main_queue(), ^(int t) {
        showHUDWindowSB();
        [hudWindow hideWindow];
    });
}
