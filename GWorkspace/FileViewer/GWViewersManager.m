/* GWViewersManager.h
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
#include "GWViewersManager.h"
#include "GWViewer.h"
#include "GWSpatialViewer.h"
#include "GWViewerWindow.h"
#include "History.h"
#include "FSNFunctions.h"
#include "GWorkspace.h"
#include "GWDesktopManager.h"

static GWViewersManager *vwrsmanager = nil;

@implementation GWViewersManager

+ (GWViewersManager *)viewersManager
{
	if (vwrsmanager == nil) {
		vwrsmanager = [[GWViewersManager alloc] init];
	}	
  return vwrsmanager;
}

- (void)dealloc
{
  [[NSDistributedNotificationCenter defaultCenter] removeObserver: self];
  [nc removeObserver: self];
  RELEASE (viewers);
  RELEASE (rootViewersKeys);
  RELEASE (spatialViewersHistory);
    
	[super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];  
    id entry = [defaults objectForKey: @"root_viewers_keys"];
    
    gworkspace = [GWorkspace gworkspace];
    viewers = [NSMutableArray new];
    orderingViewers = NO;
    
    rootViewersKeys = [NSMutableArray new];
    if (entry) {
      [rootViewersKeys addObjectsFromArray: entry];
    }
    
    spatialViewersHistory = [NSMutableArray new]; 
    spvHistoryPos = 0;  
    historyWindow = [gworkspace historyWindow]; 
    nc = [NSNotificationCenter defaultCenter];

    [nc addObserver: self 
           selector: @selector(fileSystemWillChange:) 
               name: @"GWFileSystemWillChangeNotification"
             object: nil];

    [nc addObserver: self 
           selector: @selector(fileSystemDidChange:) 
               name: @"GWFileSystemDidChangeNotification"
             object: nil];

    [nc addObserver: self 
           selector: @selector(watcherNotification:) 
               name: @"GWFileWatcherFileDidChangeNotification"
             object: nil];    
    
    [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                				selector: @selector(sortTypeDidChange:) 
                					  name: @"GWSortTypeDidChangeNotification"
                					object: nil];
    
    [[FSNodeRep sharedInstance] setLabelWFactor: 9.0];
  }
  
  return self;
}


- (void)showViewers
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];  
  NSArray *viewersInfo = [defaults objectForKey: @"viewersinfo"];

  if (viewersInfo && [viewersInfo count]) {
    int i;
    
    for (i = 0; i < [viewersInfo count]; i++) {
      NSDictionary *dict = [viewersInfo objectAtIndex: i];
      NSString *path = [dict objectForKey: @"path"];
      int type = [[dict objectForKey: @"type"] intValue];
      FSNode *node = [FSNode nodeWithPath: path];
    
      if (node && [node isValid]) {
        [self newViewerOfType: type
                     showType: nil
                      forNode: node
                showSelection: YES
               closeOldViewer: NO
                     forceNew: YES];
      }
    }

  } else {
    [self showRootViewer];
  }
}

- (id)showRootViewer
{
  NSString *path = path_separator();
  FSNode *node = [FSNode nodeWithPath: path];
  id viewer = [self rootViewer];
  int type = BROWSING;
  
  if (viewer == nil) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *prefsname = [NSString stringWithFormat: @"viewer_at_%@", path];
    NSDictionary *viewerPrefs = [defaults objectForKey: prefsname];
  
    if (viewerPrefs) {
      id entry = [viewerPrefs objectForKey: @"spatial"];
   
      if (entry) {
        type = ([entry boolValue] ? SPATIAL : BROWSING);
      }
    }
  
    viewer = [self newViewerOfType: type
                          showType: nil
                           forNode: node
                     showSelection: YES
                    closeOldViewer: NO
                          forceNew: NO];
  } else {
    if ([[viewer win] isVisible] == NO) {
  	  [viewer activate];
      
    } else {
      if ([self viewerOfType: SPATIAL withBaseNode: node] == nil) {
        type = [self typeOfViewerForNode: node];
      } else {
        type = BROWSING;
      }

      viewer = [self newViewerOfType: type
                            showType: nil
                             forNode: node
                       showSelection: (type == BROWSING)
                      closeOldViewer: NO
                            forceNew: YES];
    }
  }
  
  return viewer;
}

- (void)selectRepOfNode:(FSNode *)node
          inViewerWithBaseNode:(FSNode *)base
{
  BOOL inRootViewer = [[base path] isEqual: path_separator()];
  BOOL baseIsParent = [[node parentPath] isEqual: [base path]];
  NSArray *selection = [NSArray arrayWithObject: node];
  id viewer = nil;
  
  if ([base isEqual: node] || ([node isSubnodeOfNode: base] == NO)) {
    baseIsParent = YES;
    selection = nil;      
  }
  
  if (inRootViewer) {  
    viewer = [self rootViewer];
    
    if (viewer == nil) {
      viewer = [self showRootViewer];
    }
    
    if (([viewer vtype] == SPATIAL) 
            && [[viewer nodeView] isSingleNode]
                              && (baseIsParent == NO)) { 
      viewer = [self newViewerOfType: BROWSING
                            showType: nil
                             forNode: base
                       showSelection: NO
                      closeOldViewer: NO
                            forceNew: YES];
    }
    
  } else {
    int type = [self typeOfViewerForNode: base];
    int newtype = ((type == SPATIAL) && baseIsParent) ? SPATIAL : BROWSING;

    viewer = [self newViewerOfType: newtype
                          showType: nil
                           forNode: base
                     showSelection: NO
                    closeOldViewer: NO
                          forceNew: NO];
  } 
  
  if (selection) {
    [[viewer nodeView] selectRepsOfSubnodes: selection];  
  }
}

- (id)newViewerOfType:(unsigned)vtype
             showType:(NSString *)stype
              forNode:(FSNode *)node
        showSelection:(BOOL)showsel
       closeOldViewer:(id)oldvwr
             forceNew:(BOOL)force
{
  id viewer = [self viewerOfType: vtype withBaseNode: node];
  int i;
    
  if ((viewer == nil) || (force && (vtype != SPATIAL))) {
    Class c = (vtype == SPATIAL) ? [GWSpatialViewer class] : [GWViewer class];
    GWViewerWindow *win = [GWViewerWindow new];
    
    [win setReleasedWhenClosed: NO];
    
    viewer = [[c alloc] initForNode: node 
                           inWindow: win 
                           showType: stype
                      showSelection: showsel]; 
                        
    [viewers addObject: viewer];
    RELEASE (win);
    RELEASE (viewer);
  } 

  if (oldvwr) {
    [[oldvwr win] close]; 
  }
  
  [viewer activate];
  
  if (vtype == SPATIAL) {
    NSArray *reps = [[viewer nodeView] reps];  

    for (i = 0; i < [reps count]; i++) {
      id rep = [reps objectAtIndex: i];  

      if ([self viewerOfType: SPATIAL showingNode: [rep node]]) {
        [rep setOpened: YES];
      }
    }
  }
       
  return viewer;
}

- (void)setBehaviour:(NSString *)behaviour 
           forViewer:(id)aviewer
{
  int vtype = ([behaviour isEqual: NSLocalizedString(@"Spatial", @"")] ? SPATIAL : BROWSING);

  if (vtype != [aviewer vtype]) {
    Class c = (vtype == SPATIAL) ? [GWSpatialViewer class] : [GWViewer class];
    GWViewerWindow *win = RETAIN ([aviewer win]);
    FSNode *node = RETAIN ([aviewer baseNode]);
    id viewer;
    
    [aviewer windowWillClose: nil];
    
    viewer = [[c alloc] initForNode: node 
                           inWindow: win 
                           showType: nil
                      showSelection: YES];   
    [viewers addObject: viewer];
    RELEASE (viewer);
    RELEASE (node);
    RELEASE (win);
    
    [viewer activate];
    [viewer windowDidBecomeKey: nil];
  }
}

- (NSArray *)viewersForBaseNode:(FSNode *)node
{
  NSMutableArray *vwrs = [NSMutableArray array];
  int i;
  
  for (i = 0; i < [viewers count]; i++) {
    id viewer = [viewers objectAtIndex: i];
    
    if ([[viewer baseNode] isEqual: node]) {
      [vwrs addObject: viewer];
    }
  }
  
  return vwrs;
}

- (id)viewerOfType:(unsigned)type
      withBaseNode:(FSNode *)node
{
  int i;
  
  for (i = 0; i < [viewers count]; i++) {
    id viewer = [viewers objectAtIndex: i];

    if (([viewer vtype] == type) && [[viewer baseNode] isEqual: node]) {
      return viewer;
    }
  }
  
  return nil;
}

- (id)viewerOfType:(unsigned)type
       showingNode:(FSNode *)node
{
  int i;
  
  for (i = 0; i < [viewers count]; i++) {
    id viewer = [viewers objectAtIndex: i];

    if (([viewer vtype] == type) && [viewer isShowingNode: node]) {
      return viewer;
    }
  }
  
  return nil;
}

- (id)rootViewer
{
  int i;

  for (i = 0; i < [viewers count]; i++) {
    id viewer = [viewers objectAtIndex: i];

    if ([viewer isRootViewer]) {
      return viewer;
    }
  }

  return nil;
}

- (NSNumber *)nextRootViewerKey
{
  NSNumber *key = nil;
    
  if ([rootViewersKeys count]) {
    key = [rootViewersKeys objectAtIndex: 0];
    RETAIN (key);
    [rootViewersKeys removeObjectAtIndex: 0];
  }
  
  return TEST_AUTORELEASE (key);
}

- (int)typeOfViewerForNode:(FSNode *)node
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *path = [node path];
  NSString *dictPath = [path stringByAppendingPathComponent: @".gwdir"];
  NSString *prefsname = [NSString stringWithFormat: @"viewer_at_%@", path];
  NSDictionary *viewerPrefs = nil;

  if ([node isWritable] && ([fm fileExistsAtPath: dictPath])) {
    viewerPrefs = [NSDictionary dictionaryWithContentsOfFile: dictPath];
  }
  
  if (viewerPrefs == nil) {
    viewerPrefs = [[NSUserDefaults standardUserDefaults] objectForKey: prefsname];
  }
  
  if (viewerPrefs) {
    id entry = [viewerPrefs objectForKey: @"spatial"];
  
    if (entry) {
      return ([entry boolValue] ? SPATIAL : BROWSING);
    }
  }
  
  return BROWSING;
}

- (id)parentOfSpatialViewer:(id)aviewer
{
  if ([aviewer isSpatial]) {
    FSNode *node = [aviewer baseNode];

    if ([[node path] isEqual: path_separator()] == NO) {
      FSNode *parentNode = [FSNode nodeWithPath: [node parentPath]];

      return [self viewerOfType: SPATIAL showingNode: parentNode];
    }
  }
      
  return nil;  
}

- (void)viewerWillClose:(id)aviewer
{
  FSNode *node = [aviewer baseNode];
  NSString *path = [node path];
  NSArray *watchedNodes = [aviewer watchedNodes];
  NSNumber *key = [aviewer rootViewerKey];
  id parentViewer = [self parentOfSpatialViewer: aviewer];
  id desktopManager = [gworkspace desktopManager];  
  int i;

  if ([desktopManager isActive]) {
    [desktopManager deselectAllIcons];
  }
  
  if (parentViewer && ([parentViewer invalidated] == NO)) {
    [parentViewer setOpened: NO repOfNode: node];
  }
  
  if ([node isValid] == NO) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];  
    NSString *prefsname = [NSString stringWithFormat: @"viewer_at_%@", path]; 
    NSDictionary *vwrprefs = [defaults dictionaryForKey: prefsname];
    
    if (vwrprefs) {
      [defaults removeObjectForKey: prefsname];
    } 
    
    [NSWindow removeFrameUsingName: prefsname]; 
  }
  
  for (i = 0; i < [watchedNodes count]; i++) {
    [gworkspace removeWatcherForPath: [[watchedNodes objectAtIndex: i] path]];
  }

  if (aviewer == [historyWindow viewer]) {
    [self changeHistoryOwner: nil];
  }
      
  if (key) {
    [rootViewersKeys insertObject: key atIndex: 0];
  }

  [viewers removeObject: aviewer];
}

- (void)closeInvalidViewers:(NSArray *)vwrs
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  int i, j;

  for (i = 0; i < [vwrs count]; i++) {
    id viewer = [vwrs objectAtIndex: i];
    NSString *vpath = [[viewer baseNode] path];
    NSArray *watchedNodes = [viewer watchedNodes];
    id parentViewer = [self parentOfSpatialViewer: viewer];
    NSString *prefsname = [NSString stringWithFormat: @"viewer_at_%@", vpath]; 
    NSDictionary *vwrprefs = [defaults dictionaryForKey: prefsname];
    
    if (parentViewer && ([vwrs containsObject: parentViewer] == NO)) {
      [parentViewer setOpened: NO repOfNode: [viewer baseNode]];
    }

    if (vwrprefs) {
      [defaults removeObjectForKey: prefsname];
    } 

    [NSWindow removeFrameUsingName: prefsname]; 
    
    for (j = 0; j < [watchedNodes count]; j++) {
      [gworkspace removeWatcherForPath: [[watchedNodes objectAtIndex: j] path]];
    }
  }
      
  for (i = 0; i < [vwrs count]; i++) {
    id viewer = [vwrs objectAtIndex: i];
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow: 0.1];
    
    if (viewer == [historyWindow viewer]) {
      [self changeHistoryOwner: nil];
    }

    [viewer deactivate];
	  [[NSRunLoop currentRunLoop] runUntilDate: limit];
    [viewers removeObject: viewer];
  }
}


/* 
 * deselects the current selection in all the spatial viewers 
 * different from "aviewer"
 */
