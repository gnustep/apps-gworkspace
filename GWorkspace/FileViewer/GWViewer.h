/* GWViewer.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: July 2004
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

#ifndef GWVIEWER_H
#define GWVIEWER_H

#include <Foundation/Foundation.h>

@class GWViewersManager;
@class FSNode;
@class GWViewerWindow;
@class GWViewerSplit;
@class GWViewerShelf;
@class NSScrollView;
@class GWViewerIconsPath;
@class GWViewerScroll;
@class NSView;
@class GWorkspace;

@interface GWViewer : NSObject
{
  GWViewerWindow *vwrwin;
  GWViewerSplit *split;
  GWViewerShelf *shelf;
  float shelfHeight;
  NSView *lowBox;
  GWViewerScroll *pathsScroll;
  GWViewerIconsPath *pathsView;
  NSScrollView *nviewScroll;
  id nodeView;
  
  NSString *viewType;
  BOOL rootviewer;
  BOOL spatial;

  int visibleCols;
  int resizeIncrement;
    
  FSNode *baseNode;
  NSArray *lastSelection;  
  NSMutableArray *watchedNodes;
  NSMutableArray *watchedSuspended;

  BOOL invalidated;
  
  GWViewersManager *manager;
  GWorkspace *gworkspace;

  NSNotificationCenter *nc;        
}

- (id)initForNode:(FSNode *)node
         inWindow:(GWViewerWindow *)win
    showSelection:(BOOL)showsel;
- (void)createSubviews;
- (FSNode *)baseNode;
- (BOOL)isShowingNode:(FSNode *)anode;
- (BOOL)isShowingPath:(NSString *)apath;
- (void)reloadNodeContents;
- (void)reloadFromNode:(FSNode *)anode;
- (void)unloadFromNode:(FSNode *)anode;

- (GWViewerWindow *)win;
- (id)nodeView;
- (NSString *)viewType;
- (BOOL)isRootViewer;
- (BOOL)isSpatial;
- (int)vtype;

- (void)activate;
- (void)deactivate;
- (void)tileViews;
- (void)scrollToBeginning;
- (void)invalidate;
- (BOOL)invalidated;

- (void)setOpened:(BOOL)opened 
        repOfNode:(FSNode *)anode;
- (void)unselectAllReps;
- (void)selectionChanged:(NSArray *)newsel;
- (void)pathsViewDidSelectIcon:(id)icon;
- (void)setSelectableNodesRange:(NSRange)range;
- (void)updeateInfoLabels;

- (BOOL)involvedByFileOperation:(NSDictionary *)opinfo;
- (void)nodeContentsWillChange:(NSDictionary *)info;
- (void)nodeContentsDidChange:(NSDictionary *)info;

- (void)suspendWatchersFromPath:(NSString *)path;
- (void)reactivateWatchersFromPath:(NSString *)path;
- (void)clearSuspendedWatchersFromPath:(NSString *)path;
- (void)watchedPathChanged:(NSDictionary *)info;
- (NSArray *)watchedNodes;

- (void)columnsWidthChanged:(NSNotification *)notification;

- (void)updateDefaults;

@end


//
// GWViewerWindow Delegate Methods
//
@interface GWViewer (GWViewerWindowDelegateMethods)

- (void)openSelectionInNewViewer:(BOOL)newv;
- (void)openSelectionAsFolder;
- (void)newFolder;
- (void)newFile;
- (void)duplicateFiles;
- (void)deleteFiles;
- (void)setViewerBehaviour:(id)sender;
- (void)setViewerType:(id)sender;
- (void)selectAllInViewer;
- (void)showTerminal;
- (BOOL)validateItem:(id)menuItem;

@end

#endif // GWVIEWER_H
