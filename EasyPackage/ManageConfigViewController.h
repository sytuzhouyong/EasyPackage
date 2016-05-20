//
//  ManageConfigViewController.h
//  EasyPackage
//
//  Created by zhouyong on 16/5/3.
//  Copyright © 2016年 zhouyong. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PackageViewController.h"

@interface ManageConfigViewController : NSViewController

@property (nonatomic, strong) IBOutlet NSTableView *tableView;
@property (nonatomic, strong) IBOutlet NSTextField *nameTextField;
@property (nonatomic, strong) IBOutlet NSTextField *rootPathTextField;
@property (nonatomic, strong) IBOutlet NSTextField *versionTextField;
@property (nonatomic, strong) IBOutlet NSComboBox *configurationsBox;
@property (nonatomic, strong) IBOutlet NSComboBox *targetsBox;
@property (nonatomic, strong) IBOutlet NSComboBox *schemesBox;
@property (nonatomic, strong) IBOutlet NSTextField *ipaPathTextField;
@property (nonatomic, strong) IBOutlet NSTextField *provisionProfilePathTextField;

@property (nonatomic, weak) PackageViewController *packageVC;

@end
