 /*  -*-objc-*-
 *  FileOpsPref.m: Implementation of the FileOpsPref Class 
 *  of the GNUstep GWorkspace application
 *
 *  Copyright (c) 2002 Enrico Sersale <enrico@imago.ro>
 *  
 *  Author: Enrico Sersale
 *  Date: September 2002
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
  #ifdef GNUSTEP 
#include "GWFunctions.h"
#include "GWNotifications.h"
  #else
#include <GWorkspace/GWFunctions.h>
#include <GWorkspace/GWNotifications.h>
  #endif
#include "FileOpsPref.h"
#include "GWorkspace.h"
#include "GNUstep.h"

static NSString *nibName = @"FileOpsPref";

#define MOVEOP 0
#define COPYOP 1
#define LINKOP 2
#define RECYCLEOP 3
#define DUPLICATEOP 4
#define DESTROYOP 5

@implementation FileOpsPref

- (void)dealloc
{
  TEST_RELEASE (prefbox);
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {  
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
    } else {
      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
      NSArray *cells;
      NSString *confirmString;      
      id butt;

      RETAIN (prefbox);
      RELEASE (win); 
  
      gw = [GWorkspace gworkspace];        

      statusItem = [tabView tabViewItemAtIndex: 0];
      [statusItem setLabel: NSLocalizedString(@"Status Window", @"")];
           
      confirmItem = [tabView tabViewItemAtIndex: 1];
      [confirmItem setLabel: NSLocalizedString(@"Confirmation", @"")];

      showstatus = [gw showFileOpStatus];
      [statChooseButt setState: (showstatus ? NSOnState : NSOffState)];  
    
      cells = [confMatrix cells];
  
      butt = [cells objectAtIndex: MOVEOP];
      confirmString = [NSWorkspaceMoveOperation stringByAppendingString: @"Confirm"];    
      [butt setState: !([defaults boolForKey: confirmString])];    
      
      butt = [cells objectAtIndex: COPYOP];
      confirmString = [NSWorkspaceCopyOperation stringByAppendingString: @"Confirm"];    
      [butt setState: !([defaults boolForKey: confirmString])];    
      
      butt = [cells objectAtIndex: LINKOP];
      confirmString = [NSWorkspaceLinkOperation stringByAppendingString: @"Confirm"];    
      [butt setState: !([defaults boolForKey: confirmString])];    
      
      butt = [cells objectAtIndex: RECYCLEOP];
      confirmString = [NSWorkspaceRecycleOperation stringByAppendingString: @"Confirm"];    
      [butt setState: !([defaults boolForKey: confirmString])];    
      
      butt = [cells objectAtIndex: DUPLICATEOP];
      confirmString = [NSWorkspaceDuplicateOperation stringByAppendingString: @"Confirm"];    
      [butt setState: !([defaults boolForKey: confirmString])];
      
      butt = [cells objectAtIndex: DESTROYOP];
      confirmString = [NSWorkspaceDestroyOperation stringByAppendingString: @"Confirm"];    
      [butt setState: !([defaults boolForKey: confirmString])];
      
      /* Internationalization */
      [statActivButt setTitle: NSLocalizedString(@"Set", @"")];
      [confActivButt setTitle: NSLocalizedString(@"Set", @"")];
      [confirmBox setTitle: NSLocalizedString(@"Confirmation", @"")];
      [statusBox setTitle: NSLocalizedString(@"Status Window", @"")];
      [[confMatrix cellAtRow:0 column:0] setStringValue: NSLocalizedString(@"Move", @"")];
      [[confMatrix cellAtRow:1 column:0] setStringValue: NSLocalizedString(@"Copy", @"")];
      [[confMatrix cellAtRow:2 column:0] setStringValue: NSLocalizedString(@"Link", @"")];
      [[confMatrix cellAtRow:3 column:0] setStringValue: NSLocalizedString(@"Recycler", @"")];
      [[confMatrix cellAtRow:4 column:0] setStringValue: NSLocalizedString(@"Duplicate", @"")];
      [[confMatrix cellAtRow:5 column:0] setStringValue: NSLocalizedString(@"Destroy", @"")];
      [labelinfo1 setStringValue: NSLocalizedString(@"Uncheck the buttons to allow automatic confirmation", @"")];
      [labelinfo2 setStringValue: NSLocalizedString(@"of file operations", @"")];
      [statusinfo1 setStringValue: NSLocalizedString(@"Check this option to show a status window", @"")];
      [statusinfo2 setStringValue: NSLocalizedString(@"during the file operations", @"")];
      [statuslabel setStringValue: NSLocalizedString(@"Show status window", @"")];      
    }
  }
  
  return self;
}

- (NSView *)prefView
{
  return prefbox;
}

- (NSString *)prefName
{
  return NSLocalizedString(@"File Operations", @"");
}

- (void)setUnsetStatWin:(id)sender
{
	int state = [sender state];
	
  if (showstatus) {
    if (state == NSOffState) {
      showstatus = NO;
      [statActivButt setEnabled: YES];
    }
  } else {
    if (state == NSOnState) {
      showstatus = YES;
      [statActivButt setEnabled: YES];
    }
  }  
}

- (void)activateStatWinChanges:(id)sender
{
	[gw setShowFileOpStatus: showstatus];
	[statActivButt setEnabled: NO];
}

- (void)setUnsetFileOp:(id)sender
{
	[confActivButt setEnabled: YES];
}

- (void)activateFileOpChanges:(id)sender
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
  NSArray *cells = [confMatrix cells];
  NSString *confirmString;

#define CHECK_CONFIRM(x, s) \
confirmString = [s stringByAppendingString: @"Confirm"]; \
[defaults setBool: (([[cells objectAtIndex: x] state] == NSOnState) ? NO : YES) \
forKey: confirmString]

  CHECK_CONFIRM (MOVEOP, NSWorkspaceMoveOperation);
  CHECK_CONFIRM (COPYOP, NSWorkspaceCopyOperation);
  CHECK_CONFIRM (LINKOP, NSWorkspaceLinkOperation);
  CHECK_CONFIRM (RECYCLEOP, NSWorkspaceRecycleOperation);
  CHECK_CONFIRM (RECYCLEOP, GWorkspaceRecycleOutOperation);
  CHECK_CONFIRM (RECYCLEOP, GWorkspaceEmptyRecyclerOperation);
  CHECK_CONFIRM (DUPLICATEOP, NSWorkspaceDuplicateOperation);
  CHECK_CONFIRM (DESTROYOP, NSWorkspaceDestroyOperation);

  [defaults synchronize];
	[confActivButt setEnabled: NO];
}

@end
