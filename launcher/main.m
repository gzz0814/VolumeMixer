// VolumeMixerLauncher — a tiny LSUIElement companion app whose only job is to
// own the "volumemixer://" URL scheme so the Shortcuts "Open URL" action can
// resolve it (there is otherwise no host app, which is why the action errored
// with "not installed"). When iOS opens a URL here we translate it into the
// same Darwin notification that SpringBoard already listens for, so the mixer
// panel shows/hides/toggles, and then we exit immediately: the launcher has no
// UI and must not linger in the foreground, so the panel appears over whatever
// app the user was already using (exactly like pressing the volume buttons).
#import <UIKit/UIKit.h>
#import <notify.h>

static BOOL sDidPost = NO;

static NSString *VMActionFromURL(NSURL *url){
    NSString *action = url.host.lowercaseString;
    if(![action length]){
        // Accept "volumemixer:///show" style too.
        action = [[url.path stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]] lowercaseString];
    }
    if([action isEqualToString:@"show"]){
        return @"com.brend0n.volumemixer/show";
    }
    if([action isEqualToString:@"hide"]){
        return @"com.brend0n.volumemixer/hide";
    }
    return @"com.brend0n.volumemixer/toggle";
}

static void VMPostOnce(NSURL *url){
    if(sDidPost){
        return;
    }
    sDidPost = YES;
    notify_post(VMActionFromURL(url).UTF8String);
}

@interface AppDelegate : NSObject <UIApplicationDelegate>
@end

@implementation AppDelegate

- (void)vm_exitSoon {
    // Give SpringBoard a moment to receive the notification, then quit so the
    // launcher never stays in the foreground.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        exit(0);
    });
}

// Cold launch via URL (the normal case, since we always quit after handling):
// the URL arrives in launchOptions. On some iOS versions the openURL: delegate
// method is not called, so this is the reliable place to post.
- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    VMPostOnce(launchOptions[UIApplicationLaunchOptionsURLKey]);
    [self vm_exitSoon];
    return YES;
}

// Warm launch (app already running) — guarded by sDidPost so we never double
// fire (a double "toggle" would cancel itself out).
- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    VMPostOnce(url);
    [self vm_exitSoon];
    return YES;
}

@end

int main(int argc, char *argv[]){
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
