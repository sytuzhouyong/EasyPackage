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
@property (nonatomic, assign) NSInteger editingIndex;
@property (nonatomic, copy) NSString *configsFilePath;

@end

@implementation ManageConfigViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    self.configsFilePath = [[NSBundle mainBundle] pathForResource:@"configs" ofType:@"plist"];
    [self setupConfigs];
    
    if (self.configs.count == 0) {
        return;
    }
    
    NSInteger index = [[NSUserDefaults standardUserDefaults] integerForKey:@"LastEditConfigIndex"];
    if (self.configs.count < index + 1) {
        index = 0;
    }
    [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
    self.tableView.usesAlternatingRowBackgroundColors = YES;
    
    ZyxPackageConfig *config = self.configs[0];
    self.nameTextField.stringValue = config.name;
    self.rootPathTextField.stringValue = config.rootPath;
    self.ipaPathTextField.stringValue = config.ipaPath;
    self.provisionProfilePathTextField.stringValue = config.provisionProfilePath;
    [self updateUIWithConfig:config];
}

- (void)viewDidDisappear {
    [super viewDidDisappear];
    [[NSUserDefaults standardUserDefaults] setInteger:self.editingIndex forKey:@"LastEditConfigIndex"];
}

#pragma mark - NSTableView

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

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    ZyxPackageConfig *config = self.configs[row];
    config.name = object;
    self.editingIndex = row;
}

// 双击cell，判断是否可编辑
- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    [self.nameTextField becomeFirstResponder];
    return NO;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSTableView *tableView = notification.object;
    NSInteger index = [tableView selectedRow];
    if (index != -1) {
        ZyxPackageConfig *config = self.configs[index];
        [self updateUIWithConfig:config];
    }
}

#pragma mark - Button Actions

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
    if ([Util selectPathInTextField:self.rootPathTextField]) {
        ZyxPackageConfig *config = [[ZyxPackageConfig alloc] initWithRootPath:self.rootPathTextField.stringValue];
        config.name = self.nameTextField.stringValue;
        [self updateUIWithConfig:config];
        
        NSInteger index = [self.tableView selectedRow];
        if (index != -1) {
            [self.configs replaceObjectAtIndex:index withObject:config];
        }
    }
}

- (IBAction)selectIPAPathButtonPressed:(NSButton *)button {
    [Util selectPathInTextField:self.ipaPathTextField];
    
    NSInteger index = [self.tableView selectedRow];
    if (index != -1) {
        ZyxPackageConfig *config = self.configs[index];
        config.ipaPath = self.ipaPathTextField.stringValue;
    }
}

- (IBAction)selectProvisionProfilePathButtonPressed:(NSButton *)button {
    [Util selectFileInTextField:self.provisionProfilePathTextField];
    
    NSInteger index = [self.tableView selectedRow];
    if (index != -1) {
        ZyxPackageConfig *config = self.configs[index];
        config.provisionProfilePath = self.provisionProfilePathTextField.stringValue;
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
    [self.tableView selectRowIndexes:indexSet byExtendingSelection:NO];
    [self.tableView endUpdates];

    [self.nameTextField becomeFirstResponder];
    self.configurationsBox.stringValue = @"";
    self.targetsBox.stringValue = @"";
    self.schemesBox.stringValue = @"";
}

- (IBAction)saveConfigButtonPressed:(id)sender {
    NSMutableArray *configs = [NSMutableArray array];
    for (ZyxPackageConfig *item in self.configs) {
        [configs addObject:[item jsonValues]];
    }
    NSDictionary *dict = @{@"configs": configs};
    if (![dict writeToFile:self.configsFilePath atomically:YES]) {
        [Util showAlertWithMessage:@"保存配置失败"];
    } else {
        [self.tableView reloadData];
    }
}

#pragma mark - Util Methods

- (void)updateUIWithConfig:(ZyxPackageConfig *)config {
    ZyxIOSProjectInfo *project = config.project;
    self.nameTextField.stringValue = config.name;
    self.versionTextField.stringValue = project.version;
    self.rootPathTextField.stringValue = config.rootPath;
    self.ipaPathTextField.stringValue = config.ipaPath;
    self.provisionProfilePathTextField.stringValue = config.provisionProfilePath;
    
    [self.configurationsBox removeAllItems];
    [self.targetsBox removeAllItems];
    [self.schemesBox removeAllItems];
    self.configurationsBox.stringValue = @"";
    self.targetsBox.stringValue = @"";
    self.schemesBox.stringValue = @"";
    
    [self.configurationsBox addItemsWithObjectValues:project.configurations];
    [self.targetsBox addItemsWithObjectValues:project.targets];
    [self.schemesBox addItemsWithObjectValues:project.schemes];
    
    if (project.configurations.count > 0) {
        NSInteger index = [self.configurationsBox indexOfItemWithObjectValue:config.configuration];
        if (NSNotFound == index) {
            index = project.configurations.count - 1;
        }
        [self.configurationsBox selectItemAtIndex:index];
    }

    if (project.targets.count > 0) {
        NSInteger index = [self.targetsBox indexOfItemWithObjectValue:config.target];
        if (NSNotFound == index) {
            index = 0;
        }
        [self.targetsBox selectItemAtIndex:index];
    }
    
    if (project.schemes.count > 0) {
        NSInteger index = [self.schemesBox indexOfItemWithObjectValue:config.scheme];
        if (NSNotFound == index) {
            index = 0;
        }
        [self.schemesBox selectItemAtIndex:index];
    }
}

@end;
