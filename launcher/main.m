// VolumeMixerLauncher — a tiny LSUIElement companion app whose only job is to
// own the "volumemixer://" URL scheme so the Shortcuts "Open URL" action can
// resolve it (there is otherwise no host app, which is why the action errored
// with "not installed"). When iOS opens a URL here we translate it into the
// same Darwin notification that SpringBoard already listens for, so the mixer
// panel shows/hides/toggles without needing the tweak to be injected into the
// caller process.
#import <UIKit/UIKit.h>
#import <notify.h>

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

@interface AppDelegate : NSObject <UIApplicationDelegate>
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    notify_post(VMActionFromURL(url).UTF8String);
    return YES;
}

// Launched directly (e.g. Shortcuts "Open App") with no URL: toggle the panel.
- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    if(!launchOptions[UIApplicationLaunchOptionsURLKey]){
        notify_post("com.brend0n.volumemixer/toggle");
    }
    return YES;
}

@end

int main(int argc, char *argv[]){
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
