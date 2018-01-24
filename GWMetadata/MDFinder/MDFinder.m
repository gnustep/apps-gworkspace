/* MDFinder.m
 *  
 * Copyright (C) 2007-2018 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@fibernet.ro>
 * Date: January 2007
 *
 * This file is part of the GNUstep GWorkspace application
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "MDFinder.h"
#import "MDKWindow.h"
#import "MDKQuery.h"
#import "FSNode.h"

static MDFinder *mdfinder = nil;

@implementation MDFinder

+ (MDFinder *)mdfinder;
{
	if (mdfinder == nil) {
		mdfinder = [[MDFinder alloc] init];
	}	
  return mdfinder;
}

- (void)dealloc
{
  DESTROY (workspaceApp);
  RELEASE (mdkwindows);
  RELEASE (lastSaveDir);
  TEST_RELEASE (startAppWin);  
  
	[super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
    mdkwindows = [NSMutableArray new];
    activeWindow = nil;
    fm = [NSFileManager defaultManager];
    nc = [NSNotificationCenter defaultCenter];
  }
  
  return self;
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
  NSMenu *mainMenu = [NSMenu new];
  NSMenu *menu;
  NSMenu *windows, *services;  
  id<NSMenuItem> menuItem;

  // Info 	
  menuItem = addItemToMenu(mainMenu, @"Info", @"", nil, @"");
  menu = AUTORELEASE ([NSMenu new]);
  [mainMenu setSubmenu: menu forItem: menuItem];	
  addItemToMenu(menu, @"Activate context help", @"", @"activateContextHelp:", @";");

  // File
  menuItem = addItemToMenu(mainMenu, @"File", @"", nil, @"");
  menu = AUTORELEASE ([NSMenu new]);
  [mainMenu setSubmenu: menu forItem: menuItem];		
  addItemToMenu(menu, @"New", @"", @"newQuery:", @"n");
  addItemToMenu(menu, @"Open...", @"", @"openQuery:", @"o");
  addItemToMenu(menu, @"Save", @"", @"saveQuery:", @"s");
  addItemToMenu(menu, @"Save as...", @"", @"saveQueryAs:", @"");

  // Edit
  menuItem = addItemToMenu(mainMenu, @"Edit", @"", nil, @"");
  menu = AUTORELEASE ([NSMenu new]);
  [mainMenu setSubmenu: menu forItem: menuItem];	
  addItemToMenu(menu, @"Cut", @"", @"cut:", @"x");
  addItemToMenu(menu, @"Copy", @"", @"copy:", @"c");
  addItemToMenu(menu, @"Paste", @"", @"paste:", @"v");
  
  // Windows
  menuItem = addItemToMenu(mainMenu, @"Windows", @"", nil, @"");
  windows = AUTORELEASE ([NSMenu new]);
  [mainMenu setSubmenu: windows forItem: menuItem];		
  addItemToMenu(windows, @"Arrange in Front", @"", nil, @"");
  addItemToMenu(windows, @"Miniaturize Window", @"", nil, @"");
  addItemToMenu(windows, @"Close Window", @"", @"closeMainWin:", @"w");
  
  // Services 
  menuItem = addItemToMenu(mainMenu, @"Services", @"", nil, @"");
  services = AUTORELEASE ([NSMenu new]);
  [mainMenu setSubmenu: services forItem: menuItem];		
  
  // Hide
  addItemToMenu(mainMenu, @"Hide", @"", @"hide:", @"h");
  
  // Print
  addItemToMenu(mainMenu, @"Print...", @"", @"print:", @"p");
  
  // Quit
  addItemToMenu(mainMenu, @"Quit", @"", @"terminate:", @"q");
  
  [mainMenu update];

  [NSApp setServicesMenu: services];
  [NSApp setWindowsMenu: windows];
  [NSApp setMainMenu: mainMenu];		
  
  RELEASE (mainMenu);
  
  workspaceApp = nil;
  startAppWin = [[StartAppWin alloc] init];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  BOOL isdir;
  
  lastSaveDir = [defaults stringForKey: @"last_save_dir"];

  if (lastSaveDir && [fm fileExistsAtPath: lastSaveDir isDirectory: &isdir] && isdir) {
    RETAIN (lastSaveDir);
  } else {
    ASSIGN (lastSaveDir, NSHomeDirectory());
  }
}

- (void)applicationDidBecomeActive:(NSNotification *)aNotification
{
}

- (BOOL)application:(NSApplication *)application 
           openFile:(NSString *)fileName
{
  MDKWindow *window = [self windowWithSavedPath: fileName];
  
  if (window) {  
    [NSApp activateIgnoringOtherApps: YES];
    [window activate];  
  } else {
    window = [[MDKWindow alloc] initWithContentsOfFile: fileName
                                      windowRect: [self frameForNewWindow]
                                        delegate: self];
    if (window) {    
      [mdkwindows addObject: window];
      RELEASE (window);
      [NSApp activateIgnoringOtherApps: YES];
      [window activate];  
    } else {
      NSString *msg = NSLocalizedString(@"Invalid query description.", @"");    
      NSRunAlertPanel(nil, 
                    [NSString stringWithFormat: @"%@: %@", fileName, msg],
					          NSLocalizedString(@"Ok", @""), 
                    nil, 
                    nil);  
      return NO;
    }
  }
  
  return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)app 
{
  NSUInteger canterminate = NSTerminateNow;
  NSUInteger i;
  
  for (i = 0; i < [mdkwindows count]; i++) {
    MDKWindow *window = [mdkwindows objectAtIndex: i];
    MDKQuery *query = [window currentQuery];
    
    if ([query isGathering] || [query waitingStart]) {
      [window stopCurrentQuery];
      canterminate = NSTerminateCancel;
    }
  }
  
  if (canterminate == NSTerminateNow) {
    for (i = 0; i < [mdkwindows count]; i++) {
      MDKWindow *window = [mdkwindows objectAtIndex: i];
      
      if (([window savePath] != nil) && ([window isSaved] == NO)) {
        canterminate = NSTerminateCancel;
        break;
      }
    }
      
    if (canterminate == NSTerminateCancel) {
      canterminate = !(NSRunAlertPanel(nil,
                          NSLocalizedString(@"You have unsaved queries", @""),
                          NSLocalizedString(@"Cancel", @""),
                          NSLocalizedString(@"Quit Anyway", @""),
                          nil));        
    }    
  }
 
  if (canterminate == NSTerminateNow) { 
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setObject: lastSaveDir forKey: @"last_save_dir"];
    [defaults synchronize];
  }
  
	return canterminate;
}

- (MDKWindow *)windowWithSavedPath:(NSString *)path
{
  int i;
  
  for (i= 0; i < [mdkwindows count]; i++) {
    MDKWindow *window = [mdkwindows objectAtIndex: i];
    NSString *savePath = [window savePath];
    
    if (savePath && [savePath isEqual: path]) {
      return window;
    }
  }
  
  return nil;
}

- (NSRect)frameForNewWindow
{
  NSRect scr = [[NSScreen mainScreen] visibleFrame];
  NSRect wrect = NSZeroRect;
  int i;  

  #define MARGIN 200
  #define SHIFT 100

  scr.origin.x += MARGIN;
  scr.origin.y += MARGIN;
  scr.size.width -= (MARGIN * 2);
  scr.size.height -= (MARGIN * 2);

	for (i = [mdkwindows count] - 1; i >= 0; i--) {
    MDKWindow *mdkwin = [mdkwindows objectAtIndex: i];
    NSRect wr = [[mdkwin window] frame];
  
    wrect = NSMakeRect(wr.origin.x + SHIFT, 
                       wr.origin.y - wr.size.height - SHIFT,
                       wr.size.width,
                       wr.size.height);

    if (NSContainsRect(scr, wrect) == NO) {
      wrect = NSMakeRect(scr.origin.x, 
                         scr.size.height - wr.size.height,
                         wr.size.width, 
                         wr.size.height);
      break;
    }    
  }

  return wrect;
}

- (void)connectWorkspaceApp
{
  if (workspaceApp == nil) {
    workspaceApp = [NSConnection rootProxyForConnectionWithRegisteredName: @"GWorkspace" 
                                                                     host: @""];

    if (workspaceApp == nil) {
      int i;
    
      [startAppWin showWindowWithTitle: @"MDFinder"
                               appName: @"GWorkspace"
                             operation: NSLocalizedString(@"starting:", @"")
                          maxProgValue: 80.0];

      [[NSWorkspace sharedWorkspace] launchApplication: @"GWorkspace"];
   
      for (i = 1; i <= 80; i++) {
        [startAppWin updateProgressBy: 1.0];
	      [[NSRunLoop currentRunLoop] runUntilDate:
		                     [NSDate dateWithTimeIntervalSinceNow: 0.1]];
        workspaceApp = [NSConnection rootProxyForConnectionWithRegisteredName: @"GWorkspace" 
                                                                         host: @""];                  
        if (workspaceApp) {
          [startAppWin updateProgressBy: 80.0 - i];
          break;
        }
      }

      [[startAppWin win] close];
    }
    
    if (workspaceApp) {
      RETAIN (workspaceApp);
      [workspaceApp setProtocolForProxy: @protocol(WorkspaceAppProtocol)];
    
	    [nc addObserver: self
	           selector: @selector(workspaceAppConnectionDidDie:)
		             name: NSConnectionDidDieNotification
		           object: [workspaceApp connectionForProxy]];
    } else {
      NSRunAlertPanel(nil,
              NSLocalizedString(@"unable to contact GWorkspace!", @""),
              NSLocalizedString(@"Ok", @""),
              nil, 
              nil);  
    }
  }
}

- (void)workspaceAppConnectionDidDie:(NSNotification *)notif
{
  [nc removeObserver: self
	              name: NSConnectionDidDieNotification
	            object: [notif object]];

  RELEASE (workspaceApp);
  workspaceApp = nil;

  NSRunAlertPanel(nil, 
                NSLocalizedString(@"The GWorkspace connection died.", @""),
					      NSLocalizedString(@"Ok", @""), 
                nil, 
                nil);  
    
  [self connectWorkspaceApp];          
}


//
// Menu
//
- (void)newQuery:(id)sender
{
  MDKWindow *window = [[MDKWindow alloc] initWithContentsOfFile: nil
                                     windowRect: [self frameForNewWindow]
                                       delegate: self];
  [mdkwindows addObject: window];
  RELEASE (window);  
  [window activate];
}

- (void)openQuery:(id)sender
{
  NSOpenPanel *openPanel = [NSOpenPanel openPanel];
  int result;
  
	[openPanel setTitle: NSLocalizedString(@"Open saved query", @"")];	
	[openPanel setAllowsMultipleSelection: NO];
	[openPanel setCanChooseFiles: YES];
	[openPanel setCanChooseDirectories: NO];

	result = [openPanel runModalForDirectory: lastSaveDir 
							                        file: nil 
                                     types: [NSArray arrayWithObject: @"mdss"]];
	if (result == NSOKButton) {
    NSString *wpath = [openPanel filename];
    MDKWindow *window = [self windowWithSavedPath: wpath];
    
    if (window == nil) {
      window = [[MDKWindow alloc] initWithContentsOfFile: wpath
                                        windowRect: [self frameForNewWindow]
                                          delegate: self];
      if (window) {    
        [mdkwindows addObject: window];
        RELEASE (window);
        [NSApp activateIgnoringOtherApps: YES];
        [window activate];  
      } else {
        NSString *msg = NSLocalizedString(@"Invalid query description.", @"");    
        NSRunAlertPanel(nil, 
                      [NSString stringWithFormat: @"%@: %@", wpath, msg],
					            NSLocalizedString(@"Ok", @""), 
                      nil, 
                      nil);  
      }
    } else {
      [NSApp activateIgnoringOtherApps: YES];
      [window activate];  
    }
	}
}

- (void)saveQuery:(id)sender
{
  if (activeWindow) {
    NSString *savePath = [activeWindow savePath];
    
    if (savePath == nil) {
      [self saveQueryAs: nil];
    
    } else {
      NSDictionary *info = [activeWindow statusInfo];
    
      if ([info writeToFile: savePath atomically: YES]) {
        [activeWindow setSaved: YES];      
      } else {
        NSRunAlertPanel(nil, 
                    NSLocalizedString(@"Error saving the query!", @""),
					          NSLocalizedString(@"Ok", @""), 
                    nil, 
                    nil);  
      }
    }
  }
}

- (void)saveQueryAs:(id)sender
{
  if (activeWindow) {
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    int result;

    [savePanel setTitle: NSLocalizedString(@"Save query", @"")];
    [savePanel setRequiredFileType: @"mdss"];
    
    result = [savePanel runModalForDirectory: lastSaveDir file: @""];

    if (result == NSOKButton) {
      NSString *savepath = [savePanel filename];

      [[activeWindow statusInfo] writeToFile: savepath atomically: YES];      
      [activeWindow setSavePath: savepath];
      [activeWindow setSaved: YES];
      ASSIGN (lastSaveDir, [savepath stringByDeletingLastPathComponent]);
    }
  }  
}

- (void)closeMainWin:(id)sender
{
  [[NSApp keyWindow] performClose: sender];
}

- (void)activateContextHelp:(id)sender
{
  if ([NSHelpManager isContextHelpModeActive] == NO) {
    [NSHelpManager setContextHelpModeActive: YES];
  }
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{	
  SEL action = [item action];

	if (sel_isEqual(action, @selector(saveQuery:))) {
    return ((activeWindow != nil) && ([activeWindow isSaved] == NO));

  } else if (sel_isEqual(action, @selector(saveQueryAs:))) {
    return ((activeWindow != nil) && ([activeWindow savePath] != nil));
	}
    
	return YES;
}


//
// MDKWindow delegate
//
- (void)setActiveWindow:(MDKWindow *)window
{
  [self connectWorkspaceApp];

  if (workspaceApp) {  
    NSArray *selection = [window selectedPaths];
    
    if ([selection count]) {  
      [workspaceApp showExternalSelection: selection];
    } else {
      [workspaceApp showExternalSelection: nil];
    }
  }
  
  activeWindow = window;
}

- (void)window:(MDKWindow *)window 
          didChangeSelection:(NSArray *)selection
{
  if (window == activeWindow) {
    [self connectWorkspaceApp];

    if (workspaceApp) {  
      NSArray *selection = [activeWindow selectedPaths];

      if ([selection count]) {  
        [workspaceApp showExternalSelection: selection];
      } else {
        [workspaceApp showExternalSelection: nil];
      }
    }
  }
}

- (void)mdkwindowWillClose:(MDKWindow *)window
{
  if (activeWindow == window) {
    [self connectWorkspaceApp];

    if (workspaceApp) {  
      [workspaceApp showExternalSelection: nil];  
    }
  
    activeWindow = nil;
  }
  
  [mdkwindows removeObject: window];
}

@end


@implementation StartAppWin

- (void)dealloc
{
  TEST_RELEASE (win);
  [super dealloc];
}

- (id)init
{
	self = [super init];

  if (self) {
		if ([NSBundle loadNibNamed: @"StartAppWin" owner: self] == NO) {
      NSLog(@"failed to load StartAppWin!");
      DESTROY (self);
      return self;
    } else {
      NSRect wframe = [win frame];
      NSRect scrframe = [[NSScreen mainScreen] frame];
      NSRect winrect = NSMakeRect((scrframe.size.width - wframe.size.width) / 2,
                              (scrframe.size.height - wframe.size.height) / 2,
                               wframe.size.width,
                               wframe.size.height);
      
      [win setFrame: winrect display: NO];
      [win setDelegate: self];  
         
      /* Internationalization */
      [startLabel setStringValue: NSLocalizedString(@"starting:", @"")];      
	  }			
  }
  
	return self;
}

- (void)showWindowWithTitle:(NSString *)title
                    appName:(NSString *)appname
                  operation:(NSString *)operation
               maxProgValue:(double)maxvalue
{
  if (win) {
    [win setTitle: title];
    [startLabel setStringValue: operation];
    [nameField setStringValue: appname];

    [progInd setMinValue: 0.0];
    [progInd setMaxValue: maxvalue];
    [progInd setDoubleValue: 0.0];

    if ([win isVisible] == NO) {
      [win orderFrontRegardless];
    }
  }
}
                 
- (void)updateProgressBy:(double)incr
{
  [progInd incrementBy: incr];
}

- (NSWindow *)win
{
  return win;
}

- (BOOL)windowShouldClose:(id)sender
{
	return YES;
}

@end


id<NSMenuItem> addItemToMenu(NSMenu *menu, NSString *str, 
																NSString *comm, NSString *sel, NSString *key)
{
  return [menu addItemWithTitle: NSLocalizedString(str, comm)
												 action: NSSelectorFromString(sel) 
                  keyEquivalent: key]; 
}

