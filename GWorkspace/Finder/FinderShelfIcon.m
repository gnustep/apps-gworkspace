/* FinderShelfIcon.m
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

@implementation FinderShelfIcon

- (void)select
{
	isSelect = YES;
  [namelabel setTextColor: [NSColor blackColor]];
	[container unselectOtherIcons: self];
  [container setCurrentSelection: paths];
	[self setNeedsDisplay: YES];
}

- (void)unselect
{
	isSelect = NO;
  [namelabel setTextColor: [NSColor blackColor]];
	[self setNeedsDisplay: YES];
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
