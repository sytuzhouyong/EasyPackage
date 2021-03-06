//
//  ZyxIOSProjectInfo.h
//  EasyPackage
//
//  Created by zhouyong on 4/15/16.
//  Copyright © 2016 zhouyong. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EasyFMDB.h"

@interface ZyxIOSProjectInfo : ZyxBaseModel

@property (nonatomic, copy  ) NSString *rootPath;
@property (nonatomic, assign) BOOL isWorkspace;
@property (nonatomic, copy  ) NSString *name;
@property (nonatomic, copy  ) NSString *version;
@property (nonatomic, copy  ) NSArray<NSString *> *targets;
@property (nonatomic, copy  ) NSArray<NSString *> *configurations;
@property (nonatomic, copy  ) NSArray<NSString *> *schemes;
@property (nonatomic, copy  ) NSArray<NSString *> *staticLibrariesPaths;

- (instancetype)initWithRootPath:(NSString *)rootPath;

- (BOOL)setProjectVersion:(NSString *)version;

@end
