/* DesktopView.h
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

#ifndef DESKTOP_VIEW_H
#define DESKTOP_VIEW_H

#include <AppKit/NSView.h>
#include "FSNIconGridContainer.h"
#include "FSNodeRep.h"

@class NSColor;
@class NSImage;
@class NSMenu;
@class Desktop;
@class FSNode;
@class FSNIcon;
@class FSNIconNameEditor;

typedef enum BackImageStyle {   
  BackImageCenterStyle = 0,
  BackImageFitStyle = 1,
  BackImageTileStyle = 2
} BackImageStyle;


@interface DesktopView : NSView <FSNodeRepContainer>
{
  FSNode *node;
  NSString *infoPath;
  NSMutableDictionary *nodeInfo;
  NSMutableArray *icons;
  FSNInfoType infoType;
  
  NSImage *verticalImage;
  NSImage *horizontalImage;

  FSNSelectionMask selectionMask;
  NSArray *lastSelection;

  FSNIconNameEditor *nameEditor;
  FSNIcon *editIcon;

  int iconSize;
  int labelTextSize;
  int iconPosition;

  NSRect screenFrame;  
  NSSize gridSize;
  NSRect *grid;
  int rowcount;
  int colcount;
  int gridcount;

	NSImage *dragIcon;
  NSPoint dragPoint;
  int insertIndex;
	BOOL isDragTarget;
	BOOL dragLocalIcon;
  
  NSColor *backColor;
  NSImage *backImage;
  NSString *imagePath;
  NSPoint imagePoint;
  BackImageStyle backImageStyle;
  BOOL useBackImage;
    
  Desktop *desktop;
}

- (void)readNodeInfo;

- (void)updateNodeInfo;

- (void)newVolumeMountedAtPath:(NSString *)vpath;

- (void)workspaceWillUnmountVolumeAtPath:(NSString *)vpath;

- (void)workspaceDidUnmountVolumeAtPath:(NSString *)vpath;

- (void)showMountedVolumes;

- (void)dockPositionDidChange;

- (void)tile;

- (int)firstFreeGridIndex;

- (int)firstFreeGridIndexAfterIndex:(int)index;

- (BOOL)isFreeGridIndex:(int)index;

- (int)indexOfGridRectContainingPoint:(NSPoint)p;

- (NSRect)iconBoundsInGridAtIndex:(int)index;

- (void)calculateGridSize;

- (void)makeIconsGrid;

- (NSImage *)tshelfBackground;

- (void)updateDefaults;

@end


@interface DesktopView (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender;

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender;

- (void)draggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

@end


@interface DesktopView (IconNameEditing)

- (void)updateNameEditor;

- (void)controlTextDidChange:(NSNotification *)aNotification;

- (void)controlTextDidEndEditing:(NSNotification *)aNotification;

- (BOOL)fileManager:(NSFileManager *)manager 
              shouldProceedAfterError:(NSDictionary *)errorDict;

- (void)fileManager:(NSFileManager *)manager willProcessPath:(NSString *)path;

@end


@interface DesktopView (BackgroundColors)

- (NSColor *)currentColor;

- (void)setCurrentColor:(NSColor *)color;

- (void)createBackImage:(NSImage *)image;

- (NSImage *)backImage;

- (NSString *)backImagePath;

- (void)setBackImageAtPath:(NSString *)impath;

- (BOOL)useBackImage;

- (void)setUseBackImage:(BOOL)value;

- (BackImageStyle)backImageStyle;

- (void)setBackImageStyle:(BackImageStyle)style;

@end

#endif // DESKTOP_VIEW_H
