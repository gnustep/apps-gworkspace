/* ViewerWindow.m
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
 *
 * This file is part of the GNUstep GWRemote application
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
#include "ViewerWindow.h"
#include "GWSplitView.h"
#include "Viewer/Shelf.h"
#include "Viewer/ShelfIcon.h"
#include "Viewer.h"
#include "GWRemote.h"
#include <GWorkspace/GWProtocol.h>
#include <GWorkspace/GWNotifications.h>
#include <GWorkspace/GWFunctions.h>
#include "GNUstep.h"

#define SETRECT(o, x, y, w, h) { \
NSRect rct = NSMakeRect(x, y, w, h); \
if (rct.size.width < 0) rct.size.width = 0; \
if (rct.size.height < 0) rct.size.height = 0; \
[o setFrame: rct]; \
}

#define MIN_SHELF_HEIGHT 2
#define MID_SHELF_HEIGHT 77
#define MAX_SHELF_HEIGHT 150

#define COLLAPSE_LIMIT 35
#define MID_LIMIT 110

#define DEFAULT_WIDTH 150
#define DEFAULT_ICONS_WIDTH 120

@implementation ViewerWindow

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  RELEASE (shelf);
  RELEASE (viewer);
  RELEASE (mainview);
  RELEASE (rootPath);
  RELEASE (serverName);
	RELEASE (selectedPaths);
  [super dealloc];
}

- (id)initForPath:(NSString *)path 
         onServer:(NSString *)server 
			viewPakages:(BOOL)canview
		 isRootViewer:(BOOL)rootviewer
          onStart:(BOOL)onstart
{
  unsigned int style;

  if (rootviewer == NO) {
    style = NSTitledWindowMask | NSClosableWindowMask 
				         | NSMiniaturizableWindowMask | NSResizableWindowMask;
  } else {
    style = NSTitledWindowMask | NSMiniaturizableWindowMask 
                                          | NSResizableWindowMask;
  }

  self = [super initWithContentRect: NSZeroRect styleMask: style
                               backing: NSBackingStoreBuffered defer: NO];

  if (self) {
    NSUserDefaults *defaults;
    NSMutableDictionary *serverPrefs;
    NSMutableDictionary *viewersPrefs = nil;
    NSMutableDictionary *myPrefs = nil;
    NSArray *shelfDicts;
    id dictEntry, defEntry;
    NSString *viewedPath = nil;
    NSMutableArray *selection = nil;
		float shfwidth = 0.0;   
    
		gw = (id <GWProtocol>)[GWRemote gwremote];
		ASSIGN (serverName, server);
		
		[self setReleasedWhenClosed: NO];
    
    defaults = [NSUserDefaults standardUserDefaults];	
        
    defEntry = [defaults objectForKey: @"browserColsWidth"];
    if (defEntry) {
      resizeIncrement = [defEntry intValue];
    } else {
      resizeIncrement = DEFAULT_WIDTH;
    }

    defEntry = [defaults objectForKey: @"iconsCellsWidth"];
    if (defEntry) {
      iconCellsWidth = [defEntry intValue];
    } else {
      iconCellsWidth = DEFAULT_ICONS_WIDTH;
    }
        
    [self setMinSize: NSMakeSize(resizeIncrement * 2, 250)];    
    [self setResizeIncrements: NSMakeSize(resizeIncrement, 1)];

    isRootViewer = rootviewer;
		
    if (isRootViewer) {
      NSString *title = [NSString stringWithFormat: @"%@ - %@", 
                      serverName, NSLocalizedString(@"Remote File Viewer", @"")];
      [self setTitle: title];
    } else {
			NSString *pth = [path stringByDeletingLastPathComponent];
			NSString *nm = [path lastPathComponent];
			NSString *title = [NSString stringWithFormat: @"%@ - %@ - %@", serverName, nm, pth];
      [self setTitle: title];   
    }		    

    if (isRootViewer == NO) {
      if ([self setFrameUsingName: [NSString stringWithFormat: @"viewer_at_%@_%@", path, serverName]] == NO) {
        [self setFrame: NSMakeRect(200, 200, resizeIncrement * 3, 500) display: NO];
      }   
    } else {
      if ([self setFrameUsingName: [NSString stringWithFormat: @"rootViewer_%@", serverName]] == NO) {
        [self setFrame: NSMakeRect(200, 200, resizeIncrement * 3, 500) display: NO];
      }         
    } 
    
    ASSIGN (rootPath, path);  
		selectedPaths = [[NSArray alloc] initWithObjects: path, nil];
  	viewsapps = canview;
        
    serverPrefs = [[defaults objectForKey: serverName] mutableCopy];
    
    defEntry = [serverPrefs objectForKey: @"viewersprefs"];
    if (defEntry) { 
 		  viewersPrefs = [defEntry mutableCopy];
    } else {
      viewersPrefs = [NSMutableDictionary new];
    }

    if (isRootViewer) {
      defEntry = [viewersPrefs objectForKey: @"rootViewer"];
    } else {
      defEntry = [viewersPrefs objectForKey: rootPath];
    }
    if (defEntry) { 
 		  myPrefs = [defEntry mutableCopy];
    } else {
      myPrefs = [[NSMutableDictionary alloc] initWithCapacity: 1];
    }
           			
		/* ************* */
		/*     shelf     */
		/* ************* */
		shfwidth = [[self contentView] frame].size.width;
		
    dictEntry = [myPrefs objectForKey: @"shelfdicts"];      
    if(dictEntry) {
      shelfDicts = [NSArray arrayWithArray: dictEntry];      
    } else {
			NSMutableDictionary *dict = [NSMutableDictionary dictionary];
      NSArray *arr;

      if (isRootViewer) {
        arr = [NSArray arrayWithObject: [gw homeDirectoryForServerWithName: serverName]];
      } else {         
        arr = [NSArray arrayWithObject: rootPath]; 
      }
			
			[dict setObject: arr forKey: @"paths"];
			[dict setObject: @"0" forKey: @"index"];
						       
      shelfDicts = [NSArray arrayWithObject: dict];         		
    }
    [myPrefs setObject: shelfDicts forKey: @"shelfdicts"];      

    shelf = [[Shelf alloc] initWithIconsDicts: shelfDicts 
                                     rootPath: rootPath
                                   remoteHost: serverName];
    dictEntry = [myPrefs objectForKey: @"shelfheight"];

    if(dictEntry) {
      shelfHeight = [dictEntry intValue];
    } else {
      shelfHeight = MID_SHELF_HEIGHT;
    }

    SETRECT (shelf, 0, 0, shfwidth, shelfHeight); 
    		
    [shelf setDelegate: self];
    [shelf setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];

		/* ************* */
		/*    viewer     */
		/* ************* */
    if (onstart) {
      dictEntry = [myPrefs objectForKey: @"viewedpath"];

      if (dictEntry) {
        viewedPath = [NSString stringWithString: dictEntry];
      } else {
        viewedPath = nil;
      }

      dictEntry = [myPrefs objectForKey: @"lastselection"];

      if (dictEntry) {
        int i, count;

        selection = [dictEntry mutableCopy];

        count = [selection count];      
        for (i = 0; i < count; i++) {
          NSString *s = [selection objectAtIndex: i];

          if ([gw server: serverName fileExistsAtPath: s] == NO) {
            [selection removeObject: s];
            count--;
            i--;
          }
        }

        if ([selection count] == 0) {
          RELEASE (selection);
          selection = nil;
        }

      } else {
        selection = nil;
      }
    } else {
      viewedPath = nil;
      selection = nil;
    }
    
    viewer = [[Viewer alloc] init];
    
   [viewer setRootPath: rootPath 
        viewedPath: viewedPath
         selection: selection 
          delegate: self 
          viewApps: viewsapps
            server: serverName];
               
    TEST_RELEASE (selection);
    
    if (isRootViewer == NO) {
	    [viewersPrefs setObject: myPrefs forKey: rootPath];
    } else {
	    [viewersPrefs setObject: myPrefs forKey: @"rootViewer"];
    }
    RELEASE (myPrefs);

    [serverPrefs setObject: viewersPrefs forKey: @"viewersprefs"];
    RELEASE (viewersPrefs);  

    [defaults setObject: serverPrefs forKey: serverName];
    RELEASE (serverPrefs);

    [defaults synchronize];    
    

		/* ************* */
		/*   mainview    */
		/* ************* */
    mainview = [[GWSplitView alloc] initWithFrame: [[self contentView] frame] viewer: self];
    [mainview setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];
    [mainview setDelegate: self];
		[mainview addSubview: shelf];

    [mainview addSubview: viewer];
		[[self contentView] addSubview: mainview];

    [[NSNotificationCenter defaultCenter] addObserver: self 
                				  selector: @selector(columnsWidthChanged:) 
                					    name: GWBrowserColumnWidthChangedNotification
                					  object: nil];

  	[mainview resizeWithOldSuperviewSize: [mainview frame].size]; 
		
		[self adjustSubviews];	
    
    [self makeFirstResponder: [viewer viewerView]];  
  }
  
  return self;
}

