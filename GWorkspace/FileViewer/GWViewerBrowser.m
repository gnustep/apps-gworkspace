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

- (void)dealloc
{
	[super dealloc];
}

- (id)initWithBaseNode:(FSNode *)bsnode
              inViewer:(id)vwr
		    visibleColumns:(int)vcols 
              scroller:(NSScroller *)scrl
            cellsIcons:(BOOL)cicns
       selectionColumn:(BOOL)selcol
{
  self = [super initWithBaseNode: bsnode
		              visibleColumns: vcols 
                        scroller: scrl
                      cellsIcons: cicns
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
    } else {
      [manager selectionDidChangeInViewer: viewer];
    }

    if ((lastSelection == nil) || ([newsel isEqual: lastSelection] == NO)) {
      ASSIGN (lastSelection, newsel);
      [viewer selectionChanged: newsel];
      [self synchronizeViewer];
      [desktopApp selectionChanged: newsel];
    }      
  }
}

- (void)synchronizeViewer
{
  NSRange range = NSMakeRange(firstVisibleColumn, visibleColumns);
  [viewer setSelectableNodesRange: range];
}

- (void)clickInMatrixOfColumn:(FSNBrowserColumn *)col
{
  int index = [col index];
  int pos = index - firstVisibleColumn + 1;  
  BOOL last = (index == lastVisibleColumn) || (index == ([columns count] -1));
  BOOL mustshift = (firstVisibleColumn > 0);
  NSArray *selection = [col selectedNodes];
  
  if ((selection == nil) || ([selection count] == 0)) {
    [self notifySelectionChange: [NSArray arrayWithObject: [[col shownNode] path]]];
    return;
  }

  currentshift = 0;
  updateViewsLock++;
  
  [self setLastColumn: index];
  
  if ([selection count] == 1) {
    FSNode *node = [selection objectAtIndex: 0];
  
    if ([node isDirectory] && ([node isPackage] == NO)) {
      [self addAndLoadColumnForNode: node];
      [manager viewer: viewer didShowPath: [node path]];
    
    } else {
      if ((last == NO) || selColumn) {
        [self addFillingColumn];
      } 
    }  
    
  } else {
    if ((last == NO) || selColumn) {
      [self addFillingColumn];
    }
  } 
    
  if (mustshift && (pos < (visibleColumns - 1))) { 
		[self setShift: visibleColumns - pos - 1];
	}
  
  updateViewsLock--;
  [self tile];
  
  [self notifySelectionChange: [col selectedPaths]];		  
}

- (void)doubleClickInMatrixOfColumn:(FSNBrowserColumn *)col
{
  unsigned int mouseFlags = [(FSNBrowserMatrix *)[col cmatrix] mouseFlags];
  BOOL closesndr = ((mouseFlags == NSAlternateKeyMask) 
                              || (mouseFlags == NSControlKeyMask));

  [manager openSelectionInViewer: viewer closeSender: closesndr];
}

@end




