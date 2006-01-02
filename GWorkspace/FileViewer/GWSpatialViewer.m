/* GWSpatialViewer.m
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <AppKit/AppKit.h>
#include <math.h>
#include "GWSpatialViewer.h"
#include "GWViewersManager.h"
#include "GWViewerWindow.h"
#include "GWViewerScrollView.h"
#include "GWViewerBrowser.h"
#include "GWViewerIconsView.h"
#include "GWViewerListView.h"
#include "GWViewerPathsPopUp.h"
#include "GWorkspace.h"
#include "GWFunctions.h"
#include "FSNodeRep.h"
#include "FSNIcon.h"
#include "FSNFunctions.h"
 
#define DEFAULT_INCR 150
#define MIN_W_HEIGHT 180

@implementation GWSpatialViewer

- (void)dealloc
{
  [nc removeObserver: self];
  
  RELEASE (baseNode);
  TEST_RELEASE (lastSelection);
  TEST_RELEASE (rootViewerKey);
  RELEASE (watchedNodes);
  RELEASE (vwrwin);
  RELEASE (viewType);
  
	[super dealloc];
}

- (id)initForNode:(FSNode *)node
         inWindow:(GWViewerWindow *)win
         showType:(NSString *)stype
    showSelection:(BOOL)showsel
{
  self = [super init];
  
  if (self) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
    NSDictionary *viewerPrefs = nil;
    NSString *prefsname;
    id defEntry;

    ASSIGN (baseNode, [FSNode nodeWithPath: [node path]]);
    lastSelection = nil;
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

    rootviewer = ([[baseNode path] isEqual: path_separator()]
                && ([[manager viewersForBaseNode: baseNode] count] == 0));

    if ((rootviewer == NO) && [[baseNode path] isEqual: path_separator()]) {
      rootViewerKey = [manager nextRootViewerKey];
      
      if (rootViewerKey == nil) {
        ASSIGN (rootViewerKey, [NSNumber numberWithUnsignedLong: (unsigned long)self]);
      } else {
        RETAIN (rootViewerKey);
      }
      
      prefsname = [NSString stringWithFormat: @"viewer_at_%@_%i", 
                            [node path], [rootViewerKey unsignedLongValue]];

    } else {
      rootViewerKey = nil;
      prefsname = [NSString stringWithFormat: @"viewer_at_%@", [node path]];
    }

    if ([baseNode isWritable] && (rootviewer == NO) && (rootViewerKey == nil)) {
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
              && ([viewType isEqual: @"List"] == NO)
              && ([viewType isEqual: @"Browser"] == NO)) {
      viewType = @"Icon";
    }

    RETAIN (viewType);

    ASSIGN (vwrwin, win);
    [vwrwin setReleasedWhenClosed: NO];
    [vwrwin setDelegate: self];
    [vwrwin setMinSize: NSMakeSize(resizeIncrement * 2, MIN_W_HEIGHT)];    
    [vwrwin setResizeIncrements: NSMakeSize(resizeIncrement, 1)];

    defEntry = [viewerPrefs objectForKey: @"geometry"];

    if (defEntry) {
      [vwrwin setFrameFromString: defEntry];
    } else {
      NSRect r = NSMakeRect(200, 200, resizeIncrement * 3, 300);
    
      [vwrwin setFrame: rectForWindow([manager viewerWindows], r, YES) 
               display: NO];
    }

    if (rootviewer) {
      [vwrwin setTitle: NSLocalizedString(@"File Viewer", @"")];
    } else {
      if (rootViewerKey == nil) {   
        [vwrwin setTitle: [NSString stringWithFormat: @"%@ - %@", [node name], [node parentPath]]];   
      } else {
        [vwrwin setTitle: [NSString stringWithFormat: @"%@", [node name]]];   
      }
    }

    [self createSubviews];

    if ([viewType isEqual: @"Icon"]) {
      nodeView = [[GWViewerIconsView alloc] initForViewer: self];

    } else if ([viewType isEqual: @"List"]) { 
      NSRect r = [[scroll contentView] frame];
      
      nodeView = [[GWViewerListView alloc] initWithFrame: r forViewer: self];

    } else if ([viewType isEqual: @"Browser"]) {
      nodeView = [[GWViewerBrowser alloc] initWithBaseNode: baseNode
                                      inViewer: self
		                            visibleColumns: visibleCols
                                      scroller: [scroll horizontalScroller]
                                    cellsIcons: YES
                                 editableCells: YES       
                               selectionColumn: NO];
    }

	  [scroll setDocumentView: nodeView];	
    RELEASE (nodeView);                 
    [nodeView showContentsOfNode: baseNode]; 

    /*
    * Beeing "spatial", we always set the selection in the browser
    */      
    if (showsel || ([nodeView isSingleNode] == NO)) {
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
          [nodeView selectRepsOfPaths: selection];
        }

        RELEASE (selection);
      }
    }

    [self updeateInfoLabels];

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
  int boxh = 32;  
  int labelw = 106;
  int labelh = 20;
  int margin = 8;
  unsigned int resizeMask;
  BOOL hasScroller;

  mainView = [[NSView alloc] initWithFrame: r];
  [mainView setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];

  r = NSMakeRect(0, h - boxh, w, boxh);
  topBox = [[NSView alloc] initWithFrame: r];
  resizeMask = NSViewNotSizable | NSViewWidthSizable | NSViewMinYMargin;
  [topBox setAutoresizingMask: resizeMask];
  [topBox setAutoresizesSubviews: YES];
  [mainView addSubview: topBox];
  RELEASE (topBox);

  r = NSMakeRect(margin, margin - 2, labelw, labelh);
  elementsLabel = [[NSTextField alloc] initWithFrame: r];
  [elementsLabel setFont: [NSFont systemFontOfSize: 10]];
  [elementsLabel setAlignment: NSLeftTextAlignment];
  [elementsLabel setDrawsBackground: NO];
  [elementsLabel setTextColor: [NSColor controlShadowColor]];
  [elementsLabel setBezeled: NO]; 
  [elementsLabel setEditable: NO]; 
  [elementsLabel setSelectable: NO];
  resizeMask = NSViewNotSizable | NSViewMaxXMargin;
  [elementsLabel setAutoresizingMask: resizeMask];
  [topBox addSubview: elementsLabel];
  RELEASE (elementsLabel);

  r = NSMakeRect(0, margin - 2, labelw, labelh);
  r.origin.x = (w / 2) - (labelw / 2);
  pathsPopUp = [[GWViewerPathsPopUp alloc] initWithFrame: r pullsDown: NO];
  resizeMask = NSViewNotSizable | NSViewMinXMargin | NSViewMaxXMargin;
  [pathsPopUp setAutoresizingMask: resizeMask];
  [pathsPopUp setTarget: self];
  [pathsPopUp setAction: @selector(popUpAction:)];
  [pathsPopUp setItemsToNode: baseNode];
  [topBox addSubview: pathsPopUp];
  RELEASE (pathsPopUp);

  r = NSMakeRect(w - labelw - margin, margin - 2, labelw, labelh);
  spaceLabel = [[NSTextField alloc] initWithFrame: r];
  [spaceLabel setFont: [NSFont systemFontOfSize: 10]];
  [spaceLabel setAlignment: NSRightTextAlignment];
  [spaceLabel setDrawsBackground: NO];
  [spaceLabel setTextColor: [NSColor controlShadowColor]];
  [spaceLabel setBezeled: NO]; 
  [spaceLabel setEditable: NO]; 
  [spaceLabel setSelectable: NO];
  resizeMask = NSViewNotSizable | NSViewMinXMargin;
  [spaceLabel setAutoresizingMask: resizeMask];
  [topBox addSubview: spaceLabel];
  RELEASE (spaceLabel);

  r = NSMakeRect(margin, 0, w - (margin * 2), h - boxh);
  scroll = [[GWViewerScrollView alloc] initWithFrame: r inViewer: self];
  [scroll setBorderType: NSBezelBorder];
  hasScroller = ([viewType isEqual: @"Icon"] || [viewType isEqual: @"List"]);
  [scroll setHasHorizontalScroller: YES];
  [scroll setHasVerticalScroller: hasScroller];
  resizeMask = NSViewNotSizable | NSViewWidthSizable | NSViewHeightSizable;
  [scroll setAutoresizingMask: resizeMask];
  [mainView addSubview: scroll];
  RELEASE (scroll);

  visibleCols = myrintf(r.size.width / [vwrwin resizeIncrements].width);  
  
  [vwrwin setContentView: mainView];
  RELEASE (mainView);
}

