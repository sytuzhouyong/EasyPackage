//
//  ViewController.m
//  TestOSX
//
//  Created by zhouyong on 16/3/6.
//  Copyright © 2016 zhouyong. All rights reserved.
//

#import "ViewController.h"

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
@property (nonatomic, strong) IBOutlet NSTextView *outputTextView;
@property (nonatomic, strong) IBOutlet NSButton *packageButton;

@property (nonatomic, strong) NSMutableArray<NSTask *> *tasks;

@property (nonatomic, copy) NSString *projectRootPath;
@property (nonatomic, copy) NSString *projectName;
@property (nonatomic, copy) NSString *buildPath;
@property (nonatomic, copy) NSString *ipaPath;
@property (nonatomic, copy) NSString *codeSign;
@property (nonatomic, copy) NSString *provisionProfilePath;
@property (nonatomic, strong) NSArray<NSString *> *libraryPaths;
@property (nonatomic, assign) BOOL isWorkspace;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(output:) name:NSFileHandleReadCompletionNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskDidTerminated:) name:NSTaskDidTerminateNotification object:nil];
}

// ResourceRules.plist 在Xcode7以后已经不准使用了，否则AppStore不让上架，但是这个是苹果的一个bug，不用又打包不通过
// 所以找到如下方法，打开 /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/PackageApplication 脚本,
// 找到 --resource-rules= , 删除这个参数，打包就没有错误了


- (void)makePackageTasks {
    NSString *rmBuildCommand = [NSString stringWithFormat:@"rm -rf %@", _buildPath];
    NSString *cleanProjectCommand = @"/usr/bin/xcodebuild clean -configuration Release";
    
    NSString *buildCommand = [self buildCommand];
    NSString *makeIPAPathCommand = [NSString stringWithFormat:@"mkdir -p %@", self.ipaPath];
    NSString *makeIPACommand = [self makeIPACommand];
    
    NSArray *tasks = @[[self asyncTaskWithShellCommand:rmBuildCommand],
                       [self asyncTaskWithShellCommand:cleanProjectCommand],
                       [self asyncTaskWithShellCommand:buildCommand],
                       [self copyStaticLibrariesTask],
                       [self asyncTaskWithShellCommand:makeIPAPathCommand],
                       [self asyncTaskWithShellCommand:makeIPACommand],
                       [self asyncTaskWithShellCommand:rmBuildCommand],
                       ];
    self.tasks = [NSMutableArray arrayWithArray:tasks];
}

#pragma mark - Make Complex Command

// "ResourceRules.plist": cannot read resources 错误，需要工程内添加$(SDKROOT)/ResourceRules.plist
- (NSString *)buildCommand {
    NSMutableString *commonCommand = [NSMutableString stringWithFormat:@"-configuration Release -sdk iphoneos OBJROOT=%@ TARGET_BUILD_DIR=%@ ", _buildPath, _buildPath];
        // @"CODE_SIGN_IDENTITY=iphoneos/ResourceRules.plist \\"
    
    if (_codeSign.length > 0 && _provisionProfilePath.length > 0) {
        NSString *UUID = [self UUIDFromProvisionProfileAtPath:self.provisionProfilePath];
        [commonCommand appendFormat:@"CODE_SIGN_IDENTITY=\"%@\" PROVISIONING_PROFILE=%@ ", _codeSign, UUID];
    }
    
    NSString *differentParamString = nil;
    if (self.isWorkspace) {
        differentParamString = [NSString stringWithFormat:@"-workspace %@.xcworkspace -scheme %@", _projectName, _projectName];
    } else {
        differentParamString = [NSString stringWithFormat:@"-target %@", _projectName];
    }
    
    NSString *command = [NSString stringWithFormat:@"/usr/bin/xcodebuild %@ %@", differentParamString, commonCommand];
    return command;
}

- (NSString *)makeIPACommand {
    NSMutableString *command = [NSMutableString stringWithFormat:@"/usr/bin/xcrun -sdk iphoneos PackageApplication -v %@/%@.app -o %@/%@.ipa", _buildPath, _projectName, _ipaPath, _projectName];
    if (_codeSign.length > 0 && _provisionProfilePath.length > 0) {
        [command appendFormat:@"--embed %@ --sign \"%@\"", _provisionProfilePath, _codeSign];
    }
    return command;
}

- (NSTask *)copyStaticLibrariesTask {
    NSMutableString *commandString = [NSMutableString string];
    for (NSString *path in self.libraryPaths) {
        [commandString appendFormat:@"cp %@ %@; ", path, self.buildPath];
    }
    if (commandString.length == 0) {
        [commandString appendString:@"echo \"no static libraries found.\""];
    }
    return [self asyncTaskWithShellCommand:commandString];
}

#pragma mark - Uitl Methods

- (void)executeTaskAsync:(NSTask *)task {
    [task launch];
    NSFileHandle *fileHandle = [task.standardOutput fileHandleForReading];
    [fileHandle readInBackgroundAndNotifyForModes:@[NSRunLoopCommonModes]];
}

- (NSString *)executeTaskSync:(NSTask *)task {
    [task launch];
    
    NSData *data = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];
    [task waitUntilExit];
    
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return text;
}

