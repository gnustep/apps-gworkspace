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
  TEST_RELEASE (shownNode);
  TEST_RELEASE (lastSelection);
  TEST_RELEASE (watchedNodes);
  TEST_RELEASE (vwrwin);
  TEST_RELEASE (viewType);
  
  [super dealloc];
}

- (id)initForNode:(FSNode *)node
{
  self = [super init];
  
  if (self) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	      
    NSString *prefsname = [NSString stringWithFormat: @"viewer_at_%@", [node path]];
    NSDictionary *viewerPrefs = nil;
    id defEntry;
    unsigned int style;
    int resincr;
    
    ASSIGN (shownNode, [FSNode nodeWithRelativePath: [node path] parent: nil]);
    lastSelection = nil;
    watchedNodes = [NSMutableArray new];
    manager = [GWViewersManager viewersManager];
    gworkspace = [GWorkspace gworkspace];
    spatial = NO;
    
    defEntry = [defaults objectForKey: @"browserColsWidth"];
    if (defEntry) {
      resincr = [defEntry intValue];
    } else {
      resincr = DEFAULT_INCR;
    }

    rootviewer = ([[shownNode path] isEqual: path_separator()]
              && ([manager viewerWithBasePath: [shownNode path]] == nil));
    
    if ([shownNode isWritable] && (rootviewer == NO)) {
		  NSString *dictPath = [[shownNode path] stringByAppendingPathComponent: @".gwdir"];

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
   
    if (rootviewer) {
      style = NSTitledWindowMask | NSMiniaturizableWindowMask 
                                            | NSResizableWindowMask;
    } else {
      style = NSTitledWindowMask | NSClosableWindowMask 
				           | NSMiniaturizableWindowMask | NSResizableWindowMask;
    }

    vwrwin = [[GWViewerWindow alloc] initWithContentRect: NSZeroRect
                                         styleMask: style
                                           backing: NSBackingStoreBuffered 
                                             defer: NO];

    [vwrwin setReleasedWhenClosed: NO];
    [vwrwin setDelegate: self];
    [vwrwin setMinSize: NSMakeSize(resincr * 2, MIN_W_HEIGHT)];    
    [vwrwin setResizeIncrements: NSMakeSize(resincr, 1)];

    defEntry = [viewerPrefs objectForKey: @"geometry"];
    
    if (defEntry) {
      [vwrwin setFrameFromString: defEntry];
    } else {
      [vwrwin setFrame: NSMakeRect(200, 200, resincr * 3, 400) 
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
   //   [shelf setContents: defEntry];
    }
        
    if ([viewType isEqual: @"Icon"]) {
      nodeView = [[GWViewerIconsView alloc] initForViewer: self];

    } else if ([viewType isEqual: @"Browser"]) {
      nodeView = [[GWViewerBrowser alloc] initWithBaseNode: shownNode
                                      inViewer: self
		                            visibleColumns: visibleCols
                                      scroller: [pathsScroll horizontalScroller]
                                    cellsIcons: NO
                               selectionColumn: YES];
    }

    [nviewScroll setDocumentView: nodeView];	
    RELEASE (nodeView);                 
    [nodeView showContentsOfNode: shownNode]; 

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
   
      if ([selection count]) { // SOLO SE ONSTART ??????????????????????????
        [nodeView selectRepsOfPaths: selection];
      }
      
      RELEASE (selection);
    }

    [self updeateInfoLabels];
    [self tileViews];

    if ([nodeView isSingleNode]) {
      NSRect r = [nodeView frame];
      [nodeView scrollRectToVisible: NSMakeRect(0, r.size.height - 1, 1, 1)];	
    }
    
    RELEASE (viewerPrefs);
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
  shelf = [[GWViewerShelf alloc] initWithFrame: r];
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
  pathsScroll = [[NSScrollView alloc] initWithFrame: r];
  [pathsScroll setBorderType: NSBezelBorder];
  [pathsScroll setHasHorizontalScroller: YES];
  [pathsScroll setHasVerticalScroller: NO];
  resizeMask = NSViewNotSizable | NSViewWidthSizable | NSViewMinYMargin;
  [pathsScroll setAutoresizingMask: resizeMask];
  [lowBox addSubview: pathsScroll];
  RELEASE (pathsScroll);

  visibleCols = rintf(r.size.width / [vwrwin resizeIncrements].width);  
  
  r = [[pathsScroll documentView] frame];
  pathsView = [[GWViewerIconsPath alloc] initWithFrame: r 
                                          visibleIcons: visibleCols];
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

- (FSNode *)shownNode
{
  return shownNode;
}

- (void)reloadNodeContents
{
  [nodeView reloadContents];
}

- (void)unloadFromPath:(NSString *)path
{
  if ([[shownNode path] isEqual: path]) {
    [self deactivate];
  } else if ([nodeView isShowingPath: path]) {
    [nodeView unloadFromPath: path];
  }
}


- (NSWindow *)win
{
  return vwrwin;
}

- (id)nodeView
{
  return nodeView;
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


- (void)activate
{
  [vwrwin makeKeyAndOrderFront: nil];
  [self tileViews];
//  [manager viewer: self didShowPath: [shownNode path]];
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

- (void)invalidate
{
  invalidated = YES;
}

- (BOOL)invalidated
{
  return invalidated;
}


- (void)setOpened:(BOOL)opened 
        repOfPath:(NSString *)path
{
  id rep = [nodeView repOfSubnodePath: path];

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

//  [manager selectionChanged: newsel];

  if (lastSelection && [newsel isEqual: lastSelection]) {
    return;
  }

  ASSIGN (lastSelection, newsel);
  [self updeateInfoLabels]; 
    
  node = [FSNode nodeWithRelativePath: [newsel objectAtIndex: 0] parent: nil];   
    
  if ([nodeView isSingleNode]) {    
    if ([node isEqual: shownNode] == NO) {
      return;
    }
  }
 
  if (([node isDirectory] == NO) || [node isPackage] || ([newsel count] > 1)) {
    if ([node isEqual: shownNode] == NO) { // if shownNode is a package 
      node = [FSNode nodeWithRelativePath: [node parentPath] parent: nil];
    }
  } 
    
  components = [FSNode nodeComponentsFromNode: shownNode toNode: node];
  
  [pathsView showPathComponents: components selection: newsel];
  
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

- (void)setSelectableNodesRange:(NSRange)range
{
  visibleCols = range.length;
  [pathsView setSelectableIconsRange: range];
}

- (void)updeateInfoLabels
{
/*
  NSArray *reps;
  NSString *labelstr;
  NSDictionary *attributes;
  NSNumber *freefs;

  reps = [nodeView reps];
  labelstr = [NSString stringWithFormat: @"%i ", (reps ? [reps count] : 0)];
  labelstr = [labelstr stringByAppendingString: NSLocalizedString(@"elements", @"")];

  [elementsLabel setStringValue: labelstr];

  attributes = [[NSFileManager defaultManager] fileSystemAttributesAtPath: [shownNode path]];
	freefs = [attributes objectForKey: NSFileSystemFreeSize];

	if (freefs == nil) {  
		labelstr = NSLocalizedString(@"unknown volume size", @"");    
	} else {
		labelstr = [NSString stringWithFormat: @"%@ %@", 
                   sizeDescription([freefs unsignedLongLongValue]),
                                        NSLocalizedString(@"free", @"")];
	}

  [spaceLabel setStringValue: labelstr];
*/
}


- (BOOL)involvedByFileOperation:(NSDictionary *)opinfo
{
  return [nodeView involvedByFileOperation: opinfo];
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
    if ([nodeView isShowingPath: destination]
                    || [shownNode isSubnodeOfPath: destination]) {
      [self unsetWatchersFromPath: destination];
    }
  }

  if ([operation isEqual: @"NSWorkspaceMoveOperation"]
        || [operation isEqual: @"NSWorkspaceDestroyOperation"]
				|| [operation isEqual: @"NSWorkspaceRecycleOperation"]
				|| [operation isEqual: @"GWorkspaceRecycleOutOperation"]
				|| [operation isEqual: @"GWorkspaceEmptyRecyclerOperation"]) {
    if ([nodeView isShowingPath: source]
                      || [shownNode isSubnodeOfPath: source]) {
      [self unsetWatchersFromPath: source]; 
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

  [nodeView nodeContentsDidChange: info];
  
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
    if ([nodeView isShowingPath: destination]
                        || [shownNode isSubnodeOfPath: destination]) {
      [self setWatchersFromPath: destination];
    }
  }

  if ([operation isEqual: @"NSWorkspaceMoveOperation"]
        || [operation isEqual: @"NSWorkspaceDestroyOperation"]
				|| [operation isEqual: @"NSWorkspaceRecycleOperation"]
				|| [operation isEqual: @"GWorkspaceRecycleOutOperation"]
				|| [operation isEqual: @"GWorkspaceEmptyRecyclerOperation"]) {
    if ([nodeView isShowingPath: source]
                        || [shownNode isSubnodeOfPath: source]) {
      [self setWatchersFromPath: source];
    }
  }
}

- (void)setWatchersFromPath:(NSString *)path
{
  NSString *start = [shownNode isSubnodeOfPath: path] ? [shownNode path] : path;
  unsigned index = [FSNode indexOfNodeWithPath: start 
                                  inComponents: watchedNodes];

  if (index != NSNotFound) {
    int count = [watchedNodes count];
    int i;
    
    for (i = index; i < count; i++) {
      FSNode *node = [watchedNodes objectAtIndex: i];
    
      if ([node isValid] && [node isDirectory]) {
        [gworkspace addWatcherForPath: [node path]];
      } else {
        [watchedNodes removeObjectAtIndex: i];
        count--;
        i--;
      }  
    }
  }
}

- (void)unsetWatchersFromPath:(NSString *)path
{
  NSString *start = [shownNode isSubnodeOfPath: path] ? [shownNode path] : path;
  unsigned index = [FSNode indexOfNodeWithPath: start 
                                  inComponents: watchedNodes];

  if (index != NSNotFound) {
    int i;

    for (i = index; i < [watchedNodes count]; i++) {      
      [gworkspace removeWatcherForPath: [[watchedNodes objectAtIndex: i] path]];
    }
  } 
}

- (void)watchedPathChanged:(NSDictionary *)info
{
  if (invalidated == NO) {
    [nodeView watchedPathChanged: info];
  }
}

- (NSArray *)watchedNodes
{
  return watchedNodes;
}


- (void)updateDefaults
{
  if ([shownNode isValid]) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	      
    NSString *prefsname = [NSString stringWithFormat: @"viewer_at_%@", [shownNode path]];
    NSString *dictPath = [[shownNode path] stringByAppendingPathComponent: @".gwdir"];
    NSMutableDictionary *updatedprefs = nil;
    id defEntry;
    
    if ([shownNode isWritable] && (rootviewer == NO)) {
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

//    [updatedprefs setObject: [shelf contentsInfo]
//                     forKey: @"shelfdicts"];

    defEntry = [nodeView selectedPaths];
    if (defEntry) {
      [updatedprefs setObject: defEntry forKey: @"lastselection"];
    }
    
    [updatedprefs setObject: [vwrwin stringWithSavedFrame] 
                     forKey: @"geometry"];

    if ([shownNode isWritable] && (rootviewer == NO)) {
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
  NSArray *selection;

  [vwrwin makeFirstResponder: nodeView];  

  if ([nodeView shownNode]) {
    selection = [nodeView selectedPaths];  
  
    if (selection && [selection count]) {
      if ([selection count] == 1) {
        if ([nodeView isSingleNode]) {
          if ([[selection objectAtIndex: 0] isEqual: [shownNode path]]) {
     //       [manager viewerSelected: self];
          } else {
    //        [manager selectionDidChangeInViewer: self];
          }
          
        } else {
  //        [manager viewerSelected: self];
        }
      } else {
  //      [manager selectionDidChangeInViewer: self];
      }
          
      [self selectionChanged: selection];
      
    } else {
      selection = [NSArray arrayWithObject: [shownNode path]];
  //    [manager viewerSelected: self];
      [self selectionChanged: selection];
    }
  } else {
    selection = [NSArray arrayWithObject: [shownNode path]];
//    [manager viewerSelected: self];
    [self selectionChanged: selection];
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
//    [manager viewerWillClose: self]; 
  }
}

- (void)openSelectionInNewViewer:(BOOL)newv
{
//  [manager openSelectionInViewer: self closeSender: newv];
}

- (void)openSelectionAsFolder
{
//  [manager openAsFolderSelectionInViewer: self];
}

- (void)newFolder
{
  [gworkspace newObjectAtPath: [shownNode path] isDirectory: YES];
}

- (void)newFile
{
  [gworkspace newObjectAtPath: [shownNode path] isDirectory: NO];
}

- (void)duplicateFiles
{
  [gworkspace duplicateFiles];
}

- (void)deleteFiles
{
  [gworkspace deleteFiles];
}

- (void)setViewerType:(id)sender
{
  NSString *title = [sender title];
  
	if ([title isEqual: NSLocalizedString(viewType, @"")] == NO) {
    NSArray *selection;
  
    [nviewScroll setDocumentView: nil];	
    
    if ([title isEqual: NSLocalizedString(@"Browser", @"")]) {
      nodeView = [[GWViewerBrowser alloc] initWithBaseNode: shownNode
                                      inViewer: self
		                            visibleColumns: visibleCols
                                      scroller: [pathsScroll horizontalScroller]
                                    cellsIcons: NO
                               selectionColumn: YES];

      [nviewScroll setHasVerticalScroller: NO];
      [nviewScroll setHasHorizontalScroller: NO];
      ASSIGN (viewType, @"Browser");
      
    } else if ([title isEqual: NSLocalizedString(@"Icon", @"")]) {
      nodeView = [[GWViewerIconsView alloc] initForViewer: self];
      [nviewScroll setHasVerticalScroller: YES];
      [nviewScroll setHasHorizontalScroller: YES];
      ASSIGN (viewType, @"Icon");
    }

    [nviewScroll setDocumentView: nodeView];	
    RELEASE (nodeView);                 
    [nodeView showContentsOfNode: shownNode]; 
    
    if ([nodeView isSingleNode]) {
      NSRect r = [nodeView frame];
      [nodeView scrollRectToVisible: NSMakeRect(0, r.size.height - 1, 1, 1)];	
    }

    [vwrwin makeFirstResponder: nodeView]; 

    [watchedNodes removeAllObjects];
    DESTROY (lastSelection);
    selection = [nodeView selectedPaths];
    
    if ((selection == nil) || ([selection count] == 0)) {
      selection = [NSArray arrayWithObject: [shownNode path]];
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
	  path = [shownNode path];
    
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
      path = [shownNode path];
    }
  }

  [gworkspace startXTermOnDirectory: path];
}

- (BOOL)validateItem:(id)menuItem
{
  return YES;
}

@end
















