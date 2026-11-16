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

// Reset / migrate buttons observed in the original bundle.
- (void)showConfirmAlert:(id)sender {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:nil
                          message:nil
                   preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)performActionsForSpecifier:(id)specifier {
    // Placeholder for the "MIGRATE_SETTINGS" / "RESET_SETTINGS" actions.
    [super performActionsForSpecifier:specifier];
}

@end
