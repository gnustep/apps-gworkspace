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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <AppKit/AppKit.h>
#include "GWViewerBrowser.h"
#include "FSNBrowserColumn.h"
#include "FSNBrowserMatrix.h"
#include "FSNBrowserCell.h"
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
    if ((lastSelection == nil) || ([newsel isEqual: lastSelection] == NO)) {
      if ([newsel count] == 0) {
        newsel = [NSArray arrayWithObject: baseNode]; 
      } else if (([viewer vtype] == SPATIAL) 
                        && [(NSWindow *)[viewer win] isKeyWindow]) {
        [manager selectedSpatialViewerChanged: viewer];
      }

      ASSIGN (lastSelection, newsel);
      [viewer selectionChanged: newsel];
      [self synchronizeViewer];
    } 
  }
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
  if (([theEvent type] == NSRightMouseDown) && ([viewer vtype] == SPATIAL)) {  
    FSNBrowserColumn *bc = [self lastLoadedColumn];
    NSPoint location = [theEvent locationInWindow];

    location = [self convertPoint: location fromView: nil];
    
    if (bc && [self mouse: location inRect: [bc frame]]) {
      NSArray *selnodes = [bc selectedNodes];
      NSAutoreleasePool *pool;
      NSMenu *menu;
      NSMenuItem *menuItem;
      NSString *firstext; 
      NSDictionary *apps;
      NSEnumerator *app_enum;
      id key; 
      int i;
  
      if (selnodes && [selnodes count]) {
        FSNBrowserMatrix *matrix = (FSNBrowserMatrix *)[bc cmatrix];
        FSNBrowserCell *cell;
        int row, col;
        
        location = [matrix convertPoint: location fromView: self];
        
        if ([matrix getRow: &row column: &col forPoint: location] == NO) {
          return [super menuForEvent: theEvent];
        }
        
        cell = [matrix cellAtRow: row column: col];
        
        if ([selnodes containsObject: [cell node]] == NO) {
          return [super menuForEvent: theEvent];
        }
        
        firstext = [[[selnodes objectAtIndex: 0] path] pathExtension];

        for (i = 0; i < [selnodes count]; i++) {
          FSNode *snode = [selnodes objectAtIndex: i];
          NSString *selpath = [snode path];
          NSString *ext = [selpath pathExtension];   

          if ([ext isEqual: firstext] == NO) {
            return [super menuForEvent: theEvent];  
          }

          if ([snode isDirectory] == NO) {
            if ([snode isPlain] == NO) {
              return [super menuForEvent: theEvent];
            }
          } else {
            if (([snode isPackage] == NO) || [snode isApplication]) {
              return [super menuForEvent: theEvent];
            } 
          }
        }

        menu = [[NSMenu alloc] initWithTitle: NSLocalizedString(@"Open with", @"")];
        apps = [[NSWorkspace sharedWorkspace] infoForExtension: firstext];
        app_enum = [[apps allKeys] objectEnumerator];

        pool = [NSAutoreleasePool new];

        while ((key = [app_enum nextObject])) {
          menuItem = [NSMenuItem new];    
          key = [key stringByDeletingPathExtension];
          [menuItem setTitle: key];
          [menuItem setTarget: desktopApp];      
          [menuItem setAction: @selector(openSelectionWithApp:)];      
          [menuItem setRepresentedObject: key];            
          [menu addItem: menuItem];
          RELEASE (menuItem);
        }

        RELEASE (pool);

        return [menu autorelease];
      }    
    }  
  }
  
  return [super menuForEvent: theEvent]; 
}

@end




