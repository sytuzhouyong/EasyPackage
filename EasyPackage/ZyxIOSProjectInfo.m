//
//  ZyxIOSProjectInfo.m
//  EasyPackage
//
//  Created by zhouyong on 4/15/16.
//  Copyright © 2016 zhouyong. All rights reserved.
//

#import "ZyxIOSProjectInfo.h"
#import "ZyxTaskUtil.h"

@implementation ZyxIOSProjectInfo

- (instancetype)initWithRootPath:(NSString *)rootPath {
    if (self = [super init]) {
        self.rootPath = rootPath;
        self.isWorkspace = [self judgeIsWorkspace];
        self.name = [self getProjectName];
        self.staticLibrariesPaths = [self getStaticLibrariesPaths];
        [self setupProjectConfigs];
    }
    return self;
}

- (BOOL)judgeIsWorkspace {
    NSString *shell = [NSString stringWithFormat:@"find %@ -name *.xcworkspace", self.rootPath];
    NSString *pathsString = [ZyxTaskUtil resultOfExecuteShell:shell];
    return pathsString.length > 0;
}

- (NSString *)getProjectName {
    NSString *shell = [NSString stringWithFormat:@"find %@ -name *.xcodeproj", self.rootPath];
    NSString *pathsString = [ZyxTaskUtil resultOfExecuteShell:shell];
    return [pathsString.lastPathComponent stringByDeletingPathExtension];
}

- (void)setupProjectConfigs {
    NSString *text = [ZyxTaskUtil resultOfExecuteShell:@"/usr/bin/xcodebuild -list"];
    
    NSScanner *scanner = [NSScanner scannerWithString:text];
    BOOL result = [scanner scanUpToString:@"Targets:" intoString:nil];
    result = [scanner scanString:@"Targets:" intoString:nil];
    NSString *targetsString = nil;
    result = [scanner scanUpToString:@"\n\n" intoString:&targetsString];
    
    result = [scanner scanUpToString:@"Configurations:" intoString:nil];
    [scanner scanString:@"Configurations:" intoString:nil];
    NSString *configurationsString = nil;
    result = [scanner scanUpToString:@"\n\n" intoString:&configurationsString];
    
    result = [scanner scanUpToString:@"Schemes:" intoString:nil];
    [scanner scanString:@"Schemes:" intoString:nil];
    NSString *schemesString = nil;
    result = [scanner scanUpToString:@"\n" intoString:&schemesString];
    
    self.targets = [targetsString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    self.configurations = [configurationsString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    self.schemes = [schemesString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}

- (NSArray<NSString *> *)getStaticLibrariesPaths {
    NSString *shell = [NSString stringWithFormat:@"find %@ -name *.a", self.rootPath];
    NSString *pathsString = [ZyxTaskUtil resultOfExecuteShell:shell];
    return [pathsString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}

@end
