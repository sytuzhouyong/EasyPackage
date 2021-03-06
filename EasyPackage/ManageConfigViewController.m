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

@property (nonatomic, assign) NSInteger editingIndex;
@property (nonatomic, strong) NSMutableArray<ZyxPackageConfig *> *configs;

@end

@implementation ManageConfigViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    self.configs = _packageVC.configs;
    if (self.configs.count == 0) {
        return;
    }
    
    NSInteger index = [[NSUserDefaults standardUserDefaults] integerForKey:@"LastEditConfigIndex"];
    if (self.configs.count < index + 1) {
        index = 0;
    }
    [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
    self.tableView.usesAlternatingRowBackgroundColors = YES;
    
    ZyxPackageConfig *config = self.configs[index];
    self.nameTextField.stringValue = SafeString(config.name);
    self.rootPathTextField.stringValue = SafeString(config.rootPath);
    self.ipaPathTextField.stringValue = SafeString(config.ipaPath);
    self.provisionProfilePathTextField.stringValue = SafeString(config.provisionProfilePath);
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
    
    self.editingIndex = index;
}

#pragma mark - Button Actions

// 项目根目录
- (IBAction)selectProjectRootPath:(NSButton *)button {
    if ([Util selectPathInTextField:self.rootPathTextField]) {
        ZyxPackageConfig *config = self.configs[self.editingIndex];
        config.rootPath = self.rootPathTextField.stringValue;
        
        [self updateUIWithConfig:config];
    }
}

- (IBAction)selectIPAPathButtonPressed:(NSButton *)button {
    [Util selectPathInTextField:self.ipaPathTextField];
    
    ZyxPackageConfig *config = self.configs[self.editingIndex];
    config.ipaPath = self.ipaPathTextField.stringValue;
}

- (IBAction)selectProvisionProfilePathButtonPressed:(NSButton *)button {
    [Util selectFileInTextField:self.provisionProfilePathTextField];
    
    ZyxPackageConfig *config = self.configs[self.editingIndex];
    config.provisionProfilePath = self.provisionProfilePathTextField.stringValue;
}

- (IBAction)addConfigButtonPressed:(id)sender {
    [self.tableView deselectAll:sender];
    
    ZyxPackageConfig *config = [ZyxPackageConfig new];
    config.name = @"新配置";
    [self.configs addObject:config];
    [config save];
    self.editingIndex = self.configs.count - 1;
    
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:self.configs.count-1];
    [self.tableView beginUpdates];
    [self.tableView insertRowsAtIndexes:indexSet withAnimation:NSTableViewAnimationEffectFade];
    [self.tableView selectRowIndexes:indexSet byExtendingSelection:NO];
    [self.tableView endUpdates];

    [self.nameTextField becomeFirstResponder];
    self.configurationsComboBox.stringValue = @"";
    self.targetsComboBox.stringValue = @"";
    self.schemesComboBox.stringValue = @"";
    
    [self.packageVC addConfigMenuItemWithName:config.name];
}

- (IBAction)deleteCongfigButtonPressed:(id)sender {
    ZyxPackageConfig *config = self.configs[self.editingIndex];
    if (![config delete]) {
        [Util showAlertWithMessage:@"配置文件删除失败"];
        return;
    }
    [self.configs removeObjectAtIndex:self.editingIndex];
    
    [self.tableView reloadData];
    
    self.editingIndex = MIN(self.editingIndex, self.configs.count-1);
    if (self.editingIndex >= 0) {
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:self.editingIndex];
        [self.tableView selectRowIndexes:indexSet byExtendingSelection:NO];
    }
}

- (IBAction)saveConfigButtonPressed:(id)sender {
    if (self.editingIndex >= self.configs.count) {
        return;
    }
    
    ZyxPackageConfig *config = self.configs[self.editingIndex];
    config.name = self.nameTextField.stringValue;
    config.rootPath = self.rootPathTextField.stringValue;
    config.project.version = self.versionTextField.stringValue;
    config.configuration = self.configurationsComboBox.stringValue;
    config.target = self.targetsComboBox.stringValue;
    config.scheme = self.schemesComboBox.stringValue;
    config.ipaPath = self.ipaPathTextField.stringValue;
    config.provisionProfilePath = self.provisionProfilePathTextField.stringValue;
    
    if ([config update]) {
        [self.tableView reloadData];
    } else {
        [Util showAlertWithMessage:@"保存配置失败"];
    }
    
    [self.packageVC updateConfigMenuItemAtIndex:self.editingIndex+1 withName:config.name];
}

#pragma mark - Util Methods

- (void)updateUIWithConfig:(ZyxPackageConfig *)config {
    ZyxIOSProjectInfo *project = config.project;
    self.nameTextField.stringValue = SafeString(config.name);
    self.versionTextField.stringValue = SafeString(project.version);
    self.rootPathTextField.stringValue = SafeString(config.rootPath);
    self.ipaPathTextField.stringValue = SafeString(config.ipaPath);
    self.provisionProfilePathTextField.stringValue = SafeString(config.provisionProfilePath);
    
    [self.configurationsComboBox removeAllItems];
    [self.targetsComboBox removeAllItems];
    [self.schemesComboBox removeAllItems];
    self.configurationsComboBox.stringValue = @"";
    self.targetsComboBox.stringValue = @"";
    self.schemesComboBox.stringValue = @"";
    
    [self.configurationsComboBox addItemsWithObjectValues:project.configurations];
    [self.targetsComboBox addItemsWithObjectValues:project.targets];
    [self.schemesComboBox addItemsWithObjectValues:project.schemes];
    
    if (project.configurations.count > 0) {
        NSInteger index = [self.configurationsComboBox indexOfItemWithObjectValue:config.configuration];
        if (NSNotFound == index) {
            index = project.configurations.count - 1;
        }
        [self.configurationsComboBox selectItemAtIndex:index];
    }

    if (project.targets.count > 0) {
        NSInteger index = [self.targetsComboBox indexOfItemWithObjectValue:config.target];
        if (NSNotFound == index) {
            index = 0;
        }
        [self.targetsComboBox selectItemAtIndex:index];
    }
    
    if (project.schemes.count > 0) {
        NSInteger index = [self.schemesComboBox indexOfItemWithObjectValue:config.scheme];
        if (NSNotFound == index) {
            index = 0;
        }
        [self.schemesComboBox selectItemAtIndex:index];
    }
}

@end;
