/* Apps.m
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */


#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
  #ifdef GNUSTEP 
#include "GWFunctions.h"
#include "GWLib.h"
  #else
#include <GWorkspace/GWFunctions.h>
#include <GWorkspace/GWLib.h>
  #endif
#include "Apps.h"
#include "GNUstep.h"

@implementation AppsViewer

- (void)dealloc
{
	[[ws notificationCenter] removeObserver: self]; 
  RELEASE (appsMatrix);
  RELEASE (appButt);
  RELEASE (appNameField);
  RELEASE (appPathField);
  RELEASE (win);
  [super dealloc];
}

- (id)init
{
	self = [super init];
  if (self) {
		id cell, scroll, view;
    NSRect rect;

    ws = [NSWorkspace sharedWorkspace];

	  win = [[NSWindow alloc] initWithContentRect: NSZeroRect
					      styleMask: NSTitledWindowMask | NSClosableWindowMask
                              backing: NSBackingStoreBuffered defer: YES];

    if ([win setFrameUsingName: @"appsviewer"] == NO) {
      [win setFrame: NSMakeRect(100, 100, 384, 180) display: NO];
    }            

    [win setMaxSize: NSMakeSize(384, 180)];
    [win setMinSize: NSMakeSize(384, 180)];
    [win setTitle: NSLocalizedString(@"Applications",@"")];
    [win setReleasedWhenClosed: NO]; 
    [win setDelegate: self];
    view = [win contentView];

    rect = NSMakeRect(8, 105, [view frame].size.width - 16, 50);
    
    scroll = [[NSScrollView alloc] initWithFrame: rect];
    [scroll setBorderType: NSBezelBorder];
    [scroll setHasHorizontalScroller: NO];
    [scroll setHasVerticalScroller: YES]; 
    [scroll setAutoresizingMask: NSViewHeightSizable];
    [view addSubview: scroll];

    cell = AUTORELEASE ([NSButtonCell new]);
    [cell setButtonType: NSPushOnPushOffButton];
    [cell setBordered: NO];
    [cell setFont: [NSFont systemFontOfSize: 12]];
    [cell setAlignment: NSLeftTextAlignment]; 

    appsMatrix = [[NSMatrix alloc] initWithFrame: NSZeroRect
			      	          mode: NSRadioModeMatrix prototype: cell
		       							          numberOfRows: 0 numberOfColumns: 0];

    [appsMatrix setIntercellSpacing: NSZeroSize];
    [appsMatrix setCellSize: NSMakeSize(345, 16)];
    [appsMatrix sizeToCells];
    [appsMatrix setTarget: self];		
    [appsMatrix setAction: @selector(setApplicationInfo:)];		

    [scroll setDocumentView: appsMatrix];
    RELEASE (scroll);

    appButt = [[NSButton alloc] initWithFrame: NSMakeRect(8, 40, 48, 48)];
	  [appButt setButtonType: NSMomentaryLight];
    [appButt setBordered: NO];
	  [appButt setImagePosition: NSImageOnly];  
    [view addSubview: appButt];

	  appNameField = [[NSTextField alloc] initWithFrame: NSMakeRect(63, 51, 230, 25)];	
	  [appNameField setFont: [NSFont systemFontOfSize: 18]];
	  [appNameField setAlignment: NSLeftTextAlignment];
	  [appNameField setBackgroundColor: [NSColor windowBackgroundColor]];
	  [appNameField setBezeled: NO];
	  [appNameField setEditable: NO];
	  [appNameField setSelectable: NO];
	  [view addSubview: appNameField]; 

	  appPathField = [[NSTextField alloc] initWithFrame: NSMakeRect(16, 12, 350, 20)];	
	  [appPathField setFont: [NSFont systemFontOfSize: 12]];
	  [appPathField setAlignment: NSLeftTextAlignment];
	  [appPathField setBackgroundColor: [NSColor windowBackgroundColor]];
	  [appPathField setBezeled: NO];
	  [appPathField setEditable: NO];
	  [appPathField setSelectable: NO];  
	  [view addSubview: appPathField]; 

    [[ws notificationCenter] addObserver: self 
                			  selector: @selector(applicationLaunched:) 
                					  name: NSWorkspaceDidLaunchApplicationNotification
                				  object: nil];

    [[ws notificationCenter] addObserver: self 
                			  selector: @selector(applicationTerminated:) 
                					  name: NSWorkspaceDidTerminateApplicationNotification
                				  object: nil];
  }
  
  return self;
}

- (void)activate
{
  [win makeKeyAndOrderFront: nil];
}
    
- (void)setApplicationInfo:(id)sender
{
  NSString *appName, *appPath;
  id cell;

  [appButt setImage: nil];	  
  [appNameField setStringValue: @""];
  [appPathField setStringValue: @""];
  
  cell = [sender selectedCell];
  if (cell == nil) {
    return;
  }

  appName = [cell title];  
  appPath = [ws fullPathForApplication: [appName stringByDeletingPathExtension]];
  [appButt setImage: [ws iconForFile: appPath]];	  

  [appNameField setStringValue: [appName stringByDeletingPathExtension]];

  appPath = pathFittingInContainer(appPathField, appPath, 30);
  appPath = [NSString stringWithFormat: @"%@%@", NSLocalizedString(@"Path: ", @""), appPath];
  [appPathField setStringValue: appPath];
}

- (void)applicationLaunched:(NSNotification *)aNotification
{
  NSDictionary *userinfo;
  NSString *appName;  
  id cell;
  int index;
    
  userinfo = [aNotification userInfo];
  appName = [userinfo objectForKey: @"NSApplicationName"];

  [appsMatrix addRow];
  index = [[appsMatrix cells] count] - 1;
  cell = [appsMatrix cellAtRow: index column: 0];
  [cell setTitle: appName];

  [appsMatrix sizeToCells]; 
	if ([win isVisible] == YES) { 	
  	[appsMatrix selectCellAtRow: [[appsMatrix cells] count] - 1 column: 0];
  }
	
	[self setApplicationInfo: appsMatrix];
}

- (void)applicationTerminated:(NSNotification *)aNotification
{
  NSDictionary *userinfo = [aNotification userInfo];
  NSString *appName = [userinfo objectForKey: @"NSApplicationName"];
  NSArray *cells = [appsMatrix cells];
  int i = 0;
  
  for (i = 0; i < [cells count]; i++) {
    NSString *title = [[appsMatrix cellAtRow: i column: 0] title];
    if ([title isEqual: appName]) {
      [appsMatrix removeRow: i];
      break;
    }
  }

  [appsMatrix sizeToCells];
  [self setApplicationInfo: appsMatrix];      
}

- (BOOL)windowShouldClose:(id)sender
{
  [self updateDefaults];
	return YES;
}

- (void)updateDefaults
{
  [win saveFrameUsingName: @"appsviewer"];
}

- (NSWindow *)myWin
{
  return win;
}

@end
