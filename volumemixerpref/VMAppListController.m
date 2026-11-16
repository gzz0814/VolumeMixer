#import "VMAppListController.h"
#import <Preferences/PSSpecifier.h>
#import <objc/runtime.h>
#import <notify.h>

// Minimal declarations for the private LaunchServices classes we enumerate.
@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (NSArray *)allApplications;
@end

@interface LSApplicationProxy : NSObject
- (NSString *)bundleIdentifier;
- (NSString *)localizedName;
- (NSUInteger)applicationType;
- (BOOL)isDockable;
- (BOOL)hidden;
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
    NSArray *all = workspace ? [workspace allApplications] : nil;

    // Keep only real, home-screen apps. This drops the hundreds of system UI
    // agents (AAUIViewService, AirDropUI, Bark, CarPlaySplashScreen, ...) that
    // would otherwise bury the apps the user actually wants.
    NSMutableArray *list = [NSMutableArray new];
    for(LSApplicationProxy *proxy in all){
        NSString *bundleID = nil;
        NSString *name = nil;
        @try {
            if([proxy respondsToSelector:@selector(applicationType)] && [proxy applicationType] != 0){
                continue; // 0 == LSApplicationProxyTypeApplicationUser
            }
            if([proxy respondsToSelector:@selector(isDockable)] && ![proxy isDockable]){
                continue;
            }
            if([proxy respondsToSelector:@selector(hidden)] && [proxy hidden]){
                continue;
            }
            bundleID = [proxy bundleIdentifier];
            name = [proxy respondsToSelector:@selector(localizedName)] ? [proxy localizedName] : nil;
        } @catch (__unused NSException *e) {
            continue;
        }
        if(![bundleID length] || ![name length]){
            continue;
        }
        [list addObject:proxy];
    }

    [list sortUsingComparator:^NSComparisonResult(LSApplicationProxy *a, LSApplicationProxy *b){
        return [[a localizedName] compare:[b localizedName] options:NSCaseInsensitiveSearch];
    }];
    _apps = list;

    self.title = VMNSLocalizedString(@"CHOOSE_ENABLED_APP");

    [super viewDidLoad];

    [self vm_setupSearchBar];
}

- (void)vm_setupSearchBar {
    if(!objc_getClass("UISearchController")){
        return;
    }
    UISearchController *searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    searchController.searchResultsUpdater = self;
    searchController.dimsBackgroundDuringPresentation = NO;
    searchController.hidesSearchBarWhenScrolling = NO;
    self.navigationItem.searchController = searchController;
    self.definesPresentationContext = YES;
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

@end
