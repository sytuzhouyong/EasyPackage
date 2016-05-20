//
//  AppDelegate.m
//  EasyPackage
//
//  Created by zhouyong on 16/3/6.
//  Copyright © 2016年 zhouyong. All rights reserved.
//

#import "AppDelegate.h"
#import "PackageViewController.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    [[ZyxFMDBManager sharedInstance] createDBWithName:@"config"];
    
    PackageViewController *vc = [[PackageViewController alloc] initWithNibName:nil bundle:nil];
    // window参数不能为空
    NSWindowController *windowController = [[NSWindowController alloc] initWithWindow:self.window];
    windowController.contentViewController = vc;
    self.window.windowController = windowController;
    [self.window setContentSize:CGSizeMake(640, 640)];
    [self.window center];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

// 为了在程序界面关闭的情况下点击dock上的app图标，能够回到app主界面
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    if (flag) {
        return YES;
    }
    [NSApp activateIgnoringOtherApps:NO];

    NSWindow *window = sender.windows.firstObject;
    [window makeKeyAndOrderFront:self];
    return YES;
}

@end
