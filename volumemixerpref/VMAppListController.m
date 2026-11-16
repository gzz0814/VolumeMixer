#import "VMAppListController.h"
#import <Preferences/PSSpecifier.h>
#import <objc/runtime.h>
#import <notify.h>
// Provides -[UIImage _applicationIconImageForBundleIdentifier:format:scale:],
// the same icon source the mixer panel uses, so the picker can show app icons.
#import <UIKit/UIImage+Private.h>

// Minimal declarations for the private LaunchServices classes we enumerate.
@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (NSArray *)allApplications;
- (NSArray *)deviceApplications;
@end

@interface LSApplicationProxy : NSObject
- (NSString *)bundleIdentifier;
- (NSString *)localizedName;
- (NSUInteger)applicationType;
- (NSURL *)bundleURL;
@end

// PSListController builds each row's cell through this method, but the
// Preferences header shipped with Theos omits the declaration, so add it here
// to let the override below call [super tableView:cellForRowAtIndexPath:specifier:].
@interface PSListController (VMAppIcons)
- (id)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath specifier:(PSSpecifier *)specifier;
@end

// Resolve an app icon inside the (sandboxed) Settings process. The UIKit icon
// cache API is tried first with a couple of formats; if it returns nothing we
// fall back to reading the icon PNG straight out of the app bundle.
static UIImage *VMAppIconImage(NSString *bundleID, id proxy){
    if(![bundleID length]){
        return nil;
    }
    CGFloat scale = [UIScreen mainScreen].scale;
    UIImage *img = nil;
    for(NSNumber *fmt in @[@(0), @(1), @(2)]){
        @try {
            img = [UIImage _applicationIconImageForBundleIdentifier:bundleID format:fmt.integerValue scale:scale];
        } @catch (__unused NSException *e) {}
        if(img){
            return img;
        }
    }
    NSURL *bundleURL = nil;
    @try {
        bundleURL = [proxy bundleURL];
    } @catch (__unused NSException *e) {}
    NSString *path = bundleURL.path;
    if(![path length]){
        return nil;
    }
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Info.plist"]];
    if(![info isKindOfClass:[NSDictionary class]]){
        return nil;
    }
    NSMutableArray *names = [NSMutableArray new];
    id icons = info[@"CFBundleIcons"];
    if([icons isKindOfClass:[NSDictionary class]]){
        id primary = ((NSDictionary *)icons)[@"CFBundlePrimaryIcon"];
        if([primary isKindOfClass:[NSDictionary class]]){
            id files = ((NSDictionary *)primary)[@"CFBundleIconFiles"];
            if([files isKindOfClass:[NSArray class]]){
                [names addObjectsFromArray:files];
            }
        }
    }
    id single = info[@"CFBundleIconFile"];
    if([single isKindOfClass:[NSString class]] && [single length]){
        [names addObject:single];
    }
    NSFileManager *fm = NSFileManager.defaultManager;
    for(NSString *base in [names reverseObjectEnumerator]){
        NSArray *candidates = @[[NSString stringWithFormat:@"%@@3x.png", base],
                                [NSString stringWithFormat:@"%@@2x.png", base],
                                [NSString stringWithFormat:@"%@.png", base]];
        for(NSString *fn in candidates){
            NSString *full = [path stringByAppendingPathComponent:fn];
            if([fm fileExistsAtPath:full]){
                img = [UIImage imageWithContentsOfFile:full];
                if(img){
                    return img;
                }
            }
        }
    }
    return nil;
}

@implementation VMAppListController {
    NSMutableArray *_selected;   // array of selected bundle identifiers
    NSArray *_apps;              // filtered + sorted LSApplicationProxy objects
    NSUserDefaults *_defaults;
    NSString *_targetKey;        // defaults key this picker writes (from the parent cell)
    NSString *_searchText;       // current search filter (nil == show all)
}

