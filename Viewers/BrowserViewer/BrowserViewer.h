/* BrowserViewer.h
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


#ifndef BROWSER_VIEWER_H
#define BROWSER_VIEWER_H

#include <AppKit/NSView.h>
  #ifdef GNUSTEP 
#include "ViewersProtocol.h"
  #else
#include <GWorkspace/ViewersProtocol.h>
  #endif

@class NSString;
@class NSMutableArray;
@class NSFileManager;
@class NSDictionary;
@class NSNotification;
@class Browser2;
@class BrowserViewerPref;

@interface BrowserViewer : NSView <ViewersProtocol, NSCopying>
{
  Browser2 *browser;
  int resizeIncrement;
  int columns;
  float columnsWidth;  
  BOOL usesShelf;
  BOOL cellsIcons;
  NSString *rootPath;
  NSString *lastPath;  
	NSArray *selectedPaths;
  BOOL autoSynchronize;
  BOOL viewsapps;
  NSMutableArray *watchedPaths;  
  BrowserViewerPref *prefs;
	id delegate;
  NSFileManager *fm;
}

- (void)checkUsesShelf;

- (void)checkUsesCellsIcons;

- (void)renewAll;

- (void)validateRootPathAfterOperation:(NSDictionary *)opdict;

- (void)fileSystemWillChange:(NSNotification *)notification;

- (void)fileSystemDidChange:(NSNotification *)notification;

- (void)sortTypeDidChange:(NSNotification *)notification;

- (void)watcherNotification:(NSNotification *)notification;

- (void)setWatchers;

- (void)setWatcherForPath:(NSString *)path;

- (void)unsetWatcherForPath:(NSString *)path;

- (void)unsetWatchersFromPath:(NSString *)path;

- (void)reSetWatchersFromPath:(NSString *)path;

- (void)closeNicely;

- (void)close:(id)sender;

@end

//
// Methods Implemented by the Delegate 
//
@interface NSObject (ViewerDelegateMethods)

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

@interface BrowserViewer (Browser2DelegateMethods)

- (void)currentSelectedPaths:(NSArray *)paths;

- (void)openSelectedPaths:(NSArray *)paths newViewer:(BOOL)isnew;

@end

#endif // BROWSER_VIEWER_H

