/* ShelfIcon.h
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
  #else
#include <GWorkspace/GWFunctions.h>
  #endif
#include "IconViewsIcon.h"
#include "GWorkspace.h"
#include "GNUstep.h"

@implementation ShelfIcon

- (void)select
{
	isSelect = YES;
  if (locked == NO) {
    [namelabel setTextColor: [NSColor controlTextColor]];
  }
  [self setNeedsDisplay: YES];
}

- (void)unselect
{
	isSelect = NO;
  if (locked == NO) {
    [namelabel setTextColor: [NSColor controlTextColor]];
  }
	[self setNeedsDisplay: YES];
}

- (void)mouseDown:(NSEvent *)theEvent
{
	if ([theEvent clickCount] == 1) {
	  NSEvent *nextEvent;
    NSPoint location;
    NSSize offset;
    BOOL startdnd = NO;
    
    if (isSelect == NO) {  
      [self select];
    }
    
    location = [theEvent locationInWindow];
    
    while (1) {
	    nextEvent = [[self window] nextEventMatchingMask:
    							              NSLeftMouseUpMask | NSLeftMouseDraggedMask];

      if ([nextEvent type] == NSLeftMouseUp) {
        NSSize ss = [self frame].size;
        NSSize is = [icon size];
        NSPoint p = NSMakePoint((ss.width - is.width) / 2, (ss.height - is.height) / 2);	

        p = [self convertPoint: p toView: nil];
        p = [[self window] convertBaseToScreen: p];

        [container setCurrentSelection: paths 
                          animateImage: icon 
                       startingAtPoint: p];

        [self unselect];
        break;

      } else if ([nextEvent type] == NSLeftMouseDragged) {
	      if(dragdelay < 5) {
          dragdelay++;
        } else {     
          NSPoint p = [nextEvent locationInWindow];
        
          offset = NSMakeSize(p.x - location.x, p.y - location.y); 
          startdnd = YES;        
          break;
        }
      }
    }

    if (startdnd == YES) {  
      [self startExternalDragOnEvent: nextEvent withMouseOffset: offset];    
    }    
  }           
}

- (void)startExternalDragOnEvent:(NSEvent *)event
                 withMouseOffset:(NSSize)offset
{
  NSPasteboard *pb = [NSPasteboard pasteboardWithName: NSDragPboard];	
  NSPoint dragPoint;
	
  [self declareAndSetShapeOnPasteboard: pb];

  ICONCENTER (self, icon, dragPoint);
  	  
  [self dragImage: icon
               at: dragPoint 
           offset: offset
            event: event
       pasteboard: pb
           source: self
        slideBack: NO];
}

- (void)draggedImage:(NSImage *)anImage 
						 endedAt:(NSPoint)aPoint 
					 deposited:(BOOL)flag
{
	if (flag == NO) {  
    NSRect r1 = [self frame];
    NSRect r2 = [namelabel frame];

    r1.origin.x = r1.origin.y = r2.origin.x = r2.origin.y = 0;

    aPoint = [[self window] convertScreenToBase: aPoint];
    aPoint = [self convertPoint: aPoint fromView: nil];
  
    if (NSPointInRect(aPoint, r1) || NSPointInRect(aPoint, r2)) {
	    dragdelay = 0;
	    onSelf = NO;
	    [self unselect];	
      return;
    }
    
    [container removeIcon: self];	
	} else {
	  dragdelay = 0;
	  onSelf = NO;
	  [self unselect];	
	}
}

- (void)declareAndSetShapeOnPasteboard:(NSPasteboard *)pb
{
  NSArray *dndtypes;

  dndtypes = [NSArray arrayWithObject: NSFilenamesPboardType];
  [pb declareTypes: dndtypes owner: nil];
  
  if ([pb setPropertyList: paths forType: NSFilenamesPboardType] == NO) {
    return;
  }
}

@end
