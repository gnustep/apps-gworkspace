/* BrowserViewerPref.m
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
#include "GWFunctions.h"
#include "GWNotifications.h"
#include "BrowserViewerPref.h"
#include "GNUstep.h"

#define EXAMPLE_X 10
#define EXAMPLE_Y 6
#define EXAMPLE_H 99  
#define RESIZER_W 16
#define RESIZER_Y 48

#define DEFAULT_WIDTH 150

static NSString *nibName = @"BrowserViewerPref";

@implementation Resizer

- (void)dealloc
{
  RELEASE (arrow);
  [super dealloc];
}

- (id)initForController:(id)acontroller
{
  self = [super init];
  [self setFrame: NSMakeRect(0, 0, RESIZER_W, RESIZER_W)];	  
  controller = acontroller;  
  ASSIGN (arrow, [NSImage imageNamed: @"RightArr.tiff"]);  
  return self;
}

- (void)mouseDown:(NSEvent *)theEvent
{
  [controller mouseDownOnResizer: theEvent];
}

- (void)drawRect:(NSRect)rect
{
  [super drawRect: rect];
	[arrow compositeToPoint: NSZeroPoint operation: NSCompositeSourceOver];
}

@end

@implementation BrowserViewerPref

- (void)dealloc
{
  RELEASE (colExample);
  RELEASE (prefbox);
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
      NSString *widthStr = [defaults objectForKey: @"browserColsWidth"];
      BOOL entry;
      
      RETAIN (prefbox);
      RELEASE (win);

      if (widthStr) {
        columnsWidth = [widthStr intValue];
      } else {
        columnsWidth = DEFAULT_WIDTH;
      }

      [colExample setBorderType: NSBezelBorder];
		  [colExample setHasHorizontalScroller: NO];
  	  [colExample setHasVerticalScroller: YES]; 

      resizer = [[Resizer alloc] initForController: self];
      [resizer setFrame: NSMakeRect(0, 0, RESIZER_W, RESIZER_W)];
	    [(NSBox *)resizerBox setContentView: resizer]; 
      
      entry = [defaults boolForKey: @"browserCellsIcons"];
      [cellIconButt setState: (entry ? NSOnState : NSOffState)];
      
      entry = [defaults boolForKey: @"viewersDontUsesShelf"];
      [shelfButt setState: (entry ? NSOffState : NSOnState)];
      
      /* Internationalization */
      [aspectBox setTitle: NSLocalizedString(@"Aspect", @"")];  
      [cellIconButt setTitle: NSLocalizedString(@"Icons in Browser Cells", @"")];  
      [shelfButt setTitle: NSLocalizedString(@"Uses Shelf", @"")];  
      
      [controlsbox setTitle: NSLocalizedString(@"Columns Width", @"")];  
      [setButt setTitle: NSLocalizedString(@"Use Default Settings", @"")];  
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
  return NSLocalizedString(@"Browser", @"");
}

- (void)tile
{
  [colExample setFrame: NSMakeRect(EXAMPLE_X, EXAMPLE_Y, columnsWidth, EXAMPLE_H)];    
  [resizerBox setFrameOrigin: NSMakePoint(columnsWidth + EXAMPLE_X, RESIZER_Y)];  
  [controlsbox setNeedsDisplay: YES];
}

- (void)mouseDownOnResizer:(NSEvent *)theEvent
{
  NSApplication	*app = [NSApplication sharedApplication];
  NSDate *farAway = [NSDate distantFuture];
  int orx = (int)[controlsbox convertPoint: [theEvent locationInWindow] fromView: nil].x;
  unsigned int eventMask = NSLeftMouseUpMask | NSLeftMouseDraggedMask;
  int newWidth = (int)[colExample frame].size.width;
  NSEvent	*e;
  
  [controlsbox lockFocus];
  [[NSRunLoop currentRunLoop] limitDateForMode: NSEventTrackingRunLoopMode];

  e = [app nextEventMatchingMask: eventMask
		                   untilDate: farAway
			                    inMode: NSEventTrackingRunLoopMode
			                   dequeue: YES];

  while ([e type] != NSLeftMouseUp) {
    int x = (int)[controlsbox convertPoint: [e locationInWindow] fromView: nil].x;
    int diff = x - orx;
    
    if ((newWidth + diff < 230) && (newWidth + diff > 120)) {                
      newWidth += diff;
      
      [resizerBox setFrameOrigin: NSMakePoint(EXAMPLE_X + newWidth, RESIZER_Y)];
      [resizerBox setNeedsDisplay: YES];
  
      [colExample setFrame: NSMakeRect(EXAMPLE_X, EXAMPLE_Y, newWidth, EXAMPLE_H)];        
      [colExample setNeedsDisplay: YES];  

      [controlsbox setNeedsDisplay: YES];

      orx = x;
    }
    
    e = [app nextEventMatchingMask: eventMask
		                     untilDate: farAway
			                      inMode: NSEventTrackingRunLoopMode
			                     dequeue: YES];
  }
  
  [controlsbox unlockFocus];
  [self setNewWidth: (int)[colExample frame].size.width];
  [setButt setEnabled: YES];
}

- (void)setNewWidth:(int)w
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  [defaults setObject: [NSString stringWithFormat: @"%i", w]
               forKey: @"browserColsWidth"];
               
  columnsWidth = w;
  
	[[NSNotificationCenter defaultCenter]
 				 postNotificationName: GWBrowserColumnWidthChangedNotification
	 								     object: [NSNumber numberWithInt: w]];  
                       
  [defaults synchronize];                           
}

- (IBAction)setDefaultWidth:(id)sender
{
  columnsWidth = DEFAULT_WIDTH;
  [self setNewWidth: columnsWidth];
  [self tile];
  [setButt setEnabled: NO];
}

- (IBAction)setIcons:(id)sender
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  [defaults setBool: (([sender state] == NSOnState) ? YES : NO)
             forKey: @"browserCellsIcons"];
  [defaults synchronize]; 
  
	[[NSNotificationCenter defaultCenter]
 				 postNotificationName: GWBrowserCellsIconsDidChangeNotification
	 								     object: nil];  
}

- (IBAction)setShelf:(id)sender
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  [defaults setBool: (([sender state] == NSOnState) ? NO : YES)
             forKey: @"viewersDontUsesShelf"];
  [defaults synchronize]; 
  
	[[NSNotificationCenter defaultCenter]
 				 postNotificationName: GWViewersUseShelfDidChangeNotification
	 								     object: nil];  
}

@end
