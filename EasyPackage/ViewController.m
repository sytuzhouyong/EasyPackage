//
//  ViewController.m
//  TestOSX
//
//  Created by zhouyong on 2/25/16.
//  Copyright © 2016 zhouyong. All rights reserved.
//

#import "ViewController.h"
#import <Automator/Automator.h>

#define ShowErrorAlertAndReturn(_m) \
    if (!success) { \
        [self showErrorAlertWithMessage:_m]; \
        return; \
    }

typedef NS_ENUM(NSUInteger, ZyxSelectDialogType) {
    ZyxSelectDialogTypeFile,
    ZyxSelectDialogTypeDirectory,
};

typedef void (^SelectDialogHandler)(NSString *path);

@interface ViewController ()

@property (nonatomic, strong) IBOutlet NSTextField *projectRootDirTextField;
@property (nonatomic, strong) IBOutlet NSTextField *ipaTextField;
@property (nonatomic, strong) IBOutlet NSTextField *codeSignTextField;
@property (nonatomic, strong) IBOutlet NSTextField *profileTextField;

@property (nonatomic, strong) NSTask *task;

@property (nonatomic, copy) NSString *projectRootPath;
@property (nonatomic, copy) NSString *projectName;
@property (nonatomic, copy) NSString *buildPath;
@property (nonatomic, copy) NSString *codeSign;
@property (nonatomic, copy) NSString *provisionProfile;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(output:) name:NSFileHandleReadCompletionNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskDidTerminated:) name:NSTaskDidTerminateNotification object:nil];
    self.codeSign = @"iPhone Distribution: ZTE CORPORATION";
}

- (IBAction)packageButtonPressed:(NSButton *)button {
    BOOL success = [self cleanBuildPath];
    ShowErrorAlertAndReturn(@"清理build目录出错");
    
    success = [self cleanProjectCache];
    ShowErrorAlertAndReturn(@"清理工程缓存出错");

    success = [self buildProject];
    ShowErrorAlertAndReturn(@"编译工程出错");
    
    success = [self makeIPA];
    ShowErrorAlertAndReturn(@"生成IPA文件出错");
}

#pragma mark -

- (BOOL)cleanBuildPath {
    NSString *mkdirCommand = [NSString stringWithFormat:@"mkdir -p %@", self.buildPath];
    [self resultStringOfExecuteCommand:mkdirCommand];
    
    NSString *rmCommand = [NSString stringWithFormat:@"rm -rf %@", self.buildPath];
    [self resultStringOfExecuteCommand:rmCommand];
    BOOL success = [self isLastCommandExecuteSuccess];
    return success;
}

- (BOOL)cleanProjectCache {
    [self resultStringOfExecuteCommand:@"/usr/bin/xcodebuild clean -configuration Release"];
    BOOL success = [self isLastCommandExecuteSuccess];
    return success;
}

// ResourceRules.plist 在Xcode7以后已经不准使用了，否则AppStore不让上架，但是这个是苹果的一个bug，不用又打包不通过
// 所以找到如下方法，打开 /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/PackageApplication 脚本,
// 找到 --resource-rules= , 删除这个参数，打包就没有错误了
- (BOOL)buildProject {
    NSString *format = @"/usr/bin/xcodebuild \\"
        @"-workspace %@.xcworkspace \\"
        @"-scheme %@ \\"
        @"-configuration Release \\"
        @"-sdk iphoneos \\"
//        @"CODE_SIGN_RESOURCE_RULES_PATH=iphoneos/ResourceRules.plist \\"
        @"OBJROOT=%@ \\"
        @"TARGET_BUILD_DIR=%@";
    NSString *command = [NSString stringWithFormat:format, self.projectName, self.projectName, self.buildPath, self.buildPath];
    [self resultStringOfExecuteCommand:command];
    BOOL success = [self isLastCommandExecuteSuccess];
    return success;
}

- (BOOL)makeIPA {
    // 如果有第三方库，就拷贝到编译输出目录下
    NSString *copy = [NSString stringWithFormat:@"cp %@ %@", self.thirdPartyLibraryTextField.stringValue, self.buildPath];
    [self resultStringOfExecuteCommand:copy];
    
    NSString *mkdir = [NSString stringWithFormat:@"mkdir -p %@", self.ipaTextField.stringValue];
    [self resultStringOfExecuteCommand:mkdir];
    
    NSString *format = @"/usr/bin/xcrun -sdk iphoneos \\"
        @"PackageApplication \\"
            @"-v %@/%@.app \\"
            @"-o %@/%@.ipa \\"
            @"--sign \"%@\" \\"
            @"--embed \"%@\"";
    NSString *command = [NSString stringWithFormat:format, self.buildPath, self.projectName, self.ipaTextField.stringValue, self.projectName, self.codeSignTextField.stringValue, self.profileTextField.stringValue];
    [self resultStringOfExecuteCommand:command];
    BOOL success = [self isLastCommandExecuteSuccess];
    return success;
}

