//
//  VMHUDRootViewController.m
//

#import "VMHUDRootViewController.h"
#import "VMHUDView.h"
#import "UIImage+VMIcon.h"
#import "VolumeControl.h"
#import "VolumeMixer.h"
#import <objc/message.h>

// Private LSApplicationWorkspace icon accessor observed in the original binary:
//   -_applicationIconImageForBundleIdentifier:format:scale:
@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (NSArray<NSString *> *)allRunningApplications;
- (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bid
                                               format:(NSInteger)format
                                                scale:(CGFloat)scale;
@end

static NSString *const kVMCellID = @"hudCell";

@interface VMHUDCell : UICollectionViewCell
@property (nonatomic, strong) VMHUDView *row;
@end

@implementation VMHUDCell
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _row = [[VMHUDView alloc] initWithFrame:self.contentView.bounds];
        _row.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.contentView addSubview:_row];
    }
    return self;
}
@end

@interface VMHUDRootViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, copy) NSArray<NSString *> *runningBundleIDs;
@end

@implementation VMHUDRootViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    UIVisualEffectView *blur = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial]];
    blur.frame = self.view.bounds;
    blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:blur];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    layout.minimumLineSpacing = 8;
    layout.sectionInset = UIEdgeInsetsMake(12, 12, 12, 12);

    self.collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds
                                             collectionViewLayout:layout];
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    [self.collectionView registerClass:[VMHUDCell class] forCellWithReuseIdentifier:kVMCellID];
    [blur.contentView addSubview:self.collectionView];
}

- (void)reloadRunningApp {
    LSApplicationWorkspace *ws = [LSApplicationWorkspace defaultWorkspace];
    self.runningBundleIDs = [ws allRunningApplications] ?: @[];
    [self.collectionView reloadData];
}

#pragma mark - Data source

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
    return self.runningBundleIDs.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    VMHUDCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kVMCellID
                                                                forIndexPath:indexPath];
    NSString *bid = self.runningBundleIDs[indexPath.item];
    cell.row.bundleID = bid;

    // ---- Feature #1: normalized, fixed-size, rounded icon ----------------
    // The private icon service returns icons at inconsistent pixel sizes and
    // internal padding depending on the app, which is what made some icons look
    // too big / misaligned. We request at the screen scale then force every icon
    // into the same square with the iOS corner mask.
    CGFloat scale = [UIScreen mainScreen].scale;
    CGFloat side = [VolumeControl sharedInstance].iconSide;
    UIImage *raw = [[LSApplicationWorkspace defaultWorkspace]
        _applicationIconImageForBundleIdentifier:bid format:0 scale:scale];
    UIImage *icon = [raw vm_iconNormalizedToSide:side scale:scale];
    cell.row.iconView.image = icon;

    cell.row.nameLabel.text = bid;
    return cell;
}

#pragma mark - Layout

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    // Icon side is fixed (kVMIconSidePoints); row height gives it room. This is
    // what caps every icon to the same on-screen footprint.
    CGFloat width = collectionView.bounds.size.width - 24;
    return CGSizeMake(width, [VolumeControl sharedInstance].iconSide + 20);
}

@end
