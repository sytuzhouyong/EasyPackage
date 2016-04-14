//
//  ViewController.h
//  EasyPackage
//
//  Created by zhouyong on 16/3/6.
//  Copyright © 2016年 zhouyong. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ViewController : NSViewController

@property (nonatomic, strong) IBOutlet NSTextField *projectRootDirTextField;
@property (nonatomic, strong) IBOutlet NSTextField *ipaTextField;
@property (nonatomic, strong) IBOutlet NSTextField *codeSignTextField;
@property (nonatomic, strong) IBOutlet NSTextField *profileTextField;
@property (nonatomic, strong) IBOutlet NSTextView *outputTextView;
@property (nonatomic, strong) IBOutlet NSButton *packageButton;
@property (nonatomic, strong) IBOutlet NSButton *cancelButton;

@end

