//
//  UIImage+VMIcon.h
//

#import <UIKit/UIKit.h>

@interface UIImage (VMIcon)

/// Returns a copy of the receiver drawn into a fixed `side`x`side` point square
/// (square = points * scale pixels) and clipped to an iOS-style rounded rect.
/// Icons returned by the private icon service vary in size and padding per app;
/// normalizing them here guarantees every cell shows an identically sized icon.
- (UIImage *)vm_iconNormalizedToSide:(CGFloat)sidePoints
                           scale:(CGFloat)scale;

@end
