//
//  ZyxPackageConfig.h
//  EasyPackage
//
//  Created by zhouyong on 4/15/16.
//  Copyright © 2016 zhouyong. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZyxIOSProjectInfo.h"

@interface ZyxPackageConfig : ZyxBaseModel

@property (nonatomic, strong) ZyxIOSProjectInfo *project;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *rootPath;
@property (nonatomic, copy) NSString *configuration;
@property (nonatomic, copy) NSString *target;
@property (nonatomic, copy) NSString *scheme;
@property (nonatomic, copy) NSString *buildPath;
@property (nonatomic, copy) NSString *ipaPath;
@property (nonatomic, copy) NSString *provisionProfilePath;

- (instancetype)initWithRootPath:(NSString *)rootPath;

- (NSTask *)buildTask;
- (NSTask *)makeIPATask;
- (NSTask *)copyStaticLibrariesTask;

+ (NSArray<ZyxPackageConfig *> *)localConfigs;

@end