- (void)selectedSpatialViewerChanged:(id)aviewer
{
  if ((aviewer == nil) || ([aviewer isSpatial] && [[aviewer win] isKeyWindow])) {
    int i;
    
    orderingViewers = YES;
    
    for (i = 0; i < [viewers count]; i++) {
      id viewer = [viewers objectAtIndex: i];

      if ((viewer != aviewer) && [viewer isSpatial]) {
        [viewer unselectAllReps];
      }
    }
    
    if (aviewer != nil) {
      id desktopManager = [gworkspace desktopManager];
      
      if ([desktopManager isActive]) {
        [desktopManager deselectAllIcons];
      }
    }
    
    orderingViewers = NO;
  }
}

/* 
 * highligts the icon corresponding to the base node of "aviewer"
 * in its parent viewer
 */
- (void)synchronizeSelectionInParentOfViewer:(id)aviewer
{
  id parentViewer = [self parentOfSpatialViewer: aviewer];
    
  if (parentViewer) {
    [parentViewer setOpened: YES repOfNode: [aviewer baseNode]];
  }
}

/* 
 * When a "single node" viewer opens or a "multiple node" viewer shows 
 * a new column, avoids duplicate views in the other spatial viewers.
 */
- (void)viewer:(id)aviewer didShowNode:(FSNode *)node
{
  if ([aviewer isSpatial]) {
    int i;

    for (i = 0; i < [viewers count]; i++) {
      id viewer = [viewers objectAtIndex: i];

      if ((viewer != aviewer) && ([viewer isSpatial]) 
                        && [viewer isShowingNode: node]) {
        [viewer unloadFromNode: node];
        break;
      }
    }
  }  
}

