#import "RLCWIFISetting.h"
#define BUNDLE_ID @"me.nepeta.relocate"
#define SSID @"SSID"
#define BSSID @"BSSID"

@implementation RLCWIFISetting

- (id)initForContentSize:(CGSize)size {
    self = [super init];

    if (self) {
        self.wifiList = [NSMutableArray new];

        _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height) style:UITableViewStyleGrouped];
        [_tableView setEstimatedSectionHeaderHeight:0];
        [_tableView setEstimatedSectionFooterHeight:0];
        [_tableView setDataSource:self];
        [_tableView setDelegate:self];
        [_tableView setEditing:NO];
        if ([self respondsToSelector:@selector(setView:)]) {
            [self performSelectorOnMainThread:@selector(setView:) withObject:_tableView waitUntilDone:YES]; 
        }
        self.saveButton = [[UIBarButtonItem alloc] initWithTitle:@"Save" style:UIBarButtonItemStylePlain target:self action:@selector(save:)];
        self.saveButton.tintColor = [UIColor blackColor];
        self.navigationItem.rightBarButtonItem = self.saveButton;
    }
    return self;
}

- (id)view {
    return _tableView;
}

- (void)loadFromSpecifier:(PSSpecifier *)specifier {
    NSString *title = [specifier name];
    [self setTitle:title];
    [self.navigationItem setTitle:title];
}

- (void)setSpecifier:(PSSpecifier *)specifier {
    [self loadFromSpecifier:specifier];
    [super setSpecifier:specifier];
}

- (void)refreshList {
    HBPreferences *prefs = [[HBPreferences alloc] initWithIdentifier:BUNDLE_ID];
    // [prefs removeObjectForKey:@"WIFIList"];
    id obj = [prefs objectForKey:SSID];
    id objBssid = [prefs objectForKey:BSSID];

    _inputSSID = obj;
    _inputBSSID = objBssid;

    NSMutableDictionary *ssid = [NSMutableDictionary new];
    [ssid setObject:obj ? obj : @"" forKey:SSID];
    [ssid setObject:objBssid ? objBssid : @"" forKey:BSSID];
    [self.wifiList addObject:ssid];

    id list = [prefs objectForKey:@"WIFIList"];
    if (list && [list isKindOfClass:[NSArray class]]) {
        [self.wifiList addObjectsFromArray:list];
    }
    [_tableView reloadData];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)@"me.nepeta.relocate/ReloadPrefs", nil, nil, true);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    [self refreshList];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return self.wifiList.count;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section ? 1 : 2;
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SettingsCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"SettingsCell"];
    }
    NSDictionary *dict = self.wifiList[indexPath.section];
    if (!indexPath.section) {
        switch (indexPath.row) {
            case 0: {
                cell.textLabel.text = @"SSID";
                cell.detailTextLabel.text = dict[SSID];
            } 
            break;
            case 1: {
                cell.textLabel.text = @"MAC Address";
                cell.detailTextLabel.text = dict[BSSID];
            }
            break;
        }
    } else {
        cell.textLabel.text = dict[SSID];
        cell.detailTextLabel.text = dict[BSSID];
    }
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 1 ? @"histroy" : @"";
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (!indexPath.section) {
        if (!indexPath.row) {
            [self addtextField:@"Please input SSID" IndexPath:indexPath];
        } else {
            [self addtextField:@"Please input MAC Address" IndexPath:indexPath];
        }
    } else {
        NSDictionary *dict = self.wifiList[indexPath.section];
        HBPreferences *prefs = [[HBPreferences alloc] initWithIdentifier:BUNDLE_ID];
        [prefs setObject:dict[SSID] forKey:SSID];
        [prefs setObject:dict[BSSID] forKey:BSSID];
        [self.wifiList removeAllObjects];
        [self refreshList];
    }
    
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section <= 1) {
        return 30;
    }
    return 0.00000001;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section < 1) {
        return 30;
    }
    return 0.00000001;
}

- (void)addtextField:(NSString *)placeholder IndexPath:(NSIndexPath *)indexPath {
    UIAlertController *alertVc = [UIAlertController alertControllerWithTitle:@"Please Input" message:@"" preferredStyle:UIAlertControllerStyleAlert];
    [alertVc addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = placeholder;
        if (!indexPath.row) {
            textField.text = _inputSSID;
        } else {
            textField.text = _inputBSSID;
        }
        [textField addTarget:self action:@selector(watchTextFieldMethod:) forControlEvents:UIControlEventEditingChanged];
    }];
    
    //添加确定和取消按钮
    UIAlertAction *cacleAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        
    }];

    UIAlertAction *sureAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        HBPreferences *prefs = [[HBPreferences alloc] initWithIdentifier:BUNDLE_ID];
        if (!indexPath.row) {
            _inputSSID = _string;
            [prefs setObject:_string forKey:SSID];
        } else {
            _inputBSSID = _string;
            [prefs setObject:_inputBSSID forKey:BSSID];
        }
        [self.wifiList removeAllObjects];
        [self refreshList];
    }];
    [alertVc addAction:cacleAction];
    [alertVc addAction:sureAction];
    
    [self presentViewController:alertVc animated:YES completion:nil];
}

- (void)save:(id)sender {
    HBPreferences *prefs = [[HBPreferences alloc] initWithIdentifier:BUNDLE_ID];
    if ([_inputSSID length] && [_inputBSSID length]) {
        [prefs setObject:_inputSSID forKey:SSID];
        [prefs setObject:_inputBSSID forKey:BSSID];
        NSMutableArray *row = [NSMutableArray new];
        NSMutableDictionary *ssid = [NSMutableDictionary new];
        [ssid setObject:_inputSSID forKey:SSID];
        [ssid setObject:_inputBSSID forKey:BSSID];

        id list = [prefs objectForKey:@"WIFIList"];
        if (list && [list isKindOfClass:[NSArray class]]) {
            [row addObjectsFromArray:list];
        }
        if (![row containsObject:ssid]) {
            [row addObject:ssid];
        }
        [prefs setObject:row forKey:@"WIFIList"];
        [self.wifiList removeAllObjects];
        [self refreshList];
    }
}

- (void)watchTextFieldMethod:(UITextField *)textField {
    _string = textField.text;
}

@end
