/* SmallIconsViewer.m
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
#include "SmallIconsViewer.h"
#include "Banner.h"
#include "PathsPopUp.h"
#include "SmallIconsPanel.h"
#include "GNUstep.h"

#define SETRECT(o, x, y, w, h) { \
NSRect rct = NSMakeRect(x, y, w, h); \
if (rct.size.width < 0) rct.size.width = 0; \
if (rct.size.height < 0) rct.size.height = 0; \
[o setFrame: rct]; \
}

@implementation SmallIconsViewer

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
  TEST_RELEASE (rootPath);
  TEST_RELEASE (lastPath);
  TEST_RELEASE (currentPath);
  TEST_RELEASE (selectedPaths);
	TEST_RELEASE (savedSelection);
  TEST_RELEASE (watchedPaths);
	TEST_RELEASE (banner);
  TEST_RELEASE (panelScroll);  
  TEST_RELEASE (panel);
  [super dealloc];
}

- (id)init
{
	self = [super initWithFrame: NSZeroRect];
	
	if (self) {
  	rootPath = nil;
    lastPath = nil;
  	currentPath = nil;
  	selectedPaths = nil;
  	watchedPaths = nil;
  	panelScroll = nil;  
		banner = nil;
  	panel = nil;	
	}
	
	return self;
}

//
// NSCopying 
//
- (id)copyWithZone:(NSZone *)zone
{
  SmallIconsViewer *vwr = [[SmallIconsViewer alloc] init]; 	
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

	[self setDelegate: adelegate];
  ASSIGN (currentPath, rpath);	
  viewsapps = canview;

	colswidth = [delegate browserColumnsWidth];
	resizeIncrement = colswidth;			
	winwidth = [delegate getWindowFrameWidth];			
	columns = (int)winwidth / resizeIncrement;      
	columnsWidth = (winwidth - 16) / columns;		

  [self setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];

	if (banner != nil) {
		[banner removeFromSuperview];
		RELEASE (banner);
	}

	banner = [[Banner alloc] init];
	pathsPopUp = [banner pathsPopUp];
	[pathsPopUp setTarget: self];
	[pathsPopUp setAction: @selector(popUpAction:)];
	[self addSubview: banner]; 

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

  panel = [[SmallIconsPanel alloc] initAtPath: currentPath delegate: self];
  [panelScroll setDocumentView: panel];	
  [panel setPath: currentPath];

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

  [self setSelectedPaths: [NSArray arrayWithObject: currentPath]]; 

  if (vpath) {
    [self setSelectedPaths: [NSArray arrayWithObject: vpath]];
    [panel setPath: vpath]; 
    [panel scrollFirstIconToVisible];
        
    if (selection && [selection count]) { 
      [panel selectIconsWithPaths: selection];
    } 
    [delegate addPathToHistory: [NSArray arrayWithObject: vpath]];
  } else {
    [delegate addPathToHistory: [NSArray arrayWithObject: currentPath]];
  }
  
	[self updateDiskInfo];

  firstResize = YES;
}

- (NSString *)menuName
{
	return @"Small Icon";
}

- (NSString *)shortCut
{
	return @"k";
}

- (BOOL)usesShelf
{
	return NO;
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
  return NO;
}

- (id)prefController
{
  return nil;
}

- (void)setSelectedPaths:(NSArray *)paths
{
  NSString *newPath;
  NSArray *components;
  NSMutableArray *wpaths;
  NSString *s;
  BOOL isDir;
  int i, j;			
			
  if ([paths count] == 0) {
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
	
	ASSIGN (currentPath, newPath);
    
	[delegate setTitleAndPath: currentPath selectedPaths: selectedPaths];

  components = [currentPath pathComponents];  
	[self makePopUp: components];
	
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
  [self updateDiskInfo];
}

- (NSPoint)positionForSlidedImage
{
  return NSMakePoint(0, 0);
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
  int i;

  for (i = 0; i < [hpaths count]; i++) {
    NSString *hpath = [hpaths objectAtIndex: i];
      
    if (subPathOfPath(hpath, currentPath) 
                            || [hpath isEqualToString: currentPath]) {
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
	NSString *name = [path lastPathComponent];
	NSPoint p = [panel locationOfIconWithName: name];
	
	if ((p.x == 0) && (p.y == 0)) {
		return p;
		
	} else { 
		NSView *sview = [[self window] contentView];
		NSRect r = [self visibleRect];
		NSPoint lim1 = r.origin;
		NSPoint lim2 = NSMakePoint(lim1.x + r.size.width, lim1.y + r.size.height);

		p = [sview convertPoint: p fromView: panel];
		lim1 = [sview convertPoint: lim1 fromView: self];
		lim2 = [sview convertPoint: lim2 fromView: self];

		if (p.x < lim1.x) p.x = lim1.x;
		if (p.y < lim1.y) p.y = lim1.y;

		if (p.x >= lim2.x) p.x = lim2.x - 60;
		if (p.y >= lim2.y) p.y = lim2.y - 60;

		if (p.x == 0) p.x = 1;
		if (p.y == 0) p.y = 1;
	}
	
	return p;
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
	resizeIncrement = increment;   // CONTROLLARE !!!!!!
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
  } else {
    int i;
  
    for (i = 0; i < [paths count]; i++) {
      NSString *dir = [paths objectAtIndex: i];

      if ([panel isOnBasePath: dir withFiles: nil]) {
        [panel reloadFromPath: dir];
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

- (void)validateCurrentPathAfterOperation:(NSDictionary *)opdict
{
  if ([currentPath isEqualToString: fixPath(@"/", 0)]) {
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

        if (subPathOfPath(fpath, currentPath)
                        	|| [fpath isEqualToString: currentPath]) {  
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

  [self validateCurrentPathAfterOperation: dict];     

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
    }
  }

  if (operation == GWorkspaceCreateFileOperation 
              || operation == GWorkspaceCreateDirOperation) {                
    if ([panel isOnBasePath: destination withFiles: nil]) {
      [self unsetWatchersFromPath: destination];
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

  if (operation == NSWorkspaceMoveOperation   
     || operation == NSWorkspaceCopyOperation 
        || operation == NSWorkspaceLinkOperation
           || operation == NSWorkspaceDuplicateOperation
						 || operation == NSWorkspaceRecycleOperation
							 || operation == GWorkspaceRecycleOutOperation) { 

    if ([panel isOnBasePath: destination withFiles: files]) {    
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
      }
      
      [self reSetWatchersFromPath: destination];
    }
  }
        
  [self updateDiskInfo];
  [self setNeedsDisplay: YES];
}

- (void)sortTypeDidChange:(NSNotification *)notification
{
  NSString *notifPath = [notification object];

  if (notifPath) {
		if (currentPath && [currentPath isEqual: notifPath]) {
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
      if ((subPathOfPath(path, currentPath)) || ([path isEqualToString: currentPath])) {  
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
        [panel tile];                 
      }
    }
  }
  
  [self updateDiskInfo];
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

- (void)openCurrentSelection:(NSArray *)paths newViewer:(BOOL)newv
{
  if (newv == YES) {    		
    [[GWLib workspaceApp] openSelectedPaths: paths newViewer: YES];
    return;
    
  } else {
    NSMutableArray *allfiles = [NSMutableArray arrayWithCapacity: 1];
    NSMutableArray *dirs = [NSMutableArray arrayWithCapacity: 1]; 
    int count = [paths count];
    int i;

    [self setSelectedPaths: paths];
    
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
      [delegate addPathToHistory: dirs];
    }
  }      
}

- (void)setSelectedIconsPaths:(NSArray *)paths
{
  if (([paths count] == 0) || ([paths isEqualToArray: selectedPaths])) {
    return;
  }

  ASSIGN (selectedPaths, paths);
	[delegate setTheSelectedPaths: selectedPaths];
}

- (void)makePopUp:(NSArray *)pathComps
{
	NSArray *titles = [pathsPopUp itemTitles];
	int i;		
		
	if ((titles != nil) && ([titles count] != 0)) {
		if ([titles isEqualToArray: pathComps]) {
		  return;
		} else {
			[pathsPopUp removeAllItems];
		}
	}

	for (i = [pathComps count] -1; i >= 0; i--) {
		[pathsPopUp addItemWithTitle: [pathComps objectAtIndex: i]]; 	
	}
}

- (void)popUpAction:(id)sender
{
	NSArray *titles = [sender itemTitles];
	NSString *title = [sender titleOfSelectedItem];
  int index = [sender indexOfSelectedItem];
	NSString *path = fixPath(@"/", 0);
	int i = [titles count] -1;
	
	while (1) {
		NSString *s = [titles objectAtIndex: i];
		path = [path stringByAppendingPathComponent: s];
		if ([s isEqualToString: title] && (i == index)) {
			break;
		}		
		i--;
	}
	
	if ([currentPath isEqualToString: path] == NO) {
		BOOL newview = [pathsPopUp newViewer];
		[self openCurrentSelection: [NSArray arrayWithObject: path] 
										 newViewer: newview];
		if (newview) {
			[self makePopUp: [currentPath pathComponents]];
		}								 
	}
}

- (void)updateDiskInfo
{
  NSDictionary *attributes;
	NSNumber *freeFs;
  NSString *infoString;
	
	attributes = [fm fileSystemAttributesAtPath: currentPath];
	freeFs = [attributes objectForKey: NSFileSystemFreeSize];
  
	if(freeFs == nil) {  
		infoString = [NSString stringWithString: NSLocalizedString(@"unknown size", @"")];    
	} else {
		infoString = [NSString stringWithFormat: @"%@ %@", 
            fileSizeDescription([freeFs unsignedLongLongValue]), 
                                NSLocalizedString(@"available", @"")];
	}
  	
  [banner updateInfo: infoString];
}

- (void)closeNicely
{
  NSTimer *t;
  
  [self unsetWatchers]; 
  [[NSNotificationCenter defaultCenter] removeObserver: self];

  t = [NSTimer timerWithTimeInterval: 1 target: self 
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
	int winwidth = [delegate getWindowFrameWidth];
	
	SETRECT (banner, 0, h - 30, w, 30);
	[banner resizeWithOldSuperviewSize: [banner frame].size];
	
	SETRECT (panelScroll, 0, 0, w, h - 30);

  if (firstResize) {
    NSArray *currSel = [panel currentSelection];
    
    [panel scrollFirstIconToVisible];
    
    if (currSel) {
      [panel scrollToVisibleIconsWithPaths: currSel];
    }
    
    firstResize = NO;
  }
				
  columns = (int)winwidth / resizeIncrement;
  columnsWidth = (winwidth - 16) / columns;	
}

@end

//
// SmallIconsPanel delegate methods
//
@implementation SmallIconsViewer (SmallIconsPanelDelegateMethods)

- (void)setTheSelectedPaths:(id)paths
{
	[delegate addPathToHistory: paths];
	[self setSelectedPaths: paths];
}

- (void)setSelectedPathsFromIcons:(id)paths
{
	[self setSelectedIconsPaths: paths];
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

