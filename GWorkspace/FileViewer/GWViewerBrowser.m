/* GWViewerBrowser.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: June 2004
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
#include "GWViewerBrowser.h"
#include "FSNBrowserColumn.h"
#include "FSNBrowserMatrix.h"
#include "GWSpatialViewer.h"
#include "GWViewersManager.h"

@implementation GWViewerBrowser

- (id)initWithBaseNode:(FSNode *)bsnode
              inViewer:(id)vwr
		    visibleColumns:(int)vcols 
              scroller:(NSScroller *)scrl
            cellsIcons:(BOOL)cicns
         editableCells:(BOOL)edcells
       selectionColumn:(BOOL)selcol
{
  self = [super initWithBaseNode: bsnode
		              visibleColumns: vcols 
                        scroller: scrl
                      cellsIcons: cicns
                   editableCells: edcells    
                 selectionColumn: selcol];

  if (self) {
    viewer = vwr;
    manager = [GWViewersManager viewersManager];
  }
  
  return self;
}

- (void)notifySelectionChange:(NSArray *)newsel
{
  if (newsel) {
    if ([newsel count] == 0) {
      newsel = [NSArray arrayWithObject: [baseNode path]]; 
    } else if (([viewer vtype] == SPATIAL) 
                      && [(NSWindow *)[viewer win] isKeyWindow]) {
      [manager selectedSpatialViewerChanged: viewer];
    }

    if ((lastSelection == nil) || ([newsel isEqual: lastSelection] == NO)) {
      ASSIGN (lastSelection, newsel);
      [viewer selectionChanged: newsel];
      [self synchronizeViewer];
    } 
  }
}

@end



