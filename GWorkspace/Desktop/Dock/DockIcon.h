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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
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
  id application;

  BOOL isWsIcon;
  BOOL isTrashIcon;
  NSImage *trashFullIcon;
  BOOL trashFull;
  BOOL isDocked;
  BOOL isLaunched;
	BOOL launching;
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
         iconSize:(int)isize;
        
- (void)setWsIcon:(BOOL)value;

- (BOOL)isWsIcon;

- (void)setTrashIcon:(BOOL)value;

- (void)setTrashFull:(BOOL)value;

- (BOOL)isTrashIcon;

- (BOOL)isSpecialIcon;

- (void)setIsDocked:(BOOL)value;

- (BOOL)isDocked;

- (void)setIsLaunched:(BOOL)value;

- (void)connectApplication;

- (void)applicationConnectionDidDie:(NSNotification *)notif;

- (BOOL)isLaunched;

- (void)animateLaunch;

- (void)setHighlightColor:(NSColor *)color;

- (void)setHighlightImage:(NSImage *)image;

- (void)setUseHlightImage:(BOOL)value;

- (void)setIsDndSourceIcon:(BOOL)value;

- (BOOL)acceptsDraggedPaths:(NSArray *)paths;

- (void)setDraggedPaths:(NSArray *)paths;

@end

#endif // DOCK_ICON_H
