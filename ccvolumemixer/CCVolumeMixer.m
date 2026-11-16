#import <objc/runtime.h>
#import <notify.h>
#import <SpringBoard/SBControlCenterController.h>
#import "CCVolumeMixer.h"
#import "../VMHUDWindow.h"

// Cross-process signal consumed by SpringBoard (see TweakSB.xm) to toggle the
// mixer panel. On iOS 14+ the Control Center toggle runs inside the separate
// ControlCenter process, where SpringBoard's VMHUDWindow / SBControlCenterController
// classes are not loaded, so a direct objc_getClass call is a silent no-op.
// Posting a notify reaches SpringBoard regardless of process.
#define kVMToggleNotification "com.brend0n.volumemixer/toggle"

@implementation CCVolumeMixer

// Resolve the preferences bundle that stores the module glyph, regardless of the
// jailbreak root. On rootless / roothide the baked-in kBundlePath prefix may not
// match the real install root, so derive the root from this bundle's own path:
//   <root>/Library/ControlCenter/Bundles/CCVolumeMixer.bundle
- (NSBundle *)vm_preferencesBundle {
    NSFileManager *fm = [NSFileManager new];
    if([fm fileExistsAtPath:kBundlePath]){
        return [NSBundle bundleWithPath:kBundlePath];
    }
    NSString *ownPath = [NSBundle bundleForClass:[self class]].bundlePath;
    NSString *marker = @"/Library/ControlCenter/Bundles/";
    NSRange range = [ownPath rangeOfString:marker];
    if(range.location != NSNotFound){
        NSString *root = [ownPath substringToIndex:range.location];
        NSString *prefs = [root stringByAppendingString:@"/Library/PreferenceBundles/volumemixer.bundle"];
        if([fm fileExistsAtPath:prefs]){
            return [NSBundle bundleWithPath:prefs];
        }
    }
    return nil;
}

//Return the icon of your module here
- (UIImage *)iconGlyph{
    NSBundle *prefs = [self vm_preferencesBundle];
    UIImage *icon = prefs ? [UIImage imageNamed:@"icon" inBundle:prefs compatibleWithTraitCollection:nil] : nil;
    if(!icon){
        // Last resort: fall back to the glyph shipped inside this CC bundle itself.
        icon = [UIImage imageNamed:@"SettingsIcon" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
    }
    return icon;
}

//Return the color selection color of your module here
- (UIColor *)selectedColor{
    return [UIColor blueColor];
}

- (BOOL)isSelected{
    return _selected;
}

- (void)setSelected:(BOOL)selected{
    _selected = selected;
    notify_post(kVMToggleNotification);
    Class ccController = objc_getClass("SBControlCenterController");
    if(ccController && [ccController respondsToSelector:@selector(sharedInstance)]){
        id instance = [ccController sharedInstance];
        if([instance respondsToSelector:@selector(dismissAnimated:completion:)]){
            [instance dismissAnimated:YES completion:nil];
        }
    }
}

@end
