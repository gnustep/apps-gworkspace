/* TShelfIconsView.h
 *  
 * Copyright (C) 2003-2013 Free Software Foundation, Inc.
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#ifndef TSHELF_ICONS_VIEW_H
#define TSHELF_ICONS_VIEW_H

#import <AppKit/NSView.h>

#define MAXSHELFHEIGHT  100

#ifndef max
  #define max(a,b) ((a) > (b) ? (a):(b))
#endif

#ifndef min
  #define min(a,b) ((a) < (b) ? (a):(b))
#endif

#ifndef FILES_TAB
  #define FILES_TAB 0
  #define DATA_TAB 1
#endif

typedef struct
{
  float x;  
  float y;  
  NSUInteger index;
  int used; 
} gridpoint;

typedef gridpoint *(*GridPointIMP)(id, SEL, NSPoint);

@class NSString;
@class NSArray;
@class NSMutableArray;
@class NSNotification;
@class NSImage;
@class NSTextField;
@class NSMenu;
@class TShelfIcon;
@class TShelfPBIcon;
@class NSFileManager;
@class GWorkspace;

@interface TShelfIconsView : NSView 
{
  BOOL isLastView;
  NSMutableArray *icons; 
  int iconsType;
  NSCountedSet *watchedPaths;
  int cellsWidth;
  gridpoint *gpoints;
  NSUInteger pcount;
  
  id focusedIcon;
  NSTextField *focusedIconLabel;
  
  BOOL isDragTarget;
  NSImage *dragImage;
  NSPoint dragPoint;
  NSRect dragRect;	
  SEL makePosSel;
  
  IMP makePos;
  SEL gridPointSel;
  GridPointIMP gridPoint;
  NSFileManager *fm;
  GWorkspace *gw;
}

- (id)initWithIconsDescription:(NSArray *)idescr 
                     iconsType:(int)itype
                      lastView:(BOOL)last;

- (NSArray *)iconsDescription;

- (void)addIconWithPaths:(NSArray *)iconpaths withGridIndex:(NSUInteger)index;

- (TShelfPBIcon *)addPBIconForDataAtPath:(NSString *)dpath 
                                dataType:(NSString *)dtype
                           withGridIndex:(NSUInteger)index; 

- (void)removeIcon:(id)anIcon;

- (void)removePBIconsWithData:(NSData *)data ofType:(NSString *)type;

- (void)setLabelRectOfIcon:(id)anIcon;

- (BOOL)hasSelectedIcon;

- (void)unselectOtherIcons:(id)anIcon;

- (void)setFocusedIcon:(id)anIcon;

- (void)updateFocusedIconLabel;

- (void)sortIcons;

- (NSArray *)icons;

- (int)iconsType;

- (void)updateIcons;

- (id)selectedIcon;

- (void)setCurrentSelection:(NSArray *)paths;

- (void)openCurrentSelection:(NSArray *)paths;

- (void)checkIconsAfterDotsFilesChange;

- (void)checkIconsAfterHidingOfPaths:(NSArray *)hpaths;

- (void)fileSystemWillChange:(NSNotification *)notification;

- (void)fileSystemDidChange:(NSNotification *)notification;

- (void)watcherNotification:(NSNotification *)notification;

- (void)setWatchers;

- (void)setWatcherForPath:(NSString *)path;

- (void)unsetWatchers;

- (void)unsetWatcherForPath:(NSString *)path;

- (void)makePositions;

- (gridpoint *)gridPointNearestToPoint:(NSPoint)p;

- (BOOL)isFreePosition:(NSPoint)pos;

- (int)cellsWidth;

- (void)setSingleClickLaunch:(BOOL)value;

@end

@interface TShelfIconsView(PBoardOperations)

- (void)setCurrentPBIcon:(id)anIcon;

- (void)doCut;

- (void)doCopy;

- (void)doPaste;

- (NSData *)readSelectionFromPasteboard:(NSPasteboard *)pboard
                                 ofType:(NSString **)pbtype;
             
@end

@interface TShelfIconsView(DraggingDestination)

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender;

- (void)draggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

@end

#endif // TSHELF_ICONS_VIEW_H
