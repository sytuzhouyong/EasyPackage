//
//  PackageViewController.m
//  EasyPackage
//
//  Created by zhouyong on 16/3/6.
//  Copyright © 2016 zhouyong. All rights reserved.
//

#import "PackageViewController.h"
#import "ZyxPackageConfig.h"
#import "ZyxTaskUtil.h"
#import "Util.h"
#import "AppDelegate.h"


@interface PackageViewController () <NSWindowDelegate>

@property (nonatomic, strong) dispatch_queue_t packageQueue;
@property (nonatomic, strong) NSMutableArray<NSTask *> *tasks;
@property (nonatomic, strong) ZyxPackageConfig *config;
@property (nonatomic, assign) BOOL isCanceled;

@end

@implementation PackageViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.packageQueue = dispatch_queue_create("zyx.EasyPackageQueue", DISPATCH_QUEUE_SERIAL);
    self.packageButton.enabled = NO;
    self.cancelButton.enabled = NO;
 
    NSMenuItem *manageConfigMenuItem = [self configMenuItem];
    manageConfigMenuItem.target = self;
    manageConfigMenuItem.action = @selector(configManageButtonPressed);
}

- (NSMenuItem *)configMenuItem {
    NSMenuItem *configMenuItems = [NSApp mainMenu].itemArray[2];
    NSMenuItem *manageConfigMenuItem = configMenuItems.submenu.itemArray.firstObject;
    return manageConfigMenuItem;
}

// ResourceRules.plist 在Xcode7以后已经不准使用了，否则AppStore不让上架，但是这个是苹果的一个bug，不用又打包不通过
// 所以找到如下方法，打开 /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/PackageApplication 脚本,
// 找到 --resource-rules= , 删除这个参数，打包就没有错误了

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
    NSString *cleanProjectCommand = [NSString stringWithFormat:@"/usr/bin/xcodebuild clean -configuration %@", _config.configuration];
    NSString *makeIPAPathCommand = [NSString stringWithFormat:@"mkdir -p %@", _config.ipaPath];
    NSArray *tasks = @[[ZyxTaskUtil taskWithShell:rmBuildCommand],
                       [ZyxTaskUtil taskWithShell:cleanProjectCommand path:_config.rootPath],
                       [_config buildTask],
                       [_config copyStaticLibrariesTask],
                       [ZyxTaskUtil taskWithShell:makeIPAPathCommand],
                       [_config makeIPATask],
                       [ZyxTaskUtil taskWithShell:rmBuildCommand],
                       ];
    self.tasks = [NSMutableArray arrayWithArray:tasks];
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
            
//            dispatch_async(dispatch_get_main_queue(), ^{
//                NSString *string = [NSString stringWithFormat:@"%@%@", self.outputTextView.string, text];
//                self.outputTextView.string = string;
//                [self.outputTextView scrollRangeToVisible:NSMakeRange(self.outputTextView.string.length, 1)];
//            });
        }
    });
}

// 此方法所在线程和[task launch]时所在线程是一样的
// 这里就是在 packageQueue 中
- (void)taskDidTerminated:(NSNotification *)notification {
    static int index = 1;
    NSTask *task = notification.object;
    int status = [task terminationStatus];
    NSLog(@"task[%@] success: %@", @(index), @(task.terminationReason));
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.isCanceled) {
            NSLog(@"cancel next task[%@], so return", @(index));
            self.cancelButton.enabled = NO;
            self.packageButton.enabled = YES;
            // 不知道为什么加了这句，取消打包就崩溃
    //        [self executeTaskSync:self.tasks.lastObject];
            self.isCanceled = NO;
            
            [self removeObservers];
            [Util showAlertWithMessage:@"取消打包成功"];
            return;
        }
        
        if (status != 0) {
            NSLog(@"Task[%@] failed.", @(index));
            self.packageButton.enabled = NO;
            self.cancelButton.enabled = YES;
            [self executeTaskSync:self.tasks.lastObject];
            [Util showAlertWithMessage:@"打包失败"];
        }
        
        NSLog(@"Task[%@] finished.", @(index));
        // 移除掉完成的任务
        if (self.tasks.count != 0) {
            [self.tasks removeObjectAtIndex:0];
        }
        
        if (self.tasks.count == 0) {
            self.cancelButton.enabled = NO;
            self.packageButton.enabled = YES;
            index = 1;
            
            NSString *message = [NSString stringWithFormat:@"打包成功!\r\n目录路径：%@/%@-%@.ipa", _config.ipaPath, _config.project.name, _config.project.version];
            [Util showAlertWithMessage:message];
            [self removeObservers];
            return;
        } else {
            [self executeTaskAsync:self.tasks.firstObject];
            index++;
        }
    });
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
    
    button.enabled = NO;
    self.cancelButton.enabled = YES;
    
    self.outputTextView.string = @"";
    self.config.codesign = self.codeSignTextField.stringValue;
    
    [self makePackageTasks];
    [self addObservers];
    
    NSTask *task = self.tasks.firstObject;
    [self executeTaskAsync:task];
}

