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
@class NSView;
@class GWorkspace;

@interface GWViewer : NSObject
{
  GWViewerWindow *vwrwin;
  GWViewerSplit *split;
  GWViewerShelf *shelf;
  float shelfHeight;
  NSView *lowBox;
  NSScrollView *pathsScroll;
  GWViewerIconsPath *pathsView;
  NSScrollView *nviewScroll;
  id nodeView;
  
  NSString *viewType;
  BOOL rootviewer;
  BOOL spatial;

  int visibleCols;
    
  FSNode *baseNode;
  NSArray *lastSelection;  
  NSMutableArray *watchedNodes;
  BOOL watchersSuspended;
  
  GWViewersManager *manager;
  GWorkspace *gworkspace;
    
  BOOL invalidated;
}

- (id)initForNode:(FSNode *)node;
- (void)createSubviews;
- (FSNode *)shownNode;
- (void)reloadNodeContents;
- (void)unloadFromPath:(NSString *)path;

- (NSWindow *)win;
- (id)nodeView;
- (NSString *)viewType;
- (BOOL)isRootViewer;
- (BOOL)isSpatial;

- (void)activate;
- (void)deactivate;
- (void)tileViews;
- (void)invalidate;
- (BOOL)invalidated;

- (void)setOpened:(BOOL)opened 
        repOfPath:(NSString *)path;
- (void)unselectAllReps;
- (void)selectionChanged:(NSArray *)newsel;
- (void)pathsViewDidSelectIcon:(id)icon;
- (void)setSelectableNodesRange:(NSRange)range;
- (void)updeateInfoLabels;

- (BOOL)involvedByFileOperation:(NSDictionary *)opinfo;
- (void)nodeContentsWillChange:(NSDictionary *)info;
- (void)nodeContentsDidChange:(NSDictionary *)info;

- (void)setWatchersFromPath:(NSString *)path;
- (void)unsetWatchersFromPath:(NSString *)path;
- (void)watchedPathChanged:(NSDictionary *)info;
- (NSArray *)watchedNodes;

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
- (void)setViewerType:(id)sender;
- (void)selectAllInViewer;
- (void)showTerminal;
- (BOOL)validateItem:(id)menuItem;

@end

#endif // GWVIEWER_H