- (void)viewDidLoad {
    _defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.apple.UIKit"];

    // Reuse a single controller for every app picker cell by reading the target
    // defaults key off the specifier that opened us (falls back to the enabled
    // apps key when unavailable).
    _targetKey = kPrefAppsKey;
    @try {
        PSSpecifier *parent = [self valueForKey:@"specifier"];
        NSString *key = [parent propertyForKey:@"key"];
        if([key length]){
            _targetKey = key;
        }
    } @catch (__unused NSException *e) {}

    _selected = [_defaults arrayForKey:_targetKey] ? [[_defaults arrayForKey:_targetKey] mutableCopy] : [NSMutableArray new];

    Class LSClass = objc_getClass("LSApplicationWorkspace");
    id workspace = LSClass ? [LSClass defaultWorkspace] : nil;
    // deviceApplications returns the real installed apps and omits the hundreds
    // of system UI agents (ViewServices, dialogs, ...) that allApplications
    // dumps in; fall back to allApplications only if it is unavailable/empty.
    NSArray *all = nil;
    @try {
        if([workspace respondsToSelector:@selector(deviceApplications)]){
            all = [workspace deviceApplications];
        }
    } @catch (__unused NSException *e) {}
    if(![all count]){
        all = [workspace allApplications];
    }

    // Keep only real, home-screen apps. This drops the hundreds of system UI
    // agents (AAUIViewService, AirDropUI, Bark, CarPlaySplashScreen, ...).
    // NB: isDockable is only meaningful inside SpringBoard (reads NO for every
    // app from the preferences process), so filter by bundle location instead.
    // applicationType / bundleURL are read via KVC because that is the form that
    // reliably works from this process; a direct typed call can misread them and
    // silently empty the list.
    NSMutableArray *userApps = [NSMutableArray new];
    for(id proxy in all){
        @try {
            NSNumber *type = [proxy valueForKey:@"applicationType"];
            if(type && type.integerValue != 0){
                continue; // 0 == LSApplicationProxyTypeApplicationUser
            }
            NSString *bundleID = [proxy bundleIdentifier];
            NSString *name = [proxy respondsToSelector:@selector(localizedName)]
                ? [proxy localizedName] : [proxy valueForKey:@"localizedName"];
            if(![bundleID length] || ![name length]){
                continue;
            }
            // The user only wants third-party (App Store) and TrollStore apps.
            // Every Apple system app and UI agent has a com.apple.* identifier,
            // while user/TrollStore apps never do, so this cleanly drops them all.
            NSString *lower = bundleID.lowercaseString;
            if([lower hasPrefix:@"com.apple."] || [lower isEqualToString:@"com.brend0n.volumemixer.launcher"]){
                continue;
            }
            [userApps addObject:proxy];
        } @catch (__unused NSException *e) {
            continue;
        }
    }

    // Drop system agents/services by bundle path. Only adopt the filtered set if
    // it is non-empty, so the picker can never go blank when bundleURL is odd.
    NSMutableArray *filtered = [NSMutableArray new];
    for(id proxy in userApps){
        NSString *path = nil;
        @try {
            path = [proxy valueForKeyPath:@"bundleURL.path"];
        } @catch (__unused NSException *e) {}
        if([path hasPrefix:@"/System/Library/"] || [path containsString:@"/XPCServices/"]){
            continue;
        }
        [filtered addObject:proxy];
    }

    NSMutableArray *list = filtered.count ? filtered : userApps;

    [list sortUsingComparator:^NSComparisonResult(id a, id b){
        return [[a valueForKey:@"localizedName"] compare:[b valueForKey:@"localizedName"] options:NSCaseInsensitiveSearch];
    }];
    _apps = list;

    self.title = VMNSLocalizedString(@"CHOOSE_ENABLED_APP");

    [super viewDidLoad];

    [self vm_setupSearchBar];
}

- (void)vm_setupSearchBar {
    if(@available(iOS 11.0, *)){
        UISearchController *searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
        searchController.searchResultsUpdater = self;
        searchController.dimsBackgroundDuringPresentation = NO;
        self.navigationItem.searchController = searchController;
        self.definesPresentationContext = YES;
    }
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *text = searchController.searchBar.text;
    _searchText = [text length] ? text : nil;
    _specifiers = nil;
    [self reloadSpecifiers];
}

