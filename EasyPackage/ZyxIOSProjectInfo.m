//
//  ZyxIOSProjectInfo.m
//  EasyPackage
//
//  Created by zhouyong on 4/15/16.
//  Copyright © 2016 zhouyong. All rights reserved.
//

#import "ZyxIOSProjectInfo.h"
#import "ZyxTaskUtil.h"

const NSString *kPlistBuddy = @"/usr/libexec/PlistBuddy";

@implementation ZyxIOSProjectInfo

- (instancetype)initWithRootPath:(NSString *)rootPath {
    if (self = [super init]) {
        self.rootPath = rootPath;
        self.name = [self getProjectName];
        self.version = [self getProjectVersion];
        self.isWorkspace = [self judgeIsWorkspace];
        self.staticLibrariesPaths = [self getStaticLibrariesPaths];
        [self setupProjectConfigs];
    }
    return self;
}

- (BOOL)judgeIsWorkspace {
    NSString *shell = [NSString stringWithFormat:@"find %@ -name %@.xcworkspace", self.rootPath, self.name];
    NSString *pathsString = [ZyxTaskUtil resultOfExecuteShell:shell];
    return pathsString.length > 0;
}

- (NSString *)getProjectName {
    NSString *shell = [NSString stringWithFormat:@"find %@ -name *.xcodeproj", self.rootPath];
    NSString *pathsString = [ZyxTaskUtil resultOfExecuteShell:shell];
    return [pathsString.lastPathComponent stringByDeletingPathExtension];
}

- (NSString *)getProjectVersion {
    NSString *plistFilePath = [[self.rootPath stringByAppendingPathComponent:self.name] stringByAppendingPathComponent:@"Info.plist"];
    NSString *shell = [NSString stringWithFormat:@"%@ -c \"Print CFBundleVersion\" %@", kPlistBuddy, plistFilePath];
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
    NSString *configurationsString = nil;
    result &= [scanner scanUpToString:@"\n\n" intoString:&configurationsString];
    
    result &= [scanner scanUpToString:@"Schemes:" intoString:nil];
    [scanner scanString:@"Schemes:" intoString:nil];
    NSString *schemesString = nil;
    result &= [scanner scanUpToString:@"\n" intoString:&schemesString];
    NSLog(@"project configs %@", @(result));
    
    self.targets = [targetsString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    self.configurations = [configurationsString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    self.schemes = [schemesString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
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

+ (BOOL)isVersionStringValid:(NSString *)version {
    NSArray<NSString *> *items = [version componentsSeparatedByString:@"."];
    if (items.count > 4) {
        return NO;
    }
    
    NSString *regex = @"^[0-9]+$";
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
    
    for (NSString *item in items) {
        if (![pred evaluateWithObject:item]) {
            return NO;
        }
        if (item.intValue < 0) {
            return NO;
        }
    }
    
    return YES;
}

@end
