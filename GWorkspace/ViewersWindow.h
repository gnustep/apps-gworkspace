/* ViewersWindow.h
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


#ifndef VIEWERSWIN_H
#define VIEWERSWIN_H

#include <AppKit/NSWindow.h>

@class NSString;
@class NSArray;
@class NSDictionary;
@class NSFileManager;
@class NSWorkspace;
@class NSNotification;
@class Shelf;
@class History;
@class GWorkspace;

@interface ViewersWindow : NSWindow 
{
  NSString *rootPath;
	NSArray *selectedPaths;
  BOOL viewsapps;
  int resizeIncrement;
  int iconCellsWidth;
  BOOL fixedResizeIncrements;
  BOOL isRootViewer;
	NSMutableArray *viewers;
	NSArray *viewerTemplates;
  NSString *viewType;
  
  id mainview;
	BOOL usingSplit;
  Shelf *shelf;
  float shelfHeight;
	id viewer;

	History *historyWin;
	NSMutableArray *ViewerHistory;
	int currHistoryPos;
  	
  GWorkspace *gw;
  NSFileManager *fm;  
}

- (id)initWithViewerTemplates:(NSArray *)templates 
                      forPath:(NSString *)path 
			            viewPakages:(BOOL)canview
			           isRootViewer:(BOOL)rootviewer
                      onStart:(BOOL)onstart;

- (void)makeViewersWithTemplates:(NSArray *)templates type:(NSString *)vtype;

- (void)changeViewer:(NSString *)newViewType;

- (id)viewer;

- (void)adjustSubviews;

- (void)viewFrameDidChange:(NSNotification *)notification;

- (void)setSelectedPaths:(NSArray *)paths;

- (NSPoint)positionForSlidedImage;

- (NSString *)rootPath;

- (void)checkRootPathAfterHidingOfPaths:(NSArray *)hpaths;

- (NSString *)currentViewedPath;

- (void)activate;

- (void)setViewerSelection:(NSArray *)selPaths;

- (void)viewersListDidChange:(NSNotification *)notification;

- (void)browserCellsIconsDidChange:(NSNotification *)notification;

- (void)viewersUseShelfDidChange:(NSNotification *)notification;

- (void)columnsWidthChanged:(NSNotification *)notification;

- (void)thumbnailsDidChangeInPaths:(NSArray *)paths;

- (void)updateDefaults;

- (void)updateInfoString;

- (NSString *)viewType;

- (BOOL)viewsApps;

- (void)selectAll;

//
// Menu operations
//
- (void)openSelection:(id)sender;

- (void)openSelectionAsFolder:(id)sender;

- (void)newFolder:(id)sender;

- (void)newFile:(id)sender;

- (void)duplicateFiles:(id)sender;

- (void)deleteFiles:(id)sender;

- (void)setViewerType:(id)sender;

- (void)selectAllInViewer:(id)sender;

- (void)print:(id)sender;

@end

//
// history methods
//
@interface ViewersWindow (historyMethods)

- (void)addToHistory:(NSString *)path;

- (void)tuneHistory;

- (void)setCurrentHistoryPosition:(int)newPosition;

- (void)goToHistoryPosition:(int)position;

- (void)goBackwardInHistory:(id)sender;

- (void)goForwardInHistory:(id)sender;

@end

//
// shelf delegate methods
//

@interface ViewersWindow (ShelfDelegateMethods)

- (NSArray *)getSelectedPaths;

- (void)shelf:(Shelf *)sender setCurrentSelection:(NSArray *)paths;

- (void)shelf:(Shelf *)sender setCurrentSelection:(NSArray *)paths
              animateImage:(NSImage *)image startingAtPoint:(NSPoint)startp;

- (void)shelf:(Shelf *)sender openCurrentSelection:(NSArray *)paths 
																				 newViewer:(BOOL)newv;
@end

//
// Viewers Delegate Methods
//

@interface ViewersWindow (ViewerDelegateMethods)

- (void)setTheSelectedPaths:(id)paths;

- (NSArray *)selectedPaths;

- (void)setTitleAndPath:(id)apath selectedPaths:(id)paths;

- (void)addPathToHistory:(NSArray *)paths;

- (void)updateTheInfoString;

- (int)browserColumnsWidth;

- (int)iconCellsWidth;

- (int)getWindowFrameWidth;

- (int)getWindowFrameHeight;

@end

#endif // VIEWERSWIN_H
