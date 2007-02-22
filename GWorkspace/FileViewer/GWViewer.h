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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#ifndef GWVIEWER_H
#define GWVIEWER_H

#include <Foundation/Foundation.h>

@class GWViewersManager;
@class FSNode;
@class FSNodeRep;
@class GWViewerWindow;
@class GWViewerSplit;
@class GWViewerShelf;
@class GWViewerScrollView;
@class GWViewerIconsPath;
@class GWViewerPathsScroll;
@class NSView;
@class GWorkspace;

@interface GWViewer : NSObject
{
  GWViewerWindow *vwrwin;
  GWViewerSplit *split;
  GWViewerShelf *shelf;
  float shelfHeight;
  NSView *lowBox;
  GWViewerPathsScroll *pathsScroll;
  GWViewerIconsPath *pathsView;
  GWViewerScrollView *nviewScroll;
  id nodeView;
  
  NSDictionary *viewerPrefs;
  NSString *viewType;
  BOOL rootviewer;
  NSNumber *rootViewerKey;

  int visibleCols;
  int resizeIncrement;
    
  FSNode *baseNode;
  NSArray *baseNodeArray;
  NSArray *lastSelection;  
  NSMutableArray *watchedNodes;

  FSNodeRep *fsnodeRep;

  NSMutableArray *history;
  int historyPosition;
  
  BOOL invalidated;
  BOOL closing;
  
  GWViewersManager *manager;
  GWorkspace *gworkspace;

  NSNotificationCenter *nc;        
}

- (id)initForNode:(FSNode *)node
         inWindow:(GWViewerWindow *)win
         showType:(NSString *)stype
    showSelection:(BOOL)showsel;
- (void)createSubviews;
- (FSNode *)baseNode;
- (BOOL)isShowingNode:(FSNode *)anode;
- (BOOL)isShowingPath:(NSString *)apath;
- (void)reloadNodeContents;
- (void)reloadFromNode:(FSNode *)anode;
- (void)unloadFromNode:(FSNode *)anode;
- (void)updateShownSelection;

- (GWViewerWindow *)win;
- (id)nodeView;
- (id)shelf;
- (NSString *)viewType;
- (BOOL)isRootViewer;
- (NSNumber *)rootViewerKey;
- (BOOL)isSpatial;
- (int)vtype;

- (void)activate;
- (void)deactivate;
- (void)tileViews;
- (void)scrollToBeginning;
- (void)invalidate;
- (BOOL)invalidated;
- (BOOL)isClosing;

- (void)setOpened:(BOOL)opened 
        repOfNode:(FSNode *)anode;
- (void)unselectAllReps;
- (void)selectionChanged:(NSArray *)newsel;
- (void)multipleNodeViewDidSelectSubNode:(FSNode *)node;
- (void)pathsViewDidSelectIcon:(id)icon;
- (void)shelfDidSelectIcon:(id)icon;
- (void)setSelectableNodesRange:(NSRange)range;
- (void)updeateInfoLabels;

- (BOOL)involvedByFileOperation:(NSDictionary *)opinfo;
- (void)nodeContentsWillChange:(NSDictionary *)info;
- (void)nodeContentsDidChange:(NSDictionary *)info;

- (void)watchedPathChanged:(NSDictionary *)info;
- (NSArray *)watchedNodes;

- (void)hideDotsFileChanged:(BOOL)hide;
- (void)hiddenFilesChanged:(NSArray *)paths;

- (NSMutableArray *)history;
- (int)historyPosition;
- (void)setHistoryPosition:(int)pos;

- (void)columnsWidthChanged:(NSNotification *)notification;

- (void)updateDefaults;

@end


//
// GWViewerWindow Delegate Methods
//
@interface GWViewer (GWViewerWindowDelegateMethods)

- (void)openSelectionInNewViewer:(BOOL)newv;
- (void)openSelectionAsFolder;
- (void)openSelectionWith;
- (void)newFolder;
- (void)newFile;
- (void)duplicateFiles;
- (void)recycleFiles;
- (void)emptyTrash;
- (void)deleteFiles;
- (void)goBackwardInHistory;
- (void)goForwardInHistory;
- (void)setViewerBehaviour:(id)sender;
- (void)setViewerType:(id)sender;
- (void)setShownType:(id)sender;
- (void)setExtendedShownType:(id)sender;
- (void)setIconsSize:(id)sender;
- (void)setIconsPosition:(id)sender;
- (void)setLabelSize:(id)sender;
- (void)chooseLabelColor:(id)sender;
- (void)chooseBackColor:(id)sender;
- (void)selectAllInViewer;
- (void)showTerminal;
- (BOOL)validateItem:(id)menuItem;

@end

#endif // GWVIEWER_H