- (void)selectionChanged:(NSArray *)selection
{
  if (orderingViewers == NO) {
    [gworkspace selectionChanged: selection];
  }
}

- (void)openSelectionInViewer:(id)viewer
                  closeSender:(BOOL)close
{
  NSArray *selreps = [[viewer nodeView] selectedReps];
  int i;
    
  for (i = 0; i < [selreps count]; i++) {
    FSNode *node = [[selreps objectAtIndex: i] node];
    
    if ([node hasValidPath]) {            
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
          [self newViewerOfType: [viewer vtype] 
                       showType: nil
                        forNode: node 
                  showSelection: NO
                 closeOldViewer: nil
                       forceNew: NO];
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
    
    } else {
      NSRunAlertPanel(NSLocalizedString(@"error", @""), 
          [NSString stringWithFormat: @"%@ %@!", 
                    NSLocalizedString(@"Can't open ", @""), [node name]],
                                        NSLocalizedString(@"OK", @""), 
                                        nil, 
                                        nil);                                     
    }
  }

  if (close) {
    [[viewer win] close]; 
  }
}

- (void)openAsFolderSelectionInViewer:(id)viewer
{
  NSArray *selnodes = [[viewer nodeView] selectedNodes];
  BOOL force = NO;
  int i;
  
  if ((selnodes == nil) || ([selnodes count] == 0)) {
    selnodes = [NSArray arrayWithObject: [[viewer nodeView] shownNode]];
    force = YES;
  }
  
  for (i = 0; i < [selnodes count]; i++) {
    FSNode *node = [selnodes objectAtIndex: i];
        
    if ([node isDirectory]) {
      [self newViewerOfType: [viewer vtype] 
                   showType: [viewer viewType]
                    forNode: node
              showSelection: NO
             closeOldViewer: nil
                   forceNew: force];
    } else if ([node isPlain]) {        
      [gworkspace openFile: [node path]];
    }
  }
}

