/* GWViewerScrollView.m
 *  
 * Copyright (C) 2004-2013 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: December 2004
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

#import "FSNFunctions.h"
#import "GWViewerScrollView.h"
#import "GWViewer.h"

@implementation GWViewerScrollView

- (id)initWithFrame:(NSRect)frameRect
           inViewer:(id)aviewer
{
  self = [super initWithFrame: frameRect];

  if (self) {
    viewer = aviewer;
  }
  
  return self;
}

- (void)setDocumentView:(NSView *)aView
{
  [super setDocumentView: aView];
  
  if (aView != nil) {
    nodeView = [viewer nodeView];
    
    if ([nodeView needsDndProxy]) {
      [self registerForDraggedTypes: [NSArray arrayWithObjects: 
                                              NSFilenamesPboardType, 
                                              @"GWLSFolderPboardType", 
                                              @"GWRemoteFilenamesPboardType", 
                                              nil]];    
    } else {
      [self unregisterDraggedTypes];
    }
  } else {
    nodeView = nil;
    [self unregisterDraggedTypes];
  }
}

@end


@implementation GWViewerScrollView (DraggingDestination)

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  if (nodeView && [nodeView needsDndProxy]) {
    return [nodeView draggingEntered: sender];
  }
  return NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
  if (nodeView && [nodeView needsDndProxy]) {
    return [nodeView draggingUpdated: sender];
  }
  return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  if (nodeView && [nodeView needsDndProxy]) {
    [nodeView draggingExited: sender];
  }
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
  if (nodeView && [nodeView needsDndProxy]) {
    return [nodeView prepareForDragOperation: sender];
  }
  return NO;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
  if (nodeView && [nodeView needsDndProxy]) {
    return [nodeView performDragOperation: sender];
  }
  return NO;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
  if (nodeView && [nodeView needsDndProxy]) {
    [nodeView concludeDragOperation: sender];
  }
}

@end











