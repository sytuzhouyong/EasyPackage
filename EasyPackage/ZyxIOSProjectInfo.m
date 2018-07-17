//
//  ZyxIOSProjectInfo.m
//  EasyPackage
//
//  Created by zhouyong on 4/15/16.
//  Copyright © 2016 zhouyong. All rights reserved.
//

#import "ZyxIOSProjectInfo.h"
#import "ZyxTaskUtil.h"
#import "Util.h"

const NSString *kPlistBuddy = @"/usr/libexec/PlistBuddy";

@implementation ZyxIOSProjectInfo

+ (void)load {
    NSLog(@"registe model : %@", NSStringFromClass(self.class));
    [self registeModel:self.class];
}

+ (NSArray *)ignoredProperties {
    return @[@"targets", @"configurations", @"schemes", @"staticLibrariesPaths"];
}

- (instancetype)init {
    if (self = [super init]) {
        self.rootPath = @"";
        self.name = @"";
        self.version = @"";
    }
    return self;
}

- (instancetype)initWithRootPath:(NSString *)rootPath {
    if (self = [super init]) {
        self.rootPath = rootPath;
    }
    return self;
}

- (void)setRootPath:(NSString *)rootPath {
    _rootPath = [rootPath copy];
    
    if ([Util isRootPathValid:rootPath]) {
        // TODO: 待优化，耗时太长
        self.name = [self getProjectName];
        self.version = [self getProjectVersion];
        self.isWorkspace = [self judgeIsWorkspace];
        self.staticLibrariesPaths = [self getStaticLibrariesPaths];
        [self setupProjectConfigs];
    } else {
        NSLog(@"oh no, root path(%@) is invalid", rootPath);
    }
}

- (BOOL)judgeIsWorkspace {
    NSString *shell = [NSString stringWithFormat:@"find %@ -name %@.xcworkspace", self.rootPath, self.name];
    NSString *pathsString = [ZyxTaskUtil resultOfExecuteShell:shell];
    return pathsString.length > 0;
}

- (NSString *)getProjectName {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSDirectoryEnumerator<NSString *> *enumerator = [manager enumeratorAtPath:self.rootPath];
    NSString *filePath = @"";
    while (nil != (filePath = [enumerator nextObject])) {
        if ([filePath hasSuffix:@".xcworkspace"] || [filePath hasSuffix:@".xcodeproj"]) {
            return [filePath.lastPathComponent stringByDeletingPathExtension];
        }
    }
    NSLog(@"not find project file");
    return @"";
}

- (NSString *)getProjectVersion {
    NSString *plistFilePath = [[self.rootPath stringByAppendingPathComponent:self.name] stringByAppendingPathComponent:@"Info.plist"];
    NSString *shell = [NSString stringWithFormat:@"%@ -c \"Print CFBundleShortVersionString\" %@", kPlistBuddy, plistFilePath];
    NSString *version = [ZyxTaskUtil resultOfExecuteShell:shell];
    version  = [version stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return version;
}

- (BOOL)setProjectVersion:(NSString *)version {
    NSString *plistFilePath = [[self.rootPath stringByAppendingPathComponent:self.name] stringByAppendingPathComponent:@"Info.plist"];
    NSString *shell = [NSString stringWithFormat:@"%@ -c \"Set:CFBundleVersion %@\" %@", kPlistBuddy, version, plistFilePath];
    NSString *result = [ZyxTaskUtil resultOfExecuteShell:shell];
    return result.length == 0;
}

- (void)setupProjectConfigs {
    NSString *text = [ZyxTaskUtil resultOfExecuteShell:@"/usr/bin/xcodebuild -list" atPath:self.rootPath];
    
    NSScanner *scanner = [NSScanner scannerWithString:text];
    BOOL result = YES;
    result &= [scanner scanUpToString:@"Targets:" intoString:nil];
    result &= [scanner scanString:@"Targets:" intoString:nil];
    NSString *targetsString = nil;
    result &= [scanner scanUpToString:@"\n\n" intoString:&targetsString];
    
    result &= [scanner scanUpToString:@"Configurations:" intoString:nil];
    [scanner scanString:@"Configurations:" intoString:nil];
    NSString *configsString = nil;
    result &= [scanner scanUpToString:@"\n\n" intoString:&configsString];
    
    result &= [scanner scanUpToString:@"Schemes:" intoString:nil];
    [scanner scanString:@"Schemes:" intoString:nil];
    NSString *schemesString = nil;
    result &= [scanner scanUpToString:@"\n" intoString:&schemesString];
    
    NSString *seperater = @"\n        ";
    self.configurations = [configsString componentsSeparatedByString:seperater];
    self.schemes = [schemesString componentsSeparatedByString:seperater];
    
    NSArray *allTargets = [targetsString componentsSeparatedByString:seperater];
    NSMutableArray *targets = [NSMutableArray array];
    for (NSString *item in allTargets) {
        // 过滤掉所有Tests的target
        if (![item hasSuffix:@"Tests"]) {
            [targets addObject:item];
        }
    }
    self.targets = targets;
}

- (NSArray<NSString *> *)getStaticLibrariesPaths {
    NSString *shell = [NSString stringWithFormat:@"find %@ -name *.a", self.rootPath];
    NSString *pathsString = [ZyxTaskUtil resultOfExecuteShell:shell];
    
    NSCharacterSet *ignoreSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    pathsString = [pathsString stringByTrimmingCharactersInSet:ignoreSet];
    if (pathsString.length > 0)
        return [pathsString componentsSeparatedByCharactersInSet:ignoreSet];
    else
        return @[];
}

@end
