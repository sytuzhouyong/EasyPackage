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

@implementation ZyxPackageConfig

- (void)commonInit {
    self.name = @"";
    self.rootPath = @"";
    self.configuration = @"";
    self.target = @"";
    self.scheme = @"";
    self.buildPath = @"";
    self.ipaPath = @"";
    self.codesign = @"";
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
        self.codesign = dict[@"codesign"];
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

// "ResourceRules.plist": cannot read resources 错误，需要工程内添加$(SDKROOT)/ResourceRules.plist
- (NSTask *)buildTask {
    NSMutableString *commonCommand = [NSMutableString stringWithFormat:@"-configuration %@ -sdk iphoneos OBJROOT=%@ TARGET_BUILD_DIR=%@ ", _configuration, _buildPath, _buildPath];
    // @"CODE_SIGN_IDENTITY=iphoneos/ResourceRules.plist \\"
    
    if (_codesign.length > 0) {
        [commonCommand appendFormat:@"CODE_SIGN_IDENTITY=\"%@\" ", _codesign];
    }
    if (_provisionProfilePath.length > 0) {
        NSString *UUID = [self uuidFromProvisionProfileAtPath:self.provisionProfilePath];
        [commonCommand appendFormat:@"PROVISIONING_PROFILE=%@ ", UUID];
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
    if (_codesign.length > 0 && _provisionProfilePath.length > 0) {
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

- (NSString *)uuidFromProvisionProfileAtPath:(NSString *)path {
    NSString *shell = [NSString stringWithFormat:@"/usr/libexec/PlistBuddy -c 'Print :UUID' /dev/stdin <<< $(security cms -D -i %@)", path];
    NSString *result = [ZyxTaskUtil resultOfExecuteShell:shell];
    return result;
}

- (NSDictionary *)jsonValues {
    return @{@"name":       SafeString(self.name),
             @"rootPath":   SafeString(self.rootPath),
             @"configuration": SafeString(self.configuration),
             @"target":     SafeString(self.target),
             @"scheme":     SafeString(self.scheme),
             @"ipaPath":    SafeString(self.ipaPath),
             @"codesign":   SafeString(self.codesign),
             @"provisionProfilePath": SafeString(self.provisionProfilePath),
             };
}


@end
