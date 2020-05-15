#import "RLCLocationPickerViewController.h"

static const double a = 6378245.0;
static const double ee = 0.00669342162296594323;
static const double pi = 3.14159265358979324;
static const double xPi = M_PI  * 3000.0 / 180.0;

@implementation RLCLocationPickerViewController

- (id)initForContentSize:(CGSize)size {
    self = [super init];

    if (self) {
        self.lpView = [[RLCLocationPickerView alloc] initWithFrame:CGRectMake(0,0,size.width,size.height) controller:self];
        if ([self respondsToSelector:@selector(setView:)])
            [self performSelectorOnMainThread:@selector(setView:) withObject:self.lpView waitUntilDone:YES];      

        self.saveButton = [[UIBarButtonItem alloc] initWithTitle:@"Save" style:UIBarButtonItemStylePlain target:self action:@selector(save:)];
        self.saveButton.tintColor = [UIColor blackColor];
        self.navigationItem.rightBarButtonItem = self.saveButton;

        self.searchResultsController = [[RLCLocationPickerSearchResultsViewController alloc] init];
        self.searchResultsController.parentController = self;

        self.searchController = [[UISearchController alloc] initWithSearchResultsController:self.searchResultsController];
        self.searchController.searchResultsUpdater = self.searchResultsController;
        self.searchController.obscuresBackgroundDuringPresentation = NO;
        self.searchController.hidesNavigationBarDuringPresentation = NO;

        self.searchController.searchBar.showsBookmarkButton = YES;
        self.searchController.searchBar.searchBarStyle = UISearchBarStyleMinimal;
        self.searchController.searchBar.delegate = self;

        self.navigationItem.searchController = self.searchController;
        self.navigationItem.hidesSearchBarWhenScrolling = NO;

        self.definesPresentationContext = YES;

        self.favorites = [NSMutableArray new];
        self.dictionary = [NSMutableDictionary new];

        HBPreferences *prefs = [[HBPreferences alloc] initWithIdentifier:@"me.nepeta.relocate"];
        id obj = [prefs objectForKey:@"Favorites"];
        if (obj && [obj isKindOfClass:[NSArray class]]) {
            self.favorites = [((NSArray *)obj) mutableCopy];
        }

        if ([prefs objectForKey:@"MapType"]) {
            switch ([[prefs objectForKey:@"MapType"] intValue]) {
                case 1:
                    self.lpView.mapView.mapType = MKMapTypeSatellite;
                    break;
                case 2:
                    self.lpView.mapView.mapType = MKMapTypeHybrid;
                    break;
                default:
                    self.lpView.mapView.mapType = MKMapTypeStandard;
            }
        }
    }

    return self;
}

- (void)searchBarBookmarkButtonClicked:(UISearchBar *)searchBar {
    [self.searchController setActive:YES];
    self.searchResultsController.allowDeletion = YES;
    self.searchResultsController.view.hidden = NO;
    self.searchResultsController.items = self.favorites;
    [self.searchResultsController.tableView reloadData];
}

- (id)view {
    return self.lpView;
}

- (void)viewWillAppear:(BOOL)animated {
    [self setTitle:[self navigationTitle]];
    [self.navigationItem setTitle:[self navigationTitle]];
    [self.navigationController.navigationBar setPrefersLargeTitles:NO];
    id value = [self readPreferenceValue:[self specifier]];
    if ([value isKindOfClass:[NSDictionary class]]) {
        self.dictionary = [(NSDictionary *)value mutableCopy];
        if (self.dictionary[@"Coordinate"]) {
            NSDictionary *coordinateDict = self.dictionary[@"Coordinate"];
            CLLocationCoordinate2D coordinate = [self transformFromWGSToGCJ:CLLocationCoordinate2DMake([coordinateDict[@"Latitude"] doubleValue], [coordinateDict[@"Longitude"] doubleValue])];
            self.lpView.coordinate = coordinate;
            [self.lpView createPinAt:coordinate];
        }
    }
}

-(void)viewDidAppear:(BOOL)animated{
    [self.lpView getSavedLocation];
}

