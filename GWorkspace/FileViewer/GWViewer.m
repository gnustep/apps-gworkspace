/* GWViewer.m
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

#include <AppKit/AppKit.h>
#include <math.h>
#include "GWViewer.h"
#include "GWViewersManager.h"
#include "GWViewerBrowser.h"
#include "GWViewerIconsView.h"
#include "GWViewerWindow.h"
#include "GWViewerSplit.h"
#include "GWViewerShelf.h"
#include "GWViewerIconsPath.h"
#include "GWorkspace.h"
#include "FSNBrowser.h"
#include "FSNIconsView.h"
#include "FSNodeRep.h"
#include "FSNIcon.h"
#include "FSNFunctions.h"

#define DEFAULT_INCR 150
#define MIN_W_HEIGHT 180

#define MIN_SHELF_HEIGHT 2.0
#define MID_SHELF_HEIGHT 77.0
#define MAX_SHELF_HEIGHT 150.0
#define COLLAPSE_LIMIT 35
#define MID_LIMIT 110

@implementation GWViewer

- (void)dealloc
{
  [nc removeObserver: self];

  RELEASE (baseNode);
  TEST_RELEASE (lastSelection);
  RELEASE (watchedNodes);
  RELEASE (watchedSuspended);
  RELEASE (vwrwin);
  RELEASE (viewType);
  
  [super dealloc];
}

- (id)initForNode:(FSNode *)node
         inWindow:(GWViewerWindow *)win
    showSelection:(BOOL)showsel
{
  self = [super init];
  
  if (self) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	      
    NSString *prefsname = [NSString stringWithFormat: @"viewer_at_%@", [node path]];
    NSDictionary *viewerPrefs = nil;
    id defEntry;
    
    ASSIGN (baseNode, [FSNode nodeWithRelativePath: [node path] parent: nil]);
    lastSelection = nil;
    watchedNodes = [NSMutableArray new];
    watchedSuspended = [NSMutableArray new];
    manager = [GWViewersManager viewersManager];
    gworkspace = [GWorkspace gworkspace];
    nc = [NSNotificationCenter defaultCenter];
    spatial = NO;
    
    defEntry = [defaults objectForKey: @"browserColsWidth"];
    if (defEntry) {
      resizeIncrement = [defEntry intValue];
    } else {
      resizeIncrement = DEFAULT_INCR;
    }

    rootviewer = ([[baseNode path] isEqual: path_separator()]
                && ([[manager viewersForBaseNode: baseNode] count] == 0));
    
    if ([baseNode isWritable] && (rootviewer == NO)) {
		  NSString *dictPath = [[baseNode path] stringByAppendingPathComponent: @".gwdir"];

      if ([[NSFileManager defaultManager] fileExistsAtPath: dictPath]) {
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: dictPath];

        if (dict) {
          viewerPrefs = [dict copy];
        }   
      }
    }
    
    if (viewerPrefs == nil) {
      defEntry = [defaults dictionaryForKey: prefsname];
    
      if (defEntry) {
        viewerPrefs = [defEntry copy];
      } else {
        viewerPrefs = [NSDictionary new];
      }
    }
    
    viewType = [viewerPrefs objectForKey: @"viewtype"];
    
    if (viewType == nil) {
      viewType = @"Icon";
    }
    if (([viewType isEqual: @"Icon"] == NO)
              && ([viewType isEqual: @"Browser"] == NO)) {
      viewType = @"Browser";
    }

    RETAIN (viewType);
    
    defEntry = [viewerPrefs objectForKey: @"shelfheight"];
    
    if (defEntry) {
      shelfHeight = [defEntry floatValue];
    } else {
      shelfHeight = MID_SHELF_HEIGHT;
    }
       
    ASSIGN (vwrwin, win);
    [vwrwin setDelegate: self];
    [vwrwin setMinSize: NSMakeSize(resizeIncrement * 2, MIN_W_HEIGHT)];    
    [vwrwin setResizeIncrements: NSMakeSize(resizeIncrement, 1)];

    defEntry = [viewerPrefs objectForKey: @"geometry"];
    
    if (defEntry) {
      [vwrwin setFrameFromString: defEntry];
    } else {
      [vwrwin setFrame: NSMakeRect(200, 200, resizeIncrement * 3, 400) 
               display: NO];
    }

    if (rootviewer) {
      [vwrwin setTitle: NSLocalizedString(@"File Viewer", @"")];
    } else {
      [vwrwin setTitle: [NSString stringWithFormat: @"%@ - %@", [node name], [node parentPath]]];   
    }

    [self createSubviews];
    
    defEntry = [viewerPrefs objectForKey: @"shelfdicts"];
    
    if (defEntry) {
      [shelf setContents: defEntry];
    }
        
    if ([viewType isEqual: @"Icon"]) {
      nodeView = [[GWViewerIconsView alloc] initForViewer: self];
      
      [pathsScroll setDelegate: pathsView];
      
    } else if ([viewType isEqual: @"Browser"]) {    
      nodeView = [[GWViewerBrowser alloc] initWithBaseNode: baseNode
                                      inViewer: self
		                            visibleColumns: visibleCols
                                      scroller: [pathsScroll horizontalScroller]
                                    cellsIcons: NO
                                 editableCells: NO   
                               selectionColumn: YES];
    }

    [nviewScroll setDocumentView: nodeView];	
    RELEASE (nodeView);                 
    [nodeView showContentsOfNode: baseNode]; 
    
    if (showsel) {
      defEntry = [viewerPrefs objectForKey: @"lastselection"];
    
      if (defEntry) {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSMutableArray *selection = [defEntry mutableCopy];
        int count = [selection count];
        int i;

        for (i = 0; i < count; i++) {
          NSString *s = [selection objectAtIndex: i];

          if ([fm fileExistsAtPath: s] == NO){
            [selection removeObject: s];
            count--;
            i--;
          }
        }

        if ([selection count]) {
          if ([nodeView isSingleNode]) {
            NSString *base;
            FSNode *basenode;
          
            base = [selection objectAtIndex: 0];
            base = [base stringByDeletingLastPathComponent];
            basenode = [FSNode nodeWithRelativePath: base parent: nil];
          
            [nodeView showContentsOfNode: basenode];
            [nodeView selectRepsOfPaths: selection];
          
          } else {
            [nodeView selectRepsOfPaths: selection];
          }
        }

        RELEASE (selection);
      }
    }

    [self updeateInfoLabels];
    [self tileViews];

    [self scrollToBeginning];
    
    RELEASE (viewerPrefs);
    
    [nc addObserver: self 
           selector: @selector(columnsWidthChanged:) 
               name: @"GWBrowserColumnWidthChangedNotification"
             object: nil];
  }
  
  return self;
}

- (void)createSubviews
{
  NSRect r = [[vwrwin contentView] frame];
  float w = r.size.width;
	float h = r.size.height;   
  float d = 0.0;
  int xmargin = 8;
  int ymargin = 6;
  int pathscrh = 98;
  unsigned int resizeMask;
  
  split = [[GWViewerSplit alloc] initWithFrame: r];
  [split setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];
  [split setDelegate: self];
  
  d = [split dividerThickness];
  
  r = NSMakeRect(0, 0, w, shelfHeight);  
  shelf = [[GWViewerShelf alloc] initWithFrame: r forViewer: self];
  [split addSubview: shelf];
  RELEASE (shelf);
  
  r = NSMakeRect(0, shelfHeight + d, w, h - shelfHeight - d);
  lowBox = [[NSView alloc] initWithFrame: r];
  resizeMask = NSViewWidthSizable | NSViewHeightSizable;
  [lowBox setAutoresizingMask: resizeMask];
  [lowBox setAutoresizesSubviews: YES];
  [split addSubview: lowBox];
  RELEASE (lowBox);

  r = [lowBox frame];
  w = r.size.width;
  h = r.size.height; 
  
  r = NSMakeRect(xmargin, h - pathscrh, w - (xmargin * 2), pathscrh);
  pathsScroll = [[GWViewerScroll alloc] initWithFrame: r];
  [pathsScroll setBorderType: NSBezelBorder];
  [pathsScroll setHasHorizontalScroller: YES];
  [pathsScroll setHasVerticalScroller: NO];
  [pathsScroll setDelegate: nil];
  resizeMask = NSViewNotSizable | NSViewWidthSizable | NSViewMinYMargin;
  [pathsScroll setAutoresizingMask: resizeMask];
  [lowBox addSubview: pathsScroll];
  RELEASE (pathsScroll);

  visibleCols = rintf(r.size.width / [vwrwin resizeIncrements].width);  
  
  r = [[pathsScroll documentView] frame];
  pathsView = [[GWViewerIconsPath alloc] initWithFrame: r 
                   visibleIcons: visibleCols forViewer: self
                   ownsScroller: ([viewType isEqual: @"Browser"] == NO)];
  resizeMask = NSViewNotSizable;
  [pathsView setAutoresizingMask: resizeMask];
  [pathsScroll setDocumentView: pathsView];
  RELEASE (pathsView);
  
  r = NSMakeRect(xmargin, 0, w - (xmargin * 2), h - pathscrh - ymargin);
  nviewScroll = [[NSScrollView alloc] initWithFrame: r];
  [nviewScroll setBorderType: NSBezelBorder];
  [nviewScroll setHasHorizontalScroller: [viewType isEqual: @"Icon"]];
  [nviewScroll setHasVerticalScroller: [viewType isEqual: @"Icon"]];
  resizeMask = NSViewNotSizable | NSViewWidthSizable | NSViewHeightSizable;
  [nviewScroll setAutoresizingMask: resizeMask];
  [lowBox addSubview: nviewScroll];
  RELEASE (nviewScroll);
  
  [vwrwin setContentView: split];
  RELEASE (split);
}

- (FSNode *)baseNode
{
  return baseNode;
}

- (BOOL)isShowingNode:(FSNode *)anode
{
  NSArray *comps = [FSNode nodeComponentsFromNode: baseNode 
                                           toNode: [nodeView shownNode]];
  return [comps containsObject: anode];
}

- (BOOL)isShowingPath:(NSString *)apath
{
  FSNode *node = [FSNode nodeWithRelativePath: apath parent: nil];
  return [self isShowingNode: node];
}

- (void)reloadNodeContents
{
  [nodeView reloadContents];
}

- (void)reloadFromNode:(FSNode *)anode
{
  [nodeView reloadFromNode: anode];
}

- (void)unloadFromNode:(FSNode *)anode
{
  if ([baseNode isEqual: anode] || [baseNode isSubnodeOfNode: anode]) {
    [self deactivate];
  } else {
    [nodeView unloadFromNode: anode];
  }
}

- (void)updateShownSelection
{
  [pathsView updateLastIcon];
}

- (GWViewerWindow *)win
{
  return vwrwin;
}

- (id)nodeView
{
  return nodeView;
}

- (id)shelf
{
  return shelf;
}

- (NSString *)viewType
{
  return viewType;
}

- (BOOL)isRootViewer
{
  return rootviewer;
}

- (BOOL)isSpatial
{
  return spatial;
}

- (int)vtype
{
  return (spatial ? SPATIAL : BROWSING);
}

- (void)activate
{
  [vwrwin makeKeyAndOrderFront: nil];
  [self tileViews];
}

- (void)deactivate
{
  [vwrwin close];
}

- (void)tileViews
{
  NSRect r = [split frame];
  float w = r.size.width;
	float h = r.size.height;   
  float d = [split dividerThickness];
    
  [shelf setFrame: NSMakeRect(0, 0, w, shelfHeight)];
  [lowBox setFrame: NSMakeRect(0, shelfHeight + d, w, h - shelfHeight - d)];
}

- (void)scrollToBeginning
{
  if ([nodeView isSingleNode]) {
    NSRect r = [nodeView frame];
    [nodeView scrollRectToVisible: NSMakeRect(0, r.size.height - 1, 1, 1)];	
  }
}

- (void)invalidate
{
  invalidated = YES;
}

- (BOOL)invalidated
{
  return invalidated;
}

- (void)setOpened:(BOOL)opened 
        repOfNode:(FSNode *)anode
{
  id rep = [nodeView repOfSubnode: anode];

  if (rep) {
    [rep setOpened: opened];
    
    if ([nodeView isSingleNode]) { 
      [rep select];
    }
  }
}

- (void)unselectAllReps
{
  [nodeView unselectOtherReps: nil];
  [nodeView selectionDidChange];
}

- (void)selectionChanged:(NSArray *)newsel
{
  FSNode *node;
  NSArray *components;
  int i, j, count;

  [manager selectionChanged: newsel];

  if (lastSelection && [newsel isEqual: lastSelection]) {
    if ([[newsel objectAtIndex: 0] isEqual: [[nodeView shownNode] path]] == NO) {
      return;
    }
  }

  ASSIGN (lastSelection, newsel);
  [self updeateInfoLabels]; 
    
  node = [FSNode nodeWithRelativePath: [newsel objectAtIndex: 0] parent: nil];   
     
  if (([node isDirectory] == NO) || [node isPackage] || ([newsel count] > 1)) {
    if ([node isEqual: baseNode] == NO) { // if baseNode is a package 
      node = [FSNode nodeWithRelativePath: [node parentPath] parent: nil];
    }
  }
    
  components = [FSNode nodeComponentsFromNode: baseNode toNode: node];
  
  [pathsView showPathComponents: components selection: newsel];

  if ([node isDirectory] && ([newsel count] == 1)) {
    if ([nodeView isSingleNode] && ([node isEqual: [nodeView shownNode]] == NO)) {
      node = [FSNode nodeWithRelativePath: [node parentPath] parent: nil];
      components = [FSNode nodeComponentsFromNode: baseNode toNode: node];
    }
  }

  count = [components count];

  for (i = 0; i < [watchedNodes count]; i++) {
    FSNode *n1 = [watchedNodes objectAtIndex: i];
    FSNode *n2 = nil;

    if (count > i) {
      n2 = [components objectAtIndex: i];  
    } else {
      i = count;
      break;
    }

    if ([n1 isEqual: n2] == NO) {
      break;
    }    
  }

  for (j = i; j < [watchedNodes count]; j++) {  
    [gworkspace removeWatcherForPath: [[watchedNodes objectAtIndex: j] path]];
  }

  for (j = i; j < [components count]; j++) { 
    [gworkspace addWatcherForPath: [[components objectAtIndex: j] path]];
  }
  
  [watchedNodes removeAllObjects];
  [watchedNodes addObjectsFromArray: components];
}

- (void)pathsViewDidSelectIcon:(id)icon
{
  FSNode *node = [icon node];

  if ([node isDirectory] && ([node isPackage] == NO)) {
    if ([nodeView isSingleNode]) {
      [nodeView showContentsOfNode: node];
      [self scrollToBeginning];
      [self selectionChanged: [NSArray arrayWithObject: [node path]]];
      
    } else {
      [nodeView setLastShownNode: node];
    }
  }
}

- (void)shelfDidSelectIcon:(id)icon
{
  FSNode *node = [icon node];
  FSNode *base = [FSNode nodeWithRelativePath: [node parentPath] parent: nil];
  NSArray *selection = [icon selection];

  if (selection == nil) {
    selection = [NSArray arrayWithObject: node];
  }
  
  [nodeView showContentsOfNode: base];
  [nodeView selectRepsOfSubnodes: selection];
}

- (void)setSelectableNodesRange:(NSRange)range
{
  visibleCols = range.length;
  [pathsView setSelectableIconsRange: range];
}

- (void)updeateInfoLabels
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSDictionary *attributes = [fm fileSystemAttributesAtPath: [[nodeView shownNode] path]];
  NSNumber *freefs = [attributes objectForKey: NSFileSystemFreeSize];
  NSString *labelstr;
  
	if (freefs == nil) {  
		labelstr = NSLocalizedString(@"unknown volume size", @"");    
	} else {
		labelstr = [NSString stringWithFormat: @"%@ %@", 
                   sizeDescription([freefs unsignedLongLongValue]),
                                        NSLocalizedString(@"free", @"")];
	}

  [split updateDiskSpaceInfo: labelstr];
}

- (BOOL)involvedByFileOperation:(NSDictionary *)opinfo
{
  FSNode *lastNode = [nodeView shownNode];
  NSArray *comps = [FSNode nodeComponentsFromNode: baseNode toNode: lastNode];
  int i;    

  for (i = 0; i < [comps count]; i++) {
    if ([[comps objectAtIndex: i] involvedByFileOperation: opinfo]) {
      return YES;
    }
  }

  return NO;
}

- (void)nodeContentsWillChange:(NSDictionary *)info
{
  NSString *operation = [info objectForKey: @"operation"];
  NSString *source = [info objectForKey: @"source"];
  NSString *destination = [info objectForKey: @"destination"];
  NSArray *files = [info objectForKey: @"files"];
    
  if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
    files = [NSArray arrayWithObject: [destination lastPathComponent]];
    destination = [destination stringByDeletingLastPathComponent]; 
  }

  if ([operation isEqual: @"NSWorkspaceMoveOperation"] 
        || [operation isEqual: @"NSWorkspaceCopyOperation"]
        || [operation isEqual: @"NSWorkspaceLinkOperation"]
        || [operation isEqual: @"NSWorkspaceDuplicateOperation"]
        || [operation isEqual: @"GWorkspaceCreateDirOperation"]
        || [operation isEqual: @"GWorkspaceCreateFileOperation"]
        || [operation isEqual: @"GWorkspaceRenameOperation"]
			  || [operation isEqual: @"GWorkspaceRecycleOutOperation"]) { 
    if ([self isShowingPath: destination]
                    || [baseNode isSubnodeOfPath: destination]) {
      [self suspendWatchersFromPath: destination];
    }
  }

  if ([operation isEqual: @"NSWorkspaceMoveOperation"]
        || [operation isEqual: @"NSWorkspaceDestroyOperation"]
				|| [operation isEqual: @"NSWorkspaceRecycleOperation"]
				|| [operation isEqual: @"GWorkspaceRecycleOutOperation"]
				|| [operation isEqual: @"GWorkspaceEmptyRecyclerOperation"]) {
    if ([self isShowingPath: source]
                    || [baseNode isSubnodeOfPath: source]) {
      [self suspendWatchersFromPath: source];
    }
  }

  [nodeView nodeContentsWillChange: info];
}

- (void)nodeContentsDidChange:(NSDictionary *)info
{
  NSString *operation = [info objectForKey: @"operation"];
  NSString *source = [info objectForKey: @"source"];
  NSString *destination = [info objectForKey: @"destination"];
  NSArray *files = [info objectForKey: @"files"];

  if ([nodeView isSingleNode] == NO) {  
    [nodeView nodeContentsDidChange: info];
  }
  
  if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
    files = [NSArray arrayWithObject: [destination lastPathComponent]];
    destination = [destination stringByDeletingLastPathComponent]; 
  }

  if ([operation isEqual: @"NSWorkspaceRecycleOperation"]) {
		files = [info objectForKey: @"origfiles"];
  }	

  if ([operation isEqual: @"NSWorkspaceMoveOperation"] 
        || [operation isEqual: @"NSWorkspaceCopyOperation"]
        || [operation isEqual: @"NSWorkspaceLinkOperation"]
        || [operation isEqual: @"NSWorkspaceDuplicateOperation"]
        || [operation isEqual: @"GWorkspaceCreateDirOperation"]
        || [operation isEqual: @"GWorkspaceCreateFileOperation"]
        || [operation isEqual: @"GWorkspaceRenameOperation"]
			  || [operation isEqual: @"GWorkspaceRecycleOutOperation"]) { 
    if ([nodeView isSingleNode]) {
      FSNode *node = [FSNode nodeWithRelativePath: destination parent: nil];
      [nodeView reloadFromNode: node];
    }
        
    if ([self isShowingPath: destination]
                        || [baseNode isSubnodeOfPath: destination]) {
      [self reactivateWatchersFromPath: destination];
    }
    
    [self clearSuspendedWatchersFromPath: destination];
  }

  if ([operation isEqual: @"NSWorkspaceMoveOperation"]
        || [operation isEqual: @"NSWorkspaceDestroyOperation"]
				|| [operation isEqual: @"NSWorkspaceRecycleOperation"]
				|| [operation isEqual: @"GWorkspaceRecycleOutOperation"]
				|| [operation isEqual: @"GWorkspaceEmptyRecyclerOperation"]) {
    if ([nodeView isSingleNode]) {
      FSNode *node = [FSNode nodeWithRelativePath: source parent: nil];
      [nodeView reloadFromNode: node];
    }
        
    if ([self isShowingPath: source] || [baseNode isSubnodeOfPath: source]) {
      [self reactivateWatchersFromPath: source];
    }
    
    [self clearSuspendedWatchersFromPath: source];
  }
}

- (void)suspendWatchersFromPath:(NSString *)path
{
  NSString *start = [baseNode isSubnodeOfPath: path] ? [baseNode path] : path;
  unsigned index = [FSNode indexOfNodeWithPath: start 
                                  inComponents: watchedNodes];
    
  if (index != NSNotFound) {
    int i;

    for (i = index; i < [watchedNodes count]; i++) { 
      NSString *path = [[watchedNodes objectAtIndex: i] path];
         
      [gworkspace removeWatcherForPath: path];
      [watchedSuspended addObject: path];
    }
  } 
}

- (void)reactivateWatchersFromPath:(NSString *)path
{
  NSString *start = [baseNode isSubnodeOfPath: path] ? [baseNode path] : path;
  unsigned index = [FSNode indexOfNodeWithPath: start 
                                  inComponents: watchedNodes];

  if (index != NSNotFound) {
    int count = [watchedNodes count];
    int i;
    
    for (i = index; i < count; i++) {
      FSNode *node = [watchedNodes objectAtIndex: i];
      NSString *path = [node path];
      
      if ([node isValid] && [node isDirectory]) {
        [gworkspace addWatcherForPath: path];
      } else {
        [watchedNodes removeObjectAtIndex: i];
        count--;
        i--;
      }
    }
  }
}

- (void)clearSuspendedWatchersFromPath:(NSString *)path
{
  int count = [watchedSuspended count];
  int i;

  for (i = 0; i < count; i++) {
    NSString *suspended = [watchedSuspended objectAtIndex: i];

    if ([suspended isEqual: path] || isSubpathOfPath(path, suspended)) {
      [watchedSuspended removeObjectAtIndex: i];
      count--;
      i--;
    }
  }
}

- (void)watchedPathChanged:(NSDictionary *)info
{
  if (invalidated == NO) {
    NSString *path = [info objectForKey: @"path"];
  
    if ([watchedSuspended containsObject: path] == NO) { 
      if ([nodeView isSingleNode] == NO) {
        [nodeView watchedPathChanged: info];
        
      } else {
        NSString *event = [info objectForKey: @"event"];
        
        if ([event isEqual: @"GWWatchedDirectoryDeleted"]) {
          NSString *s = [path stringByDeletingLastPathComponent];

          if ([self isShowingPath: s]) {
            FSNode *node = [FSNode nodeWithRelativePath: s parent: nil];
            [nodeView reloadFromNode: node];
          }
          
        } else if ([nodeView isShowingPath: path]) {
          [nodeView watchedPathChanged: info];
        }
      }
    }
  }
}

- (NSArray *)watchedNodes
{
  return watchedNodes;
}

- (void)columnsWidthChanged:(NSNotification *)notification
{
  NSRect r = [vwrwin frame];
  
  RETAIN (nodeView);  
  [nodeView removeFromSuperviewWithoutNeedingDisplay];
  [nviewScroll setDocumentView: nil];	
  
  resizeIncrement = [(NSNumber *)[notification object] intValue];
  r.size.width = (visibleCols * resizeIncrement);
  [vwrwin setFrame: r display: YES];  
  [vwrwin setMinSize: NSMakeSize(resizeIncrement * 2, MIN_W_HEIGHT)];    
  [vwrwin setResizeIncrements: NSMakeSize(resizeIncrement, 1)];

  [nviewScroll setDocumentView: nodeView];	
  RELEASE (nodeView); 
  [nodeView resizeWithOldSuperviewSize: [nodeView bounds].size];
}

- (void)updateDefaults
{
  if ([baseNode isValid]) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	      
    NSString *prefsname = [NSString stringWithFormat: @"viewer_at_%@", [baseNode path]];
    NSString *dictPath = [[baseNode path] stringByAppendingPathComponent: @".gwdir"];
    NSMutableDictionary *updatedprefs = nil;
    id defEntry;
    
    [nodeView updateNodeInfo];
    
    if ([baseNode isWritable] && (rootviewer == NO)) {
      if ([[NSFileManager defaultManager] fileExistsAtPath: dictPath]) {
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: dictPath];

        if (dict) {
          updatedprefs = [dict mutableCopy];
        }   
      }
  
    } else { 
      NSDictionary *prefs = [defaults dictionaryForKey: prefsname];
  
      if (prefs) {
        updatedprefs = [prefs mutableCopy];
      }
    }

    if (updatedprefs == nil) {
      updatedprefs = [NSMutableDictionary new];
    }

    [updatedprefs setObject: viewType forKey: @"viewtype"];

    [updatedprefs setObject: [NSNumber numberWithFloat: shelfHeight]
                     forKey: @"shelfheight"];

    [updatedprefs setObject: [shelf contentsInfo]
                     forKey: @"shelfdicts"];

    defEntry = [nodeView selectedPaths];
    if (defEntry) {
      [updatedprefs setObject: defEntry forKey: @"lastselection"];
    }
    
    [updatedprefs setObject: [vwrwin stringWithSavedFrame] 
                     forKey: @"geometry"];

    if ([baseNode isWritable] && (rootviewer == NO)) {
      [updatedprefs writeToFile: dictPath atomically: YES];
    } else {
      [defaults setObject: updatedprefs forKey: prefsname];
    }
  
    RELEASE (updatedprefs);
  }
}


//
// splitView delegate methods
//
- (void)splitView:(NSSplitView *)sender 
                      resizeSubviewsWithOldSize:(NSSize)oldSize
{
  [self tileViews];
}

- (void)splitViewDidResizeSubviews:(NSNotification *)aNotification
{
	[self tileViews];
}

- (float)splitView:(NSSplitView *)sender
          constrainSplitPosition:(float)proposedPosition 
                                        	ofSubviewAt:(int)offset
{
  if (proposedPosition < COLLAPSE_LIMIT) {
    shelfHeight = MIN_SHELF_HEIGHT;
  } else if (proposedPosition <= MID_LIMIT) {  
    shelfHeight = MID_SHELF_HEIGHT;
  } else {
    shelfHeight = MAX_SHELF_HEIGHT;
  }
  
  return shelfHeight;
}

- (float)splitView:(NSSplitView *)sender 
                  constrainMaxCoordinate:(float)proposedMax 
                                        ofSubviewAt:(int)offset
{
  if (proposedMax >= MAX_SHELF_HEIGHT) {
    return MAX_SHELF_HEIGHT;
  }
  
  return proposedMax;
}

- (float)splitView:(NSSplitView *)sender 
                  constrainMinCoordinate:(float)proposedMin 
                                          ofSubviewAt:(int)offset
{
  if (proposedMin <= MIN_SHELF_HEIGHT) {
    return MIN_SHELF_HEIGHT;
  }
  
  return proposedMin;
}

@end


//
// GWViewerWindow Delegate Methods
//
@implementation GWViewer (GWViewerWindowDelegateMethods)

- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
  NSArray *selection = [nodeView selectedPaths];  

  if ([selection count] == 0) {
    selection = [NSArray arrayWithObject: [[nodeView shownNode] path]];
  }

  [self selectionChanged: selection];
  [vwrwin makeFirstResponder: nodeView];  
}

- (void)windowDidResize:(NSNotification *)aNotification
{
  if (nodeView) {
    [nodeView stopRepNameEditing];  
    [pathsView stopRepNameEditing];  

    if ([nodeView isSingleNode]) {
      NSRect r = [[vwrwin contentView] frame];
      int cols = rintf(r.size.width / [vwrwin resizeIncrements].width);  

      if (cols != visibleCols) {
        [self setSelectableNodesRange: NSMakeRange(0, cols)];
      }
    }
  }
}

- (BOOL)windowShouldClose:(id)sender
{
	return YES;
}

- (void)windowWillClose:(NSNotification *)aNotification
{
  if (invalidated == NO) {
    [self updateDefaults];
    [manager viewerWillClose: self]; 
  }
}

- (void)openSelectionInNewViewer:(BOOL)newv
{
  NSArray *selection = [nodeView selectedNodes]; 
  
  if (selection) {
    NSMutableArray *dirs = [NSMutableArray array];
    int i;

    for (i = 0; i < [selection count]; i++) {
      FSNode *node = [selection objectAtIndex: i];
      
      if ([node isDirectory] && ([node isPackage] == NO)) {
        [dirs addObject: node];
      }
    }
    
    if ([nodeView isSingleNode] && ([dirs count] == 1) && ([selection count] == 1)) {
      [nodeView showContentsOfNode: [dirs objectAtIndex: 0]];
      [self scrollToBeginning];
      
    } else if ([dirs count] == 0) {
      [manager openSelectionInViewer: self closeSender: NO];
    }
  }
}

- (void)openSelectionAsFolder
{
  [manager openAsFolderSelectionInViewer: self];
}

- (void)newFolder
{
  [gworkspace newObjectAtPath: [[nodeView shownNode] path] 
                  isDirectory: YES];
}

- (void)newFile
{
  [gworkspace newObjectAtPath: [[nodeView shownNode] path] 
                  isDirectory: NO];
}

- (void)duplicateFiles
{
  [gworkspace duplicateFiles];
}

- (void)deleteFiles
{
  [gworkspace deleteFiles];
}

- (void)setViewerBehaviour:(id)sender
{
  [manager setBehaviour: [sender title] forViewer: self];
}

- (void)setViewerType:(id)sender
{
  NSString *title = [sender title];
  
	if ([title isEqual: NSLocalizedString(viewType, @"")] == NO) {
    NSArray *selection = [nodeView selectedPaths];
    int i;
    
    [nodeView updateNodeInfo];
    if ([nodeView isSingleNode] && ([selection count] == 0)) {
      selection = [NSArray arrayWithObject: [[nodeView shownNode] path]];
    }
    RETAIN (selection);
    
    [nviewScroll setDocumentView: nil];	
    
    if ([title isEqual: NSLocalizedString(@"Browser", @"")]) {
      [pathsScroll setDelegate: nil];
      [pathsView setOwnsScroller: NO];

      [nviewScroll setHasVerticalScroller: NO];
      [nviewScroll setHasHorizontalScroller: NO];

      nodeView = [[GWViewerBrowser alloc] initWithBaseNode: baseNode
                                      inViewer: self
		                            visibleColumns: visibleCols
                                      scroller: [pathsScroll horizontalScroller]
                                    cellsIcons: NO
                                 editableCells: NO
                               selectionColumn: YES];
      
      ASSIGN (viewType, @"Browser");
      
    } else if ([title isEqual: NSLocalizedString(@"Icon", @"")]) {
      NSScroller *scroller = RETAIN ([pathsScroll horizontalScroller]);

      [pathsScroll setHasHorizontalScroller: NO];
      [pathsScroll setHorizontalScroller: scroller]; 
      [pathsScroll setHasHorizontalScroller: YES];
      RELEASE (scroller);
      
      [pathsView setOwnsScroller: YES];
      [pathsScroll setDelegate: pathsView];

      [nviewScroll setHasVerticalScroller: YES];
      [nviewScroll setHasHorizontalScroller: YES];
   
      nodeView = [[GWViewerIconsView alloc] initForViewer: self];
      
      ASSIGN (viewType, @"Icon");
    }

    [nviewScroll setDocumentView: nodeView];	
    RELEASE (nodeView); 
    [nodeView showContentsOfNode: baseNode]; 
                    
    if ([selection count]) {
      if ([nodeView isSingleNode]) {
        NSString *base;
        FSNode *basend;

        base = [selection objectAtIndex: 0];
        
        if ([base isEqual: [baseNode path]] == NO) {
          base = [base stringByDeletingLastPathComponent];
        }
        
        basend = [FSNode nodeWithRelativePath: base parent: nil];

        [nodeView showContentsOfNode: basend];
        [nodeView selectRepsOfPaths: selection];

      } else {
        [nodeView selectRepsOfPaths: selection];
      }
    }
    
    DESTROY (selection);
    
    [self scrollToBeginning];

    [vwrwin makeFirstResponder: nodeView]; 

    for (i = 0; i < [watchedNodes count]; i++) {  
      [gworkspace removeWatcherForPath: [[watchedNodes objectAtIndex: i] path]];
    }
    [watchedNodes removeAllObjects];
    
    DESTROY (lastSelection);
    selection = [nodeView selectedPaths];
    
    if ([selection count] == 0) {
      selection = [NSArray arrayWithObject: [[nodeView shownNode] path]];
    }
    
    [self selectionChanged: selection];
  }
}

- (void)selectAllInViewer
{
	[nodeView selectAll];
}

- (void)showTerminal
{
  NSString *path;

  if ([nodeView isSingleNode]) {
	  path = [[nodeView shownNode] path];
    
  } else {
    NSArray *selection = [nodeView selectedNodes];
    
    if (selection) {
      FSNode *node = [selection objectAtIndex: 0];
      
      if ([selection count] > 1) {
        path = [node parentPath];
        
      } else {
        if ([node isDirectory] && ([node isPackage] == NO)) {
          path = [node path];
      
        } else {
          path = [node parentPath];
        }
      }
    } else {
      path = [[nodeView shownNode] path];
    }
  }

  [gworkspace startXTermOnDirectory: path];
}

- (BOOL)validateItem:(id)menuItem
{
  return YES;
}

@end
















