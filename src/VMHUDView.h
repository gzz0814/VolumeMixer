//
//  VMHUDView.h
//

#import <UIKit/UIKit.h>

@interface VMHUDView : UIView
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UISlider *slider;
@property (nonatomic, strong) UILabel *nameLabel;
/// 0.0 - 1.0 relative to the app's current volume.
@property (nonatomic, assign) float volume;
- (void)setValue:(float)value animated:(BOOL)animated;
@end
