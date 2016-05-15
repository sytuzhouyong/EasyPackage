//
//  ManageConfigViewController.m
//  EasyPackage
//
//  Created by zhouyong on 16/5/3.
//  Copyright © 2016年 zhouyong. All rights reserved.
//

#import "ManageConfigViewController.h"
#import "ZyxPackageConfig.h"
#import "Util.h"

@interface ManageConfigViewController () <NSTabViewDelegate, NSTableViewDataSource>

@property (nonatomic, strong) NSMutableArray<ZyxPackageConfig *> *configs;
@property (nonatomic, assign) NSInteger selectedIndex;
@property (nonatomic, copy) NSString *configsFilePath;

@end

@implementation ManageConfigViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    self.configsFilePath = [[NSBundle mainBundle] pathForResource:@"configs" ofType:@"plist"];
    
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
    self.selectedIndex = row;
}

// 双击cell，判断是否可编辑
- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    [self.nameTextField becomeFirstResponder];
    return NO;
}

#pragma mark - 

- (void)setupConfigs {
    self.configs = [NSMutableArray array];
    
    NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:self.configsFilePath];
    NSArray *configs = plist[@"configs"];
    if (configs == nil) {
        return;
    }
    
    for (NSDictionary *dict in configs) {
        ZyxPackageConfig *config = [[ZyxPackageConfig alloc] initWithDict:dict];
        [self.configs addObject:config];
    }
}

// 项目根目录
- (IBAction)selectProjectRootPath:(NSButton *)button {
    [Util selectPathInTextField:self.rootPathTextField];
    
    NSString *rootPath = self.rootPathTextField.stringValue;
    if (![Util isRootPathValid:rootPath]) {
        [Util showAlertWithMessage:@"该路径貌似不是一个有效的工程路径"];
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        ZyxPackageConfig *config = [[ZyxPackageConfig alloc] initWithRootPath:rootPath];
        ZyxIOSProjectInfo *project = config.project;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.versionTextField.stringValue = project.version;
            [self.configurationsBox addItemsWithObjectValues:project.configurations];
            [self.targetsBox addItemsWithObjectValues:project.targets];
            [self.schemesBox addItemsWithObjectValues:project.schemes];
            
            [self.configurationsBox selectItemAtIndex:project.configurations.count-1];
            [self.targetsBox selectItemAtIndex:0];
            [self.schemesBox selectItemAtIndex:0];
            
            config.configuration = project.configurations[0];
            config.target = project.targets[0];
            config.scheme = project.schemes[0];
        });
    });
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

- (IBAction)saveConfigButtonPressed:(id)sender {
    NSString *name = self.nameTextField.stringValue;
    if (name.length == 0) {
        [Util showAlertWithMessage:@"名称不能为空"];
        return;
    }
    
    NSString *rootPath = self.rootPathTextField.stringValue;
    if (![Util isRootPathValid:rootPath]) {
        [Util showAlertWithMessage:@"该路径貌似不是一个有效的工程路径"];
        return;
    }
    
    NSString *version = self.versionTextField.stringValue;
    if (![Util isVersionStringValid:version]) {
        [Util showAlertWithMessage:@"版本号填写不正确，请重新设置"];
        return;
    }
    
    ZyxPackageConfig *config = [[ZyxPackageConfig alloc] initWithRootPath:rootPath];
    config.name = name;
    config.rootPath = rootPath;
    config.project = [[ZyxIOSProjectInfo alloc] initWithRootPath:rootPath];
    config.project.version = version;
    self.configs[self.selectedIndex] = config;
    
    NSMutableArray *configs = [NSMutableArray array];
    for (ZyxPackageConfig *item in self.configs) {
        [configs addObject:[item jsonValues]];
    }
    NSDictionary *dict = @{@"configs": configs};
    if ([dict writeToFile:self.configsFilePath atomically:YES]) {
        
    }
    
}


@end;