- (BOOL)matches:(LSApplicationProxy *)proxy {
    if(!_searchText){
        return YES;
    }
    NSString *name = [proxy localizedName] ?: @"";
    NSString *bundleID = [proxy bundleIdentifier] ?: @"";
    return [name rangeOfString:_searchText options:NSCaseInsensitiveSearch].location != NSNotFound
        || [bundleID rangeOfString:_searchText options:NSCaseInsensitiveSearch].location != NSNotFound;
}

- (NSArray *)specifiers {
    if(!_specifiers){
        NSMutableArray *specs = [NSMutableArray new];

        for(LSApplicationProxy *proxy in _apps){
            if(![self matches:proxy]){
                continue;
            }
            NSString *bundleID = [proxy bundleIdentifier];
            NSString *name = [proxy localizedName];

            PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:name
                                                               target:self
                                                                  set:@selector(setPreferenceValue:specifier:)
                                                                  get:@selector(readPreferenceValue:)
                                                               detail:nil
                                                                 cell:PSSwitchCell
                                                                  edit:nil];
            [spec setProperty:bundleID forKey:@"bundleID"];
            [spec setProperty:proxy forKey:@"proxy"];
            [specs addObject:spec];
        }

        _specifiers = specs;
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *bundleID = [specifier propertyForKey:@"bundleID"];
    return @([_selected containsObject:bundleID]);
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *bundleID = [specifier propertyForKey:@"bundleID"];
    if(![bundleID length]){
        return;
    }
    if([value boolValue]){
        if(![_selected containsObject:bundleID]){
            [_selected addObject:bundleID];
        }
    }
    else{
        [_selected removeObject:bundleID];
    }
    [_defaults setObject:_selected forKey:_targetKey];
    [_defaults synchronize];
    notify_post("com.brend0n.volumemixer/loadPref");
}

// Feature #1: show each app's icon next to its name. PSListController builds a
// PSSwitchCell per specifier, but that cell ignores its built-in imageView, so
// we add our own icon subview to the content view and indent the row content
// (indentationLevel/Width) to make room for it without overlapping the title.
- (id)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath specifier:(PSSpecifier *)specifier {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath specifier:specifier];
    [self vm_configureCell:cell specifier:specifier];
    return cell;
}

// Hedge: some PreferenceLoader builds populate rows through the plain table
// delegate method instead of the specifier variant, so cover that too. The icon
// view is tag-guarded, so running both paths never duplicates it.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    NSArray *specs = self.specifiers;
    if([cell isKindOfClass:[UITableViewCell class]] && indexPath.row < (NSInteger)specs.count){
        [self vm_configureCell:cell specifier:specs[indexPath.row]];
    }
    return cell;
}

- (void)vm_configureCell:(UITableViewCell *)cell specifier:(PSSpecifier *)specifier {
    NSString *bundleID = [specifier propertyForKey:@"bundleID"];
    id proxy = [specifier propertyForKey:@"proxy"];
    cell.indentationLevel = 1;
    cell.indentationWidth = 40.;

    static const NSInteger kIconTag = 47821;
    UIImageView *iconView = (UIImageView *)[cell.contentView viewWithTag:kIconTag];
    if(![iconView isKindOfClass:[UIImageView class]]){
        iconView = [[UIImageView alloc] initWithFrame:CGRectMake(12., 0., 29., 29.)];
        iconView.tag = kIconTag;
        iconView.contentMode = UIViewContentModeScaleAspectFit;
        iconView.layer.cornerRadius = 6.;
        iconView.layer.masksToBounds = YES;
        [cell.contentView addSubview:iconView];
    }
    CGFloat rowHeight = cell.contentView.bounds.size.height;
    iconView.frame = CGRectMake(12., (rowHeight - 29.) / 2., 29., 29.);
    iconView.image = VMAppIconImage(bundleID, proxy);
}

@end