- (void)openWithSelectionInViewer:(id)viewer
{
  [gworkspace openSelectedPathsWith];
}

- (void)sortTypeDidChange:(NSNotification *)notif
{
  NSString *notifPath = [notif object];
  int i;

  for (i = 0; i < [viewers count]; i++) {
    [[[viewers objectAtIndex: i] nodeView] sortTypeChangedAtPath: notifPath];
  }  
}

- (void)fileSystemWillChange:(NSNotification *)notif
{
  NSDictionary *opinfo = (NSDictionary *)[notif object];  
  NSMutableArray *viewersToClose = [NSMutableArray array];
  int i;

  for (i = 0; i < [viewers count]; i++) {
    id viewer = [viewers objectAtIndex: i];
    
    if ([viewer involvedByFileOperation: opinfo]) {
      if ([[viewer baseNode] willBeValidAfterFileOperation: opinfo] == NO) {
        [viewer invalidate];
        [viewersToClose addObject: viewer];
        
      } else { 
        [viewer nodeContentsWillChange: opinfo];
      }
    }
    
    if ([viewer invalidated] == NO) {
      id shelf = [viewer shelf];
      
      if (shelf) {
        [shelf nodeContentsWillChange: opinfo];
      }
    }
  }
  
  [self closeInvalidViewers: viewersToClose];
}

