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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <AppKit/AppKit.h>
#include "GWViewersManager.h"
#include "GWViewer.h"
#include "GWSpatialViewer.h"
#include "GWViewerWindow.h"
#include "FSNFunctions.h"
#include "GWorkspace.h"

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
    
	[super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
    viewers = [NSMutableArray new];
    gworkspace = [GWorkspace gworkspace];
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
    
    [FSNodeRep setLabelWFactor: 9.0];
    [FSNodeRep setUseThumbnails: YES];
  }
  
  return self;
}

- (id)newViewerOfType:(unsigned)vtype
              forNode:(FSNode *)node
       closeOldViewer:(id)oldvwr
{
  id viewer = [self viewerOfType: vtype withBaseNode: node];
  int i;
    
  if (viewer == nil) {
    Class c = (vtype == SPATIAL) ? [GWSpatialViewer class] : [GWViewer class];
    GWViewerWindow *win;
    unsigned int style;

    if ([[node path] isEqual: path_separator()]
                  && ([[self viewersForBaseNode: node] count] == 0)) {
      style = NSTitledWindowMask | NSMiniaturizableWindowMask 
                                            | NSResizableWindowMask;
    } else {
      style = NSTitledWindowMask | NSClosableWindowMask 
				           | NSMiniaturizableWindowMask | NSResizableWindowMask;
    }
    
    win = [[GWViewerWindow alloc] initWithContentRect: NSZeroRect
                                            styleMask: style
                                              backing: NSBackingStoreBuffered 
                                                defer: NO];
    [win setReleasedWhenClosed: NO];
    viewer = [[c alloc] initForNode: node inWindow: win];   
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
    FSNode *node = RETAIN ([aviewer shownNode]);
    id viewer;
    
    [aviewer windowWillClose: nil];
    
    viewer = [[c alloc] initForNode: node inWindow: win];   
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
    
    if ([[viewer shownNode] isEqual: node]) {
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

    if (([viewer vtype] == type) && [[viewer shownNode] isEqual: node]) {
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

    if (([viewer vtype] == type) && [[viewer nodeView] isShowingNode: node]) {
      return viewer;
    }
  }
  
  return nil;
}

- (id)parentOfSpatialViewer:(id)aviewer
{
  if ([aviewer isSpatial]) {
    FSNode *node = [aviewer shownNode];

    if ([[node path] isEqual: path_separator()] == NO) {
      FSNode *parentNode = [node parent];

      if (parentNode == nil) {
        parentNode = [FSNode nodeWithRelativePath: [node parentPath] parent: nil];
      }

      return [self viewerOfType: SPATIAL showingNode: parentNode];
    }
  }
      
  return nil;  
}


- (void)viewerWillClose:(id)aviewer
{
  FSNode *node = [aviewer shownNode];
  NSString *path = [node path];
  NSArray *watchedNodes = [aviewer watchedNodes];
  id parentViewer = [self parentOfSpatialViewer: aviewer];
  int i;
  
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
    
  [viewers removeObject: aviewer];
}

- (void)closeInvalidViewers:(NSArray *)vwrs
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  int i, j;

  for (i = 0; i < [vwrs count]; i++) {
    id viewer = [vwrs objectAtIndex: i];
    NSString *vpath = [[viewer shownNode] path];
    NSArray *watchedNodes = [viewer watchedNodes];
    id parentViewer = [self parentOfSpatialViewer: viewer];
    NSString *prefsname = [NSString stringWithFormat: @"viewer_at_%@", vpath]; 
    NSDictionary *vwrprefs = [defaults dictionaryForKey: prefsname];
    
    if (parentViewer && ([vwrs containsObject: parentViewer] == NO)) {
      [parentViewer setOpened: NO repOfNode: [viewer shownNode]];
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
  if ([aviewer isSpatial] && [[aviewer win] isKeyWindow]) {
    int i;
    
    orderingViewers = YES;
    
    for (i = 0; i < [viewers count]; i++) {
      id viewer = [viewers objectAtIndex: i];

      if ((viewer != aviewer) && [viewer isSpatial]) {
        [viewer unselectAllReps];
      }
    }
    
    orderingViewers = NO;
  }
}

/* 
 * highligts the icon corresponding to the base node of "aviewer"
 * in its parent viewer
 */
- (void)reflectInParentSelectedViewer:(id)aviewer
{
  id parentViewer = [self parentOfSpatialViewer: aviewer];
    
  if (parentViewer) {
    [parentViewer setOpened: YES repOfNode: [aviewer shownNode]];
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
                         && [[viewer nodeView] isShowingNode: node]) {
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
    NSString *path = [node path];
        
    if ([node isDirectory]) {
      if ([node isPackage]) {    
        if ([node isApplication] == NO) {
          [gworkspace openFile: path];
        } else {
          [[NSWorkspace sharedWorkspace] launchApplication: path];
        }
      } else {
        [self newViewerOfType: [viewer vtype] 
                      forNode: node 
               closeOldViewer: nil];
      } 
    } else if ([node isPlain]) {        
      [gworkspace openFile: path];
    }
  }

  if (close) {
    [[viewer win] close]; 
  }
}

- (void)openAsFolderSelectionInViewer:(id)viewer
{
  NSArray *selnodes = [[viewer nodeView] selectedNodes];
  int i;
    
  for (i = 0; i < [selnodes count]; i++) {
    FSNode *node = [selnodes objectAtIndex: i];
        
    if ([node isDirectory]) {
      [self newViewerOfType: [viewer vtype] 
                    forNode: node
             closeOldViewer: nil];
    } else if ([node isPlain]) {        
      [gworkspace openFile: [node path]];
    }
  }
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
      if ([[viewer shownNode] willBeValidAfterFileOperation: opinfo] == NO) {
        [viewer invalidate];
        [viewersToClose addObject: viewer];
        
      } else { 
        [viewer nodeContentsWillChange: opinfo];
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
    FSNode *vnode = [viewer shownNode];

    if (([vnode isValid] == NO) && ([viewer invalidated] == NO)) {
      [viewer invalidate];
      [viewersToClose addObject: viewer];
      
    } else {
      if ([viewer involvedByFileOperation: opinfo]) {
        [viewer nodeContentsDidChange: opinfo];
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
    FSNode *node = [viewer shownNode];
    NSArray *watchedNodes = [viewer watchedNodes];
    
    if ([event isEqual: @"GWWatchedDirectoryDeleted"]) {  
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
  }

  [self closeInvalidViewers: viewersToClose]; 
}

@end






