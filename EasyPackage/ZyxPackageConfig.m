//
//  ZyxPackageConfig.m
//  EasyPackage
//
//  Created by zhouyong on 4/15/16.
//  Copyright © 2016 zhouyong. All rights reserved.
//

#import "ZyxPackageConfig.h"
#import "ZyxTaskUtil.h"
#import "Util.h"

@implementation ZyxPackageConfig {
    NSString *_codesign;
    NSString *_uuid;
}

- (void)commonInit {
    self.name = @"";
    self.rootPath = @"";
    self.configuration = @"";
    self.target = @"";
    self.scheme = @"";
    self.buildPath = @"";
    self.ipaPath = @"";
    self.provisionProfilePath = @"";
    self.project = [ZyxIOSProjectInfo new];
}

- (instancetype)init {
    if (self = [super init]) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithRootPath:(NSString *)rootPath {
    if (self = [super init]) {
        [self commonInit];
        self.rootPath = rootPath;
        
        if (rootPath.length > 0) {
            self.project = [[ZyxIOSProjectInfo alloc] initWithRootPath:rootPath];
            self.buildPath = [rootPath stringByAppendingPathComponent:@"build"];
            self.ipaPath = [rootPath stringByAppendingPathComponent:@"ipa"];
        }
    }
    return self;
}

- (instancetype)initWithDict:(NSDictionary *)dict {
    if (self = [super init]) {
        self.name = dict[@"name"];
        self.rootPath = dict[@"rootPath"];
        self.configuration = dict[@"configuration"];
        self.target = dict[@"target"];
        self.scheme = dict[@"scheme"];
        self.buildPath = dict[@"buildPath"];
        self.ipaPath = dict[@"ipaPath"];
        self.provisionProfilePath = dict[@"provisionProfilePath"];
        
        if (self.rootPath.length > 0) {
            self.project = [[ZyxIOSProjectInfo alloc] initWithRootPath:self.rootPath];
        }
    }
    return self;
}

- (void)setRootPath:(NSString *)rootPath {
    _rootPath = rootPath;
    
    self.project = [[ZyxIOSProjectInfo alloc] initWithRootPath:rootPath];
    self.buildPath = [rootPath stringByAppendingPathComponent:@"build"];
    self.ipaPath = [rootPath stringByAppendingPathComponent:@"ipa"];
}

- (void)setProvisionProfilePath:(NSString *)provisionProfilePath {
    _provisionProfilePath = provisionProfilePath;
    if (provisionProfilePath.length == 0) {
        return;
    }
    
    NSArray<NSString *> *infos = [self infoFromProvisionProfileAtPath:provisionProfilePath];
    if (infos != nil) {
        _codesign = infos[0];
        _uuid = infos[1];
    }
}

// "ResourceRules.plist": cannot read resources 错误，需要工程内添加$(SDKROOT)/ResourceRules.plist
- (NSTask *)buildTask {
    NSMutableString *commonCommand = [NSMutableString stringWithFormat:@"-configuration %@ -sdk iphoneos CODE_SIGN_RESOURCE_RULES_PATH=\"iphoneos/ResourceRules.plist\" OBJROOT=%@ TARGET_BUILD_DIR=%@ ", _configuration, _buildPath, _buildPath];
    // @" \\"
    
    if (_provisionProfilePath.length > 0) {
        [commonCommand appendFormat:@"CODE_SIGN_IDENTITY=\"%@\" PROVISIONING_PROFILE=%@ ", _codesign, _uuid];
    }
    
    NSString *differentParamString = nil;
    if (_project.isWorkspace) {
        differentParamString = [NSString stringWithFormat:@"-workspace %@.xcworkspace -scheme %@", _project.name, _scheme];
    } else {
        differentParamString = [NSString stringWithFormat:@"-target %@", _target];
    }
    
    NSString *shell = [NSString stringWithFormat:@"/usr/bin/xcodebuild %@ %@", differentParamString, commonCommand];
    return [ZyxTaskUtil taskWithShell:shell path:self.rootPath];
}

- (NSTask *)makeIPATask {
    NSMutableString *shell = [NSMutableString stringWithFormat:@"/usr/bin/xcrun -sdk iphoneos PackageApplication -v %@/%@.app -o %@/%@-%@.ipa", _buildPath, _project.name, _ipaPath, _project.name, _project.version];
    if (_provisionProfilePath.length > 0) {
        [shell appendFormat:@"--embed %@ --sign \"%@\"", _provisionProfilePath, _codesign];
    }
    return [ZyxTaskUtil taskWithShell:shell path:self.rootPath];
}

- (NSTask *)copyStaticLibrariesTask {
    NSMutableString *shell = [NSMutableString string];
    for (NSString *path in _project.staticLibrariesPaths) {
        [shell appendFormat:@"cp %@ %@; ", path, self.buildPath];
    }
    if (shell.length == 0) {
        [shell appendString:@"echo \"no static libraries found.\""];
    }
    return [ZyxTaskUtil taskWithShell:shell];
}

#pragma mark - Util Methods

- (NSArray<NSString *> *)infoFromProvisionProfileAtPath:(NSString *)path {
    NSString *dir = [path stringByDeletingLastPathComponent];
    NSString *tempPlistPath = @"temp.plist";
    NSString *relativePath = [path lastPathComponent];
    
    NSString *shell = [NSString stringWithFormat:@"rm %@", tempPlistPath];
    NSString *result = [ZyxTaskUtil resultOfExecuteShell:shell atPath:dir];
    if (result.length != 0) {
        return nil;
    }
    
    shell = [NSString stringWithFormat:@"security cms -D -i %@>%@", relativePath, tempPlistPath];
    result = [ZyxTaskUtil resultOfExecuteShell:shell atPath:dir];
    if (result.length != 0) {
        return nil;
    }
    
    shell = [NSString stringWithFormat:@"echo `/usr/libexec/PlistBuddy -c 'Print DeveloperCertificates:0' %@ | openssl x509 -subject -inform der | head -n 1`", tempPlistPath];
    NSString *infoString = [ZyxTaskUtil resultOfExecuteShell:shell atPath:dir];
    if (infoString.length == 0) {
        return nil;
    }
    
    // codesign
    shell = [NSString stringWithFormat:@"echo `echo \"%@\" | cut -d \"/\" -f3 | cut -d \"=\" -f2`", infoString];
    NSString *codesign = [ZyxTaskUtil resultOfExecuteShell:shell atPath:dir];
    if (codesign.length == 0) {
        return nil;
    }
    codesign = [codesign stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
    // uuid
    shell = [NSString stringWithFormat:@"/usr/libexec/PlistBuddy -c 'Print :UUID' %@", tempPlistPath];
    NSString *uuid = [ZyxTaskUtil resultOfExecuteShell:shell atPath:dir];
    if (uuid.length == 0) {
        return nil;
    }
    uuid = [uuid stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
    shell = [NSString stringWithFormat:@"rm %@", tempPlistPath];
    result = [ZyxTaskUtil resultOfExecuteShell:shell atPath:dir];
    
    return @[codesign, uuid];
}

- (NSDictionary *)jsonValues {
    return @{@"name":       SafeString(self.name),
             @"rootPath":   SafeString(self.rootPath),
             @"configuration": SafeString(self.configuration),
             @"target":     SafeString(self.target),
             @"scheme":     SafeString(self.scheme),
             @"ipaPath":    SafeString(self.ipaPath),
             @"provisionProfilePath": SafeString(self.provisionProfilePath),
             };
}

+ (NSMutableArray<ZyxPackageConfig *> *)localConfigs {
    NSString *configsFilePath = [[NSBundle mainBundle] pathForResource:@"configs" ofType:@"plist"];
    
    NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:configsFilePath];
    NSArray *configDicts = plist[@"configs"];
    if (configDicts == nil) {
        return nil;
    }
    
    NSMutableArray *configs = [NSMutableArray array];
    for (NSDictionary *dict in configDicts) {
        ZyxPackageConfig *config = [[ZyxPackageConfig alloc] initWithDict:dict];
        [configs addObject:config];
    }
    return configs;
}

@end
