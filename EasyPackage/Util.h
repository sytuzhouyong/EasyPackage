//
//  Util.h
//  EasyPackage
//
//  Created by zhouyong on 16/5/11.
//  Copyright © 2016年 zhouyong. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef void (^SelectDialogHandler)(NSString *path);

#define SafeString(_s) (_s != nil ? _s : @"")

typedef NS_ENUM(NSUInteger, ZyxSelectDialogType) {
    ZyxSelectDialogTypeFile,
    ZyxSelectDialogTypeDirectory,
};

@interface Util : NSObject

+ (void)showAlertWithMessage:(NSString *)message;

+ (BOOL)selectPathInTextField:(NSTextField *)textField;
+ (BOOL)selectFileInTextField:(NSTextField *)textField;
+ (BOOL)openSelectDialogWithType:(ZyxSelectDialogType)type handler:(SelectDialogHandler)handler;

+ (BOOL)isRootPathValid:(NSString *)rootPath;
+ (BOOL)isVersionStringValid:(NSString *)version;

+ (NSString *)jsonStringFromObject:(id)object;

@end
