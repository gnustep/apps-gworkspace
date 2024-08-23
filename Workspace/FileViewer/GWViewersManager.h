/* GWViewersManager.h
 *  
 * Copyright (C) 2004-2013 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: June 2004
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


#import <Foundation/Foundation.h>
#import "FSNodeRep.h"
#import "GWViewer.h"

@class GWorkspace;
@class History;

@interface GWViewersManager : NSObject
{
  NSMutableArray *viewers;
  BOOL orderingViewers;
  GWorkspace *gworkspace;
  History *historyWindow;
  BOOL settingHistoryPath;
  NSHelpManager *helpManager;
  NSAttributedString *bviewerHelp;
  NSNotificationCenter *nc;  
}

+ (GWViewersManager *)viewersManager;


- (void)showViewers;

- (id)showRootViewer;

- (void)selectRepOfNode:(FSNode *)node
          inViewerWithBaseNode:(FSNode *)base;
            

- (id)viewerForNode:(FSNode *)node
          showType:(GWViewType)stype
     showSelection:(BOOL)showsel
          forceNew:(BOOL)force
	   withKey:(NSString *)key;
           
- (NSArray *)viewersForBaseNode:(FSNode *)node;

- (id)viewerWithBaseNode:(FSNode *)node; 

- (id)viewerShowingNode:(FSNode *)node; 

- (id)rootViewer;


- (void)viewerWillClose:(id)aviewer;

- (void)closeInvalidViewers:(NSArray *)vwrs;

- (void)selectionChanged:(NSArray *)selection;

- (void)openSelectionInViewer:(id)viewer
                  closeSender:(BOOL)close;
                  
- (void)openAsFolderSelectionInViewer:(id)viewer;

- (void)openWithSelectionInViewer:(id)viewer;


- (void)sortTypeDidChange:(NSNotification *)notif;

- (void)fileSystemWillChange:(NSNotification *)notif;

- (void)fileSystemDidChange:(NSNotification *)notif;

- (void)watcherNotification:(NSNotification *)notif;

- (void)thumbnailsDidChangeInPaths:(NSArray *)paths;

- (void)hideDotsFileDidChange:(BOOL)hide;

- (void)hiddenFilesDidChange:(NSArray *)paths;


- (BOOL)hasViewerWithWindow:(id)awindow;

- (id)viewerWithWindow:(id)awindow;

- (NSArray *)viewerWindows;

- (BOOL)orderingViewers;

- (void)updateDesktop;

- (void)updateDefaults;

@end


@interface GWViewersManager (History)

- (void)addNode:(FSNode *)node toHistoryOfViewer:(id)viewer;

- (void)removeDuplicatesInHistory:(NSMutableArray *)history
                         position:(int *)pos;
           
- (void)changeHistoryOwner:(id)viewer;

- (void)goToHistoryPosition:(int)pos 
                   ofViewer:(id)viewer;

- (void)goBackwardInHistoryOfViewer:(id)viewer;

- (void)goForwardInHistoryOfViewer:(id)viewer;

- (void)setPosition:(int)position
          inHistory:(NSMutableArray *)history
           ofViewer:(id)viewer;

@end