- (FSNode *)baseNode
{
  return baseNode;
}

- (BOOL)isShowingNode:(FSNode *)anode
{
  return [nodeView isShowingNode: anode];
}

- (BOOL)isShowingPath:(NSString *)apath
{
  return [nodeView isShowingPath: apath];
}

- (void)reloadNodeContents
{
  [nodeView reloadContents];
}

- (void)reloadFromNode:(FSNode *)anode
{
  if ([nodeView isShowingNode: anode]) {
    [nodeView reloadFromNode: anode];
    [self updeateInfoLabels];
  }
}

- (void)unloadFromNode:(FSNode *)anode
{
  if ([baseNode isEqual: anode] || [baseNode isSubnodeOfNode: anode]) {
    [self deactivate];
  } else if ([nodeView isShowingNode: anode]) {
    [nodeView unloadFromNode: anode];
  }
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
  return nil;
}

- (NSString *)viewType
{
  return viewType;
}

- (BOOL)isRootViewer
{
  return rootviewer;
}

- (NSNumber *)rootViewerKey
{
  return rootViewerKey;
}

- (BOOL)isSpatial
{
  return YES;
}

- (int)vtype
{
  return SPATIAL;
}

- (void)activate
{
  [vwrwin makeKeyAndOrderFront: nil];
  [manager viewer: self didShowNode: baseNode];
}