- (void)fileSystemDidChange:(NSNotification *)notif
{
  NSDictionary *opinfo = (NSDictionary *)[notif object];  
  NSMutableArray *viewersToClose = [NSMutableArray array];
  int i;
    
  for (i = 0; i < [viewers count]; i++) {
    id viewer = [viewers objectAtIndex: i];
    FSNode *vnode = [viewer baseNode];

    if (([vnode isValid] == NO) && ([viewer invalidated] == NO)) {
      [viewer invalidate];
      [viewersToClose addObject: viewer];
      
    } else {
      if ([viewer involvedByFileOperation: opinfo]) {
        [viewer nodeContentsDidChange: opinfo];
      }
    }
    
    if ([viewer invalidated] == NO) {
      id shelf = [viewer shelf];
      
      if (shelf) {
        [shelf nodeContentsDidChange: opinfo];
      }
    }
  }

  [self closeInvalidViewers: viewersToClose]; 
}

- (void)watcherNotification:(NSNotification *)notif
{
  NSDictionary *info = (NSDictionary *)[notif object];
  NSString *event = [info objectForKey: @"event"];
  NSString *path = [info objectForKey: @"path"];
  NSMutableArray *viewersToClose = [NSMutableArray array];
  int i, j;

  for (i = 0; i < [viewers count]; i++) {
    id viewer = [viewers objectAtIndex: i];
    FSNode *node = [viewer baseNode];
    NSArray *watchedNodes = [viewer watchedNodes];
    
    if ([event isEqual: @"GWWatchedPathDeleted"]) {  
      if (([[node path] isEqual: path]) || [node isSubnodeOfPath: path]) { 
        if ([viewer invalidated] == NO) {
          [viewer invalidate];
          [viewersToClose addObject: viewer];
        }
      }
    }
    
    for (j = 0; j < [watchedNodes count]; j++) {
      if ([[[watchedNodes objectAtIndex: j] path] isEqual: path]) {
        [viewer watchedPathChanged: info];
        break;
      }
    }
    
    if ([viewer invalidated] == NO) {
      id shelf = [viewer shelf];
      
      if (shelf) {
        [shelf watchedPathChanged: info];
      }
    }
  }

  [self closeInvalidViewers: viewersToClose]; 
}

