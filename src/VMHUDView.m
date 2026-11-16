//
//  VMHUDView.m
//

#import "VMHUDView.h"

@implementation VMHUDView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _iconView = [[UIImageView alloc] init];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.clipsToBounds = YES;
        [self addSubview:_iconView];

        _nameLabel = [[UILabel alloc] init];
        _nameLabel.font = [UIFont systemFontOfSize:12];
        _nameLabel.textColor = [UIColor secondaryLabelColor];
        [self addSubview:_nameLabel];

        _slider = [[UISlider alloc] init];
        _slider.minimumValue = 0.0;
        _slider.maximumValue = 1.0;
        [self addSubview:_slider];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    CGFloat iconSide = MIN(h, 44.0);

    self.iconView.frame = CGRectMake(0, (h - iconSide) / 2.0, iconSide, iconSide);
    CGFloat labelH = 14.0;
    self.nameLabel.frame = CGRectMake(iconSide + 10, h / 2.0 - labelH, w - iconSide - 20, labelH);
    self.slider.frame = CGRectMake(iconSide + 10, h / 2.0, w - iconSide - 20, labelH + 4);
}

- (void)setValue:(float)value animated:(BOOL)animated {
    _volume = value;
    [self.slider setValue:value animated:animated];
}

@end
