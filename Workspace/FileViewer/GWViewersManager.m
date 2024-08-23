/* GWViewersManager.m
 *  
 * Copyright (C) 2004-2016 Free Software Foundation, Inc.
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

#import <AppKit/AppKit.h>
#import "GWViewersManager.h"
#import "GWViewer.h"
#import "GWViewerWindow.h"
#import "History.h"
#import "FSNFunctions.h"
#import "GWorkspace.h"
#import "GWDesktopManager.h"


static GWViewersManager *vwrsmanager = nil;

@implementation GWViewersManager

+ (GWViewersManager *)viewersManager
{
  if (vwrsmanager == nil)
    {
      vwrsmanager = [[GWViewersManager alloc] init];
    }	
  return vwrsmanager;
}

- (void)dealloc
{
  [[NSDistributedNotificationCenter defaultCenter] removeObserver: self];
  [nc removeObserver: self];
  RELEASE (viewers);
  RELEASE (bviewerHelp);
    
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self)
    {
      NSNotificationCenter *wsnc;
      
      gworkspace = [GWorkspace gworkspace];
      helpManager = [NSHelpManager sharedHelpManager];
      wsnc = [[NSWorkspace sharedWorkspace] notificationCenter];
      ASSIGN (bviewerHelp, [gworkspace contextHelpFromName: @"BViewer.rtfd"]);
      
      viewers = [NSMutableArray new];
      orderingViewers = NO;
      
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

      // should perhaps volume notification be distributed?
      [wsnc addObserver: self 
               selector: @selector(newVolumeMounted:) 
                   name: NSWorkspaceDidMountNotification
                 object: nil];
      
      
      [wsnc addObserver: self 
               selector: @selector(mountedVolumeDidUnmount:) 
                   name: NSWorkspaceDidUnmountNotification
                 object: nil];
      
      [[FSNodeRep sharedInstance] setLabelWFactor: 9.0];
    }
  
  return self;
}


- (void)showViewers
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];  
  NSArray *viewersInfo = [defaults objectForKey: @"viewersinfo"];

  if (viewersInfo && [viewersInfo count])
    {
      NSUInteger i;
    
      for (i = 0; i < [viewersInfo count]; i++)
        {
          NSDictionary *dict = [viewersInfo objectAtIndex: i];
          NSString *path = [dict objectForKey: @"path"];
          FSNode *node = [FSNode nodeWithPath: path];
	  NSString *key = [dict objectForKey: @"key"];
    
          if (node && [node isValid])
            {
              [self viewerForNode: node
                         showType: 0
                    showSelection: YES
                         forceNew: YES
		          withKey: key];
            }
        }

    }
  else
    {
      [self showRootViewer];
  }
}

- (id)showRootViewer
{
  NSString *path = path_separator();
  FSNode *node = [FSNode nodeWithPath: path];
  id viewer = [self rootViewer];
  
  if (viewer == nil)
    {
  
      viewer = [self viewerForNode: node
		     showType: 0
                     showSelection: YES
		     forceNew: NO
		     withKey: nil];
    }
  else
    {
      if ([[viewer win] isVisible] == NO)
        {
          [viewer activate];
        }
      else
        {
          viewer = [self viewerForNode: node
                              showType: 0
                         showSelection: YES
                              forceNew: YES
			       withKey: nil];
        }
    }
  
  return viewer;
}

- (void)selectRepOfNode:(FSNode *)node
   inViewerWithBaseNode:(FSNode *)base
{
  BOOL inRootViewer = [[base path] isEqual: path_separator()];
  NSArray *selection = [NSArray arrayWithObject: node];
  id viewer = nil;
  
  if ([base isEqual: node] || ([node isSubnodeOfNode: base] == NO))
    {
      selection = nil;      
    }
  
  if (inRootViewer)
    {  
      viewer = [self rootViewer];
    
      if (viewer == nil)
        {
          viewer = [self showRootViewer];
        }  
    }
  else
    {
      viewer = [self viewerForNode : base
                           showType: 0
                      showSelection: NO
                           forceNew: NO
		            withKey: nil];
    } 
  
  if (selection)
    {
      [[viewer nodeView] selectRepsOfSubnodes: selection];  
    }
}

- (id)viewerForNode:(FSNode *)node
          showType:(GWViewType)stype
     showSelection:(BOOL)showsel
          forceNew:(BOOL)force
	   withKey:(NSString *)key
{
  id viewer = [self viewerWithBaseNode: node];
    
  if ((viewer == nil) || (force))
    {
      Class c = [GWViewer class];
      GWViewerWindow *win = [GWViewerWindow new];
      
      [win setReleasedWhenClosed: NO];
      
      viewer = [[c alloc] initForNode: node 
			     inWindow: win 
			     showType: stype
			showSelection: showsel
			      withKey: key]; 
      
      [viewers addObject: viewer];
      RELEASE (win);
      RELEASE (viewer);
    } 
  
  [viewer activate];
  

  [helpManager setContextHelp: bviewerHelp
                    forObject: [[viewer win] contentView]];
       
  return viewer;
}

- (NSArray *)viewersForBaseNode:(FSNode *)node
{
  NSMutableArray *vwrs = [NSMutableArray array];
  NSUInteger i;
  
  for (i = 0; i < [viewers count]; i++) {
    id viewer = [viewers objectAtIndex: i];
    
    if ([[viewer baseNode] isEqual: node]) {
      [vwrs addObject: viewer];
    }
  }
  
  return vwrs;
}

- (id)viewerWithBaseNode:(FSNode *)node
{
  NSUInteger i;
  
  for (i = 0; i < [viewers count]; i++)
    {
      id viewer = [viewers objectAtIndex: i];

      if ([[viewer baseNode] isEqual: node])
        {
          return viewer;
        }
    }
  
  return nil;
}

- (id)viewerShowingNode:(FSNode *)node
{
  NSUInteger i;
  
  for (i = 0; i < [viewers count]; i++)
    {
      id viewer = [viewers objectAtIndex: i];

      if ([viewer isShowingNode: node])
        {
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

    if ([viewer isFirstRootViewer]) {
      return viewer;
    }
  }

  return nil;
}


- (void)viewerWillClose:(id)aviewer
{
  FSNode *node = [aviewer baseNode];
  NSArray *watchedNodes = [aviewer watchedNodes];
  NSUInteger i;

  
  if ([node isValid] == NO)
    {
      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];  
      NSString *prefsname;
      NSDictionary *vwrprefs;

      prefsname = [aviewer defaultsKey];

      vwrprefs = [defaults dictionaryForKey: prefsname];
      if (vwrprefs)
        {
          [defaults removeObjectForKey: prefsname];
        } 
    
      [NSWindow removeFrameUsingName: prefsname]; 
    }
  
  for (i = 0; i < [watchedNodes count]; i++)
    [gworkspace removeWatcherForPath: [[watchedNodes objectAtIndex: i] path]];

  if (aviewer == [historyWindow viewer])
    [self changeHistoryOwner: nil];

  [helpManager removeContextHelpForObject: [[aviewer win] contentView]];
  [viewers removeObject: aviewer];
}

- (void)closeInvalidViewers:(NSArray *)vwrs
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSUInteger i, j;

  for (i = 0; i < [vwrs count]; i++)
    {
      id viewer = [vwrs objectAtIndex: i];
      NSString *vpath = [[viewer baseNode] path];
      NSArray *watchedNodes = [viewer watchedNodes];
      NSString *prefsname = [NSString stringWithFormat: @"viewer_at_%@", vpath]; 
      NSDictionary *vwrprefs = [defaults dictionaryForKey: prefsname];
    

      if (vwrprefs)
        [defaults removeObjectForKey: prefsname];

      [NSWindow removeFrameUsingName: prefsname]; 
    
      for (j = 0; j < [watchedNodes count]; j++)
        [gworkspace removeWatcherForPath: [[watchedNodes objectAtIndex: j] path]];
    }
      
  for (i = 0; i < [vwrs count]; i++)
    {
      id viewer = [vwrs objectAtIndex: i];
      NSDate *limit = [NSDate dateWithTimeIntervalSinceNow: 0.1];
    
      if (viewer == [historyWindow viewer])
        [self changeHistoryOwner: nil];

      [viewer deactivate];
      [[NSRunLoop currentRunLoop] runUntilDate: limit];
      [helpManager removeContextHelpForObject: [[viewer win] contentView]];
      [viewers removeObject: viewer];
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
  NSUInteger count = [selreps count];
  NSUInteger i;
    
  if (count > MAX_FILES_TO_OPEN_DIALOG)
    {
      NSString *msg1 = NSLocalizedString(@"Are you sure you want to open", @"");
      NSString *msg2 = NSLocalizedString(@"items?", @"");

      if (NSRunAlertPanel(nil,
                          [NSString stringWithFormat: @"%@ %"PRIuPTR" %@", msg1, count, msg2],
                          NSLocalizedString(@"Cancel", @""),
                          NSLocalizedString(@"Yes", @""),
                          nil))
        {
          return;
        }
    }
    
  for (i = 0; i < count; i++)
    {
      FSNode *node = [[selreps objectAtIndex: i] node];
      
      if ([node hasValidPath])
        {            
          NS_DURING
            {
              if ([node isDirectory])
                {
                  if ([node isPackage])
                    {    
                      if ([node isApplication] == NO)
                        [gworkspace openFile: [node path]];
                      else
                        [[NSWorkspace sharedWorkspace] launchApplication: [node path]];
                    }
                  else
                    {
                      [self viewerForNode: node 
                                 showType: 0
                            showSelection: NO
                                 forceNew: NO
			          withKey: nil];
                    } 
                }
              else if ([node isPlain])
                {        
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
      else
        {
          NSRunAlertPanel(NSLocalizedString(@"error", @""), 
                          [NSString stringWithFormat: @"%@ %@!", 
                                    NSLocalizedString(@"Can't open ", @""), [node name]],
                          NSLocalizedString(@"OK", @""), 
                          nil, 
                          nil);                                     
        }
    }
  
  if (close)
    {
      [[viewer win] close]; 
    }
}

- (void)openAsFolderSelectionInViewer:(id)viewer
{
  NSArray *selnodes = [[viewer nodeView] selectedNodes];
  BOOL force = NO;
  NSUInteger i;
  
  if ((selnodes == nil) || ([selnodes count] == 0))
    {
      selnodes = [NSArray arrayWithObject: [[viewer nodeView] shownNode]];
      force = YES;
    }
  
  for (i = 0; i < [selnodes count]; i++)
    {
      FSNode *node = [selnodes objectAtIndex: i];
        
      if ([node isDirectory])
        {
          [self viewerForNode: node
                     showType: [viewer viewType]
                showSelection: NO
                     forceNew: force
		      withKey: nil];
        }
      else if ([node isPlain])
        {        
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
  NSUInteger i;  

  for (i = 0; i < [viewers count]; i++) {
    id viewer = [viewers objectAtIndex: i];
    
    if ([viewer invalidated] == NO) {
      if (paths == nil) {
        [viewer reloadFromNode: [viewer baseNode]];
      } else {
        NSUInteger j;
      
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
  NSUInteger i;  

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
  NSUInteger i, j;  

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
  NSUInteger i;  

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
  NSUInteger i;  

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
  NSUInteger i;  

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

- (void)updateDesktop
{
  id desktopManager = [gworkspace desktopManager];  

  if ([desktopManager isActive]) {
    [desktopManager deselectAllIcons];
  }
}

- (void)updateDefaults
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];  
  NSMutableArray *viewersInfo = [NSMutableArray array];
  NSUInteger i;  

  for (i = 0; i < [viewers count]; i++)
    {
      id viewer = [viewers objectAtIndex: i];

      if ([viewer invalidated] == NO)
        {
          NSMutableDictionary *dict = [NSMutableDictionary dictionary];
      
          [dict setObject: [[viewer baseNode] path] forKey: @"path"];

          if ([viewer defaultsKey])
            [dict setObject: [viewer defaultsKey] forKey: @"key"];
               
          [viewersInfo addObject: dict];
        }
    }
  
  [defaults setObject: viewersInfo forKey: @"viewersinfo"];
}

- (void)newVolumeMounted:(NSNotification *)notif
{
  NSDictionary *dict = [notif userInfo];  
  NSString *volpath = [dict objectForKey: @"NSDevicePath"];
  FSNodeRep *fnr = [FSNodeRep sharedInstance];

  if (volpath)
    [fnr addVolumeAt:volpath];
  else
    NSLog(@"newVolumeMounted notification received with empty NSDevicePath");
}

- (void)mountedVolumeDidUnmount:(NSNotification *)notif
{
  NSDictionary *dict = [notif userInfo];  
  NSString *volpath = [dict objectForKey: @"NSDevicePath"];
  FSNodeRep *fnr = [FSNodeRep sharedInstance];

  if (volpath)
    [fnr removeVolumeAt:volpath];
  else
    NSLog(@"mountedVolumeDidUnmount notification received with empty NSDevicePath");
}

@end


@implementation GWViewersManager (History)

- (void)addNode:(FSNode *)node toHistoryOfViewer:(id)viewer
{
  if ([node isValid] && (settingHistoryPath == NO))
    {
      NSMutableArray *history = [viewer history];
      int position = [viewer historyPosition];
      id hisviewer = [historyWindow viewer];
      int cachemax = [gworkspace maxHistoryCache];
      int count;
      
      while ([history count] > cachemax)
        {
          [history removeObjectAtIndex: 0];
          if (position > 0) {
            position--;
          }
        }
    
      count = [history count];
      
      if (position == (count - 1))
        {
          if ([[history lastObject] isEqual: node] == NO)
            {
              [history insertObject: node atIndex: count];
            }
          position = [history count] - 1;
          
        }
      else if (count > (position + 1))
        {
          BOOL equalpos = [[history objectAtIndex: position] isEqual: node];
          BOOL equalnext = [[history objectAtIndex: position + 1] isEqual: node];
          
          if (((equalpos == NO) && (equalnext == NO)) || equalnext)
            {
              position++;
              
              if (equalnext == NO)
                {
                  [history insertObject: node atIndex: position];
                }
              
              while ((position + 1) < [history count])
                {
                  int last = [history count] - 1;
                  [history removeObjectAtIndex: last];
                }
            }
        }
      
      [self removeDuplicatesInHistory: history position: &position];
      
      [viewer setHistoryPosition: position];
      
      if (viewer == hisviewer) 
        {
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
  if (viewer && (viewer != [historyWindow viewer]))
    {
      NSMutableArray *history = [viewer history];
      int position = [viewer historyPosition];
  
      [historyWindow setHistoryNodes: history position: position];

    } else if (viewer == nil)
    {
      [historyWindow setHistoryNodes: nil];
    }

  [historyWindow setViewer: viewer];  
}

- (void)goToHistoryPosition:(int)pos 
                   ofViewer:(id)viewer
{
  if (viewer)
    {
      NSMutableArray *history = [viewer history];
      int position = [viewer historyPosition];
 
      [self removeDuplicatesInHistory: history position: &position];

      if ((pos >= 0) && (pos < [history count]))
        {
          [self setPosition: pos inHistory: history ofViewer: viewer];
        }
    }
}

- (void)goBackwardInHistoryOfViewer:(id)viewer
{
  NSMutableArray *history = [viewer history];
  int position = [viewer historyPosition];

  [self removeDuplicatesInHistory: history position: &position];

  if ((position > 0) && (position < [history count]))
    {
      position--;
      [self setPosition: position inHistory: history ofViewer: viewer];
    }
}

- (void)goForwardInHistoryOfViewer:(id)viewer
{
  NSMutableArray *history = [viewer history];
  int position = [viewer historyPosition];

  [self removeDuplicatesInHistory: history position: &position];
  
  if ((position >= 0) && (position < ([history count] - 1)))
    {
      position++;
      [self setPosition: position inHistory: history ofViewer: viewer];
    }
}

- (void)setPosition:(int)position
          inHistory:(NSMutableArray *)history
           ofViewer:(id)viewer
{
  FSNode *node = [history objectAtIndex: position];
  id nodeView = [viewer nodeView];
  
  settingHistoryPath = YES;
  
  if ([viewer viewType] != GWViewTypeBrowser)
    {
      [nodeView showContentsOfNode: node];
    }
  else
    {
      [nodeView showContentsOfNode: [FSNode nodeWithPath: [node parentPath]]];
      [nodeView selectRepsOfSubnodes: [NSArray arrayWithObject: node]];
    }

  if ([nodeView respondsToSelector: @selector(scrollSelectionToVisible)])
    [nodeView scrollSelectionToVisible];

  [viewer setHistoryPosition: position];

  [historyWindow setHistoryPosition: position];

  settingHistoryPath = NO;
}

@end

