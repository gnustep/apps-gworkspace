/* Dock.h
 *  
 * Copyright (C) 2005-2012 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2005
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


#import <AppKit/NSView.h>
#import "GWDesktopManager.h"
#import "FSNodeRep.h"

@class NSWindow;
@class NSColor;
@class NSImage;
@class DockIcon;
@class GWorkspace;

typedef enum DockStyle
{   
  DockStyleClassic = 0,
  DockStyleModern = 1
} DockStyle;

@interface Dock : NSView 
{
  DockPosition position;
  DockStyle style;
  BOOL singleClickLaunch;

  NSMutableArray *icons;
  int iconSize;

  NSColor *backColor;
  
  DockIcon *dndSourceIcon;
  BOOL isDragTarget;
  int dragdelay;
  int targetIndex;
  NSRect targetRect;
  
  GWDesktopManager *manager; 
  GWorkspace *gw;
  NSFileManager *fm; 
  id ws;
}

- (id)initForManager:(id)mngr;

- (void)createWorkspaceIcon;

- (void)createTrashIcon;

- (DockIcon *)addIconForApplicationAtPath:(NSString *)path
                                 withName:(NSString *)name
                                  atIndex:(int)index;

- (void)addDraggedIcon:(NSData *)icondata
               atIndex:(int)index;

- (void)removeIcon:(DockIcon *)icon;

- (DockIcon *)iconForApplicationName:(NSString *)name;

- (DockIcon *)workspaceAppIcon;

- (DockIcon *)trashIcon;

- (DockIcon *)iconContainingPoint:(NSPoint)p;

- (void)setDndSourceIcon:(DockIcon *)icon;

- (void)appWillLaunch:(NSString *)appPath
              appName:(NSString *)appName;

- (void)appDidLaunch:(NSString *)appPath
             appName:(NSString *)appName;

- (void)appTerminated:(NSString *)appName;

- (void)appDidHide:(NSString *)appName;

- (void)appDidUnhide:(NSString *)appName;

- (void)iconMenuAction:(id)sender;

- (void)setSingleClickLaunch:(BOOL)value;

- (void)setPosition:(DockPosition)pos;

- (DockStyle)style;

- (void)setStyle:(DockStyle)s;

- (void)setBackColor:(NSColor *)color;

- (void)tile;

- (void)updateDefaults;

- (void)checkRemovedApp:(id)sender;

@end


@interface Dock (NodeRepContainer)

- (void)nodeContentsDidChange:(NSDictionary *)info;

- (void)watchedPathChanged:(NSDictionary *)info;

- (void)unselectOtherReps:(id)arep;

- (FSNSelectionMask)selectionMask;

- (void)setBackgroundColor:(NSColor *)acolor;

- (NSColor *)backgroundColor;

- (NSColor *)textColor;

- (NSColor *)disabledTextColor;

@end


@interface Dock (DraggingDestination)

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender;

- (void)draggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

- (BOOL)isDragTarget;

@end
