/*  -*-objc-*-
 *  Viewer.m: Implementation of the Viewer Class 
 *  of the GNUstep GWRemote application
 *
 *  Copyright (c) 2001 Enrico Sersale <enrico@imago.ro>
 *  
 *  Author: Enrico Sersale
 *  Date: August 2001
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "GNUstep.h"
#include "GWRemote.h"
#include "Viewer.h"
#include <GWorkspace/GWNotifications.h>
#include <GWorkspace/GWFunctions.h>
#include <GWorkspace/Browser2.h>

#define CHECKRECT(rct) \
if (rct.size.width < 0) rct.size.width = 0; \
if (rct.size.height < 0) rct.size.height = 0

@implementation Viewer

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  TEST_RELEASE (serverName);
  TEST_RELEASE (rootPath);
  TEST_RELEASE (lastPath);
  TEST_RELEASE (selectedPaths);
  TEST_RELEASE (watchedPaths);
  TEST_RELEASE (browser);
  [super dealloc];
}

- (id)init
{
	self = [super initWithFrame: NSZeroRect];
	
	if (self) {
		gwremote = [GWRemote gwremote];
    serverName = nil;
    browser = nil;
		rootPath = nil;
    lastPath = nil;
		selectedPaths = nil;
    watchedPaths = nil;
	}
	
	return self;
}

- (void)setRootPath:(NSString *)rpath 
         viewedPath:(NSString *)vpath 
          selection:(NSArray *)selection
           delegate:(id)adelegate
           viewApps:(BOOL)canview
             server:(NSString *)sname
{
	int colswidth, winwidth;
  unsigned int style = 0;
  
	[self setDelegate: adelegate];
  ASSIGN (serverName, sname);
  ASSIGN (rootPath, rpath);
	TEST_RELEASE (selectedPaths);
	selectedPaths = [[NSArray alloc] initWithObjects: rootPath, nil]; 
  viewsapps = canview;
  autoSynchronize = YES; 

	colswidth = [delegate browserColumnsWidth];
	resizeIncrement = colswidth;			
	winwidth = [delegate getWindowFrameWidth];			
  columns = (int)winwidth / resizeIncrement;      
  columnsWidth = (winwidth - 16) / columns;

  [self setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];

	if (browser != nil) {
		[browser removeFromSuperview];
		RELEASE (browser);
	}
  
  style = GWColumnIconMask;
  if (viewsapps) {
    style |= GWViewsPaksgesMask;
  }
  
	browser = [[Browser2 alloc] initWithBasePath: rootPath
		  												 visibleColumns: columns 
                                    styleMask: style
																  	 delegate: self
                                   remoteHost: serverName];

  [browser setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];    
  [self addSubview: browser];   

	[[NSNotificationCenter defaultCenter] removeObserver: self];

  [[NSNotificationCenter defaultCenter] addObserver: self 
                				selector: @selector(sortTypeDidChange:) 
                					  name: GWSortTypeDidChangeNotification
                					object: nil];

	if (watchedPaths != nil) {
		[self unsetWatchers];
		RELEASE (watchedPaths);
		watchedPaths = nil;
	}

  if (selection) {
	  [self setCurrentSelection: selection];
  } else {
    [self setCurrentSelection: [NSArray arrayWithObject: rootPath]];
  }
}

- (void)setCurrentSelection:(NSArray *)paths
{	
	[browser setPathAndSelection: paths];	
	[self setSelectedPaths: paths]; 
	[delegate updateTheInfoString];
}

- (void)setSelectedPaths:(NSArray *)paths
{
  NSString *newPath;
  NSArray *components;
  NSMutableArray *wpaths;
  NSString *s;
  BOOL isDir;
  int i, j;

	if ((paths == nil) || ([paths count] == 0) 
									|| ([paths isEqualToArray: selectedPaths])) {
		return;
	}
  
  ASSIGN (selectedPaths, paths);
	[delegate setTheSelectedPaths: paths];
    
  newPath = [paths objectAtIndex: 0]; 
            
  isDir = [gwremote server: serverName existsAndIsDirectoryFileAtPath: newPath];
  if ((isDir == NO) || ([paths count] > 1)) {
    newPath = [newPath stringByDeletingLastPathComponent];
  } else {
		if (([gwremote server: serverName isPakageAtPath: newPath]) 
                                                && (viewsapps == NO)) {
			newPath = [newPath stringByDeletingLastPathComponent];
		}
	}

  if (lastPath && [lastPath isEqual: newPath]) {
    return;
  } else {
    ASSIGN (lastPath, newPath);
  }

  components = [newPath pathComponents];  
  wpaths = [NSMutableArray arrayWithCapacity: 1];  
  s = [NSString string];        
   
  for (i = 0; i < [components count]; i++) {  
    s = [s stringByAppendingPathComponent: [components objectAtIndex: i]];
    [wpaths addObject: s];            
  }  
 
  if (watchedPaths == nil) {
    watchedPaths = [wpaths mutableCopy];  
    [self setWatchers];

  } else {  
    int count = [wpaths count];

    for (i = 0; i < [watchedPaths count]; i++) {
      NSString *s1, *s2;

      s1 = [watchedPaths objectAtIndex: i];

      if (count > i) {
        s2 = [wpaths objectAtIndex: i];  
      } else {
        i = count;
        break;
      }

      if ([s1 isEqualToString: s2] == NO) {
        break;
      }    
    }

    for (j = i; j < [watchedPaths count]; j++) {  
      [self unsetWatcherForPath: [watchedPaths objectAtIndex: j]];
    }

    for (j = i; j < [wpaths count]; j++) {  
      [self setWatcherForPath: [wpaths objectAtIndex: j]];
    }

    TEST_RELEASE (watchedPaths);
    watchedPaths = [wpaths mutableCopy];
  }
}

- (NSArray *)selectedPaths
{
  return selectedPaths;
}

- (NSString *)currentViewedPath
{  
  return [browser pathToLastColumn];
}

- (void)validateRootPathAfterOperation:(NSDictionary *)opdict
{
  if ([rootPath isEqualToString: fixPath(@"/", 0)] == YES) {
    return;

  } else {
    NSString *operation = [opdict objectForKey: @"operation"];
    NSString *source = [opdict objectForKey: @"source"];
    NSArray *files = [opdict objectForKey: @"files"];
    int i;
    
    if ([operation isEqual: NSWorkspaceMoveOperation] 
        || [operation isEqual: NSWorkspaceDestroyOperation]
        || [operation isEqual: GWorkspaceRenameOperation]
				|| [operation isEqual: NSWorkspaceRecycleOperation]
				|| [operation isEqual: GWorkspaceRecycleOutOperation]
				|| [operation isEqual: GWorkspaceEmptyRecyclerOperation]) { 

      if ([operation isEqual: GWorkspaceRenameOperation]) {      
        files = [NSArray arrayWithObject: [source lastPathComponent]]; 
        source = [source stringByDeletingLastPathComponent];            
      } 
      
      for (i = 0; i < [files count]; i++) {
        NSString *fpath = [source stringByAppendingPathComponent: [files objectAtIndex: i]];

        if (subPathOfPath(fpath, rootPath)
                        			|| [fpath isEqualToString: rootPath]) {  
          [self closeNicely];      
          break;
        }
      }
    }
  }  
}

- (void)fileSystemDidChange:(NSDictionary *)info
{
  NSString *path = [info objectForKey: @"path"];
  
  if ([watchedPaths containsObject: path] == NO) {
    return;    

  } else {
    NSString *event = [info objectForKey: @"event"];
				
    if ([event isEqual: GWWatchedDirectoryDeleted]) {
      if ((subPathOfPath(path, rootPath) == YES)
                            || ([path isEqualToString: rootPath] == YES)) {  
        [self closeNicely];      
        return;
      } else {
        NSString *s = [path stringByDeletingLastPathComponent];

        [self unsetWatcherForPath: path]; 
                                
        if ([browser isShowingPath: s]) {
          [browser reloadFromColumnWithPath: s]; 
        }
        
        return;
      }
    }

    if ([event isEqual: GWFileDeletedInWatchedDirectory]) {
      if (subPathOfPath(path, rootPath) == NO) {
      
        [browser removeCellsWithNames: [info objectForKey: @"files"]
                     inColumnWithPath: path];
        return;
      }
    }
       
    if ([event isEqual: GWFileCreatedInWatchedDirectory]) {  
      if (subPathOfPath(path, rootPath) == NO) {
      
        [browser addCellsWithNames: [info objectForKey: @"files"]
                  inColumnWithPath: path];
      }
    }
  } 
}

- (void)setWatchers
{
  int i;
  
  for (i = 0; i < [watchedPaths count]; i++) {
    [self setWatcherForPath: [watchedPaths objectAtIndex: i]];  
  }
}

- (void)setWatcherForPath:(NSString *)path
{
  [gwremote server: serverName addWatcherForPath: path];
}

- (void)unsetWatchers
{
  int i;

//  [[NSNotificationCenter defaultCenter] removeObserver: self 
//                name: GWFileWatcherFileDidChangeNotification object: nil];

  for (i = 0; i < [watchedPaths count]; i++) {
    [self unsetWatcherForPath: [watchedPaths objectAtIndex: i]];  
  }
}

- (void)unsetWatcherForPath:(NSString *)path
{
  [gwremote server: serverName removeWatcherForPath: path];
}

- (void)unsetWatchersFromPath:(NSString *)path
{
  unsigned index = [watchedPaths indexOfObject: path];

  if (index != NSNotFound) {
    int i;

    for (i = index; i < [watchedPaths count]; i++) {
      [self unsetWatcherForPath: [watchedPaths objectAtIndex: i]];
    }
  }
}

- (void)reSetWatchersFromPath:(NSString *)path
{
  unsigned index = [watchedPaths indexOfObject: path];

  if (index != NSNotFound) {
    int i, count;

    count = [watchedPaths count];
    
    for (i = index; i < count; i++) {
      NSString *wpath = [watchedPaths objectAtIndex: i];
            
      if ([gwremote server: serverName existsAndIsDirectoryFileAtPath: wpath]) {
        [self setWatcherForPath: wpath];
      } else {
        [watchedPaths removeObjectAtIndex: i];
        count--;
        i--;
      }  
    }
  }
}

- (void)sortTypeDidChange:(NSNotification *)notification
{
	NSString *notifPath = [notification object];
  
	if (notifPath != nil) {
  	[browser reloadColumnWithPath: notifPath];
	} else {	
		[self renewAll];
	}
}

- (NSSize)resizeIncrements
{
	return NSZeroSize;
}

- (void)setResizeIncrement:(int)increment
{
  resizeIncrement = increment;
}

- (void)setAutoSynchronize:(BOOL)value
{
  autoSynchronize = value;
}

- (NSPoint)locationOfIconForPath:(NSString *)path   
{
	if ([selectedPaths containsObject: path]) {
		NSPoint p = [browser positionOfLastIcon];
    
    if (NSEqualPoints(p, NSZeroPoint) == NO) {
		  return [self convertPoint: p toView: nil];
    }
    
    return NSZeroPoint;
	}
	
	return NSZeroPoint;
}

- (NSPoint)positionForSlidedImage
{
  NSPoint p = [browser positionForSlidedImage];
  
  if (NSEqualPoints(p, NSZeroPoint) == NO) {
		return [[self window] convertBaseToScreen: p];
  }
  
  return NSZeroPoint;  
}

- (id)viewerView
{
  return browser;
}

- (BOOL)viewsApps
{
  return viewsapps;
}

- (void)selectAll
{
  [browser selectAllInLastColumn];
}

- (void)renewAll
{
	NSArray *spats = RETAIN (selectedPaths);

	[self setRootPath: rootPath 
         viewedPath: nil
          selection: spats 
           delegate: delegate 
           viewApps: viewsapps
             server: serverName];

	[self setCurrentSelection: [NSArray arrayWithObject: rootPath]];
	[self resizeWithOldSuperviewSize: [self frame].size];
	[self setCurrentSelection: spats];
	[self resizeWithOldSuperviewSize: [self frame].size];
	RELEASE (spats);
}

- (void)closeNicely
{
  NSTimer *t;
  
  [self unsetWatchers]; 
  [[NSNotificationCenter defaultCenter] removeObserver: self];

  t = [NSTimer timerWithTimeInterval: 0.5 target: self 
          selector: @selector(close:) userInfo: nil repeats: NO];                                             
  [[NSRunLoop currentRunLoop] addTimer: t forMode: NSDefaultRunLoopMode];
}

- (void)close:(id)sender
{
  [[self window] performClose: nil];
}

- (id)delegate
{
  return delegate;
}

- (void)setDelegate:(id)anObject
{	
  delegate = anObject;
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldFrameSize
{
  NSRect r = [self frame];
  float w = r.size.width;
  float h = r.size.height; 
  NSRect brect = NSMakeRect(0, 0, w, h - 2);
  int col = columns;
  
  CHECKRECT (brect);
	[browser setFrame: brect];

  if (autoSynchronize == YES) {
    columns = (int)[[self window] frame].size.width / resizeIncrement;
  
    if (col != columns) {
      [self renewAll];
    }
  }
}

@end

//
// Browser Delegate Methods
//
@implementation Viewer (Browser2DelegateMethods)

- (void)currentSelectedPaths:(NSArray *)paths
{
  if (autoSynchronize == YES) {		
    [self setSelectedPaths: paths];
		[delegate updateTheInfoString];
  }
}

- (void)openSelectedPaths:(NSArray *)paths newViewer:(BOOL)isnew
{
	[self setSelectedPaths: paths];	
	[gwremote server: serverName openSelectedPaths: paths newViewer: isnew]; 
}

@end
