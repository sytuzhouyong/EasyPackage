//
//  ZyxPackageConfig.m
//  EasyPackage
//
//  Created by zhouyong on 4/15/16.
//  Copyright © 2016 zhouyong. All rights reserved.
//

#import "ZyxPackageConfig.h"

@implementation ZyxPackageConfig

- (instancetype)initWithRootPath:(NSString *)rootPath {
    if (self = [super init]) {
        self.project = [[ZyxIOSProjectInfo alloc] initWithRootPath:rootPath];
        self.rootPath = rootPath;
        self.buildPath = [rootPath stringByAppendingPathComponent:@"build"];
        self.ipaPath = [rootPath stringByAppendingPathComponent:@"ipa"];
    }
    return self;
}

@end
