/* FSNBrowserScroll.h
 *  
 * Copyright (C) 2004-2010 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: July 2004
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

#import <AppKit/AppKit.h>
#import "FSNBrowserScroll.h"
#import "FSNBrowserColumn.h"

@implementation FSNBrowserScroll

- (void)dealloc
{
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect
           inColumn:(FSNBrowserColumn *)col
          acceptDnd:(BOOL)dnd
{
  self = [super initWithFrame: frameRect];

  if (self) {
    [self setBorderType: NSNoBorder];
    [self setHasHorizontalScroller: NO];
    [self setHasVerticalScroller: YES]; 
    column = col;
    if (dnd) {
      [self registerForDraggedTypes: [NSArray arrayWithObjects: 
                                                NSFilenamesPboardType, 
                                                @"GWLSFolderPboardType", 
                                                @"GWRemoteFilenamesPboardType", 
                                                nil]];    
    }
  }
  
  return self;
}

- (void)reflectScrolledClipView:(NSClipView *)aClipView
{
  if (aClipView == [self contentView]) {
    [column stopCellEditing];
    [super reflectScrolledClipView: aClipView];
  }
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

@end


@implementation FSNBrowserScroll (DraggingDestination)

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  return [column draggingEntered: sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
  return [column draggingUpdated: sender];
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  [column draggingExited: sender];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
  return [column prepareForDragOperation: sender];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
  return [column performDragOperation: sender];
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
  [column concludeDragOperation: sender];
}

@end