- (void)deactivate
{
  [vwrwin close];
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
  [nodeView stopRepNameEditing];
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
    return;
  }

  ASSIGN (lastSelection, newsel);
  [self updeateInfoLabels]; 
    
  node = [FSNode nodeWithPath: [newsel objectAtIndex: 0]];   
    
  if ([nodeView isSingleNode]) {    
    if ([node isEqual: baseNode] == NO) {
      return;
    }
  }
 
  if (([node isDirectory] == NO) || [node isPackage] || ([newsel count] > 1)) {
    if ([node isEqual: baseNode] == NO) { // if baseNode is a package 
      node = [FSNode nodeWithPath: [node parentPath]];
    }
  } 
    
  components = [FSNode nodeComponentsFromNode: baseNode toNode: node];
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

- (void)multipleNodeViewDidSelectSubNode:(FSNode *)node
{
  if ([node isDirectory] && ([node isPackage] == NO)) {
    [nodeView setLastShownNode: node];
  }
}

- (void)setSelectableNodesRange:(NSRange)range
{
  visibleCols = range.length;
}

- (void)updeateInfoLabels
{
  NSArray *reps;
  NSString *labelstr;
  NSDictionary *attributes;
  NSNumber *freefs;

  reps = [nodeView reps];
  labelstr = [NSString stringWithFormat: @"%i ", (reps ? [reps count] : 0)];
  labelstr = [labelstr stringByAppendingString: NSLocalizedString(@"elements", @"")];

  [elementsLabel setStringValue: labelstr];

  attributes = [[NSFileManager defaultManager] fileSystemAttributesAtPath: [[nodeView shownNode] path]];
	freefs = [attributes objectForKey: NSFileSystemFreeSize];

	if (freefs == nil) {  
		labelstr = NSLocalizedString(@"unknown volume size", @"");    
	} else {
    unsigned long long freeSize = [freefs unsignedLongLongValue];
    unsigned systemType = [[FSNodeRep sharedInstance] systemType];
    
    switch (systemType) {
      case NSBSDOperatingSystem:
        freeSize = (freeSize >> 8);
        break;

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

  [spaceLabel setStringValue: labelstr];
}

- (void)popUpAction:(id)sender
{
  NSString *path = [[sender selectedItem] representedObject];

  if ([path isEqual: [baseNode path]] == NO) {
    FSNode *node = [FSNode nodeWithPath: path];
    BOOL close = [sender closeViewer];
  
    if (close) {
      [pathsPopUp setTarget: nil];
    }
  
    [manager newViewerOfType: SPATIAL
                    showType: nil
                     forNode: node 
               showSelection: NO
              closeOldViewer: (close ? self : nil)
                    forceNew: NO];
  } else {
    [nodeView showContentsOfNode: baseNode]; 
    [self scrollToBeginning];
    [vwrwin makeFirstResponder: nodeView];
    [manager selectedSpatialViewerChanged: self];
    [manager synchronizeSelectionInParentOfViewer: self];
  }
}

- (BOOL)involvedByFileOperation:(NSDictionary *)opinfo
{
  return [nodeView involvedByFileOperation: opinfo];
}

- (void)nodeContentsWillChange:(NSDictionary *)info
{
  [nodeView nodeContentsWillChange: info];
}
 
- (void)nodeContentsDidChange:(NSDictionary *)info
{
  [nodeView nodeContentsDidChange: info];
}

- (void)watchedPathChanged:(NSDictionary *)info
{
  if (invalidated == NO) {
    NSString *path = [info objectForKey: @"path"];
  
    if ([nodeView isShowingPath: path]) {
      [nodeView watchedPathChanged: info];
      [self updeateInfoLabels];
    }
  }
}

- (NSArray *)watchedNodes
{
  return watchedNodes;
}

- (void)hideDotsFileChanged:(BOOL)hide
{
  [self reloadFromNode: baseNode];
}

- (void)hiddenFilesChanged:(NSArray *)paths
{
  [self reloadFromNode: baseNode];
}

- (void)columnsWidthChanged:(NSNotification *)notification
{
  NSRect r = [vwrwin frame];
  
  RETAIN (nodeView);  
  [nodeView removeFromSuperviewWithoutNeedingDisplay];
  [scroll setDocumentView: nil];	
  
  resizeIncrement = [(NSNumber *)[notification object] intValue];
  r.size.width = (visibleCols * resizeIncrement);
  [vwrwin setFrame: r display: YES];  
  [vwrwin setMinSize: NSMakeSize(resizeIncrement * 2, MIN_W_HEIGHT)];    
  [vwrwin setResizeIncrements: NSMakeSize(resizeIncrement, 1)];

  [scroll setDocumentView: nodeView];	
  RELEASE (nodeView); 
  [nodeView resizeWithOldSuperviewSize: [nodeView bounds].size];
  [self scrollToBeginning];
}

- (void)updateDefaults
{
  if ([baseNode isValid]) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
    NSMutableDictionary *updatedprefs = nil;
    NSString *prefsname;
    NSString *dictPath;
    id defEntry;
    
    if (rootViewerKey != nil) {
      prefsname = [NSString stringWithFormat: @"viewer_at_%@_%i", 
                          [baseNode path], [rootViewerKey unsignedLongValue]];
    } else {
      prefsname = [NSString stringWithFormat: @"viewer_at_%@", [baseNode path]];
    }    

    dictPath = [[baseNode path] stringByAppendingPathComponent: @".gwdir"];
    
    [nodeView updateNodeInfo];
    
    if ([baseNode isWritable] && (rootviewer == NO) && (rootViewerKey == nil)) {
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

    [updatedprefs setObject: [NSNumber numberWithBool: YES]
                     forKey: @"spatial"];

    [updatedprefs setObject: [NSNumber numberWithBool: [nodeView isSingleNode]]
                     forKey: @"singlenode"];

    [updatedprefs setObject: viewType forKey: @"viewtype"];

    defEntry = [nodeView selectedPaths];
    if (defEntry) {
      [updatedprefs setObject: defEntry forKey: @"lastselection"];
    }

    [updatedprefs setObject: [vwrwin stringWithSavedFrame] 
                     forKey: @"geometry"];

    if ([baseNode isWritable] && (rootviewer == NO) && (rootViewerKey == nil)) {
      [updatedprefs writeToFile: dictPath atomically: YES];
    } else {
      [defaults setObject: updatedprefs forKey: prefsname];
    }
  
    RELEASE (updatedprefs);
  }
}

@end


//
// GWViewerWindow Delegate Methods
//
@implementation GWSpatialViewer (GWViewerWindowDelegateMethods)

- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
  NSArray *selection = [nodeView selectedPaths];  
  int count = [selection count];
  
  [vwrwin makeFirstResponder: nodeView]; 

  [manager selectedSpatialViewerChanged: self];

  if (count == 0) {
    selection = [NSArray arrayWithObject: [[nodeView shownNode] path]];
    [manager synchronizeSelectionInParentOfViewer: self];
  
  } else if (count == 1) {
    if (([nodeView isSingleNode] == NO)
             || ([[selection objectAtIndex: 0] isEqual: [baseNode path]])) {
      [manager synchronizeSelectionInParentOfViewer: self];
    }
    
  } else if ([nodeView isSingleNode] == NO) {
    [manager synchronizeSelectionInParentOfViewer: self];
  }
  
  [self selectionChanged: selection];

  if (invalidated == NO) {
    [manager addNode: baseNode toHistoryOfViewer: self];     
    [manager changeHistoryOwner: self];
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

- (void)windowWillMiniaturize:(NSNotification *)aNotification
{
  NSImage *image = [[FSNodeRep sharedInstance] iconOfSize: 48 forNode: baseNode];

  [vwrwin setMiniwindowImage: image];
  [vwrwin setMiniwindowTitle: [baseNode name]];
}

- (void)windowDidResize:(NSNotification *)aNotification
{
  if (nodeView) {
    [nodeView stopRepNameEditing];
    
    if ([nodeView isKindOfClass: [GWViewerBrowser class]]) { 
      [nodeView updateScroller];
    }
  }
}

- (void)openSelectionInNewViewer:(BOOL)newv
{
  [manager openSelectionInViewer: self closeSender: newv];
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
  NSArray *selection = [nodeView selectedNodes];

  if (selection && [selection count]) {
    if ([nodeView isSingleNode]) {
      [gworkspace duplicateFiles];
    } else if ([selection isEqual: [NSArray arrayWithObject: baseNode]] == NO) {
      [gworkspace duplicateFiles];
    }
  }
}

- (void)recycleFiles
{
  NSArray *selection = [nodeView selectedNodes];

  if (selection && [selection count]) {
    if ([nodeView isSingleNode]) {
      [gworkspace moveToTrash];
    } else if ([selection isEqual: [NSArray arrayWithObject: baseNode]] == NO) {
      [gworkspace moveToTrash];
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
    } else if ([selection isEqual: [NSArray arrayWithObject: baseNode]] == NO) {
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
    [scroll setDocumentView: nil];	
    
    if ([title isEqual: NSLocalizedString(@"Browser", @"")]) {
      nodeView = [[GWViewerBrowser alloc] initWithBaseNode: baseNode
                                      inViewer: self
		                            visibleColumns: visibleCols
                                      scroller: [scroll horizontalScroller]
                                    cellsIcons: YES
                                 editableCells: YES   
                               selectionColumn: NO]; 
      
      [scroll setHasVerticalScroller: NO];
      ASSIGN (viewType, @"Browser");
      
    } else if ([title isEqual: NSLocalizedString(@"Icon", @"")]) {
      nodeView = [[GWViewerIconsView alloc] initForViewer: self];
      [scroll setHasVerticalScroller: YES];
      ASSIGN (viewType, @"Icon");
      
    } else if ([title isEqual: NSLocalizedString(@"List", @"")]) {
      NSRect r = [[scroll contentView] frame];

      nodeView = [[GWViewerListView alloc] initWithFrame: r forViewer: self];
      [scroll setHasVerticalScroller: YES];
      ASSIGN (viewType, @"List");
    }
    
    [scroll setDocumentView: nodeView];	
    RELEASE (nodeView);                 
    [nodeView showContentsOfNode: baseNode]; 
    
    if ([selection count]) {
      [nodeView selectRepsOfPaths: selection];
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
  [nodeView updateNodeInfo];
}

- (void)setExtendedShownType:(id)sender
{
  [(id <FSNodeRepContainer>)nodeView setExtendedShowType: [sender title]]; 
  [self scrollToBeginning]; 
  [nodeView updateNodeInfo];
}

- (void)setIconsSize:(id)sender
{
  if ([nodeView respondsToSelector: @selector(setIconSize:)]) {
    [(id <FSNodeRepContainer>)nodeView setIconSize: [[sender title] intValue]];
    [self scrollToBeginning];
    [nodeView updateNodeInfo];
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
    [nodeView updateNodeInfo];
  }
}

- (void)setLabelSize:(id)sender
{
  if ([nodeView respondsToSelector: @selector(setLabelTextSize:)]) {
    [nodeView setLabelTextSize: [[sender title] intValue]];
    [self scrollToBeginning];
    [nodeView updateNodeInfo];
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
  
  } else if ([itemTitle isEqual: NSLocalizedString(@"Duplicate", @"")]
       || [itemTitle isEqual: NSLocalizedString(@"Move to Recycler", @"")]) {
    NSArray *selection = [nodeView selectedNodes];

    if (selection && [selection count]) {
      if ([nodeView isSingleNode]) {
        return YES;
      } else if ([selection isEqual: [NSArray arrayWithObject: baseNode]] == NO) {
        return YES;
      }
    }
    
    return NO;
  } 

  return YES;
}

@end














