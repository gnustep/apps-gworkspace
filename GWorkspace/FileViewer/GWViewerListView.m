/* GWViewerListView.m
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
#import "GWViewerListView.h"
#import "GWViewer.h"
#import "GWViewersManager.h"
#import "GWorkspace.h"

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
  if (viewer)
    {
      return [viewer baseNode];
    }
  
  return node;
}

- (BOOL)keepsColumnsInfo
{
  return (viewer != nil);
}

- (void)selectionDidChange
{
  NSArray *selection = [self selectedNodes];

  if ([selection count] == 0)
    selection = [NSArray arrayWithObject: node];

  if ((lastSelection == nil) || ([selection isEqual: lastSelection] == NO))
    {
      ASSIGN (lastSelection, selection);
      [viewer selectionChanged: selection];
    }
}

- (void)openSelectionInNewViewer:(BOOL)newv
{
  BOOL closesndr = ((mouseFlags == NSAlternateKeyMask) 
                              || (mouseFlags == NSControlKeyMask));
  [viewer openSelectionInNewViewer: (closesndr || newv)];
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

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
  if ([theEvent type] == NSRightMouseDown) {
    NSPoint location = [theEvent locationInWindow];
    int row = [self rowAtPoint: [self convertPoint: location fromView: nil]];
    
    if (row != -1) {
      NSArray *selnodes = [self selectedNodes];
      NSAutoreleasePool *pool;
      NSMenu *menu;
      NSMenuItem *menuItem;
      NSString *firstext; 
      NSDictionary *apps;
      NSEnumerator *app_enum;
      id key; 
      int i;

      if (selnodes && [selnodes count]) {
        FSNListViewNodeRep *rep = [[self reps] objectAtIndex: row];

        if ([selnodes containsObject: [rep node]] == NO) {
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
          [menuItem setTarget: [GWorkspace gworkspace]];      
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




