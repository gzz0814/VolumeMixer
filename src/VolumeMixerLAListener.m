//
//  VolumeMixerLAListener.m
//

#import "VolumeMixerLAListener.h"
#import "VolumeControl.h"
#import "VolumeMixer.h"
#import <objc/runtime.h>
#import <objc/message.h>

// LAActivator is an optional dependency; we register dynamically so the tweak
// still loads on devices without Activator installed.
@protocol LAEvent <NSObject>
- (void)handle;
@end

@interface VolumeMixerShowListener : NSObject
@end

@implementation VolumeMixerShowListener
- (NSString *)localizedTitle { return @"Show Volume Mixer"; }
- (NSString *)localizedDescription { return @"Show the per-app volume panel"; }
- (void)receiveEvent:(id<LAEvent>)event {
    [[VolumeControl sharedInstance] togglePanel];
    [event handle];
}
@end

static VolumeMixerShowListener *gShowListener;

@implementation VolumeMixerLAListener

+ (void)registerListeners {
    Class activator = NSClassFromString(@"LAActivator");
    if (!activator) return;

    id shared = [activator performSelector:@selector(sharedActivator)];
    if (!shared) return;

    if (!gShowListener) {
        gShowListener = [[VolumeMixerShowListener alloc] init];
    }

    // Register the "show" listener under its historical name.
    SEL reg = NSSelectorFromString(@"registerListener:names:");
    if ([shared respondsToSelector:reg]) {
        NSArray *names = @[ @"com.brend0n.volumemixer.show" ];
        ((void (*)(id, SEL, id, id))objc_msgSend)(shared, reg, gShowListener, names);
    }
}

@end
