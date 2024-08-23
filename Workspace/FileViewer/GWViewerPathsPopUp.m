/* GWViewerPathsPopUp.m
 *  
 * Copyright (C) 2004-2012 Free Software Foundation, Inc.
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

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#import "FSNode.h"
#import "GWViewerPathsPopUp.h"

@implementation GWViewerPathsPopUp

- (void)setItemsToNode:(FSNode *)node
{
  NSMenu *menu = [self menu];
  NSArray *components = [FSNode pathComponentsToNode: node];
  NSString *progPath = nil;
  int i;
  
  [self removeAllItems];
  
  for (i = 0; i < [components count]; i++) {
    NSString *path = [components objectAtIndex: i];
    NSMenuItem *item = [NSMenuItem new];
  
    if (i == 0) {
      progPath = path;
    } else {
      progPath = [progPath stringByAppendingPathComponent: path];
    }

    [item setTitle: path];
    [item setRepresentedObject: progPath]; 
    [menu addItem: item];
    RELEASE (item);  
  }

  [self selectItemAtIndex: ([components count] - 1)];
}

- (void)setItemsEnabled:(BOOL)enabled
{
  NSArray *items = [[self menu] itemArray];
  int i;

  for (i = 0; i < [items count]; i++)
    {
      [[items objectAtIndex: i] setEnabled: enabled];
    }
}

- (BOOL)closeViewer
{
  return closeViewer;
}

- (void)mouseDown:(NSEvent *)theEvent
{
  RETAIN (self);

  closeViewer = (([theEvent modifierFlags] == NSAlternateKeyMask)
		 || ([theEvent modifierFlags] == NSControlKeyMask));

  [super mouseDown: theEvent];

  if ([self superview])
    {
      [self selectItemAtIndex: ([self numberOfItems] - 1)];
    }

  RELEASE (self);
}

@end







