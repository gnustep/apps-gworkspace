/* SearchPlacesMatrix.m
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
#include "SearchPlacesMatrix.h"
#include "SearchPlacesScroll.h"
#include "GNUstep.h"

@implementation SearchPlacesMatrix

- (void)dealloc
{
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect 
               mode:(int)aMode 
          prototype:(NSCell *)aCell 
       numberOfRows:(int)numRows
    numberOfColumns:(int)numColumns
         scrollView:(SearchPlacesScroll *)spscroll
{
  NSArray *pbTypes = [NSArray arrayWithObject: NSFilenamesPboardType];

  self = [super initWithFrame: frameRect mode: aMode prototype: aCell 
                        numberOfRows: numRows numberOfColumns: numColumns];

  if (self) {
    scroll = spscroll;
    [self registerForDraggedTypes: pbTypes];    
  }
  
  return self;
}

@end


@implementation SearchPlacesMatrix (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
  return [scroll draggingEntered: sender];
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
  return [scroll draggingUpdated: sender];
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  [scroll draggingExited: sender];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
  return [scroll prepareForDragOperation: sender];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	return [scroll performDragOperation: sender];
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
  [scroll concludeDragOperation: sender];
}

@end
