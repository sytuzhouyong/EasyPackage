//
//  PackageViewController.h
//  EasyPackage
//
//  Created by zhouyong on 16/3/6.
//  Copyright © 2016年 zhouyong. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PackageViewController : NSViewController

@property (nonatomic, strong) IBOutlet NSTextField *projectRootDirTextField;
@property (nonatomic, strong) IBOutlet NSTextField *versionTextField;
@property (nonatomic, strong) IBOutlet NSComboBox *configurationsComboBox;
@property (nonatomic, strong) IBOutlet NSComboBox *targetsComboBox;
@property (nonatomic, strong) IBOutlet NSComboBox *schemesComboBox;
@property (nonatomic, strong) IBOutlet NSTextField *ipaTextField;
@property (nonatomic, strong) IBOutlet NSTextField *profileTextField;
@property (nonatomic, strong) IBOutlet NSTextField *indicatorLabel;
@property (nonatomic, strong) IBOutlet NSProgressIndicator *progressIndicator;
@property (nonatomic, strong) IBOutlet NSButton *packageButton;
@property (nonatomic, strong) IBOutlet NSButton *cancelButton;

- (void)addConfigMenuItemWithName:(NSString *)name;
- (void)updateConfigMenuItemAtIndex:(NSInteger)index withName:(NSString *)name;

@end

