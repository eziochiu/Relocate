
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <CepheiPrefs/HBListController.h>
#import <CepheiPrefs/HBAppearanceSettings.h>
#import <Cephei/HBPreferences.h>

@interface RLCWIFISetting : PSViewController <UITableViewDelegate,UITableViewDataSource> {
    UITableView *_tableView;
    NSString *_string;
    NSString *_inputSSID;
    NSString *_inputBSSID;
}
@property (nonatomic, retain) NSMutableArray *wifiList;
@property (nonatomic, retain) UIBarButtonItem *saveButton;
- (void)refreshList;
@end