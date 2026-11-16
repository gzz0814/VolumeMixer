#import <Preferences/PSListController.h>

// A self-contained application picker that replaces the external AltList
// dependency. AltList ships as a separate PreferenceBundle, and on roothide a
// rootful AltList build installs to the real /Library where PreferenceLoader
// never looks, so ATLApplicationListMultiSelectionController is missing and the
// picker opens blank. This controller lives inside our own (already-loaded)
// prefs bundle and enumerates apps directly through LSApplicationWorkspace, so
// it always works. It writes the same array-of-bundle-IDs value that the tweak
// reads from kPrefAppsKey.
@interface VMAppListController : PSListController <UISearchResultsUpdating>
@end
