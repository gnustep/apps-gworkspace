 /*
 *  TShelfIconsView.h: Interface and declarations for the Shelf Class 
 *  of the GNUstep TShelf application
 *
 *  Copyright (c) 2003 Enrico Sersale <enrico@dtedu.net>
 *  
 *  Author: Enrico Sersale
 *  Date: August 2003
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#ifndef TSHELF_ICONS_VIEW_H
#define TSHELF_ICONS_VIEW_H

#include <AppKit/NSView.h>

#define MAXSHELFHEIGHT  100

#ifndef max
#define max(a,b) ((a) > (b) ? (a):(b))
#endif

#ifndef min
#define min(a,b) ((a) < (b) ? (a):(b))
#endif

typedef struct {
  float x;  
  float y;  
	int index;
	int used; 
} gridpoint;

typedef gridpoint *(*GridPointIMP)(id, SEL, NSPoint);

@class NSString;
@class NSArray;
@class NSMutableArray;
@class NSNotification;
@class NSImage;
@class NSMenu;
@class TShelfIcon;
@class NSFileManager;
@class GWorkspace;

@interface TShelfIconsView : NSView 
{
	NSMutableArray *icons; 
	NSMutableArray *watchedPaths;
  int cellsWidth;
	gridpoint *gpoints;
	int pcount;
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

- (id)initWithIconsDicts:(NSArray *)iconsDicts;

- (NSArray *)iconsDicts;

- (void)addIconWithPaths:(NSArray *)iconpaths withGridIndex:(int)index;

- (void)removeIcon:(id)anIcon;

- (void)setLabelRectOfIcon:(id)anIcon;

- (void)unselectOtherIcons:(id)anIcon;

- (void)sortIcons;

- (NSArray *)icons;

- (void)updateIcons;

- (void)setCurrentSelection:(NSArray *)paths;

- (void)openCurrentSelection:(NSArray *)paths;

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

@end

@interface TShelfIconsView(DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender;

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender;

- (void)draggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

@end

#endif // TSHELF_ICONS_VIEW_H
