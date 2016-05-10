//
//  ManageConfigViewController.m
//  EasyPackage
//
//  Created by zhouyong on 16/5/3.
//  Copyright © 2016年 zhouyong. All rights reserved.
//

#import "ManageConfigViewController.h"
#import "ZyxPackageConfig.h"

@interface ManageConfigViewController () <NSTabViewDelegate, NSTableViewDataSource>

@property (nonatomic, strong) IBOutlet NSTableView *tableView;
@property (nonatomic, strong) NSMutableArray<ZyxPackageConfig *> *configs;

@end

@implementation ManageConfigViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    
    [self setupConfigs];
    
    self.tableView.dataSource = self;
//    self.tableView.delegate = self;
    self.tableView.usesAlternatingRowBackgroundColors = YES;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.configs.count;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    return 20;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    ZyxPackageConfig *config = self.configs[row];
    return config.name;
}

#pragma mark - 

- (void)setupConfigs {
    self.configs = [NSMutableArray array];
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"configs" ofType:@"plist"];
    NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:path];
    NSArray *configs = plist[@"configs"];
    if (configs == nil) {
        return;
    }
    
    for (NSDictionary *dict in configs) {
        ZyxPackageConfig *config = [[ZyxPackageConfig alloc] initWithDict:dict];
        [self.configs addObject:config];
    }
}

- (IBAction)addConfigButtonPressed:(id)sender {
    
}

@end;
