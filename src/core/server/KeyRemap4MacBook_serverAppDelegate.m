//
//  KeyRemap4MacBook_serverAppDelegate.m
//  KeyRemap4MacBook_server
//
//  Created by Takayama Fumihiko on 09/11/01.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Carbon/Carbon.h>
#import "KeyRemap4MacBook_serverAppDelegate.h"
#include "util.h"
#include "server_objc_part.h"
#include "server.hpp"

@implementation KeyRemap4MacBook_serverAppDelegate

@synthesize window;

- (void) threadMain {
  NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

  server_run();

  [pool drain];

  [NSApp terminate:self];
}

- (void) configThreadMain {
  NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

  for (;;) {
    set_sysctl_do_reload_xml();
    sleep(1);
  }

  [pool drain];
  [NSThread exit];
}

- (void) setupStatusWindow {
  NSWindowCollectionBehavior behavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                                        NSWindowCollectionBehaviorStationary |
                                        NSWindowCollectionBehaviorIgnoresCycle;

  [window setBackgroundColor:[NSColor clearColor]];
  [window setOpaque:NO];
  [window setStyleMask:NSBorderlessWindowMask];
  [window setLevel:NSStatusWindowLevel];
  [window setIgnoresMouseEvents:YES];
  [window setCollectionBehavior:behavior];
  [window center];
}

// ----------------------------------------
- (void) statusBarItemSelected:(id)sender {
  [statusbar_ statusBarItemSelected:sender];
}

// ------------------------------------------------------------
- (void) observer_ConfigXMLReloaded:(NSNotification*)notification {
  set_sysctl_do_reset();
  set_sysctl_do_reload_xml();
}

- (void) observer_ConfigListChanged:(NSNotification*)notification {
  [statusbar_ refresh];
}

- (void) observer_PreferencesChanged:(NSNotification*)notification {
  set_sysctl_do_reload_only_config();
}

// ------------------------------------------------------------
- (void) observer_NSWorkspaceDidActivateApplicationNotification:(NSNotification*)notification
{
  NSString* name = [serverobjcpart_ getActiveApplicationName];
  if (name) {
    // We ignore our investigation application.
    if (! [name isEqualToString:@"org.pqrs.KeyRemap4MacBook.KeyDump"]) {
      unsigned int newval = [workspacedata_ getApplicationType:name];
      //NSLog(@"newval = %d", newval);
      setCurrentApplicationType(newval);
    }
  }
}

// ------------------------------------------------------------
- (void) observer_kTISNotifySelectedKeyboardInputSourceChanged:(NSNotification*)notification
{
  NSString* name = [serverobjcpart_ getTISPropertyInputModeID];
  if (name) {
    unsigned int inputmode;
    unsigned int inputmodedetail;
    [workspacedata_ getInputMode:name output_inputmode:(&inputmode) output_inputmodedetail:(&inputmodedetail)];
    setCurrentInputMode(inputmode, inputmodedetail);
  }
}

// ------------------------------------------------------------
- (void) observer_NSWorkspaceSessionDidBecomeActiveNotification:(NSNotification*)notification
{
  NSLog(@"observer_NSWorkspaceSessionDidBecomeActiveNotification");

  // Note: The console user is "real login user" or "loginwindow",
  //       when NSWorkspaceSessionDidBecomeActiveNotification, NSWorkspaceSessionDidResignActiveNotification are called.
  reset_statusmessage();

  set_sysctl_do_reset();
  set_sysctl_do_reload_xml();
}

- (void) observer_NSWorkspaceSessionDidResignActiveNotification:(NSNotification*)notification
{
  NSLog(@"observer_NSWorkspaceSessionDidResignActiveNotification");

  // Note: The console user is "real login user" or "loginwindow",
  //       when NSWorkspaceSessionDidBecomeActiveNotification, NSWorkspaceSessionDidResignActiveNotification are called.
  reset_statusmessage();

  set_sysctl_do_reset();
}

// ------------------------------------------------------------
- (void) applicationDidFinishLaunching:(NSNotification*)aNotification {
  [self setupStatusWindow];
  [serverobjcpart_ registerStatusWindow:window label:statusmessage_ background:statusmessage_background_];
  registerServerObjcPart(serverobjcpart_);

  reset_statusmessage();
  [statusbar_ refresh];

  set_sysctl_do_reset();

  // ------------------------------------------------------------
  [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                         selector:@selector(observer_NSWorkspaceDidActivateApplicationNotification:)
                                                             name:NSWorkspaceDidActivateApplicationNotification
                                                           object:nil];

  [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                      selector:@selector(observer_kTISNotifySelectedKeyboardInputSourceChanged:)
                                                          name:(NSString*)(kTISNotifySelectedKeyboardInputSourceChanged)
                                                        object:nil];

  // ------------------------------
  [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                         selector:@selector(observer_NSWorkspaceSessionDidBecomeActiveNotification:)
                                                             name:NSWorkspaceSessionDidBecomeActiveNotification
                                                           object:nil];

  [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                         selector:@selector(observer_NSWorkspaceSessionDidResignActiveNotification:)
                                                             name:NSWorkspaceSessionDidResignActiveNotification
                                                           object:nil];

  // ------------------------------
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observer_ConfigXMLReloaded:) name:@"ConfigXMLReloaded" object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observer_ConfigListChanged:) name:@"ConfigListChanged" object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observer_PreferencesChanged:) name:@"PreferencesChanged" object:nil];

  // ------------------------------------------------------------
  [self observer_NSWorkspaceDidActivateApplicationNotification:nil];
  [self observer_kTISNotifySelectedKeyboardInputSourceChanged:nil];

  // ------------------------------------------------------------
  [NSThread detachNewThreadSelector:@selector(threadMain)
                           toTarget:self
                         withObject:nil];
  [NSThread detachNewThreadSelector:@selector(configThreadMain)
                           toTarget:self
                         withObject:nil];

  // ------------------------------------------------------------
  // Kick updater
  [[NSWorkspace sharedWorkspace] launchApplication:@"/Library/org.pqrs/KeyRemap4MacBook/app/KeyRemap4MacBook.app"];
}

- (void) applicationWillTerminate:(NSNotification*)aNotification {
  NSLog(@"applicationWillTerminate");
  set_sysctl_do_reset();
}

@end
