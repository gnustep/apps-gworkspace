/* GWorkspace.m
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
#include <math.h>
  #ifdef GNUSTEP 
#include "GWLib.h"
#include "GWFunctions.h"
#include "GWNotifications.h"
#include "ViewersProtocol.h"
  #else
#include <GWorkspace/GWLib.h>
#include <GWorkspace/GWFunctions.h>
#include <GWorkspace/GWNotifications.h>
#include <GWorkspace/ViewersProtocol.h>
  #endif
#include "GWorkspace.h"
#include "FileOperations/FileOperation.h"
#include "Dialogs/Dialogs.h"
#include "Dialogs/OpenWithController.h"
#include "Dialogs/RunExternalController.h"
#include "Dialogs/StartAppWin.h"
#include "Apps/Apps.h"
#include "Finder/FinderController.h"
#include "Preferences/PrefController.h"
#include "Fiend/Fiend.h"
#include "ViewersWindow.h"
#include "Desktop/DesktopWindow.h"
#include "Desktop/DesktopView.h"
#include "TShelf/TShelfWin.h"
#include "TShelf/TShelfView.h"
#include "TShelf/TShelfViewItem.h"
#include "TShelf/TShelfIconsView.h"
#include "Recycler/Recycler.h"
#include "History/History.h"
#include "GNUstep.h"

NSString *defaulteditor = @"nedit.app";
NSString *defaultxterm = @"xterm";

static GWorkspace *gworkspace = nil;

@implementation GWorkspace

#ifndef byname
  #define byname 0
  #define bykind 1
  #define bydate 2
  #define bysize 3
  #define byowner 4
#endif

#ifndef CACHED_MAX
  #define CACHED_MAX 20
#endif

#ifndef TSHF_MAXF
  #define TSHF_MAXF 999
#endif

//
// GWProtocol
//
+ (GWorkspace *)gworkspace
{
	if (gworkspace == nil) {
		gworkspace = [[GWorkspace alloc] init];
	}	
  return gworkspace;
}

- (BOOL)performFileOperation:(NSString *)operation 
                      source:(NSString *)source 
                 destination:(NSString *)destination 
                       files:(NSArray *)files 
                         tag:(int *)tag
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *confirmString = [operation stringByAppendingString: @"Confirm"];
  BOOL confirm = !([defaults boolForKey: confirmString]);
  NSRect scr = [[NSScreen mainScreen] visibleFrame];
  NSRect wrect = NSZeroRect;
  FileOperation *op;
  NSRect wr;
  int i;

#define WMARGIN 50
#define WSHIFT 10
  
  scr.origin.x += WMARGIN;
  scr.origin.y += WMARGIN;
  scr.size.width -= (WMARGIN * 2);
  scr.size.height -= (WMARGIN * 2);

  for (i = 0; i < [operations count]; i++) {
    op = [operations objectAtIndex: i];
    wr = [op winRect];
    
    if (NSEqualRects(wr, NSZeroRect) == NO) {
      wrect = NSMakeRect(wr.origin.x + WSHIFT, 
                         wr.origin.y - wr.size.height - WSHIFT,
                         wr.size.width,
                         wr.size.height);
      
      if (NSContainsRect(scr, wrect) == NO) {
        wrect = NSMakeRect(scr.origin.x, 
                           scr.size.height - wr.size.height,
                           wr.size.width, 
                           wr.size.height);
        break;
      }
    }
  }
  	
  op = [[FileOperation alloc] initWithOperation: operation
                                         source: source 
                                    destination: destination 
                                          files: files
                                useConfirmation: confirm 
                                     showWindow: showFileOpStatus 
                                     windowRect: wrect];
  [operations addObject: op];
  RELEASE (op);
  
  return YES;
}

- (void)performFileOperationWithDictionary:(id)opdict
{
	NSString *operation = [opdict objectForKey: @"operation"];
	NSString *source = [opdict objectForKey: @"source"];
	NSString *destination = [opdict objectForKey: @"destination"];
	NSArray *files = [opdict objectForKey: @"files"];
	int tag;
	
	[self performFileOperation: operation source: source 
											destination: destination files: files tag: &tag];
}

- (BOOL)application:(NSApplication *)theApplication 
           openFile:(NSString *)filename
{
  BOOL isDir;
  
  if ([filename isAbsolutePath] 
                    && [fm fileExistsAtPath: filename isDirectory: &isDir]) {
    if (isDir) {
      id viewer = [self newViewerAtPath: filename
                            canViewApps: [GWLib isPakageAtPath: filename]];
      [viewer orderFrontRegardless];
      return YES;
    } else {
      [self selectFile: filename 
        inFileViewerRootedAtPath: [filename stringByDeletingLastPathComponent]];
      [self openFile: filename];
      return YES;
    }
  } 

  return NO;
}

- (BOOL)openFile:(NSString *)fullPath
{
	NSPoint p = [currentViewer locationOfIconForPath: fullPath];
	NSView *aview = [currentViewer viewer];
	NSImage *image;
  NSString *defApp; 
  NSString *type;

  [ws getInfoForFile: fullPath application: &defApp type: &type];
	image = [GWLib iconForFile: fullPath ofType: type];
  
	return [self openFile: fullPath fromImage: image at: p inView: aview];
}

- (BOOL)openFile:(NSString *)fullPath 
			 fromImage:(NSImage *)anImage 
			  			at:(NSPoint)point 
					inView:(NSView *)aView
{
	NSString *appName;
  NSString *type;
	id fiendLeaf;
	id app;
	NSPoint toPoint;
	BOOL dissolved;
	
#define RETURN_OPEN \
return [ws openFile: fullPath withApplication: appName]
  
  [ws getInfoForFile: fullPath application: &appName type: &type];
	
	if (appName == nil) {
		appName = defEditor;
	}		

	if (animateLaunck == NO)  RETURN_OPEN;
  
  if ((fiend == nil) || ([[fiend myWin] isVisible] == NO)) RETURN_OPEN;
	
	fiendLeaf = [fiend fiendLeafOfType: NSApplicationFileType withName: appName];
	if (fiendLeaf == nil) RETURN_OPEN;
	
	app = [self connectApplication: appName];
	if (app == nil) {
		dissolved = [fiend dissolveLeaf: fiendLeaf];
	}
	
	if (point.x <= 0 || point.y <= 0) RETURN_OPEN;

	toPoint = [fiend positionOfLeaf: fiendLeaf];
	if (toPoint.x <= 0 || toPoint.y <= 0) RETURN_OPEN;
			
	point = [[aView window] convertBaseToScreen: point];
	[self slideImage: anImage from: point to: toPoint];
	
	RETURN_OPEN;
}

- (BOOL)selectFile:(NSString *)fullPath
											inFileViewerRootedAtPath:(NSString *)rootFullpath
{
	NSArray *paths;
	int l1, l2;
	BOOL isdirRoot, isdirFpath;
	BOOL newViewer = YES;

	if ([fm fileExistsAtPath: fullPath isDirectory: &isdirFpath] == NO) {
		return NO;
	}
	
	if ((rootFullpath == nil) || ([rootFullpath length] == 0)) {
		newViewer = NO;
	} else if (([fm fileExistsAtPath: rootFullpath isDirectory: &isdirRoot] && isdirRoot) == NO) {
		return NO;
	}
	
	l1 = [rootFullpath length];
	l2 = [fullPath length];  

	if ((l1 > l2) || ((l1 == l2) && (isdirFpath == NO))) {
		return NO;
	}

	if (newViewer) {
		if ([[fullPath substringToIndex: l1] isEqualToString: rootFullpath] == NO) {
			return NO;
		}
	}
	
	paths = [NSArray arrayWithObject: fullPath];
	
	if (newViewer) {
		ViewersWindow *viewer = [self viewerRootedAtPath: rootFullpath];
    
    if ((viewer == nil) || ([rootFullpath isEqual: fixPath(@"/", 0)])) {
      NSString *app, *type;
		  [ws getInfoForFile: rootFullpath application: &app type: &type];
		  viewer = [self newViewerAtPath: rootFullpath canViewApps: (type == NSApplicationFileType)];
		}
    
    [viewer setViewerSelection: paths];
		[viewer orderFrontRegardless];
	} else {
	  [self setSelectedPaths: paths];
		[rootViewer setViewerSelection: paths];
	}
				
	return YES;
}

- (void)rootViewerSelectFiles:(NSArray *)paths
{
  [rootViewer makeKeyAndOrderFront: nil];
  [self setSelectedPaths: paths];
  [rootViewer setViewerSelection: paths];
}

- (void)slideImage:(NSImage *)image 
							from:(NSPoint)fromPoint 
								to:(NSPoint)toPoint
{
	[[NSWorkspace sharedWorkspace] slideImage: image from: fromPoint to: toPoint];
}

- (void)openSelectedPaths:(NSArray *)paths newViewer:(BOOL)newv
{
  NSString *apath;
  NSString *defApp, *type;
  int i;
  
  [self setSelectedPaths: paths];
      
  for (i = 0; i < [paths count]; i++) {
    apath = [paths objectAtIndex: i];
    
    [ws getInfoForFile: apath application: &defApp type: &type];     
    
    if ((type == NSDirectoryFileType) || (type == NSFilesystemFileType)) {
      if (newv) {    
        [self newViewerAtPath: apath canViewApps: NO];    
      }
    } else if ((type == NSPlainFileType) 
                        || ([type isEqual: NSShellCommandFileType])) {
      if ([GWLib isPakageAtPath: apath]) {
        if (newv) {    
          [self newViewerAtPath: apath canViewApps: YES];    
        } else {
          [self openFile: apath];
        }
      } else {
        [self openFile: apath];
      }
    } else if (type == NSApplicationFileType) {
      if (newv) {    
        [self newViewerAtPath: apath canViewApps: YES];    
      } else {
//        NSArray *launched = [ws launchedApplications];
//        BOOL found = NO;
//        int i;
            
//        for (i = 0; i < [launched count]; i++) {
//          NSDictionary *dict = [launched objectAtIndex: i];
//          NSString *applname = [dict objectForKey: @"NSApplicationName"]; 
            
//          if ([applname isEqual: apath]) {
//            found = YES;
//            break;
//          }
//        }
      
//        if (found == NO) {
          [ws launchApplication: apath];
//        }
      }
    }
  }
}

- (void)openSelectedPathsWith
{
  BOOL found = NO;
  int i;

  for (i = 0; i < [selectedPaths count]; i++) {
    NSString *spath = [selectedPaths objectAtIndex: i];
    NSDictionary *attributes = [fm fileAttributesAtPath: spath traverseLink: YES];

    if ([attributes objectForKey: NSFileType] != NSFileTypeDirectory) {
      NSString *defApp, *fileType;

 	    [ws getInfoForFile: spath application: &defApp type: &fileType];

      if((fileType != NSPlainFileType) && (fileType != NSShellCommandFileType)) {
        found = YES;
      }

    }	else {
      found = YES;
    }

    if (found) {
      break;
    }
  }
  
  if (found == NO) {
    [openWithController activate];
  }
}

- (ViewersWindow *)newViewerAtPath:(NSString *)path canViewApps:(BOOL)viewapps
{
  BOOL setSelection = starting ? YES : ([path isEqual: fixPath(@"/", 0)] ? YES : NO);
	ViewersWindow *viewer = [[ViewersWindow alloc] initWithViewerTemplates: viewersTemplates
                                   forPath: path viewPakages: viewapps 
                                        isRootViewer: NO onStart: setSelection];
  [viewer activate];
  [viewers addObject: viewer];
  RELEASE (viewer);
	
	return [viewers objectAtIndex: [viewers count] -1];
}

- (NSArray *)getSelectedPaths
{
  return selectedPaths;
}

- (NSString *)trashPath
{
	return trashPath;
}

- (NSArray *)viewersSearchPaths
{
  return viewersSearchPaths;
}

- (BOOL)animateChdir
{
  return animateChdir;
}

- (BOOL)animateLaunck
{
  return animateLaunck;
}

- (BOOL)animateSlideBack
{
  return animateSlideBack;
}

- (BOOL)usesContestualMenu
{
  return contestualMenu;
}

- (void)addWatcherForPath:(NSString *)path
{
  if (fswnotifications) {
    [self connectFSWatcher];
    [fswatcher client: self addWatcherForPath: path];
  }
}

- (void)removeWatcherForPath:(NSString *)path
{
  if (fswnotifications) {
    [self connectFSWatcher];
    [fswatcher client: self removeWatcherForPath: path];
  }
}
//
// end of GWProtocol
//

+ (void)initialize
{
	static BOOL initialized = NO;
	
	if (initialized == YES) {
		return;
  }
	
	initialized = YES;
}

+ (void)registerForServices
{
	NSArray *sendTypes = [NSArray arrayWithObjects: NSFilenamesPboardType, nil];	
	NSArray *returnTypes = [NSArray arrayWithObjects: NSFilenamesPboardType, nil];	
	[NSApp registerServicesMenuSendTypes: sendTypes returnTypes: returnTypes];
}

- (void)dealloc
{
  if (fswatcher && [[(NSDistantObject *)fswatcher connectionForProxy] isValid]) {
    [fswatcher unregisterClient: (id <FSWClientProtocol>)self];
    DESTROY (fswatcher);
  }
  [[NSDistributedNotificationCenter defaultCenter] removeObserver: self];
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  DESTROY (inspector);
	RELEASE (defEditor);
	RELEASE (defXterm);
	RELEASE (defXtermArgs);
  RELEASE (selectedPaths);
  TEST_RELEASE (rootViewer);
  RELEASE (viewers);  
  TEST_RELEASE (viewersTemplates);
  TEST_RELEASE (viewersSearchPaths);
  TEST_RELEASE (appsViewer);
  TEST_RELEASE (finder);
  TEST_RELEASE (fiend);
	TEST_RELEASE (history);
	TEST_RELEASE (recycler);
  TEST_RELEASE (trashPath);
  RELEASE (openWithController);
  RELEASE (runExtController);
  RELEASE (startAppWin);
  RELEASE (operations);
  TEST_RELEASE (desktopWindow);
  TEST_RELEASE (tshelfWin);
  TEST_RELEASE (tshelfPBDir);
  TEST_RELEASE (tshelfBackground);
  
	[super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSUserDefaults *defaults;
	NSString *processName;
  NSMutableArray *viewersPaths;
  NSString *path;
	id result;
	NSArray *keys;
	NSMutableDictionary *viewersPrefs;
  BOOL hideSysFiles;
  int i, count;
  
	[isa registerForServices];
  
  fm = [NSFileManager defaultManager];
	ws = [NSWorkspace sharedWorkspace];
	    
	defaults = [NSUserDefaults standardUserDefaults];
	processName = [[NSProcessInfo processInfo] processName];    
	[defaults setObject: processName forKey: @"GSWorkspaceApplication"];
        
	result = [defaults stringForKey: @"defaulteditor"];
	if (result == nil) {
		defEditor = [[NSString alloc] initWithString: defaulteditor];
	} else {
		ASSIGN (defEditor, result);
  }

	result = [defaults stringForKey: @"defxterm"];
	if (result == nil) {
		defXterm = [[NSString alloc] initWithString: defaultxterm];
	} else {
		ASSIGN (defXterm, result);
  }

	result = [defaults stringForKey: @"defaultxtermargs"];
	if (result == nil) {
		defXtermArgs = nil;
	} else {
		ASSIGN (defXtermArgs, result);
  }
  
	result = [defaults objectForKey: @"shelfcellswidth"];
	if (result == nil) {
    shelfCellsWidth = 90;
	} else {
    shelfCellsWidth = [result intValue];
  }
		
	result = [defaults objectForKey: @"defaultsorttype"];	
	if (result == nil) { 
		[defaults setObject: @"0" forKey: @"defaultsorttype"];
    [GWLib setDefSortType: byname];
	} else {
    [GWLib setDefSortType: [result intValue]];
	}

  showFileOpStatus = (![defaults boolForKey: @"fopstatusnotshown"]);

  result = [defaults objectForKey: @"GSFileBrowserHideDotFiles"];
  if (result) {
    hideSysFiles = [result boolValue];
  } else {  
    NSDictionary *domain = [defaults persistentDomainForName: NSGlobalDomain];
    
    result = [domain objectForKey: @"GSFileBrowserHideDotFiles"];
    if (result) {
      hideSysFiles = [result boolValue];
    } else {  
      hideSysFiles = NO;
    }
  }
  [GWLib setHideSysFiles: hideSysFiles];
  
	result = [defaults objectForKey: @"hiddendirs"];
	if (result) {
    [GWLib setHiddenPaths: result];
	} 
  
  animateChdir = ![defaults boolForKey: @"nochdiranim"];
  animateLaunck = ![defaults boolForKey: @"nolaunchanim"];
  animateSlideBack = ![defaults boolForKey: @"noslidebackanim"];
  
  contestualMenu = [defaults boolForKey: @"UsesContestualMenu"];

  dontWarnOnQuit = [defaults boolForKey: @"NoWarnOnQuit"];

  usesThumbnails = [defaults boolForKey: @"usesthumbnails"];
  [GWLib setUseThumbnails: usesThumbnails];

	result = [defaults dictionaryForKey: @"viewersprefs"];
	if (result) { 
		viewersPrefs = [result mutableCopy];
	} else {
		viewersPrefs = [[NSMutableDictionary alloc] initWithCapacity: 1];
	}
	keys = [viewersPrefs allKeys];
  for (i = 0; i < [keys count]; i++) {
    BOOL exists, isdir;
		NSString *key = [keys objectAtIndex: i];	
    
    if ([key isEqual: @"rootViewer"] == NO) {
		  exists = [fm fileExistsAtPath: key isDirectory: &isdir];    
		  if((exists == NO) || (isdir == NO)) {
        [viewersPrefs removeObjectForKey: key];
      }
    }
  }  
	[defaults setObject: viewersPrefs forKey: @"viewersprefs"];
	RELEASE (viewersPrefs);

	result = [defaults objectForKey: @"viewerspaths"];
	if (result == nil) {
		viewersPaths = [NSMutableArray new];
	} else {
		viewersPaths = [result mutableCopy];
  }
  count = [viewersPaths count];
  for (i = 0; i < count; i++) {
    BOOL exists, isdir;
    NSString *path = [viewersPaths objectAtIndex: i];
		exists = [fm fileExistsAtPath: path isDirectory: &isdir];    
		if((exists == NO) || (isdir == NO)) {
      [viewersPaths removeObjectAtIndex: i];
      i--;
      count--;
    }
  }  
  [defaults setObject: viewersPaths forKey: @"viewerspaths"];
  RELEASE (viewersPaths);
  
	selectedPaths = [[NSArray alloc] initWithObjects: NSHomeDirectory(), nil];

  operations = [NSMutableArray new];	
  oprefnum = 0;

  startAppWin = [[StartAppWin alloc] init];
  fswatcher = nil;
  fswnotifications = YES;
  [self connectFSWatcher];

  inspector = nil;
  useInspector = ![defaults boolForKey: @"noinspector"];
  if (useInspector) {
    [self connectInspector];
    if (inspector) {
      NSData *data = [NSArchiver archivedDataWithRootObject: selectedPaths];
      [inspector setPathsData: data];
    }
  }

  appsViewer = [[AppsViewer alloc] init];
	history = [[History alloc] init];
  prefController = [[PrefController alloc] init];  
  finder = nil;
  fiend = nil;

  tshelfBackground = nil; 
  [self showHideDesktop: [defaults boolForKey: @"desktop"]];  
  
  if ([defaults boolForKey: @"usefiend"]) {
    [self showFiend: nil];
  } else {
    [self hideFiend: nil];
  }

  tshelfPBFileNum = 0;
  if ([defaults boolForKey: @"tshelf"]) {
    [self showTShelf: nil];
  } else {
    [self hideTShelf: nil];
  }

	[self createRecycler];
  
  openWithController = [[OpenWithController alloc] init];
  runExtController = [[RunExternalController alloc] init];
  	
  starting = YES;
  viewers = [[NSMutableArray alloc] initWithCapacity: 1];
  viewersSearchPaths = [[NSMutableArray alloc] initWithCapacity: 1];
	[self makeViewersTemplates];

  rootViewer = nil;
  [self showViewer: nil];
  
	viewersPaths = [defaults objectForKey: @"viewerspaths"];
  for (i = 0; i < [viewersPaths count]; i++) {
    path = [viewersPaths objectAtIndex: i];    
    [self newViewerAtPath: path 
              canViewApps: ([GWLib isPakageAtPath: path] ? YES : NO)];
  }
    
  result = [defaults objectForKey: @"cachedmax"];
  if (result) {
    [GWLib setCachedMax: [result intValue]];
  } else {  
    [GWLib setCachedMax: CACHED_MAX];
    [defaults setObject: [NSNumber numberWithInt: CACHED_MAX] forKey: @"cachedmax"];
  }  
  
	starting = NO;
  
	[defaults synchronize];

  [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                				selector: @selector(fileSystemWillChange:) 
                					  name: GWFileSystemWillChangeNotification
                					object: nil];

  [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                				selector: @selector(fileSystemDidChange:) 
                					  name: GWFileSystemDidChangeNotification
                					object: nil];

	[[NSNotificationCenter defaultCenter] addObserver: self 
                        selector: @selector(iconAnimationChanged:) 
                					  name: GWIconAnimationChangedNotification
                					object: nil];
  
  [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                        selector: @selector(thumbnailsDidChange:) 
                					  name: GWThumbnailsDidChangeNotification
                					object: nil];

  [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                        selector: @selector(applicationForExtensionsDidChange:) 
                					  name: @"GWAppForExtensionDidChangeNotification"
                					object: nil];
}

- (BOOL)applicationShouldTerminate:(NSApplication *)app 
{
	int i;

#define TEST_CLOSE(o, w) if ((o) && ([w isVisible])) [w close]
  
  if (dontWarnOnQuit == NO) {
    if (NSRunAlertPanel(NSLocalizedString(@"Quit!", @""),
                      NSLocalizedString(@"Do you really want to quit?", @""),
                      NSLocalizedString(@"No", @""),
                      NSLocalizedString(@"Yes", @""),
                      nil)) {
      return NO;
    }
  }

  [self updateDefaults];

	TEST_CLOSE (rootViewer, rootViewer);
	for (i = 0; i < [viewers count]; i++) {
		id vwr = [viewers objectAtIndex: i];
		TEST_CLOSE (vwr, vwr);
	}
	TEST_CLOSE (appsViewer, [appsViewer myWin]);
	TEST_CLOSE (finder, [finder myWin]);
	TEST_CLOSE (prefController, [prefController myWin]);
	TEST_CLOSE (fiend, [fiend myWin]);
	TEST_CLOSE (recycler, [recycler myWin]);
	TEST_CLOSE (recycler, [recycler recyclerWin]);
	TEST_CLOSE (history, [history myWin]); 
	TEST_CLOSE (desktopWindow, desktopWindow);
	TEST_CLOSE (tshelfWin, tshelfWin);
  TEST_CLOSE (startAppWin, [startAppWin win]);

  if (fswatcher) {
    NSConnection *fswconn = [(NSDistantObject *)fswatcher connectionForProxy];
  
    if ([fswconn isValid]) {
      [[NSNotificationCenter defaultCenter] removeObserver: self
	                        name: NSConnectionDidDieNotification
	                      object: fswconn];
      [fswatcher unregisterClient: (id <FSWClientProtocol>)self];  
      DESTROY (fswatcher);
    }
  }

  if (inspector && useInspector) {
    NSConnection *inspconn = [(NSDistantObject *)inspector connectionForProxy];
  
    if (inspconn && [inspconn isValid]) {
      [[NSNotificationCenter defaultCenter] removeObserver: self
	                        name: NSConnectionDidDieNotification
	                      object: inspconn];
      DESTROY (inspector);
    }
  }
  		
	return YES;
}

- (NSString *)defEditor
{
	return defEditor;
}

- (NSString *)defXterm
{
	return defXterm;
}

- (NSString *)defXtermArgs
{
	return defXtermArgs;
}

- (History *)historyWindow
{
	return history;
}

- (id)rootViewer
{
  return rootViewer;
}

- (ViewersWindow *)viewerRootedAtPath:(NSString *)vpath
{
  int i;
  
  for (i = 0; i < [viewers count]; i++) {
    ViewersWindow *viewer = [viewers objectAtIndex: i];
    
    if ([[viewer rootPath] isEqual: vpath]) {
      return viewer;
    }
  }  
  
  return nil;
}

- (id)desktopView
{
  if (desktopWindow != nil) {
    return [desktopWindow desktopView];
  }
  return nil;
}

- (void)showHideDesktop:(BOOL)active
{
	if (active) {
  	if (desktopWindow == nil) {
    	desktopWindow = [[DesktopWindow alloc] init];
    	[desktopWindow activate];
  	} else if ([desktopWindow isVisible] == NO) {
			[desktopWindow activate];
		}
    [self makeTshelfBackground];
	} else {
		if ((desktopWindow != nil) && ([desktopWindow isVisible])) {
      [[desktopWindow desktopView] saveDefaults]; 
      [desktopWindow deactivate]; 
		}
	}
}

- (NSImage *)tshelfBackground
{
  return tshelfBackground;
}

- (void)makeTshelfBackground
{
  if ((desktopWindow != nil) && ([desktopWindow isVisible])) {
    ASSIGN (tshelfBackground, [[desktopWindow desktopView] shelfBackground]);
  }
}

- (NSColor *)tshelfBackColor
{
  if ((desktopWindow != nil) && ([desktopWindow isVisible])) {
    return [[desktopWindow desktopView] backColor];
  }
  return nil;
}

- (NSString *)tshelfPBDir
{
  return tshelfPBDir;
}

- (NSString *)tshelfPBFilePath
{
  NSString *tshelfPBFileNName;

	tshelfPBFileNum++;
  
	if (tshelfPBFileNum >= TSHF_MAXF) {
		tshelfPBFileNum = 0;
	}
  
  tshelfPBFileNName = [NSString stringWithFormat: @"%i", tshelfPBFileNum];
  
  return [tshelfPBDir stringByAppendingPathComponent: tshelfPBFileNName];
}

- (void)changeDefaultEditor:(NSString *)editor
{
  ASSIGN (defEditor, editor);
}

- (void)changeDefaultXTerm:(NSString *)xterm arguments:(NSString *)args
{
  ASSIGN (defXterm, xterm);
  ASSIGN (defXtermArgs, args);
}

- (void)updateDefaults
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSMutableArray *viewersPaths;
  int i;
 
	if ((desktopWindow != nil) && ([desktopWindow isVisible])) {
		[[desktopWindow desktopView] saveDefaults];  
		[defaults setBool: YES forKey: @"desktop"];
	} else {
		[defaults setBool: NO forKey: @"desktop"];
	}

	if ((tshelfWin != nil) && ([tshelfWin isVisible])) {
		[tshelfWin saveDefaults];  
		[defaults setBool: YES forKey: @"tshelf"];
	} else {
		[defaults setBool: NO forKey: @"tshelf"];
	}
  [defaults setObject: [NSString stringWithFormat: @"%i", tshelfPBFileNum]
               forKey: @"tshelfpbfnum"];

	if ([[appsViewer myWin] isVisible]) {  
		[appsViewer updateDefaults]; 
	}
	
	if (finder != nil) {  
		[finder updateDefaults]; 
	}
	
	if ([[prefController myWin] isVisible]) {  
		[prefController updateDefaults]; 
	}
	
	if ((fiend != nil) && ([[fiend myWin] isVisible])) {  
		[fiend updateDefaults]; 
    [defaults setBool: YES forKey: @"usefiend"];
	} else {
    [defaults setBool: NO forKey: @"usefiend"];
	}
  
	[recycler updateDefaults];
	[history updateDefaults];
  [rootViewer updateDefaults];
  
  [defaults setObject: [GWLib hiddenPaths] forKey: @"hiddendirs"];

	viewersPaths = [NSMutableArray arrayWithCapacity: 1];
  for (i = 0; i < [viewers count]; i++) {
    ViewersWindow *viewer = [viewers objectAtIndex: i];
    [viewer updateDefaults];
    [viewersPaths addObject: [viewer rootPath]];
  }  
	
	[defaults setObject: viewersPaths forKey: @"viewerspaths"];
      
	[defaults setObject: defEditor forKey: @"defaulteditor"];
	[defaults setObject: defXterm forKey: @"defxterm"];
  if (defXtermArgs != nil) {
	  [defaults setObject: defXtermArgs forKey: @"defaultxtermargs"];
  }
	
  [defaults setObject: [NSString stringWithFormat: @"%i", shelfCellsWidth]
               forKey: @"shelfcellswidth"];

  [defaults setBool: !animateChdir forKey: @"nochdiranim"];
  [defaults setBool: !animateLaunck forKey: @"nolaunchanim"];
  [defaults setBool: !animateSlideBack forKey: @"noslidebackanim"];

  [defaults setBool: usesThumbnails forKey: @"usesthumbnails"];

	[defaults synchronize];
}

- (void)startXTermOnDirectory:(NSString *)dirPath
{
	NSTask *task = [NSTask new];
	AUTORELEASE (task);
	[task setCurrentDirectoryPath: dirPath];			
	[task setLaunchPath: defXterm];
  if (defXtermArgs != nil) {
	  NSArray *args = [defXtermArgs componentsSeparatedByString:@" "];
	  [task setArguments: args];
  }
	[task launch];
}

- (int)defaultSortType
{
	return [GWLib defSortType];
}

- (void)setDefaultSortType:(int)type
{
  [GWLib setDefSortType: type];
}

- (int)shelfCellsWidth
{
  return shelfCellsWidth;
}

- (int)defaultShelfCellsWidth
{
  [self setShelfCellsWidth: 90];
  return 90;
}

- (void)setShelfCellsWidth:(int)w
{
  shelfCellsWidth = w;
    
	[[NSNotificationCenter defaultCenter]
 				 postNotificationName: GWShelfCellsWidthChangedNotification
	 								     object: nil];  
}

- (void)createRecycler
{
	NSString *basePath, *tpath; 
	BOOL isdir;

  basePath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
  basePath = [basePath stringByAppendingPathComponent: @"GWorkspace"];

  if (([fm fileExistsAtPath: basePath isDirectory: &isdir] && isdir) == NO) {
    if ([fm createDirectoryAtPath: basePath attributes: nil] == NO) {
      NSLog(@"Can't create the GWorkspace directory! Quitting now.");
      [NSApp terminate: self];
    }
  }
  
	tpath = [basePath stringByAppendingPathComponent: @".GWTrash"];

	if ([fm fileExistsAtPath: tpath isDirectory: &isdir] == NO) {
    if ([fm createDirectoryAtPath: tpath attributes: nil] == NO) {
      NSLog(@"Can't create the Recycler directory! Quitting now.");
      [NSApp terminate: self];
    }
	} else {
		if (isdir == NO) {
			NSLog (@"Warning - %@ is not a directory - quitting now!", tpath);			
			[NSApp terminate: self];
		}
  }
  
  ASSIGN (trashPath, tpath);
	recycler = [[Recycler alloc] initWithTrashPath: trashPath];
	[recycler activate];
}

- (void)createTabbedShelf
{
	NSUserDefaults *defaults;  
  id entry;
  NSString *basePath;
  BOOL isdir;

	defaults = [NSUserDefaults standardUserDefaults];
			
  entry = [defaults objectForKey: @"tshelfpbfnum"];
  if (entry) {
    tshelfPBFileNum = [entry intValue];
  } else {
    tshelfPBFileNum = 0;
  }      
       
  basePath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
  basePath = [basePath stringByAppendingPathComponent: @"GWorkspace"];

  if (([fm fileExistsAtPath: basePath isDirectory: &isdir] && isdir) == NO) {
    if ([fm createDirectoryAtPath: basePath attributes: nil] == NO) {
      NSLog(@"Can't create the GWorkspace directory! Quitting now.");
      [NSApp terminate: self];
    }
  }

	tshelfPBDir = [basePath stringByAppendingPathComponent: @"PBData"];

	if ([fm fileExistsAtPath: tshelfPBDir isDirectory: &isdir] == NO) {
    if ([fm createDirectoryAtPath: tshelfPBDir attributes: nil] == NO) {
      NSLog(@"Can't create the TShelf directory! Quitting now.");
      [NSApp terminate: self];
    }
	} else {
		if (isdir == NO) {
			NSLog (@"Warning - %@ is not a directory - quitting now!", tshelfPBDir);			
			[NSApp terminate: self];
		}
  }
  
  RETAIN (tshelfPBDir);

  tshelfWin = [[TShelfWin alloc] init];
}

- (BOOL)validateMenuItem:(NSMenuItem *)anItem 
{	
	NSString *title = [anItem title];
	
	if ([title isEqual: NSLocalizedString(@"Empty Recycler", @"")]) {
		return [recycler isFull];
	} else if ([title isEqual: NSLocalizedString(@"Put Away", @"")]) {
		if ([recycler isFull] && [recycler isFull]) {
			if ([recycler selectedPath] != nil) {
				return YES;
			}
		}		
		return NO;	
	}

	if ([title isEqual: NSLocalizedString(@"File Operations...", @"")]) {
    return [operations count];
  }

	if ([title isEqual: NSLocalizedString(@"Open With...", @"")]) {
    BOOL found = NO;
    int i;
    
    for (i = 0; i < [selectedPaths count]; i++) {
      NSString *spath = [selectedPaths objectAtIndex: i];
      NSDictionary *attributes = [fm fileAttributesAtPath: spath traverseLink: YES];
      
      if ([attributes objectForKey: NSFileType] != NSFileTypeDirectory) {
        NSString *defApp, *fileType;
        
 	      [ws getInfoForFile: spath application: &defApp type: &fileType];
       
        if((fileType != NSPlainFileType) && (fileType != NSShellCommandFileType)) {
          found = YES;
        }
        
      }	else {
        found = YES;
      }
      
      if (found) {
        break;
      }
    }
    
    return !found;
  }
  
	if ([title isEqual: NSLocalizedString(@"Cut", @"")]
          || [title isEqual: NSLocalizedString(@"Copy", @"")]
          || [title isEqual: NSLocalizedString(@"Paste", @"")]) {
    if ((tshelfWin == nil) || ([tshelfWin isVisible] == NO)) {
      return NO;
    } else {
      TShelfView *tview = [tshelfWin shelfView];
      TShelfViewItem *item = [[tshelfWin shelfView] selectedTabItem];
  
      if ([tview hiddenTabs]) {
        return NO;
      }
  
      if (item) {
        TShelfIconsView *iview = (TShelfIconsView *)[item view];
        
        if ([iview iconsType] == DATA_TAB) {
          if ([title isEqual: NSLocalizedString(@"Paste", @"")]) {
            return YES;
          } else {
            return [iview hasSelectedIcon];
          }
        } else {
          return NO;
        }
      } else {
        return NO;
      }
    }
  }
  
	return YES;
}

- (void)makeViewersTemplates
{
	NSMutableArray *bundlesPaths;
	NSArray *bPaths;
  NSString *home;
	int i;
	
#define VERIFY_VIEWERS( x ) \
if (!x) { \
NSRunAlertPanel(NSLocalizedString(@"error", @""), \
NSLocalizedString(@"No Viewer found! Quitting now.", @""), \
NSLocalizedString(@"OK", @""), nil, nil); \
[[NSApplication sharedApplication] terminate: nil];	\
} 

	TEST_RELEASE (viewersTemplates);
  viewersTemplates = [[NSMutableArray alloc] initWithCapacity: 1];
  
  bundlesPaths = [NSMutableArray array];
  
  //load all default Viewers
  bPaths = [self bundlesWithExtension: @"viewer" 
                          inDirectory: [[NSBundle mainBundle] resourcePath]];
	[bundlesPaths addObjectsFromArray: bPaths];
  
	VERIFY_VIEWERS (bundlesPaths && [bundlesPaths count]);																								

  //load user Viewers
  home = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
  [bundlesPaths addObjectsFromArray: [self bundlesWithExtension: @"viewer" 
			     inDirectory: [home stringByAppendingPathComponent: @"GWorkspace"]]];
              
  for (i = 0; i < [bundlesPaths count]; i++) {
		NSString *bpath = [bundlesPaths objectAtIndex: i];
		NSBundle *bundle = [NSBundle bundleWithPath: bpath]; 
		
		if (bundle) {
			Class principalClass = [bundle principalClass];
			
			if (principalClass) {
				if ([principalClass conformsToProtocol: @protocol(ViewersProtocol)]) {	
					id<ViewersProtocol> vwr = AUTORELEASE ([[principalClass alloc] init]);

          [self addViewer: vwr withBundlePath: bpath];
				}
			}
  	}
	}
	
	VERIFY_VIEWERS([viewersTemplates count]);
  
  [[NSNotificationCenter defaultCenter] addObserver: self 
                	selector: @selector(watcherNotification:) 
                			name: GWFileWatcherFileDidChangeNotification
                		object: nil];

  [viewersSearchPaths addObject: [[NSBundle mainBundle] resourcePath]];
  [viewersSearchPaths addObject: [home stringByAppendingPathComponent: @"GWorkspace"]];
    
  for (i = 0; i < [viewersSearchPaths count]; i++) {
    NSString *spath = [viewersSearchPaths objectAtIndex: i];
    [GWLib addWatcherForPath: spath];
  }
}

- (void)addViewer:(id)vwr withBundlePath:(NSString *)bpath
{
	NSString *name = [vwr menuName];
  BOOL found = NO;
  int i = 0;
  
	for (i = 0; i < [viewersTemplates count]; i++) {
		NSDictionary *vdict = [viewersTemplates objectAtIndex: i];
    NSString *vname = [vdict objectForKey: @"name"];
    
    if ([vname isEqual: name]) {
      found = YES;
      break;
    }
	}
  
  if (found == NO) {
	  NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity: 1];

    [dict setObject: vwr forKey: @"viewer"];
	  [dict setObject: name forKey: @"name"];
    [dict setObject: bpath forKey: @"path"];
    [viewersTemplates addObject: dict];
    
    if ([vwr hasPreferences]) {
      [prefController addPreference: [vwr prefController]];
    }

	  [[NSNotificationCenter defaultCenter]
 				  postNotificationName: GWViewersListDidChangeNotification
	 								      object: viewersTemplates];  
  }
}

- (void)removeViewerWithBundlePath:(NSString *)bpath
{
  int i, count;
  
  count = [viewersTemplates count];
	for (i = 0; i < count; i++) {
		NSDictionary *vdict = [viewersTemplates objectAtIndex: i];
    id vwr = [vdict objectForKey: @"viewer"];
    NSString *path = [vdict objectForKey: @"path"];
    
    if ([path isEqual: bpath]) {
      if ((count - 1) == 0) {
        NSRunAlertPanel(NSLocalizedString(@"error", @""), 
             NSLocalizedString(@"No Viewer found! Quitting now.", @""), 
                                    NSLocalizedString(@"OK", @""), nil, nil);                                     
        [[NSApplication sharedApplication] terminate: nil];
      }
      
      if ([vwr hasPreferences]) {
        [prefController removePreference: [vwr prefController]];
      }
      
      [viewersTemplates removeObject: vdict];
      [[NSNotificationCenter defaultCenter]
              postNotificationName: GWViewersListDidChangeNotification
                            object: viewersTemplates];  
      break;
    }
  }
}

- (NSMutableArray *)bundlesWithExtension:(NSString *)extension 
											       inDirectory:(NSString *)dirpath
{
  NSMutableArray *bundleList = [NSMutableArray array];
  NSEnumerator *enumerator;
  NSString *dir;
  BOOL isDir;
  
  if (!(([fm fileExistsAtPath: dirpath isDirectory: &isDir]) && isDir)) {
		return nil;
  }
	  
  enumerator = [[fm directoryContentsAtPath: dirpath] objectEnumerator];
  while ((dir = [enumerator nextObject])) {
    if ([[dir pathExtension] isEqualToString: extension]) {
			[bundleList addObject: [dirpath stringByAppendingPathComponent: dir]];
		}
  }
  
  return bundleList;
}

- (NSArray *)viewersPaths
{
	NSMutableArray *vpaths = [NSMutableArray arrayWithCapacity: 1];
	int i;

	for (i = 0; i < [viewersTemplates count]; i++) {
		NSDictionary *vdict = [viewersTemplates objectAtIndex: i];
		[vpaths addObject: [vdict objectForKey: @"path"]];
	}
	
	return vpaths;
}

- (void)checkViewersAfterHidingOfPaths:(NSArray *)paths
{
  int i = [viewers count] - 1;
  
	while (i >= 0) {
		id viewer = [viewers objectAtIndex: i];
    
    [viewer checkRootPathAfterHidingOfPaths: paths];
    i--;
	}
  
  [rootViewer checkRootPathAfterHidingOfPaths: paths];
  
  if (desktopWindow != nil) {
    [[desktopWindow desktopView] checkIconsAfterHidingOfPaths: paths]; 
	}
  
  if (tshelfWin != nil) {
    [tshelfWin checkIconsAfterHidingOfPaths: paths]; 
	}
  
	if (finder != nil) {  
		[finder checkIconsAfterHidingOfPaths: paths]; 
	}  
}

- (void)watcherNotification:(NSNotification *)notification
{
  NSDictionary *notifdict = (NSDictionary *)[notification object];
  NSString *path = [notifdict objectForKey: @"path"];
  NSArray *vpaths = [self viewersPaths];
  
  if ([viewersSearchPaths containsObject: path] == NO) {
    return;    

  } else {
    NSString *event = [notifdict objectForKey: @"event"];
    int i, count;

    if (event == GWFileDeletedInWatchedDirectory) {
      NSArray *files = [notifdict objectForKey: @"files"];

      count = [files count];
      for (i = 0; i < count; i++) { 
        NSString *fname = [files objectAtIndex: i];
        NSString *bpath = [path stringByAppendingPathComponent: fname];
        
        if ([vpaths containsObject: bpath]) { 
          [self removeViewerWithBundlePath: bpath];      
          i--;
          count--;
        }
      }

    } else if (event == GWFileCreatedInWatchedDirectory) {
      NSArray *files = [notifdict objectForKey: @"files"];
      
      for (i = 0; i < [files count]; i++) { 
        NSString *fname = [files objectAtIndex: i];
        NSString *bpath = [path stringByAppendingPathComponent: fname];
        NSBundle *bundle = [NSBundle bundleWithPath: bpath]; 
		
		    if (bundle) {
			    Class principalClass = [bundle principalClass];

			    if (principalClass) {
				    if ([principalClass conformsToProtocol: @protocol(ViewersProtocol)]) {	
					    id<ViewersProtocol> vwr = AUTORELEASE ([[principalClass alloc] init]);

              [self addViewer: vwr withBundlePath: bpath];
				    }
			    }
  	    }
      }
    }
  }
}

- (void)viewerHasClosed:(id)sender
{
  if (sender != rootViewer) {
    [viewers removeObject: sender];
  }
}

- (void)setCurrentViewer:(ViewersWindow *)viewer
{
  currentViewer = viewer;
}

- (void)iconAnimationChanged:(NSNotification *)notif
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];     
  
  animateChdir = ![defaults boolForKey: @"nochdiranim"];
  animateLaunck = ![defaults boolForKey: @"nolaunchanim"];
  animateSlideBack = ![defaults boolForKey: @"noslidebackanim"];
}

- (BOOL)showFileOpStatus
{
  return showFileOpStatus;
}
           
- (void)setShowFileOpStatus:(BOOL)value
{
  if (showFileOpStatus != value) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];     
    showFileOpStatus = value;  
    [defaults setBool: !showFileOpStatus forKey: @"fopstatusnotshown"];
    [defaults synchronize];
  }
}

- (void)fileSystemWillChange:(NSNotification *)notif
{
  NSDictionary *info = [notif userInfo];
  NSString *operation = [info objectForKey: @"operation"];
  NSString *source = [info objectForKey: @"source"];
  NSString *destination = [info objectForKey: @"destination"];
  NSArray *files = [info objectForKey: @"files"];
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity: 1];		
  NSString *opPtr = nil;

  if ([operation isEqual: NSWorkspaceMoveOperation]) {
    opPtr = NSWorkspaceMoveOperation;    
  } else if ([operation isEqual: NSWorkspaceCopyOperation]) {
    opPtr = NSWorkspaceCopyOperation;    
  } else if ([operation isEqual: NSWorkspaceLinkOperation]) {
    opPtr = NSWorkspaceLinkOperation;    
  } else if ([operation isEqual: NSWorkspaceDuplicateOperation]) {
    opPtr = NSWorkspaceDuplicateOperation;    
  } else if ([operation isEqual: NSWorkspaceDestroyOperation]) {
    opPtr = NSWorkspaceDestroyOperation;    
  } else if ([operation isEqual: NSWorkspaceRecycleOperation]) {
    opPtr = NSWorkspaceRecycleOperation;    
  } else if ([operation isEqual: GWorkspaceRecycleOutOperation]) {
    opPtr = GWorkspaceRecycleOutOperation;    
  } else if ([operation isEqual: GWorkspaceEmptyRecyclerOperation]) {
    opPtr = GWorkspaceEmptyRecyclerOperation;    
  }

  if (opPtr == NSWorkspaceMoveOperation   
     || opPtr == NSWorkspaceCopyOperation 
        || opPtr == NSWorkspaceLinkOperation
           || opPtr == NSWorkspaceDuplicateOperation
						 || opPtr == NSWorkspaceRecycleOperation
							 || opPtr == GWorkspaceRecycleOutOperation) { 
    if ([viewersSearchPaths containsObject: destination] == NO) {
      [GWLib lockFiles: files inDirectoryAtPath: destination];
    }
  }

  if (opPtr == NSWorkspaceMoveOperation 
        || opPtr == NSWorkspaceDestroyOperation
				|| opPtr == NSWorkspaceRecycleOperation
				|| opPtr == GWorkspaceRecycleOutOperation
				|| opPtr == GWorkspaceEmptyRecyclerOperation) {
    if ([viewersSearchPaths containsObject: source] == NO) {
      [GWLib lockFiles: files inDirectoryAtPath: source];
    }
  }

	[dict setObject: opPtr forKey: @"operation"];	
  [dict setObject: source forKey: @"source"];	
  [dict setObject: destination forKey: @"destination"];	
  [dict setObject: files forKey: @"files"];	

  [[NSNotificationCenter defaultCenter]
 				postNotificationName: GWFileSystemWillChangeNotification
	 								        object: dict];
}

- (void)fileSystemDidChange:(NSNotification *)notif
{
  NSDictionary *info = [notif userInfo];
  NSString *operation = [info objectForKey: @"operation"];
  NSString *source = [info objectForKey: @"source"];
  NSString *destination = [info objectForKey: @"destination"];
  NSArray *files = [info objectForKey: @"files"];
  NSArray *origfiles = [info objectForKey: @"origfiles"];
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity: 1];		
  NSString *opPtr = nil;

  if ([operation isEqual: NSWorkspaceMoveOperation]) {
    opPtr = NSWorkspaceMoveOperation;    
  } else if ([operation isEqual: NSWorkspaceCopyOperation]) {
    opPtr = NSWorkspaceCopyOperation;    
  } else if ([operation isEqual: NSWorkspaceLinkOperation]) {
    opPtr = NSWorkspaceLinkOperation;    
  } else if ([operation isEqual: NSWorkspaceDuplicateOperation]) {
    opPtr = NSWorkspaceDuplicateOperation;    
  } else if ([operation isEqual: NSWorkspaceDestroyOperation]) {
    opPtr = NSWorkspaceDestroyOperation;    
  } else if ([operation isEqual: NSWorkspaceRecycleOperation]) {
    opPtr = NSWorkspaceRecycleOperation;    
  } else if ([operation isEqual: GWorkspaceRecycleOutOperation]) {
    opPtr = GWorkspaceRecycleOutOperation;    
  } else if ([operation isEqual: GWorkspaceEmptyRecyclerOperation]) {
    opPtr = GWorkspaceEmptyRecyclerOperation;    
  }

  if (opPtr == NSWorkspaceMoveOperation 
     || opPtr == NSWorkspaceCopyOperation
        || opPtr == NSWorkspaceLinkOperation
           || opPtr == NSWorkspaceDuplicateOperation
						 || opPtr == NSWorkspaceRecycleOperation
							 || opPtr == GWorkspaceRecycleOutOperation) { 
		[GWLib unLockFiles: origfiles inDirectoryAtPath: destination];	
  }

  if (opPtr == NSWorkspaceMoveOperation 
        || opPtr == NSWorkspaceDestroyOperation
				|| opPtr == NSWorkspaceRecycleOperation
				|| opPtr == GWorkspaceRecycleOutOperation
				|| opPtr == GWorkspaceEmptyRecyclerOperation) {
    [GWLib unLockFiles: origfiles inDirectoryAtPath: source];
  }

	[dict setObject: opPtr forKey: @"operation"];	
  [dict setObject: source forKey: @"source"];	
  [dict setObject: destination forKey: @"destination"];	
  [dict setObject: files forKey: @"files"];	

	[[NSNotificationCenter defaultCenter]
 				postNotificationName: GWFileSystemDidChangeNotification
	 								    object: dict];
}

- (void)setSelectedPaths:(NSArray *)paths
{
  if (paths && ([selectedPaths isEqualToArray: paths] == NO)) {
    ASSIGN (selectedPaths, paths);

    if (inspector && useInspector) {
      NSData *data = [NSArchiver archivedDataWithRootObject: selectedPaths];
      [inspector setPathsData: data];
    }
  }
}

- (void)resetSelectedPaths
{
  if (selectedPaths == nil) {
    return;
  }
  
  if (inspector && useInspector) {
    NSData *data = [NSArchiver archivedDataWithRootObject: selectedPaths];
    [inspector setPathsData: data];
  }    
				
  [[NSNotificationCenter defaultCenter]
 				 postNotificationName: GWCurrentSelectionChangedNotification
	 								        object: nil];    
}

- (void)setSelectedPaths:(NSArray *)paths 
         fromDesktopView:(DesktopView *)view
{
  [rootViewer makeKeyAndOrderFront: nil];
  [self setSelectedPaths: paths];
  [rootViewer setViewerSelection: paths];
}

- (void)setSelectedPaths:(NSArray *)paths 
         fromDesktopView:(DesktopView *)view
            animateImage:(NSImage *)image 
         startingAtPoint:(NSPoint)startp
{
  #define SELRETURN \
  [self setSelectedPaths: paths]; \
  [rootViewer setViewerSelection: paths]; \
  return

  NSPoint endp = [rootViewer positionForSlidedImage];

  [rootViewer makeKeyAndOrderFront: nil];

  if (animateChdir == NO) {
    SELRETURN;
  }

  if (startp.x <= 0 || startp.y <= 0) {
    SELRETURN;
  }

  if (endp.x <= 0 || endp.y <= 0) {
    SELRETURN;
  }

  [self slideImage: image from: startp to: endp];

  SELRETURN;
}  

- (NSArray *)selectedPaths
{
  return selectedPaths;
}

- (void)showPasteboardData:(NSData *)data 
                    ofType:(NSString *)type
                  typeIcon:(NSImage *)icon
{
  if (inspector && useInspector) {
    if ([inspector canDisplayDataOfType: type]) {
      [inspector showData: data ofType: type];
    }
  }
}

- (void)newObjectAtPath:(NSString *)basePath isDirectory:(BOOL)directory
{
  NSString *fullPath;
	NSString *fileName;
	NSString *operation;
  NSMutableDictionary *notifObj;  
  int suff;
    
	if ([self verifyFileAtPath: basePath] == NO) {
		return;
	}
	
	if ([fm isWritableFileAtPath: basePath] == NO) {
		NSString *err = NSLocalizedString(@"Error", @"");
		NSString *msg = NSLocalizedString(@"You have not write permission\nfor", @"");
		NSString *buttstr = NSLocalizedString(@"Continue", @"");
    NSRunAlertPanel(err, [NSString stringWithFormat: @"%@ \"%@\"!\n", msg, basePath], buttstr, nil, nil);   
		return;
	}

  if (directory == YES) {
    fileName = @"NewFolder";
    operation = GWorkspaceCreateDirOperation;
  } else {
    fileName = @"NewFile";
    operation = GWorkspaceCreateFileOperation;
  }

  fullPath = [basePath stringByAppendingPathComponent: fileName];
  	
  if ([fm fileExistsAtPath: fullPath]) {    
    suff = 1;
    while (1) {    
      NSString *s = [fileName stringByAppendingFormat: @"%i", suff];
      fullPath = [basePath stringByAppendingPathComponent: s];
      if ([fm fileExistsAtPath: fullPath] == NO) {
        fileName = [NSString stringWithString: s];
        break;      
      }      
      suff++;
    }     
  }

	notifObj = [NSMutableDictionary dictionaryWithCapacity: 1];		
	[notifObj setObject: operation forKey: @"operation"];	
  [notifObj setObject: @"" forKey: @"source"];	
  [notifObj setObject: basePath forKey: @"destination"];	
  [notifObj setObject: [NSArray arrayWithObjects: fileName, nil] forKey: @"files"];	

	[[NSNotificationCenter defaultCenter]
 				 postNotificationName: GWFileSystemWillChangeNotification
	 								object: notifObj];

  if (directory == YES) {
    [fm createDirectoryAtPath: fullPath attributes: nil];
  } else {
	  [fm createFileAtPath: fullPath contents: nil attributes: nil];
  }

	[[NSNotificationCenter defaultCenter]
 				 postNotificationName: GWFileSystemDidChangeNotification
	 								object: notifObj];
}

- (void)duplicateFiles
{
  NSString *basePath;
  NSMutableArray *files;
  int tag, i;

  basePath = [NSString stringWithString: [selectedPaths objectAtIndex: 0]];
  basePath = [basePath stringByDeletingLastPathComponent];

	if ([fm isWritableFileAtPath: basePath] == NO) {
		NSString *err = NSLocalizedString(@"Error", @"");
		NSString *msg = NSLocalizedString(@"You have not write permission\nfor", @"");
		NSString *buttstr = NSLocalizedString(@"Continue", @"");
    NSRunAlertPanel(err, [NSString stringWithFormat: @"%@ \"%@\"!\n", msg, basePath], buttstr, nil, nil);   
		return;
	}

  files = [NSMutableArray arrayWithCapacity: 1];
  for (i = 0; i < [selectedPaths count]; i++) {
    [files addObject: [[selectedPaths objectAtIndex: i] lastPathComponent]];
  }

  [self performFileOperation: NSWorkspaceDuplicateOperation 
              source: basePath destination: basePath files: files tag: &tag];
}

- (void)deleteFiles
{
  NSString *basePath;
  NSMutableArray *files;
  int tag, i;

  basePath = [NSString stringWithString: [selectedPaths objectAtIndex: 0]];
  basePath = [basePath stringByDeletingLastPathComponent];

	if ([fm isWritableFileAtPath: basePath] == NO) {
		NSString *err = NSLocalizedString(@"Error", @"");
		NSString *msg = NSLocalizedString(@"You have not write permission\nfor", @"");
		NSString *buttstr = NSLocalizedString(@"Continue", @"");
    NSRunAlertPanel(err, [NSString stringWithFormat: @"%@ \"%@\"!\n", msg, basePath], buttstr, nil, nil);   
		return;
	}

  files = [NSMutableArray arrayWithCapacity: 1];
  for (i = 0; i < [selectedPaths count]; i++) {
    [files addObject: [[selectedPaths objectAtIndex: i] lastPathComponent]];
  }

  [self performFileOperation: NSWorkspaceDestroyOperation 
              source: basePath destination: basePath files: files tag: &tag];
}

- (BOOL)verifyFileAtPath:(NSString *)path
{
	if ([fm fileExistsAtPath: path] == NO) {
		NSString *err = NSLocalizedString(@"Error", @"");
		NSString *msg = NSLocalizedString(@": no such file or directory!", @"");
		NSString *buttstr = NSLocalizedString(@"Continue", @"");
		NSMutableDictionary *notifObj = [NSMutableDictionary dictionaryWithCapacity: 1];		
		NSString *basePath = [path stringByDeletingLastPathComponent];
		
    NSRunAlertPanel(err, [NSString stringWithFormat: @"%@%@", path, msg], buttstr, nil, nil);   

		[notifObj setObject: NSWorkspaceDestroyOperation forKey: @"operation"];	
  	[notifObj setObject: basePath forKey: @"source"];	
  	[notifObj setObject: basePath forKey: @"destination"];	
  	[notifObj setObject: [NSArray arrayWithObjects: path, nil] forKey: @"files"];	

		[[NSNotificationCenter defaultCenter]
 					 postNotificationName: GWFileSystemWillChangeNotification
	 									object: notifObj];

		[[NSNotificationCenter defaultCenter]
 				  postNotificationName: GWFileSystemDidChangeNotification
	 									object: notifObj];
		return NO;
	}
	
	return YES;
}

- (void)setUsesThumbnails:(BOOL)value
{
  int i;
  
  if (usesThumbnails == value) {
    return;
  }
  
  [GWLib setUseThumbnails: value];
  
  usesThumbnails = value;
  
  [rootViewer thumbnailsDidChangeInPaths: nil];
  for (i = 0; i < [viewers count]; i++) {
		[[viewers objectAtIndex: i] thumbnailsDidChangeInPaths: nil];
	}
  if ((desktopWindow != nil) && ([desktopWindow isVisible])) {
    [[desktopWindow desktopView] updateIcons]; 
	}
  if ((tshelfWin != nil) && ([tshelfWin isVisible])) {
    [tshelfWin updateIcons]; 
	}
	if (finder != nil) {  
		[finder updateIcons]; 
	}
}

- (void)thumbnailsDidChange:(NSNotification *)notif
{
  NSDictionary *info = [notif userInfo];
  NSArray *deleted = [info objectForKey: @"deleted"];	
  NSArray *created = [info objectForKey: @"created"];	
  NSMutableArray *tmbdirs = [NSMutableArray array];
  int i;

  if (usesThumbnails == NO) {
    return;
  } else {
    NSString *thumbnailDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];

    thumbnailDir = [thumbnailDir stringByAppendingPathComponent: @"Thumbnails"];
  
    if ([deleted count]) {
      for (i = 0; i < [deleted count]; i++) {
        NSString *path = [deleted objectAtIndex: i];
        NSString *dir = [path stringByDeletingLastPathComponent];

        if ([tmbdirs containsObject: dir] == NO) {
          [tmbdirs addObject: dir];
        }
      }

      [rootViewer thumbnailsDidChangeInPaths: tmbdirs];
      for (i = 0; i < [viewers count]; i++) {
		    [[viewers objectAtIndex: i] thumbnailsDidChangeInPaths: tmbdirs];
	    }
      if ((desktopWindow != nil) && ([desktopWindow isVisible])) {
        [[desktopWindow desktopView] updateIcons]; 
		  }
      if ((tshelfWin != nil) && ([tshelfWin isVisible])) {
        [tshelfWin updateIcons]; 
		  }
	    if (finder != nil) {  
		    [finder updateIcons]; 
	    }

      [tmbdirs removeAllObjects];
    }

    if ([created count]) {
      NSString *dictName = @"thumbnails.plist";
      NSString *dictPath = [thumbnailDir stringByAppendingPathComponent: dictName];
      NSDictionary *tdict = [NSDictionary dictionaryWithContentsOfFile: dictPath];

      for (i = 0; i < [created count]; i++) {
        NSString *key = [created objectAtIndex: i];
        NSString *dir = [key stringByDeletingLastPathComponent];
        NSString *tumbname = [tdict objectForKey: key];
        NSString *tumbpath = [thumbnailDir stringByAppendingPathComponent: tumbname]; 

        if ([fm fileExistsAtPath: tumbpath]) {        
          if ([tmbdirs containsObject: dir] == NO) {
            [tmbdirs addObject: dir];
          }
        }
      }

      [rootViewer thumbnailsDidChangeInPaths: tmbdirs];
      for (i = 0; i < [viewers count]; i++) {
		    [[viewers objectAtIndex: i] thumbnailsDidChangeInPaths: tmbdirs];
	    }
      if ((desktopWindow != nil) && ([desktopWindow isVisible])) {
        [[desktopWindow desktopView] updateIcons]; 
		  }
      if ((tshelfWin != nil) && ([tshelfWin isVisible])) {
        [tshelfWin updateIcons]; 
		  }
	    if (finder != nil) {  
		    [finder updateIcons]; 
	    }
    }
  }
}

- (void)applicationForExtensionsDidChange:(NSNotification *)notif
{
  NSDictionary *changedInfo = [notif userInfo];
  NSString *app = [changedInfo objectForKey: @"app"];
  NSArray *extensions = [changedInfo objectForKey: @"exts"];
  int i;

  for (i = 0; i < [extensions count]; i++) {
    [[NSWorkspace sharedWorkspace] setBestApp: app
                                       inRole: nil 
                                 forExtension: [extensions objectAtIndex: i]];  
  }
}

- (void)connectFSWatcher
{
  if (fswatcher == nil) {
    id fsw = [NSConnection rootProxyForConnectionWithRegisteredName: @"fswatcher" 
                                                               host: @""];

    if (fsw) {
      NSConnection *c = [fsw connectionForProxy];

	    [[NSNotificationCenter defaultCenter] addObserver: self
	                   selector: @selector(fswatcherConnectionDidDie:)
		                     name: NSConnectionDidDieNotification
		                   object: c];
      
      fswatcher = fsw;
	    [fswatcher setProtocolForProxy: @protocol(FSWatcherProtocol)];
      RETAIN (fswatcher);
                                   
	    [fswatcher registerClient: (id <FSWClientProtocol>)self];
      
	  } else {
	    static BOOL recursion = NO;
	    static NSString	*cmd = nil;

	    if (recursion == NO) {
        if (cmd == nil) {
            cmd = RETAIN ([[NSSearchPathForDirectoriesInDomains(
                      GSToolsDirectory, NSSystemDomainMask, YES) objectAtIndex: 0]
                            stringByAppendingPathComponent: @"fswatcher"]);
		    }
      }
	  
      if (recursion == NO && cmd != nil) {
        int i;
        
        [startAppWin showWindowWithTitle: @"GWorkspace"
                                 appName: @"fswatcher"
                            maxProgValue: 40.0];

	      [NSTask launchedTaskWithLaunchPath: cmd arguments: nil];
        RELEASE (cmd);
        
        for (i = 1; i <= 40; i++) {
          [startAppWin updateProgressBy: 1.0];
	        [[NSRunLoop currentRunLoop] runUntilDate:
		                       [NSDate dateWithTimeIntervalSinceNow: 0.1]];
                           
          fsw = [NSConnection rootProxyForConnectionWithRegisteredName: @"fswatcher" 
                                                                  host: @""];                  
          if (fsw) {
            [startAppWin updateProgressBy: 40.0 - i];
            break;
          }
        }
        
        [[startAppWin win] close];
        
	      recursion = YES;
	      [self connectFSWatcher];
	      recursion = NO;
        
	    } else { 
	      recursion = NO;
        fswnotifications = NO;
        NSRunAlertPanel(nil,
                NSLocalizedString(@"unable to contact fswatcher\nfswatcher notifications disabled!", @""),
                NSLocalizedString(@"Ok", @""),
                nil, 
                nil);  
      }
	  }
  }
}

- (void)fswatcherConnectionDidDie:(NSNotification *)notif
{
  id connection = [notif object];

  [[NSNotificationCenter defaultCenter] removeObserver: self
	                    name: NSConnectionDidDieNotification
	                  object: connection];

  NSAssert(connection == [fswatcher connectionForProxy],
		                                  NSInternalInconsistencyException);
  RELEASE (fswatcher);
  fswatcher = nil;

  if (NSRunAlertPanel(nil,
                    NSLocalizedString(@"The fswatcher connection died.\nDo you want to restart it?", @""),
                    NSLocalizedString(@"Yes", @""),
                    NSLocalizedString(@"No", @""),
                    nil)) {
    [self connectFSWatcher];                
  } else {
    fswnotifications = NO;
    NSRunAlertPanel(nil,
                    NSLocalizedString(@"fswatcher notifications disabled!", @""),
                    NSLocalizedString(@"Ok", @""),
                    nil, 
                    nil);  
  }
}

- (void)watchedPathDidChange:(NSData *)dirinfo
{
  NSMutableDictionary *info = [[NSUnarchiver unarchiveObjectWithData: dirinfo] mutableCopy];
  NSString *event = [info objectForKey: @"event"];

  if ([event isEqual: @"GWWatchedDirectoryDeleted"]) {
    [info setObject: GWWatchedDirectoryDeleted forKey: @"event"];
  }

  if ([event isEqual: @"GWFileDeletedInWatchedDirectory"]) {
    [info setObject: GWFileDeletedInWatchedDirectory forKey: @"event"];
  }

  if ([event isEqual: @"GWFileCreatedInWatchedDirectory"]) {
    [info setObject: GWFileCreatedInWatchedDirectory forKey: @"event"];
  }

	[[NSNotificationCenter defaultCenter]
 				 postNotificationName: GWFileWatcherFileDidChangeNotification
	 								     object: info];  
                       
  RELEASE (info);
}

- (void)connectInspector
{
  if (inspector == nil) {
    id insp = [NSConnection rootProxyForConnectionWithRegisteredName: @"Inspector" 
                                                                host: @""];

    if (insp) {
      NSConnection *c = [insp connectionForProxy];

	    [[NSNotificationCenter defaultCenter] addObserver: self
	                   selector: @selector(inspectorConnectionDidDie:)
		                     name: NSConnectionDidDieNotification
		                   object: c];
      
      inspector = insp;
	    [inspector setProtocolForProxy: @protocol(InspectorProtocol)];
      RETAIN (inspector);
      useInspector = YES;
      
	  } else {
	    static BOOL recursion = NO;
	  
      if (recursion == NO) {
        int i;
        
        [startAppWin showWindowWithTitle: @"GWorkspace"
                                 appName: @"Inspector"
                            maxProgValue: 40.0];

        [ws launchApplication: @"Inspector"];

        for (i = 1; i <= 40; i++) {
          [startAppWin updateProgressBy: 1.0];
	        [[NSRunLoop currentRunLoop] runUntilDate:
		                       [NSDate dateWithTimeIntervalSinceNow: 0.1]];
          insp = [NSConnection rootProxyForConnectionWithRegisteredName: @"Inspector" 
                                                                   host: @""];                  
          if (insp) {
            [startAppWin updateProgressBy: 40.0 - i];
            break;
          }
        }
        
        [[startAppWin win] close];
        
	      recursion = YES;
	      [self connectInspector];
	      recursion = NO;
        
	    } else { 
	      recursion = NO;
        useInspector = NO;
        NSRunAlertPanel(nil,
                NSLocalizedString(@"unable to contact Inspector!", @""),
                NSLocalizedString(@"Ok", @""),
                nil, 
                nil);  
      }
	  }
  }
}

- (void)inspectorConnectionDidDie:(NSNotification *)notif
{
  id connection = [notif object];

  [[NSNotificationCenter defaultCenter] removeObserver: self
	                    name: NSConnectionDidDieNotification
	                  object: connection];

  NSAssert(connection == [inspector connectionForProxy],
		                                  NSInternalInconsistencyException);
  RELEASE (inspector);
  inspector = nil;

  if (NSRunAlertPanel(nil,
                    NSLocalizedString(@"The Inspector connection died.\nDo you want to restart it?", @""),
                    NSLocalizedString(@"Yes", @""),
                    NSLocalizedString(@"No", @""),
                    nil)) {
    [self connectInspector]; 
     
    if (inspector) {
      NSData *data = [NSArchiver archivedDataWithRootObject: selectedPaths];
      [inspector setPathsData: data];
    }
                  
  } else {
    useInspector = NO;
  }
}

- (id)connectApplication:(NSString *)appName
{
	NSString *host;
	NSString *port;
	id app = nil;

	host = [[NSUserDefaults standardUserDefaults] stringForKey: @"NSHost"];
	if (host == nil) {
		host = @"";
	} else {
		NSHost *h = [NSHost hostWithName: host];
		
		if ([h isEqual: [NSHost currentHost]] == YES) {
	  	host = @"";
		}
	}
  
	port = [appName stringByDeletingPathExtension];

	NS_DURING
		{
			app = [NSConnection rootProxyForConnectionWithRegisteredName: port  
                                                              host: host];
		}
	NS_HANDLER
		{
			app = nil;
	}
	NS_ENDHANDLER

	return app;
}

//
// NSServicesRequests protocol
//

- (id)validRequestorForSendType:(NSString *)sendType
                     returnType:(NSString *)returnType
{	
  BOOL sendOK = NO;
  BOOL returnOK = NO;

  if (sendType == nil) {
		sendOK = YES;
	} else if ([sendType isEqual: NSFilenamesPboardType] && (selectedPaths != nil)) {
		sendOK = YES;
	}

  if (returnType == nil) {
		returnOK = YES;
	} else if ([returnType isEqual: NSFilenamesPboardType]) {
		returnOK = YES;
	}

  if (sendOK && returnOK) {
		return self;
	}
		
	return nil;
}
	
- (BOOL)readSelectionFromPasteboard:(NSPasteboard *)pboard
{
	if ([[pboard types] indexOfObject: NSFilenamesPboardType] != NSNotFound) {
		return YES;
	}
	
	return NO;
}

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard
                             types:(NSArray *)types
{
	if ([types containsObject: NSFilenamesPboardType] == YES) {
		NSArray *typesDeclared = [NSArray arrayWithObject: NSFilenamesPboardType];

		[pboard declareTypes: typesDeclared owner: self];
		
		return [pboard setPropertyList: selectedPaths 
									  		   forType: NSFilenamesPboardType];
	}
	
	return NO;
}

//
// Menu Operations
//
- (void)closeMainWin:(id)sender
{
  [[[NSApplication sharedApplication] keyWindow] performClose: sender];
}

- (void)showInfo:(id)sender
{
  NSMutableDictionary *d = AUTORELEASE ([NSMutableDictionary new]);
  [d setObject: @"GWorkspace" forKey: @"ApplicationName"];
  [d setObject: NSLocalizedString(@"GNUstep Workspace Manager", @"")
      	forKey: @"ApplicationDescription"];
  [d setObject: @"GWorkspace 0.6.3" forKey: @"ApplicationRelease"];
  [d setObject: @"01 2004" forKey: @"FullVersionID"];
  [d setObject: [NSArray arrayWithObjects: 
      @"Enrico Sersale <enrico@imago.ro>.\n\
InspectorViewer, PlistViewer, StringsViewer\n\
by Fabien Vallon <fabien.vallon@fr.alcove.com>.\n\
Makefiles and configuration scripts\n\
by Alexey I. Froloff <raorn@altlinux.ru>.",
      nil]
     forKey: @"Authors"];
  [d setObject: NSLocalizedString(@"See http://www.gnustep.it/enrico/gworkspace", @"") forKey: @"URL"];
  [d setObject: @"Copyright (C) 2003, 2004 Free Software Foundation, Inc."
     forKey: @"Copyright"];
  [d setObject: NSLocalizedString(@"Released under the GNU General Public License 2.0", @"")
     forKey: @"CopyrightDescription"];
  
#ifdef GNUSTEP	
  [NSApp orderFrontStandardInfoPanelWithOptions: d];
#else
	[NSApp orderFrontStandardAboutPanel: d];
#endif
}

- (void)showPreferences:(id)sender
{
  [prefController activate]; 
}

- (void)showViewer:(id)sender
{
	if(rootViewer == nil) {
    rootViewer = [[ViewersWindow alloc] initWithViewerTemplates: viewersTemplates
                                forPath: fixPath(@"/", 0) viewPakages: NO  
                                            isRootViewer: YES onStart: starting];
    [rootViewer activate];
  } else {
    if([rootViewer isVisible] == NO) {
  	  [rootViewer activate];
    } else {
      [self newViewerAtPath: fixPath(@"/", 0) canViewApps: NO];
    }
  }
}

- (void)showHistory:(id)sender
{
  [history activate];
}

- (void)showInspector:(id)sender
{
	if (inspector == nil) {
    [self connectInspector];
    if (inspector) {
      NSData *data = [NSArchiver archivedDataWithRootObject: selectedPaths];
      [inspector setPathsData: data];
    }    
  }
	if (inspector && useInspector) {
    [inspector showWindow];
  } 
}

- (void)showAttributesInspector:(id)sender
{
	if (inspector == nil) {
    [self connectInspector];
    if (inspector) {
      NSData *data = [NSArchiver archivedDataWithRootObject: selectedPaths];
      [inspector setPathsData: data];
    }
  }
  if (inspector && useInspector) {  
    [inspector showAttributes];
  } 
}

- (void)showContentsInspector:(id)sender
{
	if (inspector == nil) {
    [self connectInspector];
    if (inspector) {
      NSData *data = [NSArchiver archivedDataWithRootObject: selectedPaths];
      [inspector setPathsData: data];
    }
  }
  if (inspector && useInspector) {  
    [inspector showContents];
  } 
}

- (void)showToolsInspector:(id)sender
{
	if (inspector == nil) {
    [self connectInspector];
    if (inspector) {
      NSData *data = [NSArchiver archivedDataWithRootObject: selectedPaths];
      [inspector setPathsData: data];
    }
  }
  if (inspector && useInspector) {  
    [inspector showTools];
  } 
}

- (void)showApps:(id)sender
{
  [appsViewer activate]; 
}

- (void)showFileOps:(id)sender
{
  int i;
  
  for (i = 0; i < [operations count]; i++) {
    FileOperation *op = [operations objectAtIndex: i];
    
    if ([op showsWindow] == NO) {
      [op showProgressWin];
    }
  }
}

- (void)showFinder:(id)sender
{
  if (finder == nil) {    
    finder = [[FinderController alloc] init];
  }
  [finder activate];
}

- (void)showFiend:(id)sender
{
	NSMenu *menu = [[[NSApp mainMenu] itemWithTitle: NSLocalizedString(@"Tools", @"")] submenu];
	menu = [[menu itemWithTitle: NSLocalizedString(@"Fiend", @"")] submenu];

  while (1) {
    if ([menu numberOfItems] == 0) {
      break;
    }
    [menu removeItemAtIndex: 0];
  }

	[menu addItemWithTitle: NSLocalizedString(@"Hide Fiend", @"") 
													action: @selector(hideFiend:) keyEquivalent: @""];	
	[menu addItemWithTitle: NSLocalizedString(@"Remove Current Layer", @"") 
										action: @selector(removeFiendLayer:) keyEquivalent: @""];	
	[menu addItemWithTitle: NSLocalizedString(@"Rename Current Layer", @"") 
										action: @selector(renameFiendLayer:) keyEquivalent: @""];	
	[menu addItemWithTitle: NSLocalizedString(@"Add Layer...", @"") 
										action: @selector(addFiendLayer:) keyEquivalent: @""];								

  if (fiend == nil) {    
    fiend = [[Fiend alloc] init];
  }
  [fiend activate];
}

- (void)hideFiend:(id)sender
{
	NSMenu *menu = [[[NSApp mainMenu] itemWithTitle: NSLocalizedString(@"Tools", @"")] submenu];
	menu = [[menu itemWithTitle: NSLocalizedString(@"Fiend", @"")] submenu];

	 while (1) {
  	 if ([menu numberOfItems] == 0) {
    	 break;
  	 }
  	 [menu removeItemAtIndex: 0];
	 }

	[menu addItemWithTitle: NSLocalizedString(@"Show Fiend", @"") 
									action: @selector(showFiend:) keyEquivalent: @""];		

  if (fiend != nil) {    
    [fiend hide];
  }
}

- (void)addFiendLayer:(id)sender
{
  [fiend addLayer];
}

- (void)removeFiendLayer:(id)sender
{
  [fiend removeCurrentLayer];
}

- (void)renameFiendLayer:(id)sender
{
  [fiend renameCurrentLayer];
}

- (void)showTShelf:(id)sender
{
	NSMenu *menu = [[[NSApp mainMenu] itemWithTitle: NSLocalizedString(@"Tools", @"")] submenu];
	menu = [[menu itemWithTitle: NSLocalizedString(@"Tabbed Shelf", @"")] submenu];

  while (1) {
    if ([menu numberOfItems] == 0) {
      break;
    }
    [menu removeItemAtIndex: 0];
  }

	[menu addItemWithTitle: NSLocalizedString(@"Hide Tabbed Shelf", @"") 
													action: @selector(hideTShelf:) keyEquivalent: @""];
	[menu addItemWithTitle: NSLocalizedString(@"Maximize/Minimize Tabbed Shelf", @"") 
													action: @selector(maximizeMinimizeTShelf:) keyEquivalent: @"s"];
	[menu addItemWithTitle: NSLocalizedString(@"Select Special Tab", @"") 
													action: @selector(selectSpecialTShelfTab:) keyEquivalent: @"S"];
	[menu addItemWithTitle: NSLocalizedString(@"Remove Current Tab", @"") 
										action: @selector(removeTShelfTab:) keyEquivalent: @""];	
	[menu addItemWithTitle: NSLocalizedString(@"Rename Current Tab", @"") 
										action: @selector(renameTShelfTab:) keyEquivalent: @""];	
	[menu addItemWithTitle: NSLocalizedString(@"Add Tab...", @"") 
										action: @selector(addTShelfTab:) keyEquivalent: @""];		
                    						
  if (tshelfWin == nil) {
    [self createTabbedShelf];
    [tshelfWin activate];
  } else if ([tshelfWin isVisible] == NO) {
		[tshelfWin activate];
	}
}

- (void)hideTShelf:(id)sender
{
	NSMenu *menu = [[[NSApp mainMenu] itemWithTitle: NSLocalizedString(@"Tools", @"")] submenu];
	menu = [[menu itemWithTitle: NSLocalizedString(@"Tabbed Shelf", @"")] submenu];

  while (1) {
    if ([menu numberOfItems] == 0) {
      break;
    }
    [menu removeItemAtIndex: 0];
  }

	[menu addItemWithTitle: NSLocalizedString(@"Show Tabbed Shelf", @"") 
									action: @selector(showTShelf:) keyEquivalent: @""];		

	if ((tshelfWin != nil) && ([tshelfWin isVisible])) {
    [tshelfWin saveDefaults]; 
    [tshelfWin deactivate]; 
	}
}

- (void)maximizeMinimizeTShelf:(id)sender
{
  if ((tshelfWin != nil) && ([tshelfWin isVisible])) {
    [[tshelfWin shelfView] hideShowTabs: nil];
  }
}

- (void)selectSpecialTShelfTab:(id)sender
{
  if (tshelfWin != nil) {
    if ([tshelfWin isVisible] == NO) {
      [tshelfWin activate];
    }
    
    [[tshelfWin shelfView] selectLastItem];
  }
}

- (void)addTShelfTab:(id)sender
{
  [tshelfWin addTab]; 
}

- (void)removeTShelfTab:(id)sender
{
  [tshelfWin removeTab]; 
}

- (void)renameTShelfTab:(id)sender
{
  [tshelfWin renameTab]; 
}

- (void)cut:(id)sender
{
  TShelfViewItem *item = [[tshelfWin shelfView] selectedTabItem];
  
  if (item) {
    TShelfIconsView *iview = (TShelfIconsView *)[item view];
    [iview doCut];    
  }
}

- (void)copy:(id)sender
{
  TShelfViewItem *item = [[tshelfWin shelfView] selectedTabItem];
  
  if (item) {
    TShelfIconsView *iview = (TShelfIconsView *)[item view];
    [iview doCopy];    
  }
}

- (void)paste:(id)sender
{
  TShelfViewItem *item = [[tshelfWin shelfView] selectedTabItem];
  
  if (item) {
    TShelfIconsView *iview = (TShelfIconsView *)[item view];
    [iview doPaste];    
  }
}

- (void)openWith:(id)sender
{
  [self openSelectedPathsWith];
}

- (void)runCommand:(id)sender
{
  [runExtController activate];
}

- (void)startXTerm:(id)sender
{
  NSString *path;  
  BOOL isdir;
  
  path = [currentViewer currentViewedPath];
  
  if (path == nil) {
    if ([selectedPaths count] > 1) {
      path = [[selectedPaths objectAtIndex: 0] stringByDeletingLastPathComponent];
    } else {
      path = [selectedPaths objectAtIndex: 0];
      [fm fileExistsAtPath: path isDirectory: &isdir];    
      if (isdir == NO) {
        path = [path stringByDeletingLastPathComponent];
      }
    }
	}
  
	[self startXTermOnDirectory: path];
}

- (void)emptyRecycler:(id)sender
{
	[recycler emptyRecycler];
}

- (void)putAway:(id)sender
{
	[recycler putAway];
}

#ifndef GNUSTEP
- (void)terminate:(id)sender
{
  [NSApp terminate: self];
}
#endif

@end