- (void)activate
{
  [self makeKeyAndOrderFront: nil];
}

- (void)setSelectedPaths:(NSArray *)paths
{
	ASSIGN (selectedPaths, paths);
}

- (void)setViewerSelection:(NSArray *)selPaths
{
  [viewer setCurrentSelection: selPaths];
}

- (NSString *)currentViewedPath
{  
  return [viewer currentViewedPath];
}

- (void)fileSystemDidChange:(NSDictionary *)info
{
  [viewer fileSystemDidChange: info];
  [shelf fileSystemDidChange: info];
}

- (void)adjustSubviews
{
  NSRect r = [mainview frame];
  float w = r.size.width;
	float h = r.size.height;   	
  float sh = [shelf frame].size.height;
  float d = [mainview dividerThickness];
		
  if (sh < COLLAPSE_LIMIT) {
    shelfHeight = MIN_SHELF_HEIGHT;
  } else if (sh <= MID_LIMIT) {  
    shelfHeight = MID_SHELF_HEIGHT;
  } else {
    shelfHeight = MAX_SHELF_HEIGHT;
  }

	SETRECT (shelf, 0, 0, r.size.width, shelfHeight);
  [shelf resizeWithOldSuperviewSize: [shelf frame].size]; 

	SETRECT (viewer, 8, shelfHeight + d, w - 16, h - shelfHeight - d);
  [viewer resizeWithOldSuperviewSize: [viewer frame].size]; 
}

