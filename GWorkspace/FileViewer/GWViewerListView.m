/* GWViewerListView.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <AppKit/AppKit.h>
#include "GWViewerListView.h"
#include "GWSpatialViewer.h"
#include "GWViewer.h"
#include "GWViewersManager.h"

@implementation GWViewerListViewDataSource

- (id)initForListView:(FSNListView *)aview
{
  self = [super initForListView: aview];
  
  if (self) {
    manager = [GWViewersManager viewersManager];
  }
  
  return self;
}

- (void)setViewer:(id)vwr
{
  viewer = vwr;
}

- (FSNode *)infoNode
{
  if (viewer && ([viewer isSpatial] == NO)) {
    return [viewer baseNode];
  }
  
  return node;
}

- (BOOL)keepsColumnsInfo
{
  return (viewer && ([viewer isSpatial] == NO));
}

- (void)selectionDidChange
{
  NSArray *selection = [self selectedPaths];

  if ([selection count] == 0) {
    selection = [NSArray arrayWithObject: [node path]];
  } else if (([viewer vtype] == SPATIAL) 
                      && [(NSWindow *)[viewer win] isKeyWindow]) {
    [manager selectedSpatialViewerChanged: viewer];
  }

  if ((lastSelection == nil) || ([selection isEqual: lastSelection] == NO)) {
    ASSIGN (lastSelection, selection);
    [viewer selectionChanged: selection];
  }
}

- (void)openSelectionInNewViewer:(BOOL)newv
{
  [viewer openSelectionInNewViewer: newv];
}

@end


@implementation GWViewerListView

- (id)initWithFrame:(NSRect)rect 
          forViewer:(id)vwr
{
  self = [super initWithFrame: rect 
              dataSourceClass: [GWViewerListViewDataSource class]];
  
  if (self) {
		viewer = vwr;
    manager = [GWViewersManager viewersManager];
    [dsource setViewer: viewer];
  }
  
  return self;
}

- (void)mouseUp:(NSEvent *)theEvent
{
  [super mouseUp: theEvent];

  if ([viewer vtype] == SPATIAL) {
    [manager selectedSpatialViewerChanged: viewer];
    [manager synchronizeSelectionInParentOfViewer: viewer];
  }
}

@end




