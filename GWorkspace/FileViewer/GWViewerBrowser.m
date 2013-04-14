/* GWViewerBrowser.m
 *  
 * Copyright (C) 2004-2013 Free Software Foundation, Inc.
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#import <AppKit/AppKit.h>
#import "GWViewerBrowser.h"
#import "FSNBrowserColumn.h"
#import "FSNBrowserMatrix.h"
#import "FSNBrowserCell.h"
#import "GWViewersManager.h"

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
  if (newsel)
    {
      if ((lastSelection == nil) || ([newsel isEqual: lastSelection] == NO))
        {
          if ([newsel count] == 0)
            {
              newsel = [NSArray arrayWithObject: baseNode]; 
            }

          ASSIGN (lastSelection, newsel);
          [viewer selectionChanged: newsel];
          [self synchronizeViewer];
        } 
    }
}

@end