- (void)thumbnailsDidChangeInPaths:(NSArray *)paths
{
  int i;  

  for (i = 0; i < [viewers count]; i++) {
    id viewer = [viewers objectAtIndex: i];
    
    if ([viewer invalidated] == NO) {
      if (paths == nil) {
        [viewer reloadFromNode: [viewer baseNode]];
      } else {
        int j;
      
        for (j = 0; j < [paths count]; j++) {
          NSString *path = [paths objectAtIndex: j];

          if ([viewer isShowingPath: path]) {
            FSNode *node = [FSNode nodeWithPath: path];
            
            [viewer reloadFromNode: node];
            
            if ([viewer respondsToSelector: @selector(updateShownSelection)]) {
              [viewer updateShownSelection];
            }
          }
        }
      }
    }
  }
}

- (void)hideDotsFileDidChange:(BOOL)hide
{
  NSMutableArray *viewersToClose = [NSMutableArray array];
  int i;  

  for (i = 0; i < [viewers count]; i++) {
    id viewer = [viewers objectAtIndex: i];
        
    if ([viewer invalidated] == NO) {
      if (hide) {
        if ([[[viewer baseNode] path] rangeOfString: @"."].location != NSNotFound) {
          [viewer invalidate];
          [viewersToClose addObject: viewer];
        }
      }
      
      if ([viewersToClose containsObject: viewer] == NO) {
        [viewer hideDotsFileChanged: hide];
      }
    }
  }

  [self closeInvalidViewers: viewersToClose]; 
}

- (void)hiddenFilesDidChange:(NSArray *)paths
{
  NSMutableArray *viewersToClose = [NSMutableArray array];
  int i, j;  

  for (i = 0; i < [viewers count]; i++) {
    id viewer = [viewers objectAtIndex: i];
    NSString *vwrpath = [[viewer baseNode] path];

    for (j = 0; j < [paths count]; j++) {
      NSString *path = [paths objectAtIndex: j];
      
      if (isSubpathOfPath(path, vwrpath) || [path isEqual: vwrpath]) {
        [viewer invalidate];
        [viewersToClose addObject: viewer];
      }
    }
    
    if ([viewersToClose containsObject: viewer] == NO) {
      [viewer hiddenFilesChanged: paths];
    }
  }

  [self closeInvalidViewers: viewersToClose]; 
}


- (BOOL)hasViewerWithWindow:(id)awindow
{
  int i;  

  for (i = 0; i < [viewers count]; i++) {
    id viewer = [viewers objectAtIndex: i];
    
    if ([viewer win] == awindow) {
      return YES;
    }
  }
  
  return NO;
}

- (id)viewerWithWindow:(id)awindow
{
  int i;  

  for (i = 0; i < [viewers count]; i++) {
    id viewer = [viewers objectAtIndex: i];
    
    if ([viewer win] == awindow) {
      return viewer;
    }
  }
  
  return nil;
}

