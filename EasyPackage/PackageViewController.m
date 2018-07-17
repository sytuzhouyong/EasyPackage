//
//  PackageViewController.m
//  EasyPackage
//
//  Created by zhouyong on 16/3/6.
//  Copyright © 2016 zhouyong. All rights reserved.
//

#import "PackageViewController.h"
#import "ZyxTaskUtil.h"
#import "Util.h"
#import "AppDelegate.h"
#import "ManageConfigViewController.h"


@interface PackageViewController () <NSWindowDelegate>

@property (nonatomic, strong) dispatch_queue_t packageQueue;
@property (nonatomic, strong) NSMutableArray<NSTask *> *tasks;
@property (nonatomic, strong) NSArray<NSString *> *taskTips;
@property (nonatomic, strong) ZyxPackageConfig *config;
@property (nonatomic, assign) BOOL isCanceled;
@property (nonatomic, assign) int index;

@end

@implementation PackageViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.packageQueue = dispatch_queue_create("zyx.EasyPackageQueue", DISPATCH_QUEUE_SERIAL);
    self.packageButton.enabled = NO;
    self.cancelButton.enabled = NO;
 
    NSMenuItem *manageConfigMenuItem = [self configMenuItemAtIndex:0];
    manageConfigMenuItem.target = self;
    manageConfigMenuItem.action = @selector(configManageButtonPressed);
    
    [self addConfigItems];
    
    NSInteger index = [[NSUserDefaults standardUserDefaults] integerForKey:@"LastEditConfigIndex"];
    if (self.configs.count < index + 1) {
        index = 0;
    }
    [self menuItemSelected:[self configMenuItemAtIndex:index + 1]];
}

- (NSMenuItem *)configMenuItemAtIndex:(NSInteger)index {
    NSMenuItem *configMenuItems = [NSApp mainMenu].itemArray[1];
    NSMenuItem *manageConfigMenuItem = configMenuItems.submenu.itemArray[index];
    return manageConfigMenuItem;
}

- (void)addConfigItems {
    NSMenu *configMenu = [NSApp mainMenu].itemArray[1].submenu;
    
    self.configs = [NSMutableArray arrayWithArray:[ZyxPackageConfig localConfigs]];
    for (int i=0; i<self.configs.count; i++) {
        ZyxPackageConfig *config = self.configs[i];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:config.name action:@selector(menuItemSelected:) keyEquivalent:@(i+1).stringValue];
        [configMenu addItem:item];
    }
}

- (void)menuItemSelected:(NSMenuItem *)menuItem {
    NSInteger index = menuItem.keyEquivalent.integerValue - 1;
    if (index >= 0) {
        self.config = self.configs[index];
        [self updateUIWithConfig:self.config];
        
        [[NSUserDefaults standardUserDefaults] setInteger:index forKey:@"LastEditConfigIndex"];
        self.packageButton.enabled = self.config.project.version.length > 0;
    }
}

- (void)addObservers {
    NSLog(@"aha, add observer");
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(output:) name:NSFileHandleReadCompletionNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskDidTerminated:) name:NSTaskDidTerminateNotification object:nil];
}

- (void)removeObservers {
    NSLog(@"yes, remove observer");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)makePackageTasks {
    NSString *rmBuildCommand = [NSString stringWithFormat:@"rm -rf %@", _config.buildPath];
//    NSString *cleanProjectCommand = [NSString stringWithFormat:@"/usr/bin/xcodebuild clean -configuration %@", _config.configuration];
    NSString *makeIPAPathCommand = [NSString stringWithFormat:@"mkdir -p %@", _config.ipaPath];
    NSArray *tasks = @[[ZyxTaskUtil taskWithShell:rmBuildCommand],
//                       [ZyxTaskUtil taskWithShell:cleanProjectCommand path:_config.rootPath],
                       [_config buildTask],
                       [_config copyStaticLibrariesTask],
                       [ZyxTaskUtil taskWithShell:makeIPAPathCommand],
                       [_config makeIPATask],
                       ];
    self.tasks = [NSMutableArray arrayWithArray:tasks];
    self.taskTips = @[@"删除build目录...", @"清理工程...", @"编译工程...", @"拷贝静态库", @"创建打包目录...", @"打包..."];
    self.progressIndicator.maxValue = tasks.count;
}


#pragma mark - Uitl Methods

- (void)executeTaskAsync:(NSTask *)task {
    NSLog(@"task started");
    [task launch];
    
    NSFileHandle *fileHandle = (NSFileHandle *)[task.standardOutput fileHandleForReading];
    [fileHandle readInBackgroundAndNotify];
}

