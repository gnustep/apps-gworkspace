 /*
 *  ViewerWindow.h: Interface and declarations for the ViewerWindow Class 
 *  of the GNUstep GWRemote application
 *
 *  Copyright (c) 2001 Enrico Sersale <enrico@imago.ro>
 *  
 *  Author: Enrico Sersale
 *  Date: August 2001
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

#ifndef VIEWERWIN_H
#define VIEWERWIN_H

#include <AppKit/NSWindow.h>

@class NSString;
@class NSArray;
@class NSDictionary;
@class NSFileManager;
@class NSNotification;
@class Shelf;

@interface ViewerWindow : NSWindow 
{
  NSString *serverName;
  NSString *rootPath;
	NSArray *selectedPaths;
  BOOL viewsapps;
  int resizeIncrement;
  int iconCellsWidth;
  BOOL fixedResizeIncrements;
  BOOL isRootViewer;
  
  id mainview;
  Shelf *shelf;
  float shelfHeight;
	id viewer;
  	
  id gw;
}

- (id)initForPath:(NSString *)path 
         onServer:(NSString *)server 
			viewPakages:(BOOL)canview
		 isRootViewer:(BOOL)rootviewer
          onStart:(BOOL)onstart;

- (void)activate;

- (void)setSelectedPaths:(NSArray *)paths;

- (void)setViewerSelection:(NSArray *)selPaths;

- (NSString *)currentViewedPath;

- (void)fileSystemDidChange:(NSDictionary *)info;

- (void)adjustSubviews;

- (NSPoint)positionForSlidedImage;

- (NSPoint)locationOfIconForPath:(NSString *)apath;

- (void)columnsWidthChanged:(NSNotification *)notification;

- (void)selectAll;

- (void)updateInfoString;

- (NSString *)serverName;

- (NSString *)rootPath;

- (id)viewer;

- (BOOL)viewsApps;

- (void)updateDefaults;


//
// Menu operations
//
- (void)openSelection:(id)sender;

- (void)openSelectionAsFolder:(id)sender;

- (void)newFolder:(id)sender;

- (void)newFile:(id)sender;

- (void)duplicateFiles:(id)sender;

- (void)deleteFiles:(id)sender;

- (void)selectAllInViewer:(id)sender;

- (void)print:(id)sender;

@end

//
// shelf delegate methods
//
@interface ViewerWindow (ShelfDelegateMethods)

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

@interface ViewerWindow (ViewerDelegateMethods)

- (void)setTheSelectedPaths:(id)paths;

- (NSArray *)selectedPaths;

- (void)setTitleAndPath:(id)apath selectedPaths:(id)paths;

- (void)updateTheInfoString;

- (int)browserColumnsWidth;

- (int)iconCellsWidth;

- (int)getWindowFrameWidth;

- (int)getWindowFrameHeight;

- (void)startIndicatorForOperation:(NSString *)operation;

- (void)stopIndicatorForOperation:(NSString *)operation;

@end

#endif // VIEWERWIN_H
