/* GWViewer.m
 *  
 * Copyright (C) 2004-2015 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 *         Riccardo Mottola
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

#include <math.h>

#import <AppKit/AppKit.h>
#import "GWViewer.h"
#import "GWViewersManager.h"
#import "GWViewerBrowser.h"
#import "GWViewerIconsView.h"
#import "GWViewerListView.h"
#import "GWViewerWindow.h"
#import "GWViewerScrollView.h"
#import "GWViewerSplit.h"
#import "GWViewerShelf.h"
#import "GWViewerIconsPath.h"
#import "GWorkspace.h"
#import "GWFunctions.h"
#import "FSNBrowser.h"
#import "FSNIconsView.h"
#import "FSNodeRep.h"
#import "FSNIcon.h"
#import "FSNFunctions.h"
#import "Thumbnailer/GWThumbnailer.h"

#define DEFAULT_INCR 150
#define MIN_WIN_H 300

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
  RELEASE (baseNodeArray);
  RELEASE (lastSelection);
  RELEASE (defaultsKeyStr);
  RELEASE (watchedNodes);
  RELEASE (vwrwin);
  RELEASE (viewerPrefs);
  RELEASE (history);
  
  [super dealloc];
}

- (id)initForNode:(FSNode *)node
         inWindow:(GWViewerWindow *)win
         showType:(GWViewType)stype
    showSelection:(BOOL)showsel
	  withKey:(NSString *)key
{
  self = [super init];
  
  if (self) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
    NSString *prefsname;
    id defEntry;
    NSRect r;
    NSString *viewTypeStr;
        
    ASSIGN (baseNode, [FSNode nodeWithPath: [node path]]);
    ASSIGN (baseNodeArray, [NSArray arrayWithObject: baseNode]);
    fsnodeRep = [FSNodeRep sharedInstance];
    lastSelection = nil;
    history = [NSMutableArray new];
    historyPosition = 0;
    watchedNodes = [NSMutableArray new];
    manager = [GWViewersManager viewersManager];
    gworkspace = [GWorkspace gworkspace];
    nc = [NSNotificationCenter defaultCenter];
    
    defEntry = [defaults objectForKey: @"browserColsWidth"];
    if (defEntry) {
      resizeIncrement = [defEntry intValue];
    } else {
      resizeIncrement = DEFAULT_INCR;
    }
    
    rootViewer = [[baseNode path] isEqual: path_separator()];
    firstRootViewer = (rootViewer && ([[manager viewersForBaseNode: baseNode] count] == 0));
    
    if (rootViewer == YES)
      {
	if (firstRootViewer)
	  {
	    prefsname = @"root_viewer";
	  }
	else
	  {
	    if (key == nil)
	      {
		NSNumber *rootViewerKey;

		rootViewerKey = [NSNumber numberWithUnsignedLong: (unsigned long)self];

		prefsname = [NSString stringWithFormat: @"%lu_viewer_at_%@", [rootViewerKey unsignedLongValue], [node path]];
	      }
	    else
	      {
		prefsname = [key retain];
	      }
	  }
      }
    else
      {
	prefsname = [NSString stringWithFormat: @"viewer_at_%@", [node path]];
      }

    defaultsKeyStr = [prefsname retain];
    if ([baseNode isWritable] && (rootViewer == NO)
            && ([[fsnodeRep volumes] containsObject: [baseNode path]] == NO)) {
		  NSString *dictPath = [[baseNode path] stringByAppendingPathComponent: @".gwdir"];

      if ([[NSFileManager defaultManager] fileExistsAtPath: dictPath]) {
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: dictPath];

        if (dict) {
          viewerPrefs = [dict copy];
        }   
      }
    }
    
    if (viewerPrefs == nil) {
      defEntry = [defaults dictionaryForKey: defaultsKeyStr];
      if (defEntry) {
        viewerPrefs = [defEntry copy];
      } else {
        viewerPrefs = [NSDictionary new];
      }
    }
    
    viewType = GWViewTypeBrowser;
    viewTypeStr = [viewerPrefs objectForKey: @"viewtype"];
    if (viewTypeStr == nil)
      {
        if (stype != 0)
          {
            viewType = stype;
          }
      }
    else if ([viewTypeStr isEqual: @"Browser"])
      {
        viewType = GWViewTypeBrowser;
      }
    else if ([viewTypeStr isEqual: @"List"])
      {
        viewType = GWViewTypeList;
      }
    else if ([viewTypeStr isEqual: @"Icon"])
      {
        viewType = GWViewTypeIcon;
      }
    
    defEntry = [viewerPrefs objectForKey: @"shelfheight"];
    if (defEntry) {
      shelfHeight = [defEntry floatValue];
    } else {
      shelfHeight = MID_SHELF_HEIGHT;
    }
       
    ASSIGN (vwrwin, win);
    [vwrwin setDelegate: self];

    defEntry = [viewerPrefs objectForKey: @"geometry"];
    if (defEntry) {
      [vwrwin setFrameFromString: defEntry];
    } else {
      r = NSMakeRect(200, 200, resizeIncrement * 3, 350);
      [vwrwin setFrame: rectForWindow([manager viewerWindows], r, YES) 
               display: NO];
    }
    
    r = [vwrwin frame];
    
    if (r.size.height < MIN_WIN_H) {
      r.origin.y -= (MIN_WIN_H - r.size.height);
      r.size.height = MIN_WIN_H;
    
      if (r.origin.y < 0) {
        r.origin.y = 5;
      }
      
      [vwrwin setFrame: r display: NO];
    }

    [vwrwin setMinSize: NSMakeSize(resizeIncrement * 2, MIN_WIN_H)];    
    [vwrwin setResizeIncrements: NSMakeSize(resizeIncrement, 1)];

    if (firstRootViewer) {
      [vwrwin setTitle: NSLocalizedString(@"File Viewer", @"")];
    } else {
      if (rootViewer) {   
        [vwrwin setTitle: [NSString stringWithFormat: @"%@ - %@", [node name], [node parentPath]]];   
      } else {
        [vwrwin setTitle: [NSString stringWithFormat: @"%@", [node name]]];   
      }
    }

    [self createSubviews];
    
    defEntry = [viewerPrefs objectForKey: @"shelfdicts"];

    if (defEntry && [defEntry count]) {
      [shelf setContents: defEntry];
    } else if (rootViewer) {
      NSDictionary *sfdict = [NSDictionary dictionaryWithObjectsAndKeys:
                        [NSNumber numberWithInt: 0], @"index", 
                        [NSArray arrayWithObject: NSHomeDirectory()], @"paths", 
                        nil];
      [shelf setContents: [NSArray arrayWithObject: sfdict]];
    }
    
    if (viewType == GWViewTypeIcon) {
      nodeView = [[GWViewerIconsView alloc] initForViewer: self];
      
      [pathsScroll setDelegate: pathsView];
      
    } else if (viewType == GWViewTypeList) { 
      NSRect r = [[nviewScroll contentView] bounds];
      
      nodeView = [[GWViewerListView alloc] initWithFrame: r forViewer: self];
       
      [pathsScroll setDelegate: pathsView];
       
    } else if (viewType == GWViewTypeBrowser ) {    
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

          if ([fm fileExistsAtPath: s] == NO) {
            [selection removeObject: s];
            count--;
            i--;
          }
        }

        if ([selection count]) {
          if ([nodeView isSingleNode]) {
            NSString *base = [selection objectAtIndex: 0];
            FSNode *basenode = [FSNode nodeWithPath: base];
          
            if (([basenode isDirectory] == NO) || [basenode isPackage]) {
              base = [base stringByDeletingLastPathComponent];
              basenode = [FSNode nodeWithPath: base];
            }
            
            [nodeView showContentsOfNode: basenode];
            [nodeView selectRepsOfPaths: selection];
          
          } else {
            [nodeView selectRepsOfPaths: selection];
          }
        }

        RELEASE (selection);
      }
    }
        
    [nc addObserver: self 
           selector: @selector(columnsWidthChanged:) 
               name: @"GWBrowserColumnWidthChangedNotification"
             object: nil];

    invalidated = NO;
    closing = NO;    
  }
  
  return self;
}

- (void)createSubviews
{
  NSRect r = [[vwrwin contentView] bounds];
  CGFloat w = r.size.width;
  CGFloat h = r.size.height;   
  CGFloat d = 0.0;
  int xmargin = 8;
  int ymargin = 6;
  int pathscrh = 98;
  NSUInteger resizeMask;
  BOOL hasScroller;
  
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

  r = [lowBox bounds];
  w = r.size.width;
  h = r.size.height; 
  
  r = NSMakeRect(xmargin, h - pathscrh, w - (xmargin * 2), pathscrh);
  pathsScroll = [[GWViewerPathsScroll alloc] initWithFrame: r];
  [pathsScroll setBorderType: NSBezelBorder];
  [pathsScroll setHasHorizontalScroller: YES];
  [pathsScroll setHasVerticalScroller: NO];
  [pathsScroll setDelegate: nil];
  resizeMask = NSViewNotSizable | NSViewWidthSizable | NSViewMinYMargin;
  [pathsScroll setAutoresizingMask: resizeMask];
  [lowBox addSubview: pathsScroll];
  RELEASE (pathsScroll);

  visibleCols = myrintf(r.size.width / [vwrwin resizeIncrements].width);  
  
  r = [[pathsScroll contentView] bounds];
  pathsView = [[GWViewerIconsPath alloc] initWithFrame: r 
                   visibleIcons: visibleCols forViewer: self
                   ownsScroller: (viewType != GWViewTypeBrowser)];
  resizeMask = NSViewNotSizable;
  [pathsView setAutoresizingMask: resizeMask];
  [pathsScroll setDocumentView: pathsView];
  RELEASE (pathsView);
  
  r = NSMakeRect(xmargin, 0, w - (xmargin * 2), h - pathscrh - ymargin);
  nviewScroll = [[GWViewerScrollView alloc] initWithFrame: r inViewer: self];
  [nviewScroll setBorderType: NSBezelBorder];
  hasScroller = ((viewType ==GWViewTypeIcon) || (viewType ==GWViewTypeList));
  [nviewScroll setHasHorizontalScroller: hasScroller];
  [nviewScroll setHasVerticalScroller: hasScroller];
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
  FSNode *node = [FSNode nodeWithPath: apath];
  return [self isShowingNode: node];
}

- (void)reloadNodeContents
{
  [nodeView reloadContents];
}

- (void)reloadFromNode:(FSNode *)anode
{
  [nodeView reloadFromNode: anode];
  [self updeateInfoLabels];
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

- (GWViewType)viewType
{
  return viewType;
}

- (BOOL)isFirstRootViewer
{
  return firstRootViewer;
}

- (NSString *)defaultsKey
{
  return defaultsKeyStr;
}

- (void)activate
{
  [vwrwin makeKeyAndOrderFront: nil];
  [self tileViews];
  [self scrollToBeginning];    
}

- (void)deactivate
{
  [vwrwin close];
}

- (void)tileViews
{
  NSRect r = [split bounds];
  CGFloat w = r.size.width;
  CGFloat h = r.size.height;   
  CGFloat d = [split dividerThickness];
    
  [shelf setFrame: NSMakeRect(0, 0, w, shelfHeight)];
  [lowBox setFrame: NSMakeRect(0, shelfHeight + d, w, h - shelfHeight - d)];
}

- (void)scrollToBeginning
{
  if ([nodeView isSingleNode]) {
    [nodeView scrollSelectionToVisible];
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

- (BOOL)isClosing
{
  return closing;
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

  if (closing)
    return;

  [manager selectionChanged: newsel];

  if (lastSelection && [newsel isEqual: lastSelection]) {
    if ([[newsel objectAtIndex: 0] isEqual: [nodeView shownNode]] == NO) {
      return;
    }
  }

  ASSIGN (lastSelection, newsel);
  [self updeateInfoLabels]; 
    
  node = [newsel objectAtIndex: 0];   
     
  if (([node isDirectory] == NO) || [node isPackage] || ([newsel count] > 1)) {
    if ([node isEqual: baseNode] == NO) { // if baseNode is a package 
      node = [FSNode nodeWithPath: [node parentPath]];
    }
  }
    
  components = [FSNode nodeComponentsFromNode: baseNode toNode: node];
  
  [pathsView showPathComponents: components selection: newsel];

  if ([node isDirectory] && ([newsel count] == 1)) {
    if ([nodeView isSingleNode] && ([node isEqual: [nodeView shownNode]] == NO)) {
      node = [FSNode nodeWithPath: [node parentPath]];
      components = [FSNode nodeComponentsFromNode: baseNode toNode: node];
    }
  }

  if ([components isEqual: watchedNodes] == NO) {
    NSUInteger count = [components count];
    unsigned pos = 0;
    NSUInteger i;
  
    for (i = 0; i < [watchedNodes count]; i++) { 
      FSNode *nd = [watchedNodes objectAtIndex: i];
      
      if (i < count) {
        FSNode *ndcomp = [components objectAtIndex: i];

        if ([nd isEqual: ndcomp] == NO) {
          [gworkspace removeWatcherForPath: [nd path]];
        } else {
          pos = i + 1;
        }

      } else {
        [gworkspace removeWatcherForPath: [nd path]];
      }
    }

    for (i = pos; i < count; i++) {   
      [gworkspace addWatcherForPath: [[components objectAtIndex: i] path]];
    }

    [watchedNodes removeAllObjects];
    [watchedNodes addObjectsFromArray: components];
  }  
  
  [manager addNode: node toHistoryOfViewer: self];
}

- (void)multipleNodeViewDidSelectSubNode:(FSNode *)node
{
}

- (void)pathsViewDidSelectIcon:(id)icon
{
  FSNode *node = [icon node];
  int index = [icon gridIndex];
  
  if ([node isDirectory] && (([node isPackage] == NO) || (index == 0))) {
    if ([nodeView isSingleNode]) {
      [nodeView showContentsOfNode: node];
      [self scrollToBeginning];
      [self selectionChanged: [NSArray arrayWithObject: node]];
      
    } else {
      [nodeView setLastShownNode: node];
    }
  }
}

- (void)shelfDidSelectIcon:(id)icon
{
  FSNode *node = [icon node];
  NSArray *selection = [icon selection];
  FSNode *nodetoshow;
  
  if (selection && ([selection count] > 1)) {
    nodetoshow = [FSNode nodeWithPath: [node parentPath]];
  } else {
    if ([node isDirectory] && ([node isPackage] == NO)) {
      nodetoshow = node;
      
      if (viewType != GWViewTypeBrowser) {
        selection = nil;
      } else {
        selection = [NSArray arrayWithObject: node];
      }
    
    } else {
      nodetoshow = [FSNode nodeWithPath: [node parentPath]];
      selection = [NSArray arrayWithObject: node];
    }
  }

  [nodeView showContentsOfNode: nodetoshow];
  
  if (selection) {
    [nodeView selectRepsOfSubnodes: selection];
  }

  if ([nodeView respondsToSelector: @selector(scrollSelectionToVisible)]) {
    [nodeView scrollSelectionToVisible];
  }
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
  
  if (freefs == nil)
    {
      labelstr = NSLocalizedString(@"unknown volume size", @"");
    }
  else
    {
      unsigned long long freeSize = [freefs unsignedLongLongValue];
      unsigned systemType = [fsnodeRep systemType];

      switch (systemType)
	{
	case NSMACHOperatingSystem:
	  freeSize = (freeSize >> 8);
	  break;
	default:
	  break;
	}
      labelstr = [NSString stringWithFormat: @"%@ %@",
			   sizeDescription(freeSize),
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
  [nodeView nodeContentsWillChange: info];
}

- (void)nodeContentsDidChange:(NSDictionary *)info
{
  if ([nodeView isSingleNode]) {  
    NSString *operation = [info objectForKey: @"operation"];
    NSString *source = [info objectForKey: @"source"];
    NSString *destination = [info objectForKey: @"destination"];
  
    if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
      destination = [destination stringByDeletingLastPathComponent]; 
    }

    if ([operation isEqual: NSWorkspaceMoveOperation]
          || [operation isEqual: NSWorkspaceCopyOperation]
          || [operation isEqual: NSWorkspaceLinkOperation]
          || [operation isEqual: NSWorkspaceDuplicateOperation]
          || [operation isEqual: @"GWorkspaceCreateDirOperation"]
          || [operation isEqual: @"GWorkspaceCreateFileOperation"]
          || [operation isEqual: NSWorkspaceRecycleOperation]
          || [operation isEqual: @"GWorkspaceRenameOperation"]
			    || [operation isEqual: @"GWorkspaceRecycleOutOperation"]) { 
      [nodeView reloadFromNode: [FSNode nodeWithPath: destination]];
    }

    if ([operation isEqual: NSWorkspaceMoveOperation]
          || [operation isEqual: NSWorkspaceDestroyOperation]
				  || [operation isEqual: NSWorkspaceRecycleOperation]
				  || [operation isEqual: @"GWorkspaceRecycleOutOperation"]
				  || [operation isEqual: @"GWorkspaceEmptyRecyclerOperation"]) {
      [nodeView reloadFromNode: [FSNode nodeWithPath: source]];
    }
    
  } else {
    [nodeView nodeContentsDidChange: info];
  }
}

- (void)watchedPathChanged:(NSDictionary *)info
{
  if (invalidated == NO) {
    if ([nodeView isSingleNode]) {
      NSString *path = [info objectForKey: @"path"];
      NSString *event = [info objectForKey: @"event"];
  
      if ([event isEqual: @"GWWatchedPathDeleted"]) {
        NSString *s = [path stringByDeletingLastPathComponent];

        if ([self isShowingPath: s]) {
          FSNode *node = [FSNode nodeWithPath: s];
          [nodeView reloadFromNode: node];
        }

      } else if ([nodeView isShowingPath: path]) {
        [nodeView watchedPathChanged: info];
      }
  
    } else {
      [nodeView watchedPathChanged: info];
    }
  }
}

- (NSMutableArray *)history
{
  return history;
}

- (int)historyPosition
{
  return historyPosition;
}

- (void)setHistoryPosition:(int)pos
{
  historyPosition = pos;
}

- (NSArray *)watchedNodes
{
  return watchedNodes;
}

- (void)hideDotsFileChanged:(BOOL)hide
{
  [self reloadFromNode: baseNode];
  [shelf checkIconsAfterDotsFilesChange];
}

- (void)hiddenFilesChanged:(NSArray *)paths
{
  [self reloadFromNode: baseNode];
  [shelf checkIconsAfterHidingOfPaths: paths];
}

- (void)columnsWidthChanged:(NSNotification *)notification
{
  NSRect r = [vwrwin frame];
  NSRange range;
    
  RETAIN (nodeView);  
  [nodeView removeFromSuperviewWithoutNeedingDisplay];
  [nviewScroll setDocumentView: nil];	

  RETAIN (pathsView);  
  [pathsView removeFromSuperviewWithoutNeedingDisplay];
  [pathsScroll setDocumentView: nil];	  

  resizeIncrement = [(NSNumber *)[notification object] intValue];
  r.size.width = (visibleCols * resizeIncrement);
  [vwrwin setFrame: r display: YES];  
  [vwrwin setMinSize: NSMakeSize(resizeIncrement * 2, MIN_WIN_H)];    
  [vwrwin setResizeIncrements: NSMakeSize(resizeIncrement, 1)];

  [pathsScroll setDocumentView: pathsView];	
  RELEASE (pathsView); 
  range = NSMakeRange([pathsView firstVisibleIcon], [pathsView lastVisibleIcon]);
  [pathsView setSelectableIconsRange: range];

  [nviewScroll setDocumentView: nodeView];	
  RELEASE (nodeView); 
  [nodeView resizeWithOldSuperviewSize: [nodeView bounds].size];

  [self windowDidResize: nil];
}

- (void)updateDefaults
{
  if ([baseNode isValid])
    {
      NSMutableDictionary *updatedprefs = [nodeView updateNodeInfo: NO];
      id defEntry;
      NSString *viewTypeStr;

      if (viewType == GWViewTypeIcon)
        viewTypeStr = @"Icon";
      else if (viewType == GWViewTypeList)
        viewTypeStr = @"List";
      else
        viewTypeStr = @"Browser";

    if (updatedprefs == nil) {
      updatedprefs = [NSMutableDictionary dictionary];
    }

    [updatedprefs setObject: [NSNumber numberWithBool: [nodeView isSingleNode]]
                     forKey: @"singlenode"];

    [updatedprefs setObject: viewTypeStr forKey: @"viewtype"];

    [updatedprefs setObject: [NSNumber numberWithFloat: shelfHeight]
                     forKey: @"shelfheight"];

    [updatedprefs setObject: [shelf contentsInfo]
                     forKey: @"shelfdicts"];

    defEntry = [nodeView selectedPaths];
    if (defEntry) {
      if ([defEntry count] == 0) {
        defEntry = [NSArray arrayWithObject: [[nodeView shownNode] path]];
      }
      [updatedprefs setObject: defEntry forKey: @"lastselection"];
    }
    
    [updatedprefs setObject: [vwrwin stringWithSavedFrame] 
                     forKey: @"geometry"];

    [baseNode checkWritable];

    if ([baseNode isWritable] && (rootViewer == NO)
              && ([[fsnodeRep volumes] containsObject: [baseNode path]] == NO)) {
      NSString *dictPath = [[baseNode path] stringByAppendingPathComponent: @".gwdir"];

      [updatedprefs writeToFile: dictPath atomically: YES];
    } else {
      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	    
      [defaults setObject: updatedprefs forKey: defaultsKeyStr];
    }
    
    ASSIGN (viewerPrefs, [updatedprefs makeImmutableCopyOnFail: NO]);
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

- (CGFloat)splitView:(NSSplitView *)sender
constrainSplitPosition:(CGFloat)proposedPosition 
         ofSubviewAt:(NSInteger)offset
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

- (CGFloat)splitView:(NSSplitView *)sender 
constrainMaxCoordinate:(CGFloat)proposedMax 
         ofSubviewAt:(NSInteger)offset
{
  if (proposedMax >= MAX_SHELF_HEIGHT) {
    return MAX_SHELF_HEIGHT;
  }
  
  return proposedMax;
}

- (CGFloat)splitView:(NSSplitView *)sender 
constrainMinCoordinate:(CGFloat)proposedMin 
         ofSubviewAt:(NSInteger)offset
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

- (void)windowDidExpose:(NSNotification *)aNotification
{
  [self updeateInfoLabels];
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
  NSArray *selection = [nodeView selectedNodes];

  [manager updateDesktop];
  if ([selection count] == 0)
    {
      selection = [NSArray arrayWithObject: [nodeView shownNode]];
    }
  [self selectionChanged: selection];
  
  [manager changeHistoryOwner: self];
}

- (void)windowDidResize:(NSNotification *)aNotification
{
  if (nodeView) {
    [nodeView stopRepNameEditing];  
    [pathsView stopRepNameEditing];  

    if ([nodeView isSingleNode]) {
      NSRect r = [[vwrwin contentView] bounds];
      int cols = myrintf(r.size.width / [vwrwin resizeIncrements].width);  

      if (cols != visibleCols) {
        [self setSelectableNodesRange: NSMakeRange(0, cols)];
      }
    }
  }
}

- (BOOL)windowShouldClose:(id)sender
{
  [manager updateDesktop];
	return YES;
}

- (void)windowWillClose:(NSNotification *)aNotification
{
  if (invalidated == NO) {
    closing = YES;
    [self updateDefaults];
    [vwrwin setDelegate: nil];
    [manager viewerWillClose: self]; 
  }
}

- (void)windowWillMiniaturize:(NSNotification *)aNotification
{
  NSImage *image = [fsnodeRep iconOfSize: 48 forNode: baseNode];

  [vwrwin setMiniwindowImage: image];
  [vwrwin setMiniwindowTitle: [baseNode name]];
}

- (void)openSelectionInNewViewer:(BOOL)newv
{
  if ([[baseNode path] isEqual: [gworkspace trashPath]] == NO) {
    NSArray *selection = [nodeView selectedNodes]; 
    NSUInteger count = (selection ? [selection count] : 0);
    
    if (count) {
      NSMutableArray *dirs = [NSMutableArray array];
      NSUInteger i;

      if (count > MAX_FILES_TO_OPEN_DIALOG) {
        NSString *msg1 = NSLocalizedString(@"Are you sure you want to open", @"");
        NSString *msg2 = NSLocalizedString(@"items?", @"");

        if (NSRunAlertPanel(nil,
                            [NSString stringWithFormat: @"%@ %lu %@", msg1, (unsigned long)count, msg2],
                    NSLocalizedString(@"Cancel", @""),
                    NSLocalizedString(@"Yes", @""),
                    nil)) {
          return;
        }
      }

      for (i = 0; i < count; i++) {
        FSNode *node = [selection objectAtIndex: i];

        NS_DURING
          {
        if ([node isDirectory]) {
          if ([node isPackage]) {    
            if ([node isApplication] == NO) {
              [gworkspace openFile: [node path]];
            } else {
              [[NSWorkspace sharedWorkspace] launchApplication: [node path]];
            }
          } else {
            [dirs addObject: node];
          }
        } else if ([node isPlain]) {
          [gworkspace openFile: [node path]];
        }      
          }
        NS_HANDLER
          {
            NSRunAlertPanel(NSLocalizedString(@"error", @""), 
                [NSString stringWithFormat: @"%@ %@!", 
                          NSLocalizedString(@"Can't open ", @""), [node name]],
                                              NSLocalizedString(@"OK", @""), 
                                              nil, 
                                              nil);                                     
          }
        NS_ENDHANDLER
      }

      if (([dirs count] == 1) && ([selection count] == 1)) {
        if (newv == NO) {
          if ([nodeView isSingleNode]) {
            [nodeView showContentsOfNode: [dirs objectAtIndex: 0]];
            [self scrollToBeginning];
          }
        } else {
          [manager openAsFolderSelectionInViewer: self];
        }
      }

    } else if (newv) {
      [manager openAsFolderSelectionInViewer: self];
    }
  
  } else {
    NSRunAlertPanel(nil, 
                  NSLocalizedString(@"You can't open a document that is in the Recycler!", @""),
					        NSLocalizedString(@"OK", @""), 
                  nil, 
                  nil);  
  }
}

- (void)openSelectionAsFolder
{
  if ([[baseNode path] isEqual: [gworkspace trashPath]] == NO) {
    [manager openAsFolderSelectionInViewer: self];
  } else {
    NSRunAlertPanel(nil, 
                  NSLocalizedString(@"You can't do this in the Recycler!", @""),
					        NSLocalizedString(@"OK", @""), 
                  nil, 
                  nil);  
  }
}

- (void)openSelectionWith
{
  if ([[baseNode path] isEqual: [gworkspace trashPath]] == NO) {
    [manager openWithSelectionInViewer: self];
  } else {
    NSRunAlertPanel(nil, 
                  NSLocalizedString(@"You can't do this in the Recycler!", @""),
					        NSLocalizedString(@"OK", @""), 
                  nil, 
                  nil);  
  }
}

- (void)newFolder
{
  if ([[baseNode path] isEqual: [gworkspace trashPath]] == NO) {
    [gworkspace newObjectAtPath: [[nodeView shownNode] path] 
                    isDirectory: YES];
  } else {
    NSRunAlertPanel(nil, 
                  NSLocalizedString(@"You can't create a new folder in the Recycler!", @""),
					        NSLocalizedString(@"OK", @""), 
                  nil, 
                  nil);  
  }
}

- (void)newFile
{
  if ([[baseNode path] isEqual: [gworkspace trashPath]] == NO) {
    [gworkspace newObjectAtPath: [[nodeView shownNode] path] 
                    isDirectory: NO];
  } else {
    NSRunAlertPanel(nil, 
                  NSLocalizedString(@"You can't create a new file in the Recycler!", @""),
					        NSLocalizedString(@"OK", @""), 
                  nil, 
                  nil);  
  }
}

- (void)duplicateFiles
{
  if ([[baseNode path] isEqual: [gworkspace trashPath]] == NO) {
    NSArray *selection = [nodeView selectedNodes];

    if (selection && [selection count]) {
      if ([nodeView isSingleNode]) {
        [gworkspace duplicateFiles];
      } else if ([selection isEqual: baseNodeArray] == NO) {
        [gworkspace duplicateFiles];
      }
    }
  } else {
    NSRunAlertPanel(nil, 
                  NSLocalizedString(@"You can't duplicate files in the Recycler!", @""),
					        NSLocalizedString(@"OK", @""), 
                  nil, 
                  nil);  
  }
}

- (void)recycleFiles
{
  if ([[baseNode path] isEqual: [gworkspace trashPath]] == NO) {
    NSArray *selection = [nodeView selectedNodes];

    if (selection && [selection count]) {
      if ([nodeView isSingleNode]) {
        [gworkspace moveToTrash];
      } else if ([selection isEqual: baseNodeArray] == NO) {
        [gworkspace moveToTrash];
      }
    }
  }
}

- (void)emptyTrash
{
  [gworkspace emptyRecycler: nil];
}

- (void)deleteFiles
{
  NSArray *selection = [nodeView selectedNodes];

  if (selection && [selection count]) {
    if ([nodeView isSingleNode]) {
      [gworkspace deleteFiles];
    } else if ([selection isEqual: baseNodeArray] == NO) {
      [gworkspace deleteFiles];
    }
  }
}

- (void)goBackwardInHistory
{
  [manager goBackwardInHistoryOfViewer: self];
}

- (void)goForwardInHistory
{
  [manager goForwardInHistoryOfViewer: self];
}

- (void)setViewerType:(id)sender
{
  NSInteger tag = [sender tag];

  if (tag > 0)
    {
      NSArray *selection = [nodeView selectedNodes];
      NSUInteger i;
    
      [nodeView updateNodeInfo: YES];
      if ([nodeView isSingleNode] && ([selection count] == 0))
        selection = [NSArray arrayWithObject: [nodeView shownNode]];
 
      RETAIN (selection);
    
      [nviewScroll setDocumentView: nil];	
    
      if (tag == GWViewTypeBrowser)
        {
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
      
          viewType = GWViewTypeBrowser;
        }
      else if (tag == GWViewTypeIcon)
        {
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
      
          viewType = GWViewTypeIcon;     
        }
      else if (tag == GWViewTypeList)
        {
          NSRect r = [[nviewScroll contentView] bounds];

          NSScroller *scroller = RETAIN ([pathsScroll horizontalScroller]);

          [pathsScroll setHasHorizontalScroller: NO];
          [pathsScroll setHorizontalScroller: scroller]; 
          [pathsScroll setHasHorizontalScroller: YES];
          RELEASE (scroller);
      
          [pathsView setOwnsScroller: YES];
          [pathsScroll setDelegate: pathsView];

          [nviewScroll setHasVerticalScroller: YES];
          [nviewScroll setHasHorizontalScroller: YES];

          nodeView = [[GWViewerListView alloc] initWithFrame: r forViewer: self];

          viewType = GWViewTypeList;
        }
    
      [nviewScroll setDocumentView: nodeView];	
      RELEASE (nodeView); 
      [nodeView showContentsOfNode: baseNode]; 
                    
      if ([selection count])
        {
          if ([nodeView isSingleNode])
            {
              FSNode *basend = [selection objectAtIndex: 0];
        
              if ([basend isEqual: baseNode] == NO)
                {
                  if (([selection count] > 1) || (([basend isDirectory] == NO) || ([basend isPackage])))
                    {
                      basend = [FSNode nodeWithPath: [basend parentPath]];
                    }
                }
              
              [nodeView showContentsOfNode: basend];
              [nodeView selectRepsOfSubnodes: selection];
              
            }
          else
            {
              [nodeView selectRepsOfSubnodes: selection];
            }
        }
      
      DESTROY (selection);
    
      [self scrollToBeginning];

      [vwrwin makeFirstResponder: nodeView]; 

      for (i = 0; i < [watchedNodes count]; i++)
        {  
          [gworkspace removeWatcherForPath: [[watchedNodes objectAtIndex: i] path]];
        }
      [watchedNodes removeAllObjects];
      
      DESTROY (lastSelection);
      selection = [nodeView selectedNodes];
      
      if ([selection count] == 0)
        {
          selection = [NSArray arrayWithObject: [nodeView shownNode]];
        }
      
      [self selectionChanged: selection];
      
      [self updateDefaults];
    }
}

- (void)setShownType:(id)sender
{
  NSString *title = [sender title];
  FSNInfoType type = FSNInfoNameType;

  if ([title isEqual: NSLocalizedString(@"Name", @"")]) {
    type = FSNInfoNameType;
  } else if ([title isEqual: NSLocalizedString(@"Type", @"")]) {
    type = FSNInfoKindType;
  } else if ([title isEqual: NSLocalizedString(@"Size", @"")]) {
    type = FSNInfoSizeType;
  } else if ([title isEqual: NSLocalizedString(@"Modification date", @"")]) {
    type = FSNInfoDateType;
  } else if ([title isEqual: NSLocalizedString(@"Owner", @"")]) {
    type = FSNInfoOwnerType;
  } else {
    type = FSNInfoNameType;
  } 

  [(id <FSNodeRepContainer>)nodeView setShowType: type]; 
  [self scrollToBeginning]; 
  [nodeView updateNodeInfo: YES];
}

- (void)setExtendedShownType:(id)sender
{
  [(id <FSNodeRepContainer>)nodeView setExtendedShowType: [sender title]];  
  [self scrollToBeginning];
  [nodeView updateNodeInfo: YES];
}

- (void)setIconsSize:(id)sender
{
  if ([nodeView respondsToSelector: @selector(setIconSize:)]) {
    [(id <FSNodeRepContainer>)nodeView setIconSize: [[sender title] intValue]];
    [self scrollToBeginning];
    [nodeView updateNodeInfo: YES];
  }
}

- (void)setIconsPosition:(id)sender
{
  if ([nodeView respondsToSelector: @selector(setIconPosition:)]) {
    NSString *title = [sender title];
    
    if ([title isEqual: NSLocalizedString(@"Left", @"")]) {
      [(id <FSNodeRepContainer>)nodeView setIconPosition: NSImageLeft];
    } else {
      [(id <FSNodeRepContainer>)nodeView setIconPosition: NSImageAbove];
    }
    
    [self scrollToBeginning];
    [nodeView updateNodeInfo: YES];
  }
}

- (void)setLabelSize:(id)sender
{
  if ([nodeView respondsToSelector: @selector(setLabelTextSize:)]) {
    [nodeView setLabelTextSize: [[sender title] intValue]];
    [self scrollToBeginning];
    [nodeView updateNodeInfo: YES];
  }
}

- (void)chooseLabelColor:(id)sender
{
  if ([nodeView respondsToSelector: @selector(setTextColor:)]) {

  }
}

- (void)chooseBackColor:(id)sender
{
  if ([nodeView respondsToSelector: @selector(setBackgroundColor:)]) {

  }
}

- (void)selectAllInViewer
{
  [nodeView selectAll];
}

- (void)showTerminal
{
  NSString *path;

  if ([nodeView isSingleNode])
    {
      path = [[nodeView shownNode] path];
    }
  else
    {
      NSArray *selection = [nodeView selectedNodes];

      if (selection)
	{
	  FSNode *node = [selection objectAtIndex: 0];

	  if ([selection count] > 1)
	    {
	      path = [node parentPath];
	    }
	  else
	    {
	      if ([node isDirectory] && ([node isPackage] == NO))
		{
		  path = [node path];
		}
	      else
		{
		  path = [node parentPath];
		}
	    }
	}
      else
	{
	  path = [[nodeView shownNode] path];
	}
    }

  [gworkspace startXTermOnDirectory: path];
}

- (BOOL)validateItem:(id)menuItem
{
  if ([NSApp keyWindow] == vwrwin) {
    SEL action = [menuItem action];
    NSString *itemTitle = [menuItem title];
    NSString *menuTitle = [[menuItem menu] title];

    if ([menuTitle isEqual: NSLocalizedString(@"Icon Size", @"")]) {
      return [nodeView respondsToSelector: @selector(setIconSize:)];
    } else if ([menuTitle isEqual: NSLocalizedString(@"Icon Position", @"")]) {
      return [nodeView respondsToSelector: @selector(setIconPosition:)];
    } else if ([menuTitle isEqual: NSLocalizedString(@"Label Size", @"")]) {
      return [nodeView respondsToSelector: @selector(setLabelTextSize:)];
    } else if ([itemTitle isEqual: NSLocalizedString(@"Label Color...", @"")]) {
      return [nodeView respondsToSelector: @selector(setTextColor:)];
    } else if ([itemTitle isEqual: NSLocalizedString(@"Background Color...", @"")]) {
      return [nodeView respondsToSelector: @selector(setBackgroundColor:)];

    } else if (sel_isEqual(action, @selector(duplicateFiles:))
                    || sel_isEqual(action, @selector(recycleFiles:))
                        || sel_isEqual(action, @selector(deleteFiles:))) {
      if (lastSelection && [lastSelection count]
              && ([lastSelection isEqual: baseNodeArray] == NO)) {
        return ([[baseNode path] isEqual: [gworkspace trashPath]] == NO);
      }

      return NO;
    } else if (sel_isEqual(action, @selector(makeThumbnails:)) || sel_isEqual(action, @selector(removeThumbnails:)))
      {
        /* Make or Remove Thumbnails */
        return YES;
    } else if (sel_isEqual(action, @selector(openSelection:))) {
      if ([[baseNode path] isEqual: [gworkspace trashPath]] == NO) {
        BOOL canopen = YES;
        NSUInteger i;

        if (lastSelection && [lastSelection count] 
                && ([lastSelection isEqual: baseNodeArray] == NO)) {
          for (i = 0; i < [lastSelection count]; i++) {
            FSNode *node = [lastSelection objectAtIndex: i];

            if ([node isDirectory] && ([node isPackage] == NO)) {
              canopen = NO;
              break;      
            }
          }
        } else {
          canopen = NO;
        }

        return canopen;
      }

      return NO;

    } else if (sel_isEqual(action, @selector(openSelectionAsFolder:))) {
      if (lastSelection && ([lastSelection count] == 1)) {  
        return [[lastSelection objectAtIndex: 0] isDirectory];
      }

      return NO;

    } else if (sel_isEqual(action, @selector(openWith:))) {
      BOOL canopen = YES;
      int i;

      if (lastSelection && [lastSelection count]
            && ([lastSelection isEqual: baseNodeArray] == NO)) {
        for (i = 0; i < [lastSelection count]; i++) {
          FSNode *node = [lastSelection objectAtIndex: i];

          if (([node isPlain] == NO) 
                && (([node isPackage] == NO) || [node isApplication])) {
            canopen = NO;
            break;
          }
        }
      } else {
        canopen = NO;
      }

      return canopen;

    } else if (sel_isEqual(action, @selector(newFolder:))
                                  || sel_isEqual(action, @selector(newFile:))) {
      if ([[baseNode path] isEqual: [gworkspace trashPath]] == NO) {
        return [[nodeView shownNode] isWritable];
      }

      return NO;
    }
    
    return YES;   
  } else {
    SEL action = [menuItem action];
    if (sel_isEqual(action, @selector(makeKeyAndOrderFront:))) {
      return YES;
    }
  }
  
  return NO;
}

- (void)makeThumbnails:(id)sender
{
  NSString *path;

  path = [[nodeView shownNode] path];
  path = [path stringByResolvingSymlinksInPath];
  if (path)
    {
      Thumbnailer *t;
      
      t = [Thumbnailer sharedThumbnailer];
      [t makeThumbnails:path];
      [t release];
    }
}

- (void)removeThumbnails:(id)sender
{
  NSString *path;

  path = [[nodeView shownNode] path];
  path = [path stringByResolvingSymlinksInPath];
  if (path)
    {
      Thumbnailer *t;
      
      t = [Thumbnailer sharedThumbnailer];
      [t removeThumbnails:path];
      [t release];
    }
}

@end
















