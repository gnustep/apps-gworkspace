/* SearchPlacesScroll.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
 *
 * This file is part of the GNUstep Finder application
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
#include "SearchPlacesScroll.h"
#include "FSNBrowserCell.h"
#include "Finder.h"
#include "GNUstep.h"

@implementation SearchPlacesScroll

- (void)dealloc
{
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect
{
  NSArray *pbTypes = [NSArray arrayWithObject: NSFilenamesPboardType];

  self = [super initWithFrame: frameRect];

  if (self) {
    [self setBorderType: NSBezelBorder];
    [self setHasHorizontalScroller: NO];
    [self setHasVerticalScroller: YES]; 
    finder = [Finder finder];
    [self registerForDraggedTypes: pbTypes];  
    isDragTarget = NO;  
  }
  
  return self;
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

@end


@implementation SearchPlacesScroll (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb = [sender draggingPasteboard];

	isDragTarget = NO;

  if ([[pb types] containsObject: NSFilenamesPboardType]) {
	  NSArray *sourcePaths = [pb propertyListForType: NSFilenamesPboardType]; 
    NSArray *cells = [(NSMatrix *)[self documentView] cells];
    int count = [sourcePaths count];
    int i;
    
	  if (count == 0) {
		  return NSDragOperationNone;
    } 

    for (i = 0; i < [cells count]; i++) {
      FSNBrowserCell *cell = [cells objectAtIndex: i];

      if ([sourcePaths containsObject: [cell path]]) {
		    return NSDragOperationNone;
      }
    }

    isDragTarget = YES;    
    
    return [sender draggingSourceOperationMask];
  }
  
  return NSDragOperationNone;
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
	if (isDragTarget) {
		return [sender draggingSourceOperationMask];
	}

  return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{

}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
  return isDragTarget;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	return isDragTarget;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
	isDragTarget = NO;
  [finder addSearchPlaceFromPasteboard: [sender draggingPasteboard]];
}

@end