- (NSArray *)viewerWindows
{
  NSMutableArray *wins = [NSMutableArray array];
  int i;  

  for (i = 0; i < [viewers count]; i++) {
    id viewer = [viewers objectAtIndex: i];
    
    if ([viewer invalidated] == NO) {
      [wins addObject: [viewer win]];
    }
  }

  return wins;
}

- (BOOL)orderingViewers
{
  return orderingViewers;
}

- (void)updateDefaults
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];  
  NSMutableArray *viewersInfo = [NSMutableArray array];
  int i;  

  for (i = 0; i < [viewers count]; i++) {
    id viewer = [viewers objectAtIndex: i];

    if ([viewer invalidated] == NO) {
      NSMutableDictionary *dict = [NSMutableDictionary dictionary];
      
      [dict setObject: [[viewer baseNode] path] forKey: @"path"];
      [dict setObject: [NSNumber numberWithInt: [viewer vtype]] 
               forKey: @"type"];
               
      [viewersInfo addObject: dict];
    }
  }
  
	[defaults setObject: viewersInfo forKey: @"viewersinfo"];
  
  [defaults setObject: rootViewersKeys forKey: @"root_viewers_keys"];
}

@end


@implementation GWViewersManager (History)

- (void)addNode:(FSNode *)node toHistoryOfViewer:(id)viewer
{
  if ([node isValid] && (settingHistoryPath == NO)) {
    BOOL spatial = [viewer isSpatial];
    NSMutableArray *history = (spatial ? spatialViewersHistory: [viewer history]);
    int position = (spatial ? spvHistoryPos : [viewer historyPosition]);
    id hisviewer = [historyWindow viewer];
    int cachemax = [gworkspace maxHistoryCache];
    int count;

    while ([history count] > cachemax) {
      [history removeObjectAtIndex: 0];
      if (position > 0) {
        position--;
      }
    }
    
    count = [history count];
    
	  if (position == (count - 1)) {
		  if ([[history lastObject] isEqual: node] == NO) {
			  [history insertObject: node atIndex: count];
		  }
      position = [history count] - 1;

    } else if (count > (position + 1)) {
      BOOL equalpos = [[history objectAtIndex: position] isEqual: node];
      BOOL equalnext = [[history objectAtIndex: position + 1] isEqual: node];
    
		  if (((equalpos == NO) && (equalnext == NO)) || equalnext) {
			  position++;
        
        if (equalnext == NO) {
			    [history insertObject: node atIndex: position];
        }
        
			  while ((position + 1) < [history count]) {
				  int last = [history count] - 1;
				  [history removeObjectAtIndex: last];
			  }
		  }
	  }

    [self removeDuplicatesInHistory: history position: &position];

    if (spatial) {
      spvHistoryPos = position;
    } else {
      [viewer setHistoryPosition: position];
    }

    if ((viewer == hisviewer) 
                || (spatial && (hisviewer && [hisviewer isSpatial]))) {
      [historyWindow setHistoryNodes: history position: position];
    }
  }
}

- (void)removeDuplicatesInHistory:(NSMutableArray *)history
                         position:(int *)pos
{
  int count = [history count];
  int i;
  
#define CHECK_POSITION(n) \
if (*pos >= i) *pos -= n; \
*pos = (*pos < 0) ? 0 : *pos; \
*pos = (*pos >= count) ? (count - 1) : *pos	
  
	for (i = 0; i < count; i++) {
		FSNode *node = [history objectAtIndex: i];
		
		if ([node isValid] == NO) {
			[history removeObjectAtIndex: i];
			CHECK_POSITION (1);		
			count--;
			i--;
		}
	}

	for (i = 0; i < count; i++) {
		FSNode *node = [history objectAtIndex: i];

		if (i < ([history count] - 1)) {
			FSNode *next = [history objectAtIndex: i + 1];
			
			if ([next isEqual: node]) {
				[history removeObjectAtIndex: i + 1];
				CHECK_POSITION (1);
				count--;
				i--;
			}
		}
	}
  
  count = [history count];
  
	if (count > 4) {
		FSNode *na[2], *nb[2];
		
		for (i = 0; i < count; i++) {
			if (i < (count - 3)) {
				na[0] = [history objectAtIndex: i];
				na[1] = [history objectAtIndex: i + 1];
				nb[0] = [history objectAtIndex: i + 2]; 
				nb[1] = [history objectAtIndex: i + 3];
		
				if (([na[0] isEqual: nb[0]]) && ([na[1] isEqual: nb[1]])) {
					[history removeObjectAtIndex: i + 3];
					[history removeObjectAtIndex: i + 2];
					CHECK_POSITION (2);
					count -= 2;
					i--;
				}
			}
		}
	}
    
  CHECK_POSITION (0);
}

