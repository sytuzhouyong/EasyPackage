//
//  AppDelegate.m
//  EasyPackage
//
//  Created by zhouyong on 16/3/6.
//  Copyright © 2016年 zhouyong. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    if (flag) {
        return YES;
    }
    [NSApp activateIgnoringOtherApps:NO];
    
    NSStoryboard *storyboard = [NSStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]];
    NSWindowController *main = [storyboard instantiateControllerWithIdentifier:@"WindowController"];
    NSWindow *window = main.window;
    [window makeKeyAndOrderFront:self];
    return YES;
}

@end
