//
//  ZyxTaskUtil.m
//  EasyPackage
//
//  Created by zhouyong on 4/15/16.
//  Copyright © 2016 zhouyong. All rights reserved.
//

#import "ZyxTaskUtil.h"

@implementation ZyxTaskUtil

+ (instancetype)sharedInstance {
    static ZyxTaskUtil *util = nil;
    
    if (util != nil) {
        return util;
    }
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        util = [[ZyxTaskUtil alloc] init];
    });
    return util;
}

+ (NSTask *)taskWithShell:(NSString *)shell {
    NSTask *task = [[NSTask alloc] init];
    task.currentDirectoryPath = @"~/";
    task.launchPath = @"/bin/sh";
    task.arguments = @[@"-c", shell];
    task.standardOutput = [NSPipe pipe];
    return task;
}

+ (NSTask *)taskWithShell:(NSString *)shell path:(NSString *)path {
    NSTask *task = [[NSTask alloc] init];
    task.currentDirectoryPath = path;
    task.launchPath = @"/bin/sh";
    task.arguments = @[@"-c", shell];
    task.standardOutput = [NSPipe pipe];
    return task;
}

+ (NSString *)resultOfExecuteShell:(NSString *)shell {
    NSTask *task = [ZyxTaskUtil taskWithShell:shell];
    [task launch];
    [task waitUntilExit];
    NSData *data = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return text;
}

@end