- (void)changeHistoryOwner:(id)viewer
{
  if (viewer && (viewer != [historyWindow viewer])) {
    BOOL spatial = [viewer isSpatial];
    NSMutableArray *history = (spatial ? spatialViewersHistory: [viewer history]);
    int position = (spatial ? spvHistoryPos : [viewer historyPosition]);
  
    [historyWindow setHistoryNodes: history position: position];

  } else if (viewer == nil) {
    [historyWindow setHistoryNodes: nil];
  }

  [historyWindow setViewer: viewer];  
}

- (void)goToHistoryPosition:(int)pos 
                   ofViewer:(id)viewer
{
  if (viewer) {
    BOOL spatial = [viewer isSpatial];
    NSMutableArray *history = (spatial ? spatialViewersHistory: [viewer history]);
    int position = (spatial ? spvHistoryPos : [viewer historyPosition]);
 
    [self removeDuplicatesInHistory: history position: &position];

	  if ((pos >= 0) && (pos < [history count])) {
      [self setPosition: pos inHistory: history ofViewer: viewer];
    }
  }
}

- (void)goBackwardInHistoryOfViewer:(id)viewer
{
  BOOL spatial = [viewer isSpatial];
  NSMutableArray *history = (spatial ? spatialViewersHistory: [viewer history]);
  int position = (spatial ? spvHistoryPos : [viewer historyPosition]);

  [self removeDuplicatesInHistory: history position: &position];

  if ((position > 0) && (position < [history count])) {
    position--;
    [self setPosition: position inHistory: history ofViewer: viewer];
  }
}

- (void)goForwardInHistoryOfViewer:(id)viewer
{
  BOOL spatial = [viewer isSpatial];
  NSMutableArray *history = (spatial ? spatialViewersHistory: [viewer history]);
  int position = (spatial ? spvHistoryPos : [viewer historyPosition]);

  [self removeDuplicatesInHistory: history position: &position];
  
  if ((position >= 0) && (position < ([history count] - 1))) {
    position++;
    [self setPosition: position inHistory: history ofViewer: viewer];
  }
}

- (void)setPosition:(int)position
          inHistory:(NSMutableArray *)history
           ofViewer:(id)viewer
{
  FSNode *node = [history objectAtIndex: position];
  BOOL spatial = [viewer isSpatial];

  settingHistoryPath = YES;

  if (spatial == NO) {
    id nodeView = [viewer nodeView];
  
    if ([[viewer viewType] isEqual: @"Browser"] == NO) {
      [nodeView showContentsOfNode: node];
    } else {
      [nodeView showContentsOfNode: [FSNode nodeWithPath: [node parentPath]]];
      [nodeView selectRepsOfSubnodes: [NSArray arrayWithObject: node]];
    }

    if ([nodeView respondsToSelector: @selector(scrollSelectionToVisible)]) {
      [nodeView scrollSelectionToVisible];
    }
  } else {
    [self newViewerOfType: SPATIAL
                 showType: nil
                  forNode: node
            showSelection: YES
           closeOldViewer: nil
                 forceNew: NO];
  }

  if (spatial) {
    spvHistoryPos = position;
  } else {
    [viewer setHistoryPosition: position];
  }

  [historyWindow setHistoryPosition: position];

  settingHistoryPath = NO;
}

@end

