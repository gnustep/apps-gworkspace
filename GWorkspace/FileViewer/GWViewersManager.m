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
#include "FSNodeRep.h"
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

- (id)newViewerForPath:(NSString *)path
        closeOldViewer:(id)oldvwr
{
  id viewer = [self viewerWithBasePath: path];
  NSArray *reps;
  int i;
  
  if (viewer == nil) {
    FSNode *node = [FSNode nodeWithRelativePath: path parent: nil];
  
    viewer = [[GWSpatialViewer alloc] initForNode: node];    
    [viewers addObject: viewer];
    RELEASE (viewer);
  } 

  if (oldvwr) {
    [[oldvwr win] close]; 
  }
  
  [viewer activate];
      
  reps = [[viewer nodeView] reps];  
    
  for (i = 0; i < [reps count]; i++) {
    id rep = [reps objectAtIndex: i];  
    
    if ([self viewerForPath: [[rep node] path]]) {
      [rep setOpened: YES];
    }
  }
     
  return viewer;
}

- (id)viewerWithBasePath:(NSString *)path
{
  int i;
  
  for (i = 0; i < [viewers count]; i++) {
    id viewer = [viewers objectAtIndex: i];
    FSNode *node = [viewer shownNode];
    
    if ([[node path] isEqual: path]) {
      return viewer;
    }
  }
  
  return nil;
}

- (id)viewerForPath:(NSString *)path
{
  int i;
  
  for (i = 0; i < [viewers count]; i++) {
    id viewer = [viewers objectAtIndex: i];
    
    if ([[viewer nodeView] isShowingPath: path]) {
      return viewer;
    }
  }
  
  return nil;
}

- (id)parentOfViewer:(id)aviewer
{
  FSNode *node = [aviewer shownNode];

  if ([[node path] isEqual: path_separator()] == NO) {
    return [self viewerForPath: [node parentPath]];
  }
    
  return nil;  
}


- (void)viewerWillClose:(id)aviewer
{
  FSNode *node = [aviewer shownNode];
  NSString *path = [node path];
  NSArray *watchedNodes = [aviewer watchedNodes];
  id parentViewer = [self parentOfViewer: aviewer];
  int i;
  
  if (parentViewer && ([parentViewer invalidated] == NO)) {
    [parentViewer setOpened: NO repOfPath: path];
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
    id parentViewer = [self parentOfViewer: viewer];
    NSString *prefsname = [NSString stringWithFormat: @"viewer_at_%@", vpath]; 
    NSDictionary *vwrprefs = [defaults dictionaryForKey: prefsname];
    
    if (parentViewer && ([vwrs containsObject: parentViewer] == NO)) {
      [parentViewer setOpened: NO repOfPath: vpath];
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

- (void)closeViewerWithBasePath:(NSString *)path
{
  id viewer = [self viewerWithBasePath: path];
  
  if (viewer) {
    [[viewer win] close]; 
  } 
}

- (void)viewerSelected:(id)aviewer
{
  id parentViewer = [self parentOfViewer: aviewer];
  
  [self unselectOtherViewers: aviewer];
  
  if (parentViewer) {
    [parentViewer setOpened: YES repOfPath: [[aviewer shownNode] path]];
  }
}

- (void)unselectOtherViewers:(id)aviewer
{
  int i;
  
  for (i = 0; i < [viewers count]; i++) {
    id viewer = [viewers objectAtIndex: i];

    if (viewer != aviewer) {
      [viewer unselectAllReps];
    }
  }  
}


- (void)viewer:(id)aviewer didShowPath:(NSString *)apath
{
  int i;
  
  for (i = 0; i < [viewers count]; i++) {
    id viewer = [viewers objectAtIndex: i];
    
    if ([[viewer nodeView] isShowingPath: apath] && (viewer != aviewer)) {
      [viewer unloadFromPath: apath];
      break;
    }
  }
}

- (void)selectionDidChangeInViewer:(id)aviewer
{
  [self unselectOtherViewers: aviewer];
}

- (void)selectionChanged:(NSArray *)selection
{
  [gworkspace selectionChanged: selection];
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
        [self newViewerForPath: path closeOldViewer: nil]; 
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
      [self newViewerForPath: [node path] closeOldViewer: nil]; 
    } else if ([node isPlain]) {        
      [gworkspace openFile: [node path]];
    }
  }
  
  
    {
      FSNode *node = [FSNode nodeWithRelativePath: @"/home/enrico/Butt/GNUstep/CopyPix/CartaNuova/CooopyPix" 
                                           parent: nil];
      GWViewer *gwv = [[GWViewer alloc] initForNode: node];
      [gwv activate];
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






