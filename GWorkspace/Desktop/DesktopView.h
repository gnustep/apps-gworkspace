/* DesktopView.h
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
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


#ifndef DESKTOPVIEW_H
#define DESKTOPVIEW_H

#include <AppKit/NSView.h>
  #ifdef GNUSTEP 
#include "IconViewsProtocol.h"
  #else
#include <GWorkspace/IconViewsProtocol.h>
  #endif

@class NSString;
@class NSArray;
@class NSNotification;
@class NSMutableArray;
@class NSColor;
@class NSImage;
@class NSFileManager;
@class GWorkspace;

@interface DesktopView : NSView <IconViewsProtocol>
{
  NSColor *backColor;
  NSImage *backImage;
	NSImage *dragImage;
	NSPoint dragPoint;
	NSRect dragRect;
	SEL gridCoordSel;
	IMP gridCoord;			
	NSString *imagePath;
	NSMutableArray *icons; 
	float *xpositions;
  float *ypositions;
	int xcount, ycount;
	NSMutableArray *watchedPaths;
  int cellsWidth;
	int cellsHeight;
	BOOL isDragTarget;
  id delegate;
  
  NSFileManager *fm;
  GWorkspace *gw;
}

- (void)addIconWithPaths:(NSArray *)iconpaths atPosition:(NSPoint)pos;

- (NSArray *)iconsPaths;

- (NSArray *)icons;

- (NSColor *)backColor;

- (NSImage *)shelfBackground;

- (void)changeBackColor:(NSNotification *)notification;

- (void)changeBackImage:(NSNotification *)notification;

- (void)unsetBackImage:(NSNotification *)notification;

- (void)fileSystemWillChange:(NSNotification *)notification;

- (void)fileSystemDidChange:(NSNotification *)notification;

- (void)watcherNotification:(NSNotification *)notification;

- (void)setWatchers;

- (void)setWatcherForPath:(NSString *)path;

- (void)unsetWatchers;

- (void)unsetWatcherForPath:(NSString *)path;

- (void)cellsWidthChanged:(NSNotification *)notification;

- (void)updateIcons;

- (void)saveDefaults;

- (void)makePositions;

- (void)gridCoordonatesX:(float *)x Y:(float *)y nearestToPoint:(NSPoint)p;

- (void)getOnGridPositionX:(int *)x Y:(int *)y ofPoint:(NSPoint)p;

- (NSPoint)firstFreePosition;

- (BOOL)isFreePosition:(NSPoint)pos;

- (NSPoint)arrangePosition:(NSPoint)p;

@end

@interface DesktopView(DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender;

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender;

- (void)draggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

@end

#endif // DESKTOPVIEW_H
