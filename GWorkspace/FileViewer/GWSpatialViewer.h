/* GWSpatialViewer.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#ifndef GW_SPATIAL_VIEWER_H
#define GW_SPATIAL_VIEWER_H

#include <Foundation/Foundation.h>

@class GWViewersManager;
@class GWViewerPathsPopUp;
@class FSNode;
@class GWViewerWindow;
@class GWorkspace;
@class NSView;
@class NSTextField;
@class NSScrollView;

@interface GWSpatialViewer : NSObject
{
  GWViewerWindow *vwrwin;
  NSView *mainView;
  NSView *topBox;
  NSTextField *elementsLabel;
  NSTextField *spaceLabel;
  GWViewerPathsPopUp *pathsPopUp;
  NSScrollView *scroll;
  id nodeView;
  
  NSString *viewType;
  BOOL rootviewer;
  BOOL spatial;

  int visibleCols;
    
  FSNode *shownNode;
  NSArray *lastSelection;  
  NSMutableArray *watchedNodes;
  BOOL watchersSuspended;
  int resizeIncrement;

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
- (void)invalidate;
- (BOOL)invalidated;

- (void)setOpened:(BOOL)opened 
        repOfPath:(NSString *)path;
- (void)unselectAllReps;
- (void)selectionChanged:(NSArray *)newsel;
- (void)setSelectableNodesRange:(NSRange)range;
- (void)updeateInfoLabels;
- (void)popUpAction:(id)sender;

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
@interface GWSpatialViewer (GWViewerWindowDelegateMethods)

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

#endif // GW_SPATIAL_VIEWER_H