- (IBAction)cancelPackageButtonPressed:(NSButton *)button {
    if (self.tasks.count == 0) {
        return;
    }
    
    self.isCanceled = YES;
    button.enabled = NO;
}

// 项目根目录
- (IBAction)selectProjectRootPath:(NSButton *)button {
    BOOL selected = [Util selectPathInTextField:self.projectRootDirTextField];
    NSString *rootPath = self.projectRootDirTextField.stringValue;
    if (selected && ![Util isRootPathValid:rootPath]) {
        [Util showAlertWithMessage:@"该路径貌似不是一个有效的工程路径"];
        return;
    }
    self.packageButton.enabled = YES;
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        ZyxPackageConfig *config = [[ZyxPackageConfig alloc] initWithRootPath:rootPath];
        ZyxIOSProjectInfo *project = config.project;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.versionTextField.stringValue = project.version;
            
            [self.configurationsComboBox removeAllItems];
            [self.targetsComboBox removeAllItems];
            [self.schemesComboBox removeAllItems];
            
            [self.configurationsComboBox addItemsWithObjectValues:project.configurations];
            [self.targetsComboBox addItemsWithObjectValues:project.targets];
            [self.schemesComboBox addItemsWithObjectValues:project.schemes];
            
            [self.configurationsComboBox selectItemAtIndex:project.configurations.count-1];
            [self.targetsComboBox selectItemAtIndex:0];
            [self.schemesComboBox selectItemAtIndex:0];
            
            config.configuration = project.configurations[0];
            config.target = project.targets[0];
            config.scheme = project.schemes[0];
//            self.targetsComboBox.enabled = !project.isWorkspace;
//            self.schemesComboBox.enabled = project.isWorkspace;
            
            self.config = config;
        });
    });
}

// IPA Path
- (IBAction)selectIPAPathButtonPressed:(NSButton *)button {
    [Util selectPathInTextField:self.ipaTextField];
    NSString *path = self.ipaTextField.stringValue;
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
    [Util selectFileInTextField:self.profileTextField];
    NSString *path = self.profileTextField.stringValue;
    if (path.length != 0) {
        self.config.provisionProfilePath = path;
    }
}

#pragma mark -

#pragma mark - 配置管理

- (void)configManageButtonPressed {
    ManageConfigViewController *configVC = [[ManageConfigViewController alloc] initWithNibName:nil bundle:nil];
    NSRect frame = configVC.view.frame;
    NSUInteger style =  NSTitledWindowMask | NSClosableWindowMask |NSMiniaturizableWindowMask | NSResizableWindowMask;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame styleMask:style backing:NSBackingStoreRetained defer:NO];
    window.title = @"配置管理";
    [window.contentView addSubview:configVC.view];
    window.delegate = self;
    
    NSWindowController *windowController = [[NSWindowController alloc] initWithWindow:window];
    [[NSApplication sharedApplication] runModalForWindow:windowController.window];
}

- (void)windowWillClose:(NSNotification *)notification {
    [[NSApplication sharedApplication] stopModal];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}
- (void)dealloc {
    NSLog(@"DEALLLOC");
}

@end
