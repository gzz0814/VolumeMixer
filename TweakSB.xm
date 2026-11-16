#import "VMHUDWindow.h"
#import "VMHUDRootViewController.h"
#import <notify.h>
#import <theos/IOSMacros.h>
#import "TweakSB.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <string.h>

@interface AXPassthroughWindow : UIWindow
+ (id)sharedInstance;
@end

NSUserDefaults *g_defaults = nil;

VMHUDWindow *hudWindow = nil;
VMHUDRootViewController *rootViewController = nil;
static BOOL byVolumeButton = NO;

static void VMStartURLServer(void);

static void loadPref(){
    byVolumeButton = [g_defaults objectForKey:kPrefByVolumeButtonKey] ? [g_defaults boolForKey:kPrefByVolumeButtonKey] : NO;

    [rootViewController loadPref];

    // (Re)start the loopback server if the configured port changed, so the
    // Shortcuts "Get Contents of URL" endpoint follows the setting live.
    VMStartURLServer();
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

// Feature #2 (roothide fallback): the tweak is not injected into the Shortcuts
// process on this jailbreak, so the canOpenURL/openURL hooks above never run
// there and "Open URL" reports the scheme as not installed. Instead SpringBoard
// (which is always injected) runs a loopback-only HTTP server; the Shortcuts
// "Get Contents of URL" action fetches http://localhost:8020/show and we reveal /
// dismiss the panel here. No companion app, no home-screen icon, no app switch.
static int g_vmListenFd = -1;
static int g_vmPort = 0;

static void VMStartURLServer(void){
    id pv = g_defaults ? [g_defaults objectForKey:kPrefHTTPPortKey] : nil;
    int port = 0;
    if([pv isKindOfClass:NSString.class]){
        port = [(NSString *)pv intValue];
    }
    else if([pv isKindOfClass:NSNumber.class]){
        port = [(NSNumber *)pv intValue];
    }
    if(port <= 0 || port > 65535){
        port = 8020;
    }
    if(port == g_vmPort && g_vmListenFd >= 0){
        return; // already serving on this port
    }
    if(g_vmListenFd >= 0){
        close(g_vmListenFd); // unblock the previous accept loop so its thread exits
        g_vmListenFd = -1;
    }
    int srv = socket(AF_INET, SOCK_STREAM, 0);
    if(srv < 0){
        return;
    }
    int yes = 1;
    setsockopt(srv, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK); // 127.0.0.1 only
    if(bind(srv, (struct sockaddr *)&addr, sizeof(addr)) < 0 || listen(srv, 16) < 0){
        close(srv);
        return;
    }
    g_vmListenFd = srv;
    g_vmPort = port;
    int mySrv = srv;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        for(;;){
            int c = accept(mySrv, NULL, NULL);
            if(c < 0){
                if(mySrv != g_vmListenFd){
                    break; // socket was replaced for a restart
                }
                usleep(20000);
                continue;
            }
            char buf[2048];
            ssize_t n = read(c, buf, sizeof(buf) - 1);
            NSString *action = @"toggle";
            if(n > 0){
                buf[n] = 0;
                NSString *req = [NSString stringWithUTF8String:buf];
                NSArray *lines = [req componentsSeparatedByString:@"\r\n"];
                if(lines.count){
                    NSArray *parts = [lines[0] componentsSeparatedByString:@" "];
                    if(parts.count >= 2){
                        NSString *path = [parts[1] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
                        if(path.length){
                            action = path.lowercaseString;
                        }
                    }
                }
            }
            NSString *act = [action copy];
            dispatch_async(dispatch_get_main_queue(), ^{
                showHUDWindowSB();
                if([act isEqualToString:@"show"]){
                    [hudWindow showWindow];
                }
                else if([act isEqualToString:@"hide"]){
                    [hudWindow hideWindow];
                }
                else{
                    [hudWindow changeVisibility];
                }
            });
            const char *resp = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK";
            ssize_t w = write(c, resp, strlen(resp));
            (void)w;
            close(c);
        }
    });
}

// The Shortcuts "Open URL" action runs inside the caller process. A custom
// scheme with no owning app is rejected by LaunchServices there, before it can
// ever reach SpringBoard, so we intercept UIApplication's openURL: entry points
// in every process the tweak loads and turn volumemixer:// into a Darwin notify
// that SpringBoard listens for.
@interface LSApplicationWorkspace : NSObject
- (BOOL)canOpenURL:(NSURL *)url;
- (BOOL)openURL:(NSURL *)url;
- (BOOL)openURL:(NSURL *)url options:(NSDictionary *)options withCompletionCallback:(void(^)(NSInteger, id, NSError *))callback;
- (BOOL)openURL:(NSURL *)url options:(NSDictionary *)options withCompletionCallback:(void(^)(NSInteger, id, NSError *))callback error:(id *)error;
@end
%group url
%hook UIApplication
- (BOOL)canOpenURL:(NSURL *)url{
    // Shortcuts' "Open URL" validates here first; without this the action errors
    // with "no app installed" before it can ever reach the open handlers below.
    if([url.scheme isEqualToString:@"volumemixer"]){
        return YES;
    }
    return %orig;
}
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
%hook LSApplicationWorkspace
- (BOOL)canOpenURL:(NSURL *)url{
    if([url.scheme isEqualToString:@"volumemixer"]){
        return YES;
    }
    return %orig;
}
- (BOOL)openURL:(NSURL *)url{
    if([url.scheme isEqualToString:@"volumemixer"]){
        VMPostSchemeNotify(url);
        return YES;
    }
    return %orig;
}
- (BOOL)openURL:(NSURL *)url options:(NSDictionary *)options withCompletionCallback:(void(^)(NSInteger, id, NSError *))callback{
    if([url.scheme isEqualToString:@"volumemixer"]){
        VMPostSchemeNotify(url);
        if(callback) callback(0, nil, nil);
        return YES;
    }
    return %orig;
}
- (BOOL)openURL:(NSURL *)url options:(NSDictionary *)options withCompletionCallback:(void(^)(NSInteger, id, NSError *))callback error:(id *)error{
    if([url.scheme isEqualToString:@"volumemixer"]){
        VMPostSchemeNotify(url);
        if(callback) callback(0, nil, nil);
        return YES;
    }
    return %orig;
}
%end //LSApplicationWorkspace
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

    // Loopback HTTP server so Shortcuts "Get Contents of URL" can reveal the
    // panel without a companion app (see VMStartURLServer).
    VMStartURLServer();
}
