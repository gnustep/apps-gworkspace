/* IconsViewer.m
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
#include "GWProtocol.h"
#include "GWFunctions.h"
#include "GWNotifications.h"
  #else
#include <GWorkspace/GWLib.h>
#include <GWorkspace/GWProtocol.h>
#include <GWorkspace/GWFunctions.h>
#include <GWorkspace/GWNotifications.h>
  #endif
#include "IconsViewer.h"
#include "IconsPath.h"
#include "PathIcon.h"
#include "IconsPanel.h"
#include "GWScrollView.h"
#include "IconsViewerPref.h"
#include "GNUstep.h"

#define ICNWIDTH 64 

@implementation IconsViewer

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  TEST_RELEASE (rootPath);
  TEST_RELEASE (lastPath);
  TEST_RELEASE (selectedPaths);
	TEST_RELEASE (savedSelection);
  TEST_RELEASE (watchedPaths);
  TEST_RELEASE (iconsPath);
  TEST_RELEASE (pathsScroll);
  TEST_RELEASE (panelScroll);  
  TEST_RELEASE (panel);
  TEST_RELEASE (prefs);
  [super dealloc];
}

- (id)init
{
	self = [super initWithFrame: NSZeroRect];
	
	if (self) {
    usesShelf = YES;
  	rootPath = nil;
    lastPath = nil;
  	selectedPaths = nil;
  	watchedPaths = nil;
  	iconsPath = nil;
  	pathsScroll = nil;
  	panelScroll = nil;  
  	panel = nil;
    prefs = nil;
	}
		
	return self;
}

//
// NSCopying 
//
- (id)copyWithZone:(NSZone *)zone
{
  IconsViewer *vwr = [[IconsViewer alloc] init]; 	
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

  fm = [NSFileManager defaultManager];
  [self checkUsesShelf];
	[self setDelegate: adelegate];
  ASSIGN (rootPath, rpath);
  viewsapps = canview;
  [self setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];

	colswidth = [delegate browserColumnsWidth];
	resizeIncrement = colswidth;			
	winwidth = [delegate getWindowFrameWidth];			
	columns = (int)winwidth / resizeIncrement;      
	columnsWidth = (winwidth - 16) / columns;		
  autoSynchronize = YES;

	TEST_RELEASE (iconsPath);

	if (pathsScroll != nil) {
		[pathsScroll removeFromSuperview];
		RELEASE (pathsScroll);
	}
	
	pathsScroll = [[GWScrollView alloc] init];
  [pathsScroll setBorderType: NSBezelBorder];
  [pathsScroll setHasHorizontalScroller: YES];
  [pathsScroll setHasVerticalScroller: NO]; 
  [pathsScroll setLineScroll: columnsWidth];
  [pathsScroll setAutoresizingMask: NSViewWidthSizable];      
  [pathsScroll setDelegate: self];

  iconsPath = [[IconsPath alloc] initWithRootAtPath: rootPath
                    			columnsWidth: columnsWidth delegate: self];

  [pathsScroll setDocumentView: iconsPath];	
  [self addSubview: pathsScroll]; 

	TEST_RELEASE (panel);

	if (panelScroll != nil) {
		[panelScroll removeFromSuperview];
		RELEASE (panelScroll);
	}

  panelScroll = [NSScrollView new];
  [panelScroll setBorderType: NSBezelBorder];
  [panelScroll setHasHorizontalScroller: YES];
  [panelScroll setHasVerticalScroller: YES]; 
  [panelScroll setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];      
  [self addSubview: panelScroll]; 

  panel = [[IconsPanel alloc] initAtPath: rootPath delegate: self];
  [panelScroll setDocumentView: panel];	
  [panel setPath:rootPath];
  
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
		DESTROY (watchedPaths);
	}

  [self setSelectedPaths: [NSArray arrayWithObject: rootPath]]; 
  
  if (vpath) {
    [self setSelectedPaths: [NSArray arrayWithObject: vpath]];
    [panel setPath: vpath]; 
    [panel scrollFirstIconToVisible];
  
    if (selection && [selection count]) { 
      [panel selectIconsWithPaths: selection];
    }
    [delegate addPathToHistory: [NSArray arrayWithObject: vpath]];
  } else {
    [delegate addPathToHistory: [NSArray arrayWithObject: rootPath]];
  }
    
  [delegate updateTheInfoString];

  firstResize = YES;
}

- (NSString *)menuName
{
	return @"Icon";
}

- (NSString *)shortCut
{
	return @"i";
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
    prefs = [[IconsViewerPref alloc] init];
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

  if (([paths count] == 0) 
                || ([paths isEqualToArray: selectedPaths])) {
    return;
  }

  ASSIGN (selectedPaths, paths);
	[delegate setTheSelectedPaths: paths];   
  
  [self synchronize];     
  
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
  NSString *path;
  NSArray *selection;
  
  if ([paths count] == 0) {
    return;
  }
  
  [self setSelectedPaths: paths];
  
  path = [paths objectAtIndex: 0];
  
  if ([paths count] > 1) {
    path = [path stringByDeletingLastPathComponent];
    selection = [NSArray arrayWithArray: selectedPaths];
  } else {
    BOOL isdir;
  
    [fm fileExistsAtPath: path isDirectory: &isdir];
  
    if (isdir == NO) {
      path = [path stringByDeletingLastPathComponent];
      selection = [NSArray arrayWithArray: selectedPaths];
    } else {
			if ([GWLib isPakageAtPath: path] && (viewsapps == NO)) {
				path = [path stringByDeletingLastPathComponent];
        selection = [NSArray arrayWithArray: selectedPaths];
			} else {
        selection = [NSArray array];
      }
    }
  }
  
  [panel setPath: path]; 
  [panel scrollFirstIconToVisible];
  [panel selectIconsWithPaths: selection];
  [panel setNeedsDisplay: YES];
  [delegate updateTheInfoString];
}

- (NSPoint)positionForSlidedImage
{
  NSPoint p = [iconsPath positionForSlidedImage];    
  p.y += [pathsScroll frame].origin.y;
  return [[self window] convertBaseToScreen: p];
}

- (void)selectAll
{
  [panel selectAllIcons];
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
  return [panel currentPath];
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
		NSPoint p = [iconsPath positionOfLastIcon];   
    
    if (p.x > ([self frame].size.width - ICNWIDTH)) {
      return NSZeroPoint;
    }
     
    p.y += [pathsScroll frame].origin.y;
    return [self convertPoint: p toView: nil];
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
  int winwidth = [delegate getWindowFrameWidth];	

  resizeIncrement = [delegate browserColumnsWidth];
	columns = (int)winwidth / resizeIncrement;      
	columnsWidth = (winwidth - 16) / columns;		
  
  [pathsScroll setLineScroll: columnsWidth];  
  [iconsPath setColumnWidth: columnsWidth];
}

- (void)setAutoSynchronize:(BOOL)value
{
  autoSynchronize = value;
}

- (void)thumbnailsDidChangeInPaths:(NSArray *)paths
{
  if (paths == nil) {
    [panel makeFileIcons];
    [panel resizeWithOldSuperviewSize: [panel frame].size];  
    [[iconsPath lastIcon] renewIcon];
  } else {
    int i;
  
    for (i = 0; i < [paths count]; i++) {
      NSString *dir = [paths objectAtIndex: i];

      if ([panel isOnBasePath: dir withFiles: nil]) {
        [panel reloadFromPath: dir];
        [[iconsPath lastIcon] renewIcon];
        [self setNeedsDisplay: YES];
      }
    }
  }
}

- (id)viewerView
{
  return panel;
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

- (void)validateRootPathAfterOperation:(NSDictionary *)opdict
{
  if ([rootPath isEqualToString: fixPath(@"/", 0)]) {
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

        if ((subPathOfPath(fpath, rootPath) == YES) 
                        || ([fpath isEqualToString: rootPath] == YES)) {  
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

  [delegate startIndicatorForOperation: operation];

  if (operation == NSWorkspaceMoveOperation
     || operation == NSWorkspaceCopyOperation
        || operation == NSWorkspaceLinkOperation
           || operation == NSWorkspaceDuplicateOperation
						 || operation == NSWorkspaceRecycleOperation
							 || operation == GWorkspaceRecycleOutOperation) {
                    
    if ([panel isOnBasePath: destination withFiles: files]) {
      [self unsetWatchersFromPath: destination];

      [panel extendSelectionWithDimmedFiles: files 
                             startingAtPath: destination];
                             
      [iconsPath lockIconsFromPath: destination];
    }
  }

	if (operation == GWorkspaceRenameOperation) { 
    NSString *dest = [destination stringByDeletingLastPathComponent];                      
    
    if ([panel isOnBasePath: dest withFiles: nil]) {
      [self unsetWatchersFromPath: dest];
    }
	}

  if (operation == GWorkspaceCreateFileOperation 
              || operation == GWorkspaceCreateDirOperation) {                
    if ([panel isOnBasePath: destination withFiles: nil]) {
      [self unsetWatchersFromPath: destination];
    }
	}
    
  if (operation == NSWorkspaceMoveOperation
      || operation == NSWorkspaceDestroyOperation
			|| operation == NSWorkspaceRecycleOperation
			|| operation == GWorkspaceRecycleOutOperation
			|| operation == GWorkspaceEmptyRecyclerOperation) { 

    if ([panel isOnBasePath: source withFiles: files]) {
      [self unsetWatchersFromPath: source];
            
      [panel extendSelectionWithDimmedFiles: files 
                             startingAtPath: source];
      
      [iconsPath lockIconsFromPath: source];
    }
  }
}

- (void)fileSystemDidChange:(NSNotification *)notification
{
  NSMutableDictionary *dict;
  NSString *operation, *source, *destination;
  NSArray *files;
    	
	dict = [NSMutableDictionary dictionaryWithCapacity: 1];	
	[dict addEntriesFromDictionary: (NSDictionary *)[notification object]];
	 
  operation = [dict objectForKey: @"operation"];
  source = [dict objectForKey: @"source"];
  destination = [dict objectForKey: @"destination"];
  files = [dict objectForKey: @"files"];

  [delegate stopIndicatorForOperation: operation];
  
  if (operation == NSWorkspaceMoveOperation   
     || operation == NSWorkspaceCopyOperation 
        || operation == NSWorkspaceLinkOperation
           || operation == NSWorkspaceDuplicateOperation
						 || operation == NSWorkspaceRecycleOperation
							 || operation == GWorkspaceRecycleOutOperation) { 

    if ([panel isOnBasePath: destination withFiles: files]) {
      [iconsPath unlockIconsFromPath: destination];
      [panel reloadFromPath: destination];
      [self reSetWatchersFromPath: destination];
    }
  }
  
  if (operation == NSWorkspaceMoveOperation 
      || operation == NSWorkspaceDestroyOperation
			|| operation == NSWorkspaceRecycleOperation
			|| operation == GWorkspaceRecycleOutOperation
			|| operation == GWorkspaceEmptyRecyclerOperation) { 
    
    if ([panel isOnBasePath: source withFiles: files]) {
      [iconsPath unlockIconsFromPath: source];
      [panel reloadFromPath: source];
      [self reSetWatchersFromPath: source];
    }
  }
    
  if (operation == GWorkspaceRenameOperation) {
    NSString *dest = [destination stringByDeletingLastPathComponent];                      
  
    if ([panel isOnBasePath: dest withFiles: nil]) {
      [panel reloadFromPath: dest];
  
      if ([[self window] isKeyWindow]) {
        [panel selectIconWithPath: destination];
      }
      
      [self reSetWatchersFromPath: dest];
    }
  }

  if (operation == GWorkspaceCreateFileOperation 
              || operation == GWorkspaceCreateDirOperation) {  
      
    if ([panel isOnBasePath: destination withFiles: nil]) {
      [panel reloadFromPath: destination];
  
      if ([[self window] isKeyWindow]) {
		    NSString *fileName = [files objectAtIndex: 0];    
		    NSString *filePath = [destination stringByAppendingPathComponent: fileName];    
      
        [self setCurrentSelection: [NSArray arrayWithObject: destination]];
        
        [panel selectIconWithPath: filePath];
        [self synchronize];
      }
      
      [self reSetWatchersFromPath: destination];
    }
  }
  
  [delegate updateTheInfoString];
  [self setNeedsDisplay: YES];
}

- (void)sortTypeDidChange:(NSNotification *)notification
{
  NSString *notifPath = [notification object];

  if (notifPath) {
    NSString *currpath = [panel currentPath];

		if (currpath && [currpath isEqual: notifPath]) {
			[panel makeFileIcons];
		}
  } else {
    [panel makeFileIcons];
  }

  [panel resizeWithOldSuperviewSize: [panel frame].size];
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
      if ((subPathOfPath(path, rootPath)) || ([path isEqualToString: rootPath])) {  
        [self closeNicely];      
        return;
      } else {
        NSString *s = [path stringByDeletingLastPathComponent];
        
        [self unsetWatcherForPath: path];    
            
        if ([panel isOnBasePath: s withFiles: nil]) {
          [panel reloadFromPath: s];
          [self setNeedsDisplay: YES];
        }
        
        return;
      }
    }

    if (event == GWFileDeletedInWatchedDirectory) {
      if ([path isEqualToString: [panel currentPath]]) {
        [panel reloadFromPath: path];		
        [self setNeedsDisplay: YES];		
        return;
      }
    }
    
    if (event == GWFileCreatedInWatchedDirectory) {
      if ([path isEqualToString: [panel currentPath]]) {
        [panel addIconsWithNames: [notifdict objectForKey: @"files"] 
                          dimmed: NO];
      }
    }
  }
  
  [delegate updateTheInfoString];
  [self setNeedsDisplay: YES];
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

  t = [NSTimer timerWithTimeInterval: 2 target: self 
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
  int col = columns;
  int winwidth;
	 
	[pathsScroll setFrame: NSMakeRect(0, r.size.height - 98, r.size.width, 98)];
	[panelScroll setFrame: NSMakeRect(0, 0, r.size.width, r.size.height - 104)];
  
  if (firstResize) {
    NSArray *currSel = [panel currentSelection];
    
    [panel scrollFirstIconToVisible];
    
    if (currSel) {
      [panel scrollToVisibleIconsWithPaths: currSel];
    }
    
    firstResize = NO;
  }
  
	winwidth = [delegate getWindowFrameWidth];
  columns = (int)winwidth / resizeIncrement;
  columnsWidth = (winwidth - 16) / columns;
    
  if (col != columns) {
    [pathsScroll setLineScroll: columnsWidth];  
    [iconsPath setColumnWidth: columnsWidth];
  }
  
  [self synchronize];  
}

- (void)clickOnIcon:(PathIcon *)icon
{
  NSArray *ipaths = RETAIN ([icon paths]);
  NSString *type = [icon type];
  BOOL chdir = NO;
  
  if (type && ((type == NSDirectoryFileType) || (type == NSFilesystemFileType))) {  
    if (([icon isPakage] == NO) || ([icon isPakage] && viewsapps)) {
      chdir = YES;
    }
  }
  
  if (chdir && (icon == [iconsPath lastIcon])) {
    [self setSelectedPaths: ipaths];   
    [panel scrollToVisibleIconsWithPaths: ipaths];
    [panel selectIconsWithPaths: ipaths];
    
  } else {
    [self setCurrentSelection: ipaths];
  
    if (chdir) {
      [panel scrollFirstIconToVisible];
    } else {
      [panel scrollToVisibleIconsWithPaths: ipaths];
      [panel selectIconsWithPaths: ipaths];
    }
  }
  
  RELEASE (ipaths);
}

- (void)doubleClickOnIcon:(PathIcon *)icon newViewer:(BOOL)isnew
{
  [self clickOnIcon: icon];
  [self openCurrentSelection: [icon paths] newViewer: isnew];
}

- (void)synchronize
{
  NSClipView *clip;
  float x, y;
  int nicons;

  if (autoSynchronize == NO) {
    return;
  } 
    
  [iconsPath setIconsForSelection: selectedPaths]; 
  nicons = [iconsPath numberOfIcons];
  clip = [pathsScroll contentView];
  x = [clip bounds].origin.x;
  y = [clip bounds].origin.y;

  if (nicons > columns) {    
    x += columnsWidth * (nicons - columns);
    [clip scrollToPoint: NSMakePoint(x, y)];
  }
}

- (void)openCurrentSelection:(NSArray *)paths newViewer:(BOOL)newv
{    
  [self setSelectedPaths: paths];

  if (newv == YES) {    		
    [[GWLib workspaceApp] openSelectedPaths: paths newViewer: YES];
    return;
    
  } else {
    NSMutableArray *allfiles = [NSMutableArray arrayWithCapacity: 1];
    NSMutableArray *dirs = [NSMutableArray arrayWithCapacity: 1]; 
    int count = [paths count];
    int i;

    [allfiles addObjectsFromArray: paths];    
     
    for (i = 0; i < count; i++) {
      NSString *fpath = [allfiles objectAtIndex: i];
      NSString *defApp = nil;
      NSString *type = nil;

      [[NSWorkspace sharedWorkspace] getInfoForFile: fpath 
                                        application: &defApp 
                                               type: &type];     

      if (([type isEqualToString: NSDirectoryFileType])
                        || ([type isEqualToString: NSFilesystemFileType])) { 
        if ([GWLib isPakageAtPath: fpath] == NO) {
          [dirs addObject: fpath]; 
          [allfiles removeObject: fpath];
          count--;
          i--;
        }
      }
    }
    
    if ([allfiles count]) {      
      [[GWLib workspaceApp] openSelectedPaths: allfiles newViewer: newv];
    }      

    if ([dirs count] == 1) {  
      [self setSelectedPaths: dirs];
      [panel setPath: [dirs objectAtIndex: 0]];
      [panel scrollFirstIconToVisible];
      [panel setNeedsDisplay: YES];
    }
  }      
}     

//
// scrollview delegate methods
//
- (void)gwscrollView:(GWScrollView *)sender 
  scrollViewScrolled:(NSClipView *)clip
             hitPart:(NSScrollerPart)hitpart
{
  if (autoSynchronize == NO) {
    return;
  } else {
    int x = (int)[clip bounds].origin.x;
    int y = (int)[clip bounds].origin.y;
    int rem = x % (int)columnsWidth;
    
    if (rem != 0) {
      if (rem <= columnsWidth / 2) {
        x -= rem;
      } else {
        x += columnsWidth - rem;
      }
      
      [clip scrollToPoint: NSMakePoint(x, y)];    
      [iconsPath setNeedsDisplay: YES];
    }
  }
}

@end

//
// IconsPanel delegate methods
//
@implementation IconsViewer (IconsPanelDelegateMethods)

- (void)setTheSelectedPaths:(id)paths
{
	[delegate addPathToHistory: paths];
	[self setSelectedPaths: paths];
}

- (void)openTheCurrentSelection:(id)paths newViewer:(BOOL)newv
{
	[self openCurrentSelection: paths newViewer: newv];
}

- (int)iconCellsWidth
{
  return [delegate iconCellsWidth];
}

@end

//
// IconsPath delegate methods
//

@implementation IconsViewer (IconsPathDelegateMethods)

- (void)clickedIcon:(id)anicon
{
	[self clickOnIcon: anicon];
}

- (void)doubleClickedIcon:(id)anicon newViewer:(BOOL)isnew
{
	[self doubleClickOnIcon: anicon newViewer: isnew];
}

@end