- (NSString *)executeTaskSync:(NSTask *)task {
    [task launch];
    [task waitUntilExit];
    NSData *data = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return text;
}

#pragma mark - NSTask output notification

- (void)output:(NSNotification *)notification {
    NSFileHandle *fileHandle = notification.object;
    
    dispatch_async(self.packageQueue, ^{
        NSData *data = nil;
        while ((data = fileHandle.availableData) && data.length > 0) {
            NSTask *task = self.tasks.firstObject;
            if (self.isCanceled && task != nil) {
                NSLog(@"cancel task, so terminate task[%@]", task);
                [task terminate];
            }
            
            NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSLog(@"text = %@", text);
        }
    });
}

// 此方法所在线程和[task launch]时所在线程是一样的
// 这里就是在 packageQueue 中
- (void)taskDidTerminated:(NSNotification *)notification {
    NSTask *task = notification.object;
    int status = [task terminationStatus];
    NSLog(@"task[%@] terminated: %@", @(_index), @(task.terminationReason));
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.isCanceled) {
            NSLog(@"cancel next task[%@], so return", @(_index));
            self.isCanceled = NO;
            
            [Util showAlertWithMessage:@"取消打包成功"];
            [self clear];
            return;
        }
        
        if (status != 0) {
            NSLog(@"Task[%@] failed.", @(_index));
            [Util showAlertWithMessage:@"打包失败"];
            [self clear];
            return;
        }
        
        NSLog(@"Task[%@] success.", @(_index));
        [self.progressIndicator incrementBy:1];
        
        // 移除掉完成的任务
        if (self.tasks.count != 0) {
            [self.tasks removeObjectAtIndex:0];
        }
        if (self.tasks.count == 0) {
            NSString *message = [NSString stringWithFormat:@"打包成功!\r\n目录路径：%@/%@-%@.ipa", _config.ipaPath, _config.project.name, _config.project.version];
            [Util showAlertWithMessage:message];
            [self clear];
            return;
        }
        
        _index++;
        self.indicatorLabel.stringValue = self.taskTips[_index-1];
        [self executeTaskAsync:self.tasks.firstObject];
    });
}

- (void)clear {
    _index = 1;
    [self removeObservers];
    
    self.packageButton.enabled = YES;
    self.cancelButton.enabled = NO;
    self.indicatorLabel.stringValue = @"无任务进行";
    self.progressIndicator.doubleValue = 0;
    
    NSString *rmBuildCommand = [NSString stringWithFormat:@"rm -rf %@", _config.buildPath];
    NSTask *task = [ZyxTaskUtil taskWithShell:rmBuildCommand];
    [self executeTaskSync:task];
}

#pragma mark - Button Action

- (IBAction)packageButtonPressed:(NSButton *)button {
    NSString *version = self.versionTextField.stringValue;
    if (![Util isVersionStringValid:version]) {
        [Util showAlertWithMessage:@"版本号填写不正确，请重新设置"];
        return;
    }
    if (![self.config.project setProjectVersion:version]) {
        [Util showAlertWithMessage:@"版本号设置失败"];
        return;
    }
    self.config.project.version = version;
    self.index = 1;
    
    button.enabled = NO;
    self.cancelButton.enabled = YES;
    
    [self makePackageTasks];
    [self addObservers];
    
    self.indicatorLabel.stringValue = self.taskTips[self.index-1];
    
    NSTask *task = self.tasks.firstObject;
    [self executeTaskAsync:task];
}

- (IBAction)cancelPackageButtonPressed:(NSButton *)button {
    if (self.tasks.count == 0) {
        return;
    }
    
    self.isCanceled = YES;
    button.enabled = NO;
    self.indicatorLabel.stringValue = @"无任务进行";
    self.progressIndicator.doubleValue = 0;
}

