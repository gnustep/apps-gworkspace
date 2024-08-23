/* OperationPrefs.m
 *  
 * Copyright (C) 2004-2014 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
 *
 * This file is part of the GNUstep Operation application
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
#import <GNUstepBase/GNUstep.h>

#import "OperationPrefs.h"


static NSString *nibName = @"OperationPrefs";

#define MOVEOP 0
#define COPYOP 1
#define LINKOP 2
#define RECYCLEOP 3
#define DUPLICATEOP 4
#define DESTROYOP 5

@implementation OperationPrefs

- (void)dealloc
{
  RELEASE (prefbox);
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) { 
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
    NSArray *cells;
    NSString *confirmString;      
    id butt;
  
    if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
      DESTROY (self);
      return self;
    }

    RETAIN (prefbox);
    RELEASE (win); 
  
    statusItem = [tabView tabViewItemAtIndex: 0];
    [statusItem setLabel: NSLocalizedString(@"Status Window", @"")];

    confirmItem = [tabView tabViewItemAtIndex: 1];
    [confirmItem setLabel: NSLocalizedString(@"Confirmation", @"")];

    showstatus = (![defaults boolForKey: @"fopstatusnotshown"]);
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
    [win setTitle: NSLocalizedString(@"Operation Preferences", @"")];
    [statusBox setTitle: NSLocalizedString(@"Status Window", @"")];
    [statuslabel setStringValue: NSLocalizedString(@"Show status window", @"")];      
    [statusinfo1 setStringValue: NSLocalizedString(@"Check this option to show a status window", @"")];
    [statusinfo2 setStringValue: NSLocalizedString(@"during the file operations", @"")];
    [confirmBox setTitle: NSLocalizedString(@"Confirmation", @"")];
    [[confMatrix cellAtRow:0 column:0] setTitle: NSLocalizedString(@"Move", @"")];
    [[confMatrix cellAtRow:1 column:0] setTitle: NSLocalizedString(@"Copy", @"")];
    [[confMatrix cellAtRow:2 column:0] setTitle: NSLocalizedString(@"Link", @"")];
    [[confMatrix cellAtRow:3 column:0] setTitle: NSLocalizedString(@"Recycler", @"")];
    [[confMatrix cellAtRow:4 column:0] setTitle: NSLocalizedString(@"Duplicate", @"")];
    [[confMatrix cellAtRow:5 column:0] setTitle: NSLocalizedString(@"Destroy", @"")];
    [labelinfo1 setStringValue: NSLocalizedString(@"Uncheck the buttons to allow automatic confirmation", @"")];
    [labelinfo2 setStringValue: NSLocalizedString(@"of file operations", @"")];    
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
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];     
  showstatus = ([sender state] == NSOnState) ? YES : NO;
  [defaults setBool: !showstatus forKey: @"fopstatusnotshown"];
  [defaults synchronize];
}

- (void)setUnsetFileOp:(id)sender
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
  CHECK_CONFIRM (RECYCLEOP, @"GWorkspaceRecycleOutOperation");
  CHECK_CONFIRM (RECYCLEOP, @"GWorkspaceEmptyRecyclerOperation");
  CHECK_CONFIRM (DUPLICATEOP, NSWorkspaceDuplicateOperation);
  CHECK_CONFIRM (DESTROYOP, NSWorkspaceDestroyOperation);

  [defaults synchronize];
}

@end
