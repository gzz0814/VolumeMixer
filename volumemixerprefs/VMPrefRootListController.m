//
//  VMPrefRootListController.m
//

#import <Preferences/PSListController.h>
#import <Preferences/PSViewController.h>

@interface VMPrefRootListController : PSListController
@end

@implementation VMPrefRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

@end
