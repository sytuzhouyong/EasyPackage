//
//  Util.m
//  EasyPackage
//
//  Created by zhouyong on 16/5/11.
//  Copyright © 2016年 zhouyong. All rights reserved.
//

#import "Util.h"
#import "ZyxTaskUtil.h"

@implementation Util

+ (void)showAlertWithMessage:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"提示";
    alert.informativeText = message;
    [alert addButtonWithTitle:@"确定"];
    [alert runModal];
}

+ (BOOL)openSelectDialogWithType:(ZyxSelectDialogType)type handler:(SelectDialogHandler)handler {
    NSOpenPanel* dialog = [NSOpenPanel openPanel];
    dialog.allowsMultipleSelection = NO;
    
    switch (type) {
        case ZyxSelectDialogTypeFile:
            dialog.canChooseFiles = YES;
            dialog.canChooseDirectories = NO;
            break;
        case ZyxSelectDialogTypeDirectory:
            dialog.canChooseFiles = NO;
            dialog.canChooseDirectories = YES;
            dialog.canCreateDirectories = YES;
            break;
        default:
            break;
    }
    
    BOOL selected = [dialog runModal] == NSModalResponseOK;
    if (selected) {
        NSURL *url = dialog.URLs.firstObject;
        NSString *path = url.path;
        if (handler != nil) {
            handler(path);
        }
    }
    return selected;
}

+ (BOOL)selectPathInTextField:(NSTextField *)textField {
    return [self openSelectDialogWithType:ZyxSelectDialogTypeDirectory handler:^(NSString *path) {
        if (path != nil) {
            textField.stringValue = path;
        }
    }];
}

+ (BOOL)selectFileInTextField:(NSTextField *)textField {
    return [self openSelectDialogWithType:ZyxSelectDialogTypeFile handler:^(NSString *path) {
        if (path != nil) {
            textField.stringValue = path;
        }
    }];
}

+ (BOOL)isRootPathValid:(NSString *)rootPath {
    NSString *path = [rootPath stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    if (path.length == 0) {
        return NO;
    }
    
    NSString *shell = [NSString stringWithFormat:@"find %@ -name *.xcodeproj", rootPath];
    NSString *pathsString = [ZyxTaskUtil resultOfExecuteShell:shell];
    return pathsString.length > 0;
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

+ (NSString *)jsonStringFromObject:(id)object {
    if ([NSJSONSerialization isValidJSONObject:object]) {
        NSError *error;
        NSData *data = [NSJSONSerialization dataWithJSONObject:object options:NSJSONWritingPrettyPrinted error:&error];
        if (error != nil) {
            NSLog(@"object[%@] to json failed, error = %@", object, error);
            return nil;
        }
        
        NSString *jsonString =[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return jsonString;
    }
    return nil;
}

@end
