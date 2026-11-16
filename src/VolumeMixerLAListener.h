//
//  VolumeMixerLAListener.h
//  Activator listeners: "Show Volume Mixer", "Volume Up", "Volume Down".
//  These are the pre-existing invocation paths; the new URL scheme in Tweak.x
//  funnels through the same VolumeControl show/toggle API.
//

#import <Foundation/Foundation.h>

@interface VolumeMixerLAListener : NSObject
+ (void)registerListeners;
@end