- (NSPoint)positionForSlidedImage
{
  return [viewer positionForSlidedImage];
}

- (NSPoint)locationOfIconForPath:(NSString *)apath
{
	return [viewer locationOfIconForPath: apath];
}

- (void)columnsWidthChanged:(NSNotification *)notification
{
  NSRect r = [self frame];
  float x = r.origin.x;
	float y = r.origin.y;
	float w = r.size.width;
	float h = r.size.height;
  int columnsWidth = [(NSNumber *)[notification object] intValue];
  int columns = (int)(w / resizeIncrement); 

  resizeIncrement = columnsWidth;
     
  [viewer setAutoSynchronize: NO];
     
  [self setFrame: NSMakeRect(x, y, (columns * columnsWidth), h) display: YES];  
  [self setMinSize: NSMakeSize(resizeIncrement * 2, 250)];    
  [self setResizeIncrements: NSMakeSize(resizeIncrement, 1)];

  [viewer setResizeIncrement: columnsWidth];
  [viewer setAutoSynchronize: YES];
  [mainview setNeedsDisplay: YES]; 
}

- (void)selectAll
{
  [viewer selectAll];
}

- (void)updateInfoString
{
  NSString *path;
  NSDictionary *attributes;
	NSNumber *freeFs;
  NSString *infoString;
  	
  path = [[viewer selectedPaths] objectAtIndex: 0];
	attributes = [gw server: serverName fileSystemAttributesAtPath: path];
	freeFs = [attributes objectForKey: NSFileSystemFreeSize];
  
	if(freeFs == nil) {  
		infoString = [NSString stringWithString: @"unknown volume size"];    
	} else {
		infoString = [NSString stringWithFormat: @"%@ available on hard disk", 
                          fileSizeDescription([freeFs unsignedLongLongValue])];
	}
  
  [mainview updateDiskSpaceInfo: infoString];
}

