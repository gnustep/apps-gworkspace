/* InspectorPref.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
 *
 * This file is part of the GNUstep Inspector application
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
#include "InspectorPref.h"
#include "Inspector.h"
#include "ContentViewersProtocol.h"
#include "Functions.h"
#include "GNUstep.h"

#define CHECKSIZE(sz) \
if (sz.width < 0) sz.width = 0; \
if (sz.height < 0) sz.height = 0

static NSString *nibName = @"PreferencesWin";

@implementation InspectorPref

- (void)dealloc
{
  TEST_RELEASE (win);
  TEST_RELEASE (nameLabel);
  TEST_RELEASE (nameField);  
  TEST_RELEASE (cancelButt);
  [super dealloc];
}

- (id)initForInspector:(id)insp
{
	self = [super init];

  if (self) {
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
      DESTROY (self);
      return self;
    } else {
      NSSize cs, ms;
    
      [win setFrameUsingName: @"inspectorprefs"];
      [win setTitle: NSLocalizedString(@"Inspector Preferences", @"")];
      [win setDelegate: self];
    
      RETAIN (nameLabel);
      RETAIN (nameField);
      RETAIN (cancelButt);
      
      inspector = insp;
      
      [scroll setBorderType: NSBezelBorder];
      [scroll setHasHorizontalScroller: NO];
      [scroll setHasVerticalScroller: YES]; 
  
      matrix = [[NSMatrix alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)
				            	                mode: NSRadioModeMatrix 
                                 prototype: [[NSBrowserCell new] autorelease]
			       							    numberOfRows: 0 
                           numberOfColumns: 0];
      [matrix setTarget: self];
      [matrix setAction: @selector(matrixAction:)];
      [matrix setIntercellSpacing: NSZeroSize];
      [matrix setCellSize: NSMakeSize(1, 16)];
      [matrix setAutoscroll: YES];
	    [matrix setAllowsEmptySelection: NO];
      cs = [scroll contentSize];
      ms = [matrix cellSize];
      ms.width = cs.width;
      CHECKSIZE (ms);
      [matrix setCellSize: ms];
	    [scroll setDocumentView: matrix];	
      RELEASE (matrix);
               
      /* Internationalization */
      [descrLabel setStringValue: NSLocalizedString(@"Description", @"")];      
      [[descrView textStorage] setAttributedString: nil];      
      [locLabel setStringValue: NSLocalizedString(@"Bundle location", @"")];      
      [locField setStringValue: @""];      
      [extLabel setStringValue: NSLocalizedString(@"External", @"")];      
      [extField setStringValue: @""];         
      [nameLabel setStringValue: NSLocalizedString(@"Name", @"")];      
      [nameField setStringValue: @""];   
      [changeButt setTitle: NSLocalizedString(@"Deactivate", @"")];  
      [changeButt setEnabled: NO];  
      
      [self setSaveMode: NO];
	  }			
  }
  
	return self;
}

- (void)activate
{
  if (win && ([win isVisible] == NO)) {
    [win orderFrontRegardless];
    [matrix selectCellAtRow: 0 column: 0]; 
    [matrix sendAction]; 
  }
}

- (void)setSaveMode:(BOOL)mode
{
  savemode = mode;

  if (savemode) {
    if ([nameLabel superview] == nil) {
      [[win contentView] addSubview: nameLabel];
    }
    if ([nameField superview] == nil) {
      [[win contentView] addSubview: nameField];
    }
    if ([cancelButt superview] == nil) {
      [[win contentView] addSubview: cancelButt];
    }
    [cancelButt setTitle: NSLocalizedString(@"Cancel", @"")];  
    [changeButt setTitle: NSLocalizedString(@"Save", @"")]; 
     
  } else {
    if ([nameLabel superview]) {
      [nameLabel removeFromSuperview];
    }
    if ([nameField superview]) {
      [nameField removeFromSuperview];
    }
    if ([cancelButt superview]) {
      [cancelButt removeFromSuperview];
    }
    [changeButt setTitle: NSLocalizedString(@"Deactivate", @"")];  
  }
}

- (void)addViewer:(id)viewer
{
  NSString *vwrname = [viewer winname];
  int count = [[matrix cells] count];
  id cell;
  
  if (count == 0) {
    [matrix addColumn];
  } else {
    [matrix insertRow: count];
  }
  
  cell = [matrix cellAtRow: count column: 0];   
  [cell setStringValue: vwrname];
  [cell setLeaf: YES];  
  [matrix sizeToCells]; 
}

- (void)removeViewer:(id)viewer
{
  NSString *vwrname = [viewer winname];
  NSArray *cells = [matrix cells];
  int i;

  for (i = 0; i < [cells count]; i++) {
    id cell = [cells objectAtIndex: i];
  
    if ([[cell stringValue] isEqual: vwrname]) {
      if ([cells count] == 1) {
        [matrix removeColumn: 0];
        [[descrView textStorage] setAttributedString: nil];      
        [locField setStringValue: @""];      
        [extField setStringValue: @""];      
        [changeButt setEnabled: NO];  
      } else {
        int row, col;
        [matrix getRow: &row column: &col ofCell: cell];
        [matrix removeRow: row];
        [matrix selectCellAtRow: 0 column: 0]; 
        [matrix sendAction]; 
      }
      
      [matrix sizeToCells]; 
      break;
    }
  }
}

- (void)removeAllViewers
{
  while ([matrix cells] && [[matrix cells] count]) {
    NSString *name = [[[matrix cells] objectAtIndex: 0] stringValue];
    id viewer = [inspector contentViewerWithWindowName: name];  
    [self removeViewer: viewer];
  }
}

- (void)matrixAction:(id)sender
{
  id vname = [[matrix selectedCell] stringValue];
  id viewer = [inspector contentViewerWithWindowName: vname];
  
  if (viewer) {
    NSString *str;
    
    str = [viewer description];
    if (str) {
      NSAttributedString *attrstr = [[NSAttributedString alloc] initWithString: str];    
      [[descrView textStorage] setAttributedString: attrstr]; 
      RELEASE (attrstr);
    } else {
      [[descrView textStorage] setAttributedString: nil]; 
    }

    str = [viewer bundlePath];
    [locField setStringValue: (str ? str : @"")];
    str = ([viewer isExternal] ? NSLocalizedString(@"Yes", @"") : NSLocalizedString(@"No", @""));
    [extField setStringValue: str];
  
    [changeButt setEnabled: [viewer isRemovable]];  
  }
}

- (IBAction)buttonAction:(id)sender
{
  id vname = [[matrix selectedCell] stringValue];
  id viewer = [inspector contentViewerWithWindowName: vname];  

  if (viewer) {
    if (savemode == NO) {
      [inspector disableContentViewer: viewer];
      
    } else {
      if (sender == cancelButt) {
        [NSApp stopModal];
        
      } else {
        NSString *newname = [nameField stringValue];

        if ([newname length]) {
          if ([inspector saveExternalContentViewer: viewer withName: newname]) {
            [self removeViewer: viewer];
            [nameField setStringValue: @""];
          }

          if ([[matrix cells] count] == 0) {
            [NSApp stopModal];
          }

        } else {
          NSRunAlertPanel(nil,
                  NSLocalizedString(@"Invalid name!", @""),
                  NSLocalizedString(@"Ok", @""),
                  nil, 
                  nil);  
        }
      }
    }
  }
}

- (void)updateDefaults
{
  [win saveFrameUsingName: @"inspectorprefs"];
}
                 
- (NSWindow *)win
{
  return win;
}

- (BOOL)windowShouldClose:(id)sender
{
  [self updateDefaults];
	return YES;
}

@end
