//
//  UIImage+VMIcon.m
//

#import "UIImage+VMIcon.h"
#import "VolumeMixer.h"

@implementation UIImage (VMIcon)

- (UIImage *)vm_iconNormalizedToSide:(CGFloat)sidePoints
                           scale:(CGFloat)scale {
    if (scale <= 0) {
        scale = [UIScreen mainScreen].scale;
    }

    CGSize pixelSize = CGSizeMake(sidePoints * scale, sidePoints * scale);

    UIGraphicsBeginImageContextWithOptions(pixelSize, NO, scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    // Clip to the iOS super-ellipse approximated by a rounded rect. Using a
    // mask keeps oversized / padded icons visually identical across apps.
    CGFloat radius = sidePoints * scale * kVMIconCornerRatio;
    UIBezierPath *rounded = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, pixelSize.width, pixelSize.height)
                                                       cornerRadius:radius];
    CGContextAddPath(ctx, rounded.CGPath);
    CGContextClip(ctx);

    // Scale the source to fill the square (aspect fill, centered). This removes
    // the differing internal transparent padding some app icons ship with.
    CGSize src = self.size;
    if (src.width <= 0 || src.height <= 0) {
        UIGraphicsEndImageContext();
        return self;
    }

    CGFloat factor = MAX(pixelSize.width / src.width, pixelSize.height / src.height);
    CGSize drawn = CGSizeMake(src.width * factor, src.height * factor);
    CGRect target = CGRectMake((pixelSize.width - drawn.width) / 2.0,
                               (pixelSize.height - drawn.height) / 2.0,
                               drawn.width, drawn.height);
    [self drawInRect:target];

    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result ?: self;
}

@end