- (NSString *)serverName
{
  return serverName;
}

- (NSString *)rootPath
{
  return rootPath;
}

- (id)viewer
{
	return viewer;
}

- (BOOL)viewsApps
{
  return viewsapps;
}

- (void)updateDefaults
{
	NSUserDefaults *defaults;
  NSMutableDictionary *serverPrefs;  
  NSMutableDictionary *viewersPrefs;
  NSMutableDictionary *myPrefs;
  NSMutableArray *shelfDicts;
  NSString *shHeight;
  NSString *viewedPath;
  NSArray *selection;
  id dictEntry;

  if (isRootViewer == NO) {
    [self saveFrameUsingName: [NSString stringWithFormat: @"viewer_at_%@_%@", rootPath, serverName]];
  } else {
    [self saveFrameUsingName: [NSString stringWithFormat: @"rootViewer_%@", serverName]];
  }

  defaults = [NSUserDefaults standardUserDefaults];	
  serverPrefs = [[defaults objectForKey: serverName] mutableCopy];

  viewersPrefs = [[serverPrefs objectForKey: @"viewersprefs"] mutableCopy];

  if (isRootViewer == NO) {
    dictEntry = [viewersPrefs objectForKey: rootPath];
  } else {
    dictEntry = [viewersPrefs objectForKey: @"rootViewer"];
  }

  if (dictEntry) { 
 		myPrefs = [dictEntry mutableCopy];
  } else {
    myPrefs = [[NSMutableDictionary alloc] initWithCapacity: 1];
  }
  
  shHeight = [NSString stringWithFormat: @"%i", (int)[shelf frame].size.height];
  [myPrefs setObject: shHeight forKey: @"shelfheight"];

  shelfDicts = [[shelf iconsDicts] mutableCopy];
  if ([shelfDicts count] == 0) {
		NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity: 1];
		NSArray *arr = [NSArray arrayWithObject: NSHomeDirectory()];
	
		[dict setObject: arr forKey: @"paths"];
		[dict setObject: @"1" forKey: @"index"];
	
    [shelfDicts addObject: dict];
  }      
  [myPrefs setObject: shelfDicts forKey: @"shelfdicts"];
  RELEASE (shelfDicts);

  viewedPath = [viewer currentViewedPath];
  if (viewedPath) {
    [myPrefs setObject: viewedPath forKey: @"viewedpath"];
  }
  
  selection = [viewer selectedPaths];
  if (selection) {
    [myPrefs setObject: selection forKey: @"lastselection"];
  }

  if (isRootViewer == NO) {
	  [viewersPrefs setObject: myPrefs forKey: rootPath];
  } else {
	  [viewersPrefs setObject: myPrefs forKey: @"rootViewer"];
  }
  
  RELEASE (myPrefs);

  [serverPrefs setObject: viewersPrefs forKey: @"viewersprefs"];  
  RELEASE (viewersPrefs);  

  [defaults setObject: serverPrefs forKey: serverName];
  RELEASE (serverPrefs);

  [defaults synchronize];    
}

- (void)becomeMainWindow
{
  NSArray *selPaths;

  if (viewer && (selPaths = [viewer selectedPaths])) {
	  ASSIGN (selectedPaths, selPaths);
    [gw server: serverName setSelectedPaths: selPaths];
    [gw setCurrentViewer: self];  
    [self updateInfoString]; 
    [self makeFirstResponder: [viewer viewerView]];  
  }
}

- (void)becomeKeyWindow
{
  [super becomeKeyWindow];
  if (viewer && [viewer viewerView]) {
    [self makeFirstResponder: [viewer viewerView]];  
  }
}

- (BOOL)windowShouldClose:(id)sender
{
  if (self != [gw rootViewer]) {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [viewer unsetWatchers]; 
  }
    
  [self updateDefaults];
  return YES;
}

- (void)close
{
  [super close];
  [gw viewerHasClosed: self]; 
}

