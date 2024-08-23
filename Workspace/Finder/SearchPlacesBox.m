/* SearchPlacesBox.m
 *  
 * Copyright (C) 2005 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2005
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

#include <AppKit/AppKit.h>
#include "SearchPlacesBox.h"
#include "Finder.h"

@implementation SearchPlacesBox

- (id)initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame: frameRect];
  
  if (self) {
    [self setBorderType: NSNoBorder];
    [self setContentViewMargins: NSZeroSize];
    [self setTitlePosition: NSNoTitle];
    [self registerForDraggedTypes: [NSArray arrayWithObject: NSFilenamesPboardType]];  
  }
  
  return self;
}

- (void)setFinder:(id)anobject
{
  finder = anobject;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  return [finder draggingEnteredInSearchPlaces: sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
  return [finder draggingUpdatedInSearchPlaces: sender];
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
  return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
  [finder concludeDragOperationInSearchPlaces: sender];
}

@end