// 项目根目录
- (IBAction)selectProjectRootPath:(NSButton *)button {
    BOOL selected = [Util selectPathInTextField:self.rootPathTextField];
    if (!selected) {
        return;
    }
    
    NSString *rootPath = self.rootPathTextField.stringValue;
    if (![Util isRootPathValid:rootPath]) {
        [Util showAlertWithMessage:@"该路径貌似不是一个有效的工程路径"];
        return;
    }
    self.packageButton.enabled = YES;
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        ZyxPackageConfig *config = [[ZyxPackageConfig alloc] initWithRootPath:rootPath];
        ZyxIOSProjectInfo *project = config.project;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.versionTextField.stringValue = project.version;
            
            // configuration
            [self.configurationsComboBox removeAllItems];
            [self.configurationsComboBox addItemsWithObjectValues:project.configurations];
            [self.configurationsComboBox selectItemAtIndex:project.configurations.count-1];
            config.configuration = project.configurations.lastObject;
            
            // target
            [self.targetsComboBox removeAllItems];
            [self.targetsComboBox addItemsWithObjectValues:project.targets];
            [self.targetsComboBox selectItemAtIndex:0];
            config.target = project.targets[0];
            
            // scheme
            [self.schemesComboBox removeAllItems];
            [self.schemesComboBox addItemsWithObjectValues:project.schemes];
            [self.schemesComboBox selectItemAtIndex:0];
            config.scheme = project.schemes[0];
            
            self.config = config;
        });
    });
}

// IPA Path
- (IBAction)selectIPAPathButtonPressed:(NSButton *)button {
    [Util selectPathInTextField:self.ipaPathTextField];
    NSString *path = self.ipaPathTextField.stringValue;
    if (path.length != 0) {
        self.config.ipaPath = path;
    }
}

- (IBAction)configComboBoxValueChanged:(NSComboBox *)comboBox {
    self.config.configuration = self.config.project.configurations[comboBox.indexOfSelectedItem];
}

- (IBAction)targetComboBoxValueChanged:(NSComboBox *)comboBox {
    self.config.target = self.config.project.targets[comboBox.indexOfSelectedItem];
}

- (IBAction)schemeComboBoxValueChanged:(NSComboBox *)comboBox {
    self.config.scheme = self.config.project.schemes[comboBox.indexOfSelectedItem];
}

// Profile File
- (IBAction)selectProvisionProfilePathButtonPressed:(NSButton *)button {
    [Util selectFileInTextField:self.provisionProfilePathTextField];
    NSString *path = self.provisionProfilePathTextField.stringValue;
    if (path.length != 0) {
        self.config.provisionProfilePath = path;
    }
}

#pragma mark - 配置管理

- (void)configManageButtonPressed {
    ManageConfigViewController *configVC = [[ManageConfigViewController alloc] initWithNibName:nil bundle:nil];
    configVC.packageVC = self;
    
    NSRect frame = configVC.view.frame;
    NSUInteger style =  NSTitledWindowMask | NSClosableWindowMask |NSMiniaturizableWindowMask | NSResizableWindowMask;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame styleMask:style backing:NSBackingStoreRetained defer:NO];
    window.title = @"配置管理";
    [window.contentView addSubview:configVC.view];
    window.delegate = self;
    
    NSWindowController *windowController = [[NSWindowController alloc] initWithWindow:window];
    [[NSApplication sharedApplication] runModalForWindow:windowController.window];
}

- (void)addConfigMenuItemWithName:(NSString *)name {
    NSMenu *configMenu = [NSApp mainMenu].itemArray[1].submenu;
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:name action:@selector(menuItemSelected:) keyEquivalent:@""];
    [configMenu addItem:item];
}

- (void)updateConfigMenuItemAtIndex:(NSInteger)index withName:(NSString *)name {
    NSMenu *configMenu = [NSApp mainMenu].itemArray[1].submenu;
    NSMenuItem *item = configMenu.itemArray[index];
    item.title = name;
}

- (void)windowWillClose:(NSNotification *)notification {
    [[NSApplication sharedApplication] stopModal];
}


- (void)updateUIWithConfig:(ZyxPackageConfig *)config {
    ZyxIOSProjectInfo *project = config.project;
    self.versionTextField.stringValue = SafeString(project.version);
    self.rootPathTextField.stringValue = SafeString(config.rootPath);
    self.ipaPathTextField.stringValue = SafeString(config.ipaPath);
    self.provisionProfilePathTextField.stringValue = SafeString(config.provisionProfilePath);
    
    self.configurationsComboBox.stringValue = @"";
    [self.configurationsComboBox removeAllItems];
    [self.configurationsComboBox addItemsWithObjectValues:project.configurations];
    
    self.targetsComboBox.stringValue = @"";
    [self.targetsComboBox removeAllItems];
    [self.targetsComboBox addItemsWithObjectValues:project.targets];
    
    self.schemesComboBox.stringValue = @"";
    [self.schemesComboBox removeAllItems];
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

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}
- (void)dealloc {
    NSLog(@"DEALLLOC");
}

@end