- (NSTask *)asyncTaskWithShellCommand:(NSString *)shell {
    NSTask *task = [[NSTask alloc] init];
    task.currentDirectoryPath = self.projectRootPath;
    task.launchPath = @"/bin/sh";
    task.arguments = @[@"-c", shell];
    task.standardOutput = [NSPipe pipe];
    return task;
}

- (void)searchStaticLibraries {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *url = [NSURL fileURLWithPath:self.projectRootPath];
    NSDirectoryEnumerator<NSURL *> *urls = [fileManager enumeratorAtURL:url includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsPackageDescendants | NSDirectoryEnumerationSkipsHiddenFiles errorHandler:nil];
    
    NSMutableArray<NSString *> *libraryPaths = [NSMutableArray array];
    for (NSURL *url in urls) {
        NSString *path = url.path;
        if ([path.pathExtension isEqualToString:@"a"]) {
            NSLog(@"path = %@", path);
            [libraryPaths addObject:path];
        }
    }
    self.libraryPaths = libraryPaths;
}

- (void)getProjectInfo {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *url = [NSURL fileURLWithPath:self.projectRootPath];
    NSDirectoryEnumerator<NSURL *> *urls = [fileManager enumeratorAtURL:url includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsSubdirectoryDescendants | NSDirectoryEnumerationSkipsHiddenFiles errorHandler:nil];
    
    NSString *workspaceName = @"", *projectName = @"";
    for (NSURL *url in urls) {
        NSString *name = url.path.lastPathComponent;
        if ([name hasSuffix:@".xcworkspace"]) {
            workspaceName = [name stringByDeletingPathExtension];
            continue;
        }
        if ([name hasSuffix:@".xcodeproj"]) {
            projectName = [name stringByDeletingPathExtension];
            continue;
        }
    }
    self.projectName = projectName;
    self.isWorkspace = workspaceName.length > 0 && projectName.length > 0;
}

- (NSString *)UUIDFromProvisionProfileAtPath:(NSString *)path {
    NSString *command = [NSString stringWithFormat:@"/usr/libexec/PlistBuddy -c 'Print :UUID' /dev/stdin <<< $(security cms -D -i %@)", path];
    
    NSTask *task = [[NSTask alloc] init];
    task.currentDirectoryPath = @"~/";
    task.launchPath = @"/bin/sh";
    task.arguments = @[@"-c", command];
    task.standardOutput = [NSPipe pipe];
    [task launch];
    
    NSData *data = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];
    [task waitUntilExit];
    
    NSString *result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"result = %@", result);
    return result;
}

#pragma mark - NSTask output notification

- (void)output:(NSNotification *)notification {
    NSFileHandle *fileHandle = notification.object;
    
    NSData *data = nil;
    while ((data = fileHandle.availableData) && data.length > 0) {
        NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"text = %@", text);
        
        NSString *string = [NSString stringWithFormat:@"%@%@", self.outputTextView.string, text];
        self.outputTextView.string = string;
        // [self.outputTextView scrollRangeToVisible:NSMakeRange(NSUIntegerMax, 1)];
    }
}

BOOL needTerminateTask = NO;

- (void)taskDidTerminated:(NSNotification *)notification {
    static int index = 1;
    NSTask *task = notification.object;
    int status = [task terminationStatus];
    
    if (status == 0) {
        NSLog(@"Task[%@] succeeded.", @(index));
        [self.tasks removeObject:task];
        
        if (self.tasks.count == 0) {
            self.packageButton.enabled = YES;
            index = 1;
            return;
        } else if (!needTerminateTask) {
            [self executeTaskAsync:self.tasks.firstObject];
        } else {
            index = 1;
        }
    } else {
        needTerminateTask = YES;
        
        NSLog(@"Task[%@] failed. task = %@", @(index), task);
        self.packageButton.enabled = YES;
        [self executeTaskAsync:self.tasks.lastObject];
    }
    index++;
}

#pragma mark - Button Action

- (IBAction)packageButtonPressed:(NSButton *)button {
    if (self.buildPath.length == 0) {
        [self showErrorAlertWithMessage:@"请设置工程根目录"];
        return;
    }
    
    button.enabled = NO;
    self.outputTextView.string = @"";
    self.codeSign = self.codeSignTextField.stringValue;
    
    [self makePackageTasks];
    
    NSTask *task = self.tasks.firstObject;
    [self executeTaskAsync:task];
}

// 项目根目录
- (IBAction)selectProjectRootPath:(NSButton *)button {
    [self selectPathInTextField:self.projectRootDirTextField];
    self.projectRootPath = self.projectRootDirTextField.stringValue;
    self.buildPath = [self.projectRootPath stringByAppendingPathComponent:@"build"];
    self.ipaPath = [self.projectRootPath stringByAppendingPathComponent:@"ipa"];
    
    [self getProjectInfo];
    [self searchStaticLibraries];
}

// IPA Path
- (IBAction)selectIPAPathButtonPressed:(NSButton *)button {
    [self selectPathInTextField:self.ipaTextField];
    NSString *path = self.ipaTextField.stringValue;
    if (path.length != 0) {
        self.ipaPath = path;
    }
}

// Profile File
- (IBAction)selectProvisionProfilePathButtonPressed:(NSButton *)button {
    [self selectFileInTextField:self.profileTextField];
    NSString *path = self.profileTextField.stringValue;
    if (path.length != 0) {
        self.provisionProfilePath = path;
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
