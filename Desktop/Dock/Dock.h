/* Dock.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: May 2004
 *
 * This file is part of the GNUstep Desktop application
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

#ifndef DOCK_H
#define DOCK_H

#include <AppKit/NSView.h>
#include "Desktop.h"
#include "FSNodeRep.h"

@class NSColor;
@class NSImage;
@class DockIcon;

@interface DockWindow : NSWindow 
{
  id dock;
}

- (void)setDock:(id)dk;

@end

@interface Dock : NSView <FSNodeRepContainer>
{
  DockWindow *win;
  DockPosition position;

  NSMutableArray *icons;
  int iconSize;

  NSColor *backColor;
  NSImage *backImage;
  BOOL useBackImage;
  
  DockIcon *dndSourceIcon;
  BOOL isDragTarget;
  int dragdelay;
  int targetIndex;
  NSRect targetRect;
  
  Desktop *desktop;  
  id ws;
  NSNotificationCenter *wsnc; 
}

- (void)activate;

- (void)createWorkspaceIcon;

- (void)createTrashIcon;

- (DockIcon *)addIconForApplicationWithName:(NSString *)name
                                    atIndex:(int)index;

- (void)addDraggedIcon:(NSData *)icondata
               atIndex:(int)index;

- (void)removeIcon:(DockIcon *)icon;

- (DockIcon *)iconForApplicationName:(NSString *)name;

- (DockIcon *)workspaceAppIcon;

- (DockIcon *)trashIcon;

- (DockIcon *)iconContainingPoint:(NSPoint)p;

- (void)setDndSourceIcon:(DockIcon *)icon;

- (void)applicationWillLaunch:(NSNotification *)notif;

- (void)applicationLaunched:(NSNotification *)notif;

- (void)setPosition:(DockPosition)pos;

- (void)setBackColor:(NSColor *)color;

- (void)setBackImage;

- (void)setUseBackImage:(BOOL)value;

- (void)tile;

- (void)updateDefaults;

- (id)win;

@end


@interface Dock (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender;

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender;

- (void)draggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

@end

#endif // DOCK_H
