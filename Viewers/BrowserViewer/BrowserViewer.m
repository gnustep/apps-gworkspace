/* BrowserViewer.m
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
  #ifdef GNUSTEP 
#include "GWLib.h"
#include "GWFunctions.h"
#include "GWNotifications.h"
#include "GWProtocol.h"
#include "Browser2.h"
  #else
#include <GWorkspace/GWLib.h>
#include <GWorkspace/GWFunctions.h>
#include <GWorkspace/GWNotifications.h>
#include <GWorkspace/GWProtocol.h>
#include <GWorkspace/Browser2.h>
  #endif
#include "GNUstep.h"
#include "BrowserViewer.h"
#include "BrowserViewerPref.h"

#define CHECKRECT(rct) \
if (rct.size.width < 0) rct.size.width = 0; \
if (rct.size.height < 0) rct.size.height = 0

@implementation BrowserViewer

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  TEST_RELEASE (rootPath);
  TEST_RELEASE (lastPath);
  TEST_RELEASE (selectedPaths);
  TEST_RELEASE (watchedPaths);
  TEST_RELEASE (browser);
  TEST_RELEASE (prefs);
  [super dealloc];
}

- (id)init
{
	self = [super initWithFrame: NSZeroRect];
	
	if (self) {
    usesShelf = YES;
    cellsIcons = NO;
    browser = nil;
		rootPath = nil;
    lastPath = nil;
		selectedPaths = nil;
    watchedPaths = nil;
    prefs = nil;
    fm = [NSFileManager defaultManager];
	}
	
	return self;
}

//
// NSCopying 
//
- (id)copyWithZone:(NSZone *)zone
{
  BrowserViewer *vwr = [[BrowserViewer alloc] init]; 	
  return vwr;
}

//
// ViewersProtocol
//
- (void)setRootPath:(NSString *)rpath 
         viewedPath:(NSString *)vpath 
          selection:(NSArray *)selection
           delegate:(id)adelegate
           viewApps:(BOOL)canview
{
	int colswidth, winwidth;
  unsigned int style = 0;
  
  [self checkUsesShelf];
  [self checkUsesCellsIcons];
  
	[self setDelegate: adelegate];
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
  if (cellsIcons) {
    style |= GWIconCellsMask;
  }
  
	browser = [[Browser2 alloc] initWithBasePath: rootPath
		  													visibleColumns: columns 
                                     styleMask: style
																  	  delegate: self];
					 
  [browser setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];    
  [self addSubview: browser];   

	[[NSNotificationCenter defaultCenter] removeObserver: self];

  [[NSNotificationCenter defaultCenter] addObserver: self 
                				selector: @selector(fileSystemWillChange:) 
                					  name: GWFileSystemWillChangeNotification
                					object: nil];

  [[NSNotificationCenter defaultCenter] addObserver: self 
                				selector: @selector(fileSystemDidChange:) 
                					  name: GWFileSystemDidChangeNotification
                					object: nil];
                          
  [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
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
    [delegate addPathToHistory: selection];
  } else {
    [self setCurrentSelection: [NSArray arrayWithObject: rootPath]];
    [delegate addPathToHistory: [NSArray arrayWithObject: rootPath]];
  }
}

- (NSString *)menuName
{
	return @"Browser";
}

- (NSString *)shortCut
{
	return @"b";
}

- (BOOL)usesShelf
{
	return usesShelf;
}

- (NSSize)resizeIncrements
{
	return NSZeroSize;
}

- (NSImage *)miniicon
{
	NSBundle *bundle = [NSBundle bundleForClass: [self class]];
	NSString *imgpath = [bundle pathForResource: @"miniwindow" ofType: @"tiff"];
	NSImage *img = [[NSImage alloc] initWithContentsOfFile: imgpath];	
	return AUTORELEASE (img);
}

- (BOOL)hasPreferences
{
  return YES;
}

- (id)prefController
{
  if (prefs == nil) {
    prefs = [[BrowserViewerPref alloc] init];
  }

  return prefs;
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
  [fm fileExistsAtPath: newPath isDirectory: &isDir];
  if ((isDir == NO) || ([paths count] > 1)) {
    newPath = [newPath stringByDeletingLastPathComponent];
  } else {
		if (([GWLib isPakageAtPath: newPath]) && (viewsapps == NO)) {
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

- (void)setCurrentSelection:(NSArray *)paths
{	
	[browser setPathAndSelection: paths];	
	[self setSelectedPaths: paths]; 
	[delegate updateTheInfoString];
}

- (NSPoint)positionForSlidedImage
{
  NSPoint p = [browser positionForSlidedImage];
  
  if (NSEqualPoints(p, NSZeroPoint) == NO) {
		return [[self window] convertBaseToScreen: p];
  }
  
  return NSZeroPoint;  
}

- (void)selectAll
{
  [browser selectAllInLastColumn];
}

- (NSArray *)selectedPaths
{
  return selectedPaths;
}

- (NSString *)rootPath
{
  return rootPath;
}

- (NSString *)currentViewedPath
{  
  return [browser pathToLastColumn];
}

- (void)checkRootPathAfterHidingOfPaths:(NSArray *)hpaths
{
  NSArray *newsel = [NSArray arrayWithObject: rootPath];
  int i;

	[self setRootPath: rootPath
         viewedPath: nil
          selection: newsel 
           delegate: delegate 
           viewApps: viewsapps];

	[self setCurrentSelection: newsel];
	[self resizeWithOldSuperviewSize: [self frame].size];
	[delegate setTheSelectedPaths: newsel];

  for (i = 0; i < [hpaths count]; i++) {
    NSString *hpath = [hpaths objectAtIndex: i];
      
    if (subPathOfPath(hpath, rootPath) || [hpath isEqualToString: rootPath]) {
      [self closeNicely];                            
    }
  }
}

- (BOOL)validatePasteOfFilenames:(NSArray *)names
                       wasCutted:(BOOL)cutted
{
  NSString *viewedPath = [self currentViewedPath];
  NSString *prePath = [NSString stringWithString: viewedPath];
	int count = [names count];
  NSString *basePath;
  int i;
  
	if (count == 0) {
		return NO;
  } 

	if ([fm isWritableFileAtPath: viewedPath] == NO) {
		return NO;
	}
    
	for (i = 0; i < count; i++) {
		if ([fm fileExistsAtPath: [names objectAtIndex: i]] == NO) {
 		  return NO;
		}
	}
    
  basePath = [[names objectAtIndex: 0] stringByDeletingLastPathComponent];
  if ([basePath isEqual: viewedPath]) {
    return NO;
  }  

	for (i = 0; i < count; i++) {
		if ([viewedPath isEqual: [names objectAtIndex: i]]) {
		  return NO;
		}
	}

  while (1) {
    if ([names containsObject: prePath]) {
      return NO;
    }
    if ([prePath isEqual: fixPath(@"/", 0)]) {
      break;
    }            
    prePath = [prePath stringByDeletingLastPathComponent];
  }

  return YES;
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

- (void)unsetWatchers
{
  int i;

  [[NSNotificationCenter defaultCenter] removeObserver: self 
                name: GWFileWatcherFileDidChangeNotification object: nil];

  for (i = 0; i < [watchedPaths count]; i++) {
    [self unsetWatcherForPath: [watchedPaths objectAtIndex: i]];  
  }
}

- (void)setResizeIncrement:(int)increment
{
  resizeIncrement = increment;
}

- (void)setAutoSynchronize:(BOOL)value
{
  autoSynchronize = value;
}

- (void)thumbnailsDidChangeInPaths:(NSArray *)paths
{
  if (paths == nil) {
    [self renewAll];
    return;
  } else {
    int i;
    
    for (i = 0; i < [paths count]; i++) {
      NSString *dir = [paths objectAtIndex: i];
      
      if ([browser isShowingPath: dir]) {
        [browser reloadColumnWithPath: dir];
        [browser renewLastIcon];
      }
    }
  }
}

- (id)viewerView
{
  return browser;
}

- (BOOL)viewsApps
{
  return viewsapps;
}

- (id)delegate
{
  return delegate;
}

- (void)setDelegate:(id)anObject
{	
  delegate = anObject;
}

//
// End of ViewersProtocol
//

- (void)checkUsesShelf
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  usesShelf = ![defaults boolForKey: @"viewersDontUsesShelf"];
}

- (void)checkUsesCellsIcons
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  cellsIcons = [defaults boolForKey: @"browserCellsIcons"];
}

- (void)renewAll
{
	NSArray *spats = RETAIN (selectedPaths);

	[self setRootPath: rootPath 
         viewedPath: nil
          selection: spats 
           delegate: delegate 
           viewApps: viewsapps];

	[self setCurrentSelection: [NSArray arrayWithObject: rootPath]];
	[self resizeWithOldSuperviewSize: [self frame].size];
	[self setCurrentSelection: spats];
	[self resizeWithOldSuperviewSize: [self frame].size];
	RELEASE (spats);
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
    
    if (operation == NSWorkspaceMoveOperation 
        || operation == NSWorkspaceDestroyOperation
        || operation == GWorkspaceRenameOperation
				|| operation == NSWorkspaceRecycleOperation
				|| operation == GWorkspaceRecycleOutOperation
				|| operation == GWorkspaceEmptyRecyclerOperation) { 

      if (operation == GWorkspaceRenameOperation) {      
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

- (void)fileSystemWillChange:(NSNotification *)notification
{
  NSDictionary *dict = (NSDictionary *)[notification object];  
  NSString *operation = [dict objectForKey: @"operation"];
	NSString *source = [dict objectForKey: @"source"];	  
	NSString *destination = [dict objectForKey: @"destination"];	 
	NSArray *files = [dict objectForKey: @"files"];	 

  [self validateRootPathAfterOperation: dict];
  
  if (operation == NSWorkspaceMoveOperation   
     || operation == NSWorkspaceCopyOperation 
        || operation == NSWorkspaceLinkOperation
           || operation == NSWorkspaceDuplicateOperation
						 || operation == NSWorkspaceRecycleOperation
							 || operation == GWorkspaceRecycleOutOperation) { 
    
    if ([browser isShowingPath: destination]) {                      		 						
      [browser addDimmedCellsWithNames: files 
                      inColumnWithPath: destination];			
      
      [self unsetWatchersFromPath: destination];

      [browser extendSelectionWithDimmedFiles: files 
                           fromColumnWithPath: destination];
    }
	}
  
	if (operation == GWorkspaceRenameOperation) { 
    NSString *dest = [destination stringByDeletingLastPathComponent];                      
    		
    if ([browser isShowingPath: dest]) {
			[self unsetWatchersFromPath: dest];
		}
	}

  if (operation == GWorkspaceCreateFileOperation 
              || operation == GWorkspaceCreateDirOperation) {  
    if ([browser isShowingPath: destination]) {
			[self unsetWatchersFromPath: destination];
		}
	}
  	
  if (operation == NSWorkspaceMoveOperation 
        || operation == NSWorkspaceDestroyOperation
				|| operation == NSWorkspaceRecycleOperation
				|| operation == GWorkspaceRecycleOutOperation
				|| operation == GWorkspaceEmptyRecyclerOperation) {

    if ([browser isShowingPath: source]) {  	
      [self unsetWatchersFromPath: source];
      
      [browser lockCellsWithNames: files
                 inColumnWithPath: source];

      [browser extendSelectionWithDimmedFiles: files 
                           fromColumnWithPath: source];
    }
	}
}

- (void)fileSystemDidChange:(NSNotification *)notification
{
  NSDictionary *dict = (NSDictionary *)[notification object];  
  NSString *operation = [dict objectForKey: @"operation"];
	NSString *source = [dict objectForKey: @"source"];	  
	NSString *destination = [dict objectForKey: @"destination"];	 
	NSArray *files = [dict objectForKey: @"files"];	 
      
  if (operation == NSWorkspaceMoveOperation 
     || operation == NSWorkspaceCopyOperation
        || operation == NSWorkspaceLinkOperation
           || operation == NSWorkspaceDuplicateOperation
						 || operation == NSWorkspaceRecycleOperation
							 || operation == GWorkspaceRecycleOutOperation) { 
        
    if ([browser isShowingPath: destination]) {
      [browser reloadFromColumnWithPath: destination];     
      [self reSetWatchersFromPath: destination];
    }
  }
	
  if (operation == NSWorkspaceMoveOperation 
        || operation == NSWorkspaceDestroyOperation
				|| operation == NSWorkspaceRecycleOperation
				|| operation == GWorkspaceRecycleOutOperation
				|| operation == GWorkspaceEmptyRecyclerOperation) {

    if ([browser isShowingPath: source]) {
      [browser reloadFromColumnWithPath: source]; 
      [self reSetWatchersFromPath: source];
    }
  }

  if (operation == GWorkspaceRenameOperation) { 
    NSString *dest = [destination stringByDeletingLastPathComponent];                      

    if ([browser isShowingPath: dest]) {
      [browser reloadFromColumnWithPath: dest]; 

      if ([[self window] isKeyWindow]) {
        NSString *newname = [destination lastPathComponent];

        [browser selectCellsWithNames: [NSArray arrayWithObject: newname]
                     inColumnWithPath: dest
                           sendAction: YES];
      } 
      
      [self reSetWatchersFromPath: dest];
    }
  }
  
  if (operation == GWorkspaceCreateFileOperation
                      || operation == GWorkspaceCreateDirOperation) {  
              
    if ([browser isShowingPath: destination]) {
      [browser reloadFromColumnWithPath: destination]; 

      if ([[self window] isKeyWindow]) {
        [browser selectCellsWithNames: files
                     inColumnWithPath: destination
                           sendAction: YES];

        [browser selectForEditingInLastColumn];
      }

      [self reSetWatchersFromPath: destination];
    }
  }
				
	[delegate updateTheInfoString];
}

- (void)sortTypeDidChange:(NSNotification *)notification
{
  NSString *notifPath = [notification object];

  if (notifPath) {
    [browser reloadColumnWithPath: notifPath];
  } else {
    [self renewAll];
  }
}

- (void)watcherNotification:(NSNotification *)notification
{
  NSDictionary *notifdict = (NSDictionary *)[notification object];
  NSString *path = [notifdict objectForKey: @"path"];
  
  if ([watchedPaths containsObject: path] == NO) {
    return;    

  } else {
    NSString *event = [notifdict objectForKey: @"event"];
				
    if (event == GWWatchedDirectoryDeleted) {
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

    if (event == GWFileDeletedInWatchedDirectory) {
      if (subPathOfPath(path, rootPath) == NO) {
        [browser removeCellsWithNames: [notifdict objectForKey: @"files"]
                     inColumnWithPath: path];
        return;
      }
    }
       
    if (event == GWFileCreatedInWatchedDirectory) {   
      if (subPathOfPath(path, rootPath) == NO) {
        [browser addCellsWithNames: [notifdict objectForKey: @"files"]
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

  [[NSNotificationCenter defaultCenter] addObserver: self 
                		selector: @selector(watcherNotification:) 
                				name: GWFileWatcherFileDidChangeNotification
                			object: nil];
}

- (void)setWatcherForPath:(NSString *)path
{
	[GWLib addWatcherForPath: path];
}

- (void)unsetWatcherForPath:(NSString *)path
{
	[GWLib removeWatcherForPath: path];
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
    BOOL isdir;

    count = [watchedPaths count];
    
    for (i = index; i < count; i++) {
      NSString *wpath = [watchedPaths objectAtIndex: i];
      
      if ([fm fileExistsAtPath: wpath isDirectory: &isdir] && isdir) {
        [self setWatcherForPath: wpath];
      } else {
        [watchedPaths removeObjectAtIndex: i];
        count--;
        i--;
      }  
    }
  }
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
// Browser2 Delegate Methods
//
@implementation BrowserViewer (Browser2DelegateMethods)

- (void)currentSelectedPaths:(NSArray *)paths
{
  if (autoSynchronize == YES) {		
    [self setSelectedPaths: paths];
		[delegate addPathToHistory: paths];
		[delegate updateTheInfoString];
  }
}

- (void)openSelectedPaths:(NSArray *)paths newViewer:(BOOL)isnew
{
	[self setSelectedPaths: paths];	
	[[GWLib workspaceApp] openSelectedPaths: paths newViewer: isnew]; 
}

@end
