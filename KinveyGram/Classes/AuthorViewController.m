//
//  AuthorViewController.m
//  KinveyGram
//
//  Copyright (c) 2012 Kinvey. All rights reserved.
//

#import "AuthorViewController.h"

#import "KinveyFriendsUpdate.h"
#import "GravatarStore.h"
#import "UpdateCell.h"

#import <MapKit/MapKit.h>

#define kAuthor @"_acl.creator"

@interface UpdateAnnotation : NSObject <MKAnnotation>
{
    CLLocationCoordinate2D _coordinate;
}

@end

@implementation UpdateAnnotation
- (id) initWithLoc:(NSArray*)loc
{
    self = [super init];
    if (self) {
        _coordinate = CLLocationCoordinate2DMake([[loc objectAtIndex:1] doubleValue], [[loc objectAtIndex:0] doubleValue]);

    }
    return self;
}

- (CLLocationCoordinate2D)coordinate;
{
    return _coordinate;
}
@end

@interface AuthorViewController () {
    @private
    NSArray* _lastFive;
    KCSCachedStore* _updateStore;
}
@property (nonatomic) KCSGroup* grouping;
@property (nonatomic) NSString* name;
@end

@implementation AuthorViewController
@synthesize author, image, grouping, name;
- (void) commonInit
{
    _lastFive = [NSArray array];
    
    KCSCollection* collection = [KCSCollection collectionFromString:@"Updates" ofClass:[KinveyFriendsUpdate class]];
    _updateStore = [KCSCachedStore storeWithOptions:[NSDictionary dictionaryWithObjectsAndKeys:collection, KCSStoreKeyResource, [NSNumber numberWithInt:KCSCachePolicyBoth], KCSStoreKeyCachePolicy, nil]];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self =[super initWithCoder:aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void) updateGravatar
{
    KCSCollection* users = [[KCSClient sharedClient].currentUser userCollection];    KCSCachedStore* userStore = [KCSCachedStore storeWithOptions:[NSDictionary dictionaryWithObjectsAndKeys:users, KCSStoreKeyResource, [NSNumber numberWithInt:KCSCachePolicyLocalFirst], KCSStoreKeyCachePolicy, nil]];
    [userStore loadObjectWithID:self.author withCompletionBlock:^(NSArray *objectsOrNil, NSError *errorOrNil) {
        if (objectsOrNil && objectsOrNil.count > 0) {
            KCSUser* user = [objectsOrNil objectAtIndex:0];
            self.name = user.username;
            self.title = user.username;
            
            NSUInteger size = [[self.view.window screen]  scale] * 48.;
            GravatarStore* store = [GravatarStore storeWithOptions:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:size], GravatarStoreOptionSizeKey, nil]];
            [store queryWithQuery:name withCompletionBlock:^(NSArray *objectsOrNil, NSError *errorOrNil) {
                UIImage* avImage = [objectsOrNil objectAtIndex:0];
                self.image = avImage;
            } withProgressBlock:nil];
        }
    } withProgressBlock:nil];
}

- (void) updateCount
{
    [_updateStore group:[NSArray arrayWithObject:kAuthor] reduce:[KCSReduceFunction COUNT] condition:[KCSQuery query] completionBlock:^(KCSGroup *valuesOrNil, NSError *errorOrNil) {
        if (valuesOrNil != nil) {
            self.grouping = valuesOrNil;
            [self.tableView reloadData];
        }
    } progressBlock:nil];
}

- (void) updateLastFive
{
    KCSQuery* lastFiveQuery = [KCSQuery queryOnField:kAuthor withExactMatchForValue:self.author];
    lastFiveQuery.limitModifer = [[KCSQueryLimitModifier alloc] initWithLimit:5];
    KCSQuerySortModifier* sortByDate = [[KCSQuerySortModifier alloc] initWithField:@"userDate" inDirection:kKCSDescending];
    [lastFiveQuery addSortModifier:sortByDate];

    [_updateStore queryWithQuery:lastFiveQuery withCompletionBlock:^(NSArray *objectsOrNil, NSError *errorOrNil) {
        if (errorOrNil == nil) {
            _lastFive = objectsOrNil;
            [self.tableView reloadData];
        }
    } withProgressBlock:nil];
  
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.navigationController setNavigationBarHidden:NO];
    
    [self updateGravatar];
    [self updateCount];
    [self updateLastFive];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    return 48. + 16.;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    switch (section) {
        case 0:
            return 3;
            break;
        case 1:
            return _lastFive.count;
        default:
            break;
    }
    return 0;
}

- (UITableViewCell*) sec0cell:(NSUInteger)row
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    // Configure the cell...
    if (row == 0) {
        cell.textLabel.text = self.name == nil ? self.author : self.name;
        cell.imageView.image = self.image;
        
    } else if (row == 1) {
        //N Updates Row
        id updateCount = [grouping reducedValueForFields:[NSDictionary dictionaryWithObjectsAndKeys:self.author, kAuthor, nil]];
        updateCount = (updateCount == nil || [updateCount isEqual:[NSNull null]] || [updateCount intValue] == NSNotFound) ? NSLocalizedString(@"??", @"'Number' for unkown number of updates") : updateCount;
        cell.textLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%@ Updates", @"number of updates label for an author"), updateCount];
    } else if (row == 2) {
        //Location Row
        NSArray* lastLoc = nil;
        for (KinveyFriendsUpdate* update in _lastFive) {
            if (update.location && update.location.count > 0) {
                lastLoc = update.location;
                break;
            }
        }
        if (lastLoc) {
            cell.textLabel.text = [NSString stringWithFormat:@"Last location:"];
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", lastLoc];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            cell.textLabel.text = @"No Recent Location";
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    
    return cell;
}

- (UITableViewCell*) sec1cell:(NSUInteger)row
{
    static NSString *CellIdentifier = @"UpdateCell";
    UpdateCell *cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UpdateCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    KinveyFriendsUpdate* update = [_lastFive objectAtIndex:row];
    [cell setUpdate:update];

    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        return [self sec0cell:indexPath.row];
    } else {
        return [self sec1cell:indexPath.row];
    }
   
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 1) {
        return NSLocalizedString(@"Last Five Updates", @"Last five title");
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0 & indexPath.row == 2) {
        //selected the location row
        MKMapView* mapView = [[MKMapView alloc] init];
        mapView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        UIViewController* vc = [[UIViewController alloc] init];
        vc.view = mapView;
        NSArray* lastLoc = nil;
        for (KinveyFriendsUpdate* update in _lastFive) {
            if (update.location && update.location.count > 0) {
                lastLoc = update.location;
                break;
            }
        }
        UpdateAnnotation* an = [[UpdateAnnotation alloc] initWithLoc:lastLoc];
        [mapView addAnnotation:an];
        [self.navigationController pushViewController:vc animated:YES];
        [mapView setCenterCoordinate:an.coordinate];
        [mapView setRegion:MKCoordinateRegionMake(an.coordinate, MKCoordinateSpanMake(2, 2))];

    }
}
@end
