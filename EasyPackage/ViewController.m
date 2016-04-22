//
//  ViewController.m
//  TestOSX
//
//  Created by zhouyong on 16/3/6.
//  Copyright © 2016 zhouyong. All rights reserved.
//

#import "ViewController.h"
#import "ZyxPackageConfig.h"
#import "ZyxTaskUtil.h"

typedef NS_ENUM(NSUInteger, ZyxSelectDialogType) {
    ZyxSelectDialogTypeFile,
    ZyxSelectDialogTypeDirectory,
};

typedef void (^SelectDialogHandler)(NSString *path);

@interface ViewController ()

@property (nonatomic, strong) dispatch_queue_t packageQueue;
@property (nonatomic, strong) NSMutableArray<NSTask *> *tasks;
@property (nonatomic, strong) ZyxPackageConfig *config;
@property (nonatomic, assign) BOOL isCanceled;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.packageQueue = dispatch_queue_create("zyx.EasyPackageQueue", DISPATCH_QUEUE_SERIAL);
    self.packageButton.enabled = NO;
    self.cancelButton.enabled = NO;
}

// ResourceRules.plist 在Xcode7以后已经不准使用了，否则AppStore不让上架，但是这个是苹果的一个bug，不用又打包不通过
// 所以找到如下方法，打开 /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/PackageApplication 脚本,
// 找到 --resource-rules= , 删除这个参数，打包就没有错误了

- (void)addObservers {
    NSLog(@"a ha, add observer");
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(output:) name:NSFileHandleReadCompletionNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskDidTerminated:) name:NSTaskDidTerminateNotification object:nil];
}

- (void)removeObservers {
    NSLog(@"yes, remove observer");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)makePackageTasks {
    NSString *rmBuildCommand = [NSString stringWithFormat:@"rm -rf %@", _config.buildPath];
    NSString *cleanProjectCommand = @"/usr/bin/xcodebuild clean -configuration Release";
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
    dispatch_async(self.packageQueue, ^{
        NSFileHandle *fileHandle = notification.object;
        
        NSData *data = nil;//fileHandle.availableData;
        while ((data = fileHandle.availableData) && data.length > 0) {
            NSTask *task = self.tasks.firstObject;
            if (self.isCanceled && task != nil) {
                NSLog(@"cancel task, so terminate task[%@]", task);
                [task terminate];
            }
            
            NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSLog(@"text = %@", text);
            
            NSString *string = [NSString stringWithFormat:@"%@%@", self.outputTextView.string, text];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.outputTextView.string = string;
                [self.outputTextView scrollRangeToVisible:NSMakeRange(self.outputTextView.string.length, 1)];
            });
        }
    });
}

// 此方法所在线程和[task launch]时所在线程是一样的
// 这里就是在 packageQueue 中
- (void)taskDidTerminated:(NSNotification *)notification {
    static int index = 1;
    NSTask *task = notification.object;
    int status = [task terminationStatus];
    NSLog(@"task[%@] terminate reason: %@", @(index), @(task.terminationReason));
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.isCanceled) {
            NSLog(@"cancel next task[%@], so return", @(index));
            self.cancelButton.enabled = YES;
            self.packageButton.enabled = YES;
            // 不知道为什么加了这句，取消打包就崩溃
    //        [self executeTaskSync:self.tasks.lastObject];
            self.isCanceled = NO;
            
            [self removeObservers];
            [self showAlertWithMessage:@"取消打包成功"];
            return;
        }
        
        if (status == 0) {
            NSLog(@"Task[%@] finished.", @(index));
            if (self.tasks.count != 0) {
                [self.tasks removeObjectAtIndex:0];
            }
            
            if (self.tasks.count == 0) {
                self.packageButton.enabled = YES;
                index = 1;
                
                NSString *message = [NSString stringWithFormat:@"打包成功!\r\n目录路径：%@/%@-%@.ipa", _config.ipaPath, _config.project.name, _config.project.version];
                [self showAlertWithMessage:message];
                [self removeObservers];
                return;
            } else {
                [self executeTaskAsync:self.tasks.firstObject];
                index++;
            }
        } else {
            NSLog(@"Task[%@] failed.", @(index));
            self.packageButton.enabled = YES;
            self.cancelButton.enabled = YES;
            [self executeTaskSync:self.tasks.lastObject];
            [self showAlertWithMessage:@"打包失败"];
        }
    });
}

#pragma mark - Button Action

- (IBAction)packageButtonPressed:(NSButton *)button {
    NSString *version = self.versionTextField.stringValue;
    if (![ZyxIOSProjectInfo isVersionStringValid:version]) {
        [self showAlertWithMessage:@"版本号填写不正确，请重新设置"];
        return;
    }
    if (![self.config.project setProjectVersion:version]) {
        [self showAlertWithMessage:@"版本号设置失败"];
        return;
    }
    
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
    [self selectPathInTextField:self.projectRootDirTextField];
    NSString *rootPath = self.projectRootDirTextField.stringValue;
    
    BOOL valid = [ZyxPackageConfig isRootPathValid:rootPath];
    if (!valid) {
        [self showAlertWithMessage:@"该路径貌似不是一个有效的工程路径"];
        return;
    }
    self.packageButton.enabled = valid;
    
    self.config = [[ZyxPackageConfig alloc] initWithRootPath:rootPath];
    self.versionTextField.stringValue = self.config.project.version;
}

// IPA Path
- (IBAction)selectIPAPathButtonPressed:(NSButton *)button {
    [self selectPathInTextField:self.ipaTextField];
    NSString *path = self.ipaTextField.stringValue;
    if (path.length != 0) {
        self.config.ipaPath = path;
    }
}

// Profile File
- (IBAction)selectProvisionProfilePathButtonPressed:(NSButton *)button {
    [self selectFileInTextField:self.profileTextField];
    NSString *path = self.profileTextField.stringValue;
    if (path.length != 0) {
        self.config.provisionProfilePath = path;
    }
}

#pragma mark -

- (void)selectPathInTextField:(NSTextField *)textField {
    [self openSelectDialogWithType:ZyxSelectDialogTypeDirectory handler:^(NSString *path) {
        if (path != nil) {
            textField.stringValue = path;
        }
    }];
}

- (void)selectFileInTextField:(NSTextField *)textField {
    [self openSelectDialogWithType:ZyxSelectDialogTypeFile handler:^(NSString *path) {
        if (path != nil) {
            textField.stringValue = path;
        }
    }];
}

- (void)showAlertWithMessage:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"提示";
    alert.informativeText = message;
    [alert addButtonWithTitle:@"确定"];
    [alert runModal];
}

- (void)openSelectDialogWithType:(ZyxSelectDialogType)type handler:(SelectDialogHandler)handler {
    NSOpenPanel* dialog = [NSOpenPanel openPanel];
    dialog.allowsMultipleSelection = NO;
    
    switch (type) {
        case ZyxSelectDialogTypeFile:
            dialog.canChooseFiles = YES;
            dialog.canChooseDirectories = NO;
            break;
        case ZyxSelectDialogTypeDirectory:
            dialog.canChooseFiles = NO;
            dialog.canChooseDirectories = YES;
            dialog.canCreateDirectories = YES;
            break;
        default:
            break;
    }
    
    if ([dialog runModal] == NSModalResponseOK) {
        NSURL *url = dialog.URLs.firstObject;
        NSString *path = url.path;
        if (handler != nil) {
            handler(path);
        }
    }
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

@end
