/* GWDesktopView.h
 *  
 * Copyright (C) 2005-2024 Free Software Foundation, Inc.
 *
 * Author: Enrico SersalE
 *         Riccardo Mottola <rm@gnu.org>
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

#import "FSNIconsView.h"

@class NSImage;
@class GWDesktopManager;

typedef enum BackImageStyle
{
  BackImageCenterStyle = 0,
  BackImageFitStyle = 1,
  BackImageTileStyle = 2,
  BackImageScaleStyle = 3
} BackImageStyle;


@interface GWDesktopView : FSNIconsView
{
  NSRect screenFrame;  
  NSRect *grid;
  NSInteger gridItemsCount;
  NSInteger rowItemsCount;

  NSImage *dragIcon;
  NSPoint dragPoint;
  NSUInteger insertIndex;
  BOOL dragLocalIcon;
  
  NSImage *backImage;
  NSString *imagePath;
  BackImageStyle backImageStyle;
  BOOL useBackImage;

  NSMutableArray *mountedVolumes;
  NSMutableDictionary *desktopInfo;
      
  GWDesktopManager *manager;
}

- (id)initForManager:(id)mngr;

- (void)newVolumeMountedAtPath:(NSString *)vpath;

- (void)workspaceWillUnmountVolumeAtPath:(NSString *)vpath;

- (void)workspaceDidUnmountVolumeAtPath:(NSString *)vpath;

- (void)unlockVolumeAtPath:(NSString *)path;

- (void)showMountedVolumes;

- (void)dockPositionDidChange;

- (NSUInteger)firstFreeGridIndex;

- (NSUInteger)firstFreeGridIndexAfterIndex:(NSUInteger)index;

- (BOOL)isFreeGridIndex:(NSUInteger)index;

- (FSNIcon *)iconWithGridIndex:(NSUInteger)index;

- (NSArray *)iconsWithGridOriginX:(float)x;

- (NSArray *)iconsWithGridOriginY:(float)y;

- (NSUInteger)indexOfGridRectContainingPoint:(NSPoint)p;

- (NSRect)iconBoundsInGridAtIndex:(NSUInteger)index;

- (void)makeIconsGrid;

- (NSImage *)tshelfBackground;

- (void)getDesktopInfo;

- (void)updateDefaults;

@end


@interface GWDesktopView (NodeRepContainer)

@end


@interface GWDesktopView (DraggingDestination)

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender;

- (void)draggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

@end


@interface GWDesktopView (BackgroundColors)

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
