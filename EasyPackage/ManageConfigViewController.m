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
@property (nonatomic, strong) IBOutlet NSTextField *nameTextField;

@property (nonatomic, strong) NSMutableArray<ZyxPackageConfig *> *configs;

@end

@implementation ManageConfigViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    
    [self setupConfigs];
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
    self.nameTextField.stringValue = config.name;
    
    return config.name;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    ZyxPackageConfig *config = self.configs[row];
    config.name = object;
}

// 双击cell，判断是否可编辑
- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    [self.nameTextField becomeFirstResponder];
    return NO;
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
    [self.tableView deselectAll:sender];
    
    ZyxPackageConfig *config = [ZyxPackageConfig new];
    config.name = @"新配置";
    [self.configs addObject:config];
    
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:self.configs.count-1];
    [self.tableView beginUpdates];
    [self.tableView insertRowsAtIndexes:indexSet withAnimation:NSTableViewAnimationEffectFade];
    [self.tableView selectRowIndexes:indexSet byExtendingSelection:YES];
    [self.tableView endUpdates];
}

@end;
