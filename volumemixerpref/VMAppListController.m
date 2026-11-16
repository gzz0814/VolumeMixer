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
// PSSwitchCell per specifier; we let it create the cell and then drop the icon
// into the cell's imageView, keyed off the bundleID stored on the specifier.
- (id)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath specifier:(PSSpecifier *)specifier {
    id cell = [super tableView:tableView cellForRowAtIndexPath:indexPath specifier:specifier];
    NSString *bundleID = [specifier propertyForKey:@"bundleID"];
    if([bundleID length] && [cell isKindOfClass:[UITableViewCell class]]){
        UIImage *icon = [UIImage _applicationIconImageForBundleIdentifier:bundleID format:0 scale:[UIScreen mainScreen].scale];
        ((UITableViewCell *)cell).imageView.image = icon;
        ((UITableViewCell *)cell).imageView.highlightedImage = nil;
    }
    return cell;
}

@end