- (NSString*)navigationTitle {
    return [[self specifier] name] ?: @"Pick location";
}

- (CLLocationCoordinate2D)transformFromWGSToGCJ:(CLLocationCoordinate2D)wgsLoc
{
    CLLocationCoordinate2D adjustLoc;
    double adjustLat = [self transformLatWithX:wgsLoc.longitude - 105.0 withY:wgsLoc.latitude - 35.0];
    double adjustLon = [self transformLonWithX:wgsLoc.longitude - 105.0 withY:wgsLoc.latitude - 35.0];
    long double radLat = wgsLoc.latitude / 180.0 * pi;
    long double magic = sin(radLat);
    magic = 1 - ee * magic * magic;
    long double sqrtMagic = sqrt(magic);
    adjustLat = (adjustLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi);
    adjustLon = (adjustLon * 180.0) / (a / sqrtMagic * cos(radLat) * pi);
    adjustLoc.latitude = wgsLoc.latitude + adjustLat;
    adjustLoc.longitude = wgsLoc.longitude + adjustLon;

    return adjustLoc;
}

- (double)transformLatWithX:(double)x withY:(double)y
{
    double lat = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(fabs(x));
    
    lat += (20.0 * sin(6.0 * x * pi) + 20.0 *sin(2.0 * x * pi)) * 2.0 / 3.0;
    lat += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0;
    lat += (160.0 * sin(y / 12.0 * pi) + 320 * sin(y * pi / 30.0)) * 2.0 / 3.0;
    return lat;
}

- (double)transformLonWithX:(double)x withY:(double)y
{
    double lon = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(fabs(x));
    lon += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
    lon += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0;
    lon += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0;
    return lon;
}

- (CLLocationCoordinate2D)transformFromGCJToBaidu:(CLLocationCoordinate2D)p
{
    long double z = sqrt(p.longitude * p.longitude + p.latitude * p.latitude) + 0.00002 * sin(p.latitude * xPi);
    long double theta = atan2(p.latitude, p.longitude) + 0.000003 * cos(p.longitude * xPi);
    CLLocationCoordinate2D geoPoint;
    geoPoint.latitude = (z * sin(theta) + 0.006);
    geoPoint.longitude = (z * cos(theta) + 0.0065);
    return geoPoint;
}

- (CLLocationCoordinate2D)transformFromBaiduToGCJ:(CLLocationCoordinate2D)p
{
    double x = p.longitude - 0.0065, y = p.latitude - 0.006;
    double z = sqrt(x * x + y * y) - 0.00002 * sin(y * xPi);
    double theta = atan2(y, x) - 0.000003 * cos(x * xPi);
    CLLocationCoordinate2D geoPoint;
    geoPoint.latitude  = z * sin(theta);
    geoPoint.longitude = z * cos(theta);
    return geoPoint;
}

- (CLLocationCoordinate2D)transformFromGCJToWGS:(CLLocationCoordinate2D)p
{
    double threshold = 0.00001;
    
    // The boundary
    double minLat = p.latitude - 0.5;
    double maxLat = p.latitude + 0.5;
    double minLng = p.longitude - 0.5;
    double maxLng = p.longitude + 0.5;
    
    double delta = 1;
    int maxIteration = 30;
    // Binary search
    while(true)
    {
        CLLocationCoordinate2D leftBottom  = [self transformFromWGSToGCJ:(CLLocationCoordinate2D){.latitude = minLat,.longitude = minLng}];
        CLLocationCoordinate2D rightBottom = [self transformFromWGSToGCJ:(CLLocationCoordinate2D){.latitude = minLat,.longitude = maxLng}];
        CLLocationCoordinate2D leftUp      = [self transformFromWGSToGCJ:(CLLocationCoordinate2D){.latitude = maxLat,.longitude = minLng}];
        CLLocationCoordinate2D midPoint    = [self transformFromWGSToGCJ:(CLLocationCoordinate2D){.latitude = ((minLat + maxLat) / 2),.longitude = ((minLng + maxLng) / 2)}];
        delta = fabs(midPoint.latitude - p.latitude) + fabs(midPoint.longitude - p.longitude);
        
        if(maxIteration-- <= 0 || delta <= threshold)
        {
            return (CLLocationCoordinate2D){.latitude = ((minLat + maxLat) / 2),.longitude = ((minLng + maxLng) / 2)};
        }
        
        if(isContains(p, leftBottom, midPoint))
        {
            maxLat = (minLat + maxLat) / 2;
            maxLng = (minLng + maxLng) / 2;
        }
        else if(isContains(p, rightBottom, midPoint))
        {
            maxLat = (minLat + maxLat) / 2;
            minLng = (minLng + maxLng) / 2;
        }
        else if(isContains(p, leftUp, midPoint))
        {
            minLat = (minLat + maxLat) / 2;
            maxLng = (minLng + maxLng) / 2;
        }
        else
        {
            minLat = (minLat + maxLat) / 2;
            minLng = (minLng + maxLng) / 2;
        }
    }
    
}

