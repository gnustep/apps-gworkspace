/* DockIcon.h
 *  
 * Copyright (C) 2005 Free Software Foundation, Inc.
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

#ifndef DOCK_ICON_H
#define DOCK_ICON_H

#include <AppKit/NSView.h>
#include "FSNIcon.h"

@class NSColor;
@class NSImage;

@interface DockIcon : FSNIcon
{
  NSString *appName;

  BOOL isWsIcon;
  BOOL isTrashIcon;
  NSImage *trashFullIcon;
  BOOL trashFull;
  BOOL docked;
  BOOL launched;
	BOOL launching;
  BOOL apphidden;  
  BOOL appactive;  
  float dissFract;	
    
  NSColor *darkerColor;
  NSColor *highlightColor;
  NSImage *highlightImage;
  BOOL useHligtImage;
    
  NSImage *dragIcon;
  BOOL isDndSourceIcon;

  NSFileManager *fm;
  NSNotificationCenter *nc; 
  id ws;
}

- (id)initForNode:(FSNode *)anode
          appName:(NSString *)aname
         iconSize:(int)isize;

- (NSString *)appName;
        
- (void)setWsIcon:(BOOL)value;

- (BOOL)isWsIcon;

- (void)setTrashIcon:(BOOL)value;

- (void)setTrashFull:(BOOL)value;

- (BOOL)isTrashIcon;

- (BOOL)isSpecialIcon;

- (void)setDocked:(BOOL)value;

- (BOOL)isDocked;

- (void)setLaunched:(BOOL)value;

- (BOOL)isLaunched;

- (void)setAppHidden:(BOOL)value;

- (BOOL)isAppHidden;

- (void)animateLaunch;

- (void)setHighlightColor:(NSColor *)color;

- (void)setHighlightImage:(NSImage *)image;

- (void)setUseHlightImage:(BOOL)value;

- (void)setIsDndSourceIcon:(BOOL)value;

- (BOOL)acceptsDraggedPaths:(NSArray *)paths;

- (void)setDraggedPaths:(NSArray *)paths;

@end

#endif // DOCK_ICON_H
