//
//  PackageViewController.h
//  EasyPackage
//
//  Created by zhouyong on 16/3/6.
//  Copyright © 2016年 zhouyong. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ZyxPackageConfig.h"

@interface PackageViewController : NSViewController

@property (nonatomic, strong) IBOutlet NSTextField *rootPathTextField;
@property (nonatomic, strong) IBOutlet NSTextField *versionTextField;
@property (nonatomic, strong) IBOutlet NSComboBox *configurationsComboBox;
@property (nonatomic, strong) IBOutlet NSComboBox *targetsComboBox;
@property (nonatomic, strong) IBOutlet NSComboBox *schemesComboBox;
@property (nonatomic, strong) IBOutlet NSTextField *ipaPathTextField;
@property (nonatomic, strong) IBOutlet NSTextField *provisionProfilePathTextField;
@property (nonatomic, strong) IBOutlet NSTextField *indicatorLabel;
@property (nonatomic, strong) IBOutlet NSProgressIndicator *progressIndicator;
@property (nonatomic, strong) IBOutlet NSButton *packageButton;
@property (nonatomic, strong) IBOutlet NSButton *cancelButton;

@property (nonatomic, strong) NSMutableArray<ZyxPackageConfig *> *configs;

- (void)addConfigMenuItemWithName:(NSString *)name;
- (void)updateConfigMenuItemAtIndex:(NSInteger)index withName:(NSString *)name;

@end