//
// splitView delegate methods
//
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

- (void)splitView:(NSSplitView *)sender 
                  resizeSubviewsWithOldSize:(NSSize)oldSize
{
	[self adjustSubviews];
}

- (void)splitViewDidResizeSubviews:(NSNotification *)aNotification
{
	[self adjustSubviews];
}

//
// Menu operations
//
- (void)openSelection:(id)sender
{
  [gw server: serverName openSelectedPaths: selectedPaths newViewer: NO];
}

- (void)openSelectionAsFolder:(id)sender
{
  [gw server: serverName openSelectedPaths: selectedPaths newViewer: YES];
}

- (void)newFolder:(id)sender
{
  [gw server: serverName newObjectAtPath: [self currentViewedPath] isDirectory: YES];
}

- (void)newFile:(id)sender
{
  [gw server: serverName newObjectAtPath: [self currentViewedPath] isDirectory: NO];
}

- (void)duplicateFiles:(id)sender
{
  [gw duplicateFilesOnServerName: serverName];
}

- (void)deleteFiles:(id)sender
{
  [gw deleteFilesOnServerName: serverName];
}

- (void)selectAllInViewer:(id)sender
{
  [viewer selectAll];
}

- (void)print:(id)sender
{
  [super print: sender];
}

@end


//
// shelf delegate methods
//
@implementation ViewerWindow (ShelfDelegateMethods)

- (NSArray *)getSelectedPaths
{
	return selectedPaths;
}

- (void)shelf:(Shelf *)sender setCurrentSelection:(NSArray *)paths
{
  [viewer setCurrentSelection: paths];
}

- (void)shelf:(Shelf *)sender setCurrentSelection:(NSArray *)paths
              animateImage:(NSImage *)image startingAtPoint:(NSPoint)startp
{
  NSPoint endp = [viewer positionForSlidedImage];

  if ((NSEqualPoints(endp, NSZeroPoint) == NO) && [gw animateChdir]) {
    [gw slideImage: image from: startp to: endp];
  }
  
  [viewer setCurrentSelection: paths];
}

- (void)shelf:(Shelf *)sender openCurrentSelection:(NSArray *)paths newViewer:(BOOL)newv
{
  [viewer setSelectedPaths: paths];
  [gw openSelectedPaths: paths newViewer: newv];   
}

@end


//
// Viewers Delegate Methods
//
@implementation ViewerWindow (ViewerDelegateMethods)

- (void)setTheSelectedPaths:(id)paths
{
	ASSIGN (selectedPaths, paths);
  [gw server: serverName setSelectedPaths: paths];
}

- (NSArray *)selectedPaths
{
  return [gw selectedPathsForServerWithName: serverName];
}

- (void)setTitleAndPath:(id)apath selectedPaths:(id)paths
{
	ASSIGN (selectedPaths, paths);
	[gw server: serverName setSelectedPaths: paths];
	
  if ([apath isEqualToString: fixPath(@"/", 0)] == YES) {
    NSString *title = [NSString stringWithFormat: @"%@ - %@", 
                    serverName, NSLocalizedString(@"Remote File Viewer", @"")];
    [self setTitle: title];
  } else {
		NSString *pth = [apath stringByDeletingLastPathComponent];
		NSString *nm = [apath lastPathComponent];
		NSString *title = [NSString stringWithFormat: @"%@ - %@ - %@", serverName, nm, pth];
    [self setTitle: title];   
  }
}

- (void)updateTheInfoString
{
	[self updateInfoString];
}

- (int)browserColumnsWidth
{
  return resizeIncrement;
}

- (int)iconCellsWidth
{
  return iconCellsWidth;
}

- (int)getWindowFrameWidth
{
	return (int)[self frame].size.width;
}

- (int)getWindowFrameHeight
{
	return (int)[self frame].size.height;
}

- (void)startIndicatorForOperation:(NSString *)operation
{
  [(GWSplitView *)mainview startIndicatorForOperation: operation];
}

- (void)stopIndicatorForOperation:(NSString *)operation
{
  [(GWSplitView *)mainview stopIndicatorForOperation: operation];
}

@end