#pragma mark - Uitl Methods

- (NSString *)resultStringOfExecuteCommand:(NSString *)command {
    NSPipe *pipe = [NSPipe pipe];
    
    NSString *shellCommand = [NSString stringWithFormat:@"/bin/sh -c '%@'", command];
    
    __block NSString *result = nil;
    dispatch_sync(dispatch_get_global_queue(0, 0), ^{
        NSTask *task = [[NSTask alloc] init];
        task.currentDirectoryPath = self.projectTextField.stringValue;
        task.launchPath = @"/bin/sh";
        task.arguments = @[@"-c", shellCommand];
        task.standardOutput = pipe;
        // launch后，task.processIdentifier 才是有效的值
        [task launch];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        [task waitUntilExit];
        
        result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    });
    
    NSLog(@"result = %@", result);
    return result;
}

- (void)executeCommand:(NSString *)command {
    NSPipe *pipe = [NSPipe pipe];
    
    NSString *shellCommand = [NSString stringWithFormat:@"/bin/sh -c '%@'", command];
    
    NSTask *task = [[NSTask alloc] init];
    task.currentDirectoryPath = self.projectTextField.stringValue;
    task.launchPath = @"/bin/sh";
    task.arguments = @[@"-c", shellCommand];
    task.standardOutput = pipe;
    [task launch];
    self.task = task;
    
    NSFileHandle *fileHandle = [pipe fileHandleForReading];
    [fileHandle readInBackgroundAndNotifyForModes:@[NSRunLoopCommonModes]];
}

- (BOOL)isLastCommandExecuteSuccess {
    NSString *result = [self resultStringOfExecuteCommand:@"echo $?"];
    result = [result stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    return [result isEqualToString:@"0"];
}


#pragma mark -

- (void)output:(NSNotification *)notification {
    NSFileHandle *fileHandle = notification.object;
    NSDictionary *userInfo = notification.userInfo;
    
    NSData *data = [userInfo valueForKey:NSFileHandleNotificationDataItem];
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"text = %@", text);
    
    if (self.task) {
        [fileHandle readInBackgroundAndNotifyForModes:@[NSRunLoopCommonModes]];
    }
}

- (void)taskDidTerminated:(NSNotification *)notification {
    NSLog(@"info11 = %@", notification.userInfo);
    NSTask *task = notification.object;
    if (task.processIdentifier == self.task.processIdentifier) {
        self.task = nil;
    }
}


#pragma mark - Button Action

// 项目根目录
- (IBAction)selectDirectoryButton1Pressed:(NSButton *)button {
    [self selectPathInTextField:self.projectTextField];
}

// 编译输出路径
- (IBAction)selectDirectoryButton2Pressed:(NSButton *)button {
    [self selectPathInTextField:self.buildTextField];
    self.buildPath = [NSString stringWithFormat:@"%@/build", self.buildTextField.stringValue];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *url = [NSURL fileURLWithPath:self.projectTextField.stringValue];
    NSDirectoryEnumerator<NSURL *> *urls = [fileManager enumeratorAtURL:url includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsSubdirectoryDescendants | NSDirectoryEnumerationSkipsHiddenFiles errorHandler:nil];
    
    BOOL isWorkspace = NO;
    for (NSURL *url in urls) {
        NSString *name = url.path.lastPathComponent;
        if ([name hasSuffix:@".xcworkspace"]) {
            isWorkspace = YES;
            self.projectName = [name stringByDeletingPathExtension];
            break;
        }
    }
}

// 第三方库路径
- (IBAction)selectDirectoryButton3Pressed:(NSButton *)button {
    [self selectPathInTextField:self.thirdPartyLibraryTextField];
}

// IPA Path
- (IBAction)selectDirectoryButton4Pressed:(NSButton *)button {
    [self selectPathInTextField:self.ipaTextField];
}

// Profile File
- (IBAction)selectDirectoryButton5Pressed:(NSButton *)button {
    [self selectFileInTextField:self.profileTextField];
}

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

- (void)showErrorAlertWithMessage:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"出错啦！";
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
