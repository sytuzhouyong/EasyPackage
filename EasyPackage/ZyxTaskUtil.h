//
//  ZyxTaskUtil.h
//  EasyPackage
//
//  Created by zhouyong on 4/15/16.
//  Copyright © 2016 zhouyong. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZyxTaskUtil : NSObject

+ (instancetype)sharedInstance;

+ (NSTask *)taskWithShell:(NSString *)shell;
+ (NSTask *)taskWithShell:(NSString *)shell path:(NSString *)path;

+ (NSString *)resultOfExecuteShell:(NSString *)shell;
+ (NSString *)resultOfExecuteShell:(NSString *)shell atPath:(NSString *)path;

@end
