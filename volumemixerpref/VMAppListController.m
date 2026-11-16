#import "VMAppListController.h"
#import <objc/runtime.h>
#import <notify.h>

// Minimal declarations for the private LaunchServices classes we enumerate.
@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (NSArray *)allApplications;
@end

@implementation VMAppListController {
    NSMutableArray *_selected;   // array of selected bundle identifiers
    NSArray *_apps;              // filtered + sorted LSApplicationProxy objects
    NSUserDefaults *_defaults;
    NSString *_targetKey;        // defaults key this picker writes (from the parent cell)
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

    NSMutableArray *list = [NSMutableArray new];
    for(id proxy in all){
        NSString *bundleID = nil;
        NSString *name = nil;
        @try {
            bundleID = [proxy valueForKey:@"bundleIdentifier"];
            name = [proxy valueForKey:@"localizedName"];
            NSNumber *type = [proxy valueForKey:@"applicationType"];
            // 0 == LSApplicationProxyTypeApplicationUser: only show normal user apps.
            if(type && type.integerValue != 0){
                continue;
            }
        } @catch (__unused NSException *e) {
            continue;
        }
        if(![bundleID length] || ![name length]){
            continue;
        }
        [list addObject:proxy];
    }

    [list sortUsingComparator:^NSComparisonResult(id a, id b){
        NSString *na = [a valueForKey:@"localizedName"] ?: @"";
        NSString *nb = [b valueForKey:@"localizedName"] ?: @"";
        return [na compare:nb options:NSCaseInsensitiveSearch];
    }];
    _apps = list;

    self.title = VMNSLocalizedString(@"CHOOSE_ENABLED_APP");

    [super viewDidLoad];
    [self reloadData];
}

- (NSArray *)specifiers {
    if(!_specifiers){
        NSMutableArray *specs = [NSMutableArray new];

        for(id proxy in _apps){
            NSString *bundleID = [proxy valueForKey:@"bundleIdentifier"];
            NSString *name = [proxy valueForKey:@"localizedName"];

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