static bool isContains(CLLocationCoordinate2D point, CLLocationCoordinate2D p1, CLLocationCoordinate2D p2)
{
    return (point.latitude >= MIN(p1.latitude, p2.latitude) && point.latitude <= MAX(p1.latitude, p2.latitude)) && (point.longitude >= MIN(p1.longitude,p2.longitude) && point.longitude <= MAX(p1.longitude, p2.longitude));
}


- (void)save:(id)sender {
    [[UIApplication sharedApplication].keyWindow endEditing:YES];
    if (self.lpView.pin) {
        CLLocationCoordinate2D coordinate = [self transformFromGCJToWGS:CLLocationCoordinate2DMake(self.lpView.pin.coordinate.latitude, self.lpView.pin.coordinate.longitude)];
        self.dictionary[@"Coordinate"] = @{
            @"Latitude": @(coordinate.latitude),
            @"Longitude": @(coordinate.longitude)
        };
        [self setPreferenceValue:self.dictionary specifier:[self specifier]];
    }

    if ([[self specifier] propertyForKey:@"key"] && [[[self specifier] propertyForKey:@"key"] isEqualToString:@"GlobalLocation"]) {
        HBPreferences *prefs = [[HBPreferences alloc] initWithIdentifier:@"me.nepeta.relocate"];
        [prefs removeObjectForKey:@"SelectedFavorite"];
    }
    
    [self.navigationController popViewControllerAnimated:TRUE];
}

-(void)updateSavedFavorites {
    HBPreferences *prefs = [[HBPreferences alloc] initWithIdentifier:@"me.nepeta.relocate"];
    [prefs setObject:self.favorites forKey:@"Favorites"];
}

-(void)favorite:(id)sender {
    [self.lpView hideCallouts];

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Add to favorites"
        message:@"Enter name"
        preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action){
            NSString *name = [(UITextField *)alert.textFields[0] text];
        CLLocationCoordinate2D coordinate = [self transformFromGCJToWGS:CLLocationCoordinate2DMake(self.lpView.pin.coordinate.latitude, self.lpView.pin.coordinate.longitude)];
            NSDictionary *favorite = @{
                @"Name": name,
                @"Latitude": @(coordinate.latitude),
                @"Longitude": @(coordinate.longitude)
            };

            [self.favorites addObject:favorite];
            [self updateSavedFavorites];

            UIAlertController* savedAlert = [UIAlertController alertControllerWithTitle:@"Favorites"
                                        message:@"Saved!"
                                        preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
            handler:^(UIAlertAction * action) {}];
            [savedAlert addAction:defaultAction];
            [self presentViewController:savedAlert animated:YES completion:nil];

            [alert dismissViewControllerAnimated:YES completion:nil];
        }
    ];
    
    UIAlertAction* cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action) {
            [alert dismissViewControllerAnimated:YES completion:nil];
        }
    ];

    [alert addAction:ok];
    [alert addAction:cancel];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Name";
        textField.keyboardType = UIKeyboardTypeDefault;
    }];

    [self presentViewController:alert animated:YES completion:nil];
}

@end
