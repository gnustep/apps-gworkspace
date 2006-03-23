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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <math.h>
#include "GWFunctions.h"
#include "FSNodeRep.h"
#include "FSNFunctions.h"
#include "GWorkspace.h"
#include "Dialogs.h"
#include "OpenWithController.h"
#include "RunExternalController.h"
#include "StartAppWin.h"
#include "Preferences/PrefController.h"
#include "Fiend/Fiend.h"
#include "GWDesktopManager.h"
#include "Dock.h"
#include "GWViewersManager.h"
#include "GWViewer.h"
#include "GWSpatialViewer.h"
#include "Finder.h"
#include "Inspector.h"
#include "Operation.h"
#include "TShelf/TShelfWin.h"
#include "TShelf/TShelfView.h"
#include "TShelf/TShelfViewItem.h"
#include "TShelf/TShelfIconsView.h"
#include "History/History.h"
#include "GNUstep.h"

static NSString *defaulteditor = @"nedit.app";
static NSString *defaultxterm = @"xterm";

static GWorkspace *gworkspace = nil;

@implementation GWorkspace

#ifndef byname
  #define byname 0
  #define bykind 1
  #define bydate 2
  #define bysize 3
  #define byowner 4
#endif

#define HISTORT_CACHE_MAX 20

#ifndef TSHF_MAXF
  #define TSHF_MAXF 999
#endif

+ (void)initialize
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject: @"GWorkspace" 
               forKey: @"DesktopApplicationName"];
  [defaults setObject: @"gworkspace" 
               forKey: @"DesktopApplicationSelName"];
  [defaults synchronize];
}

+ (GWorkspace *)gworkspace
{
	if (gworkspace == nil) {
		gworkspace = [[GWorkspace alloc] init];
	}	
  return gworkspace;
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
  [wsnc removeObserver: self];
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  if (logoutTimer && [logoutTimer isValid]) {
    [logoutTimer invalidate];
    DESTROY (logoutTimer);
  }
  DESTROY (recyclerApp);
  DESTROY (ddbd);
	RELEASE (gwProcessName);
	RELEASE (gwBundlePath);
	RELEASE (defEditor);
	RELEASE (defXterm);
	RELEASE (defXtermArgs);
  RELEASE (selectedPaths);
  TEST_RELEASE (fiend);
	TEST_RELEASE (history);
  RELEASE (openWithController);
  RELEASE (runExtController);
  RELEASE (startAppWin);
  TEST_RELEASE (tshelfWin);
  TEST_RELEASE (tshelfPBDir);
  RELEASE (vwrsManager);
  RELEASE (dtopManager);
  DESTROY (inspector);
  DESTROY (fileOpsManager);
  RELEASE (finder);
  RELEASE (waitCursor);
  RELEASE (launchedApps);
  RELEASE (storedAppinfoPath);
  RELEASE (storedAppinfoLock);
    
	[super dealloc];
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	NSUserDefaults *defaults;
	id entry;
  BOOL boolentry;
  NSArray *extendedInfo;
  NSMenu *menu;
  NSString *lockpath;
  int i;
    
	[isa registerForServices];
  
  ASSIGN (gwProcessName, [[NSProcessInfo processInfo] processName]);
  ASSIGN (gwBundlePath, [[NSBundle mainBundle] bundlePath]);
  
  fm = [NSFileManager defaultManager];
	ws = [NSWorkspace sharedWorkspace];
  fsnodeRep = [FSNodeRep sharedInstance];  
    
  extendedInfo = [fsnodeRep availableExtendedInfoNames];
  menu = [[[NSApp mainMenu] itemWithTitle: NSLocalizedString(@"View", @"")] submenu];
  menu = [[menu itemWithTitle: NSLocalizedString(@"Show", @"")] submenu];

  for (i = 0; i < [extendedInfo count]; i++) {
	  [menu addItemWithTitle: [extendedInfo objectAtIndex: i] 
										action: @selector(setExtendedShownType:) 
             keyEquivalent: @""];
  }
	    
	defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject: gwProcessName forKey: @"GSWorkspaceApplication"];

  [fsnodeRep setVolumes: [ws removableMediaPaths]];
        
	entry = [defaults objectForKey: @"reserved_names"];
	if (entry) {
    [fsnodeRep setReservedNames: entry];
	} else {
    [fsnodeRep setReservedNames: [NSArray arrayWithObjects: @".gwdir", @".gwsort", nil]];
  }
        
	entry = [defaults stringForKey: @"defaulteditor"];
	if (entry == nil) {
		defEditor = [[NSString alloc] initWithString: defaulteditor];
	} else {
		ASSIGN (defEditor, entry);
  }

	entry = [defaults stringForKey: @"defxterm"];
	if (entry == nil) {
		defXterm = [[NSString alloc] initWithString: defaultxterm];
	} else {
		ASSIGN (defXterm, entry);
  }

	entry = [defaults stringForKey: @"defaultxtermargs"];
	if (entry == nil) {
		defXtermArgs = nil;
	} else {
		ASSIGN (defXtermArgs, entry);
  }
  
  teminalService = [defaults boolForKey: @"terminal_services"];
  [self setUseTerminalService: teminalService];
  		
	entry = [defaults objectForKey: @"default_sortorder"];	
	if (entry == nil) { 
		[defaults setObject: @"0" forKey: @"default_sortorder"];
    [fsnodeRep setDefaultSortOrder: byname];
	} else {
    [fsnodeRep setDefaultSortOrder: [entry intValue]];
	}

  boolentry = [defaults boolForKey: @"GSFileBrowserHideDotFiles"];
  [fsnodeRep setHideSysFiles: boolentry];

	entry = [defaults objectForKey: @"hiddendirs"];
	if (entry) {
    [fsnodeRep setHiddenPaths: entry];
	} 

	entry = [defaults objectForKey: @"history_cache"];
	if (entry) {
    maxHistoryCache = [entry intValue];
	} else {
    maxHistoryCache = HISTORT_CACHE_MAX;
  }
  
  dontWarnOnQuit = [defaults boolForKey: @"NoWarnOnQuit"];

  boolentry = [defaults boolForKey: @"use_thumbnails"];
  [fsnodeRep setUseThumbnails: boolentry];
  
	selectedPaths = [[NSArray alloc] initWithObjects: NSHomeDirectory(), nil];

  startAppWin = [[StartAppWin alloc] init];
  
  fswatcher = nil;
  fswnotifications = YES;
  [self connectFSWatcher];
    
  recyclerApp = nil;

  dtopManager = [GWDesktopManager desktopManager];
    
  if ([defaults boolForKey: @"no_desktop"] == NO) { 
    id item;
   
    [dtopManager activateDesktop];
    menu = [[[NSApp mainMenu] itemWithTitle: NSLocalizedString(@"Tools", @"")] submenu];
    item = [menu itemWithTitle: NSLocalizedString(@"Show Desktop", @"")];
    [item setTitle: NSLocalizedString(@"Hide Desktop", @"")];

  } else if ([defaults boolForKey: @"uses_recycler"]) { 
    [self connectRecycler];
  }  

  tshelfPBFileNum = 0;
  [self createTabbedShelf];
  if ([defaults boolForKey: @"tshelf"]) {
    [self showTShelf: nil];
  } else {
    [self hideTShelf: nil];
  }

  prefController = [PrefController new];  
  
	history = [[History alloc] init];
  fiend = nil;
  
  openWithController = [[OpenWithController alloc] init];
  runExtController = [[RunExternalController alloc] init];
  	    
  finder = [Finder finder];
  
  if ([defaults boolForKey: @"usefiend"]) {
    [self showFiend: nil];
  } else {
    [self hideFiend: nil];
  }
    
  vwrsManager = [GWViewersManager viewersManager];
  [vwrsManager showViewers];
  
  inspector = [Inspector new];
  if ([defaults boolForKey: @"uses_inspector"]) {  
    [self showInspector: nil]; 
  }
  
  fileOpsManager = [Operation new];
  
  ddbd = nil;
  [self connectDDBd];
  
	[defaults synchronize];
  terminating = NO;

  waitCursor = [[NSCursor alloc] initWithImage: [NSImage imageNamed: @"watch.tiff"]];
  [waitCursor setHotSpot: NSMakePoint(8, 8)];

  storedAppinfoPath = [NSTemporaryDirectory() stringByAppendingPathComponent: @"GSLaunchedApplications"];
  RETAIN (storedAppinfoPath); 
  lockpath = [storedAppinfoPath stringByAppendingPathExtension: @"lock"];   
  storedAppinfoLock = [[NSDistributedLock alloc] initWithPath: lockpath];

  launchedApps = [NSMutableArray new];   
  activeApplication = nil;   
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                				selector: @selector(fileSystemWillChange:) 
                					  name: @"GWFileSystemWillChangeNotification"
                					object: nil];

  [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                				selector: @selector(fileSystemDidChange:) 
                					  name: @"GWFileSystemDidChangeNotification"
                					object: nil];

  [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                				selector: @selector(changeDefaultEditor:) 
                					  name: @"GWDefaultEditorChangedNotification"
                					object: nil];

  [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                        selector: @selector(thumbnailsDidChange:) 
                					  name: @"GWThumbnailsDidChangeNotification"
                					object: nil];

  [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                        selector: @selector(removableMediaPathsDidChange:) 
                					  name: @"GSRemovableMediaPathsDidChangeNotification"
                					object: nil];

  [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                        selector: @selector(reservedMountNamesDidChange:) 
                					  name: @"GSReservedMountNamesDidChangeNotification"
                					object: nil];

  [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                        selector: @selector(hideDotsFileDidChange:) 
                					  name: @"GSHideDotFilesDidChangeNotification"
                					object: nil];

  [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                        selector: @selector(customDirectoryIconDidChange:) 
                					  name: @"GWCustomDirectoryIconDidChangeNotification"
                					object: nil];

  [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                        selector: @selector(applicationForExtensionsDidChange:) 
                					  name: @"GWAppForExtensionDidChangeNotification"
                					object: nil];
  
  [self initializeWorkspace]; 
}

- (BOOL)applicationShouldTerminate:(NSApplication *)app 
{
#define TEST_CLOSE(o, w) if ((o) && ([w isVisible])) [w close]
  
  if ([fileOpsManager operationsPending]) {
    NSRunAlertPanel(nil, 
                  NSLocalizedString(@"Wait the operations to terminate!", @""),
					        NSLocalizedString(@"Ok", @""), 
                  nil, 
                  nil);  
    return NO;  
  }
    
  if ((dontWarnOnQuit == NO) && (loggingout == NO)) {
    if (NSRunAlertPanel(NSLocalizedString(@"Quit!", @""),
                      NSLocalizedString(@"Do you really want to quit?", @""),
                      NSLocalizedString(@"No", @""),
                      NSLocalizedString(@"Yes", @""),
                      nil)) {
      return NO;
    }
  }

  if (logoutTimer && [logoutTimer isValid]) {
    [logoutTimer invalidate];
    DESTROY (logoutTimer);
  }
  
  [wsnc removeObserver: self];
  
  fswnotifications = NO;
  terminating = YES;

  [self updateDefaults];

	TEST_CLOSE (prefController, [prefController myWin]);
	TEST_CLOSE (fiend, [fiend myWin]);
	TEST_CLOSE (history, [history myWin]); 
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

  [inspector updateDefaults];

  [finder stopAllSearchs];
  
  if (recyclerApp) {
    NSConnection *rcconn = [(NSDistantObject *)recyclerApp connectionForProxy];
  
    if (rcconn && [rcconn isValid]) {
      [[NSNotificationCenter defaultCenter] removeObserver: self
	                        name: NSConnectionDidDieNotification
	                      object: rcconn];
      DESTROY (recyclerApp);
    }
  }
  
  if (ddbd) {
    NSConnection *ddbdconn = [(NSDistantObject *)ddbd connectionForProxy];
  
    if (ddbdconn && [ddbdconn isValid]) {
      [[NSNotificationCenter defaultCenter] removeObserver: self
	                        name: NSConnectionDidDieNotification
	                      object: ddbdconn];
      DESTROY (ddbd);
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

- (GWViewersManager *)viewersManager
{
  return vwrsManager;
}

- (GWDesktopManager *)desktopManager
{
  return dtopManager;
}

- (History *)historyWindow
{
	return history;
}

- (id)rootViewer
{
  return nil;
}

- (void)showRootViewer
{
  id viewer = [vwrsManager rootViewer];
  
  if (viewer == nil) {
    [vwrsManager showRootViewer];
  } else {
    [viewer activate];
  }
}

- (void)rootViewerSelectFiles:(NSArray *)paths
{
  NSString *path = [[paths objectAtIndex: 0] stringByDeletingLastPathComponent];
  FSNode *parentnode = [FSNode nodeWithPath: path];
  NSArray *selection = [NSArray arrayWithArray: paths];
  id viewer = [vwrsManager rootViewer];
  id nodeView = nil;
  BOOL newviewer = NO;

  if ([paths count] == 1) {
    FSNode *node = [FSNode nodeWithPath: [paths objectAtIndex: 0]];
  
    if ([node isDirectory] && ([node isPackage] == NO)) {
      parentnode = [FSNode nodeWithPath: [node path]];
      selection = [NSArray arrayWithObject: [node path]];
    }
  }
    
  if (viewer == nil) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *path = path_separator();
    NSString *prefsname = [NSString stringWithFormat: @"viewer_at_%@", path];
    NSDictionary *viewerPrefs = [defaults objectForKey: prefsname];
    int type = BROWSING;
    
    if (viewerPrefs) {
      id entry = [viewerPrefs objectForKey: @"spatial"];
   
      if (entry) {
        type = ([entry boolValue] ? SPATIAL : BROWSING);
      }
    }
  
    if (type == BROWSING) {
      viewer = [vwrsManager showRootViewer];
    } else {
      newviewer = YES;
    }
    
  } else if ([viewer vtype] == SPATIAL) {
    newviewer = YES;
  } 
  
  if (newviewer) {
    viewer = [vwrsManager newViewerOfType: SPATIAL
                                 showType: nil
                                  forNode: parentnode
                            showSelection: NO
                           closeOldViewer: NO
                                 forceNew: NO];
  }
  
  nodeView = [viewer nodeView];
  
  if ([viewer vtype] == BROWSING) {
    [nodeView showContentsOfNode: parentnode];
  }
  
  [nodeView selectRepsOfPaths: selection];
  
  if ([nodeView respondsToSelector: @selector(scrollSelectionToVisible)]) {
    [nodeView scrollSelectionToVisible];
  }
}

- (void)newViewerAtPath:(NSString *)path
{
  FSNode *node = [FSNode nodeWithPath: path];
  unsigned type = [vwrsManager typeOfViewerForNode: node];

  [vwrsManager newViewerOfType: type 
                      showType: nil
                       forNode: node 
                 showSelection: NO
                closeOldViewer: nil
                      forceNew: NO];
}

- (NSImage *)tshelfBackground
{
  return ([dtopManager isActive]) ? [dtopManager tabbedShelfBackground] : nil;
}

- (void)tshelfBackgroundDidChange
{
  if ([tshelfWin isVisible]) {
    [[tshelfWin shelfView] setNeedsDisplay: YES];
  }  
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

- (void)changeDefaultEditor:(NSNotification *)notif
{
  NSString *editor = [notif object];

  if (editor) {
    ASSIGN (defEditor, editor);
  }
}

- (void)changeDefaultXTerm:(NSString *)xterm 
                 arguments:(NSString *)args
{
  ASSIGN (defXterm, xterm);
  
  if ([args length]) {
    ASSIGN (defXtermArgs, args);
  } else {
    DESTROY (defXtermArgs);
  }
}

- (void)setUseTerminalService:(BOOL)value
{
  teminalService = value;
}

- (NSString *)gworkspaceProcessName
{
  return gwProcessName;
}

- (void)updateDefaults
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  id entry;

  [tshelfWin saveDefaults];  
   
	if ([tshelfWin isVisible]) {
		[defaults setBool: YES forKey: @"tshelf"];
	} else {
		[defaults setBool: NO forKey: @"tshelf"];
	}
  [defaults setObject: [NSString stringWithFormat: @"%i", tshelfPBFileNum]
               forKey: @"tshelfpbfnum"];
		
	if ([[prefController myWin] isVisible]) {  
		[prefController updateDefaults]; 
	}
	
	if ((fiend != nil) && ([[fiend myWin] isVisible])) {  
		[fiend updateDefaults]; 
    [defaults setBool: YES forKey: @"usefiend"];
	} else {
    [defaults setBool: NO forKey: @"usefiend"];
	}
  
	[history updateDefaults];
  
  [defaults setObject: [fsnodeRep hiddenPaths] 
               forKey: @"hiddendirs"];

  entry = [NSNumber numberWithInt: [fsnodeRep defaultSortOrder]];
  [defaults setObject: entry forKey: @"default_sortorder"];
  
  [vwrsManager updateDefaults];

  [dtopManager updateDefaults];
  [defaults setBool: ![dtopManager isActive] forKey: @"no_desktop"];

	[finder updateDefaults];
      
	[defaults setObject: defEditor forKey: @"defaulteditor"];
	[defaults setObject: defXterm forKey: @"defxterm"];
  if (defXtermArgs != nil) {
	  [defaults setObject: defXtermArgs forKey: @"defaultxtermargs"];
  }

  [defaults setBool: teminalService forKey: @"terminal_services"];
	
  [defaults setBool: [fsnodeRep usesThumbnails]  
             forKey: @"use_thumbnails"];

  entry = [NSNumber numberWithInt: maxHistoryCache];
  [defaults setObject: entry forKey: @"history_cache"];

  [defaults setBool: [[inspector win] isVisible] forKey: @"uses_inspector"];

  [defaults setBool: (recyclerApp != nil) forKey: @"uses_recycler"];

	[defaults synchronize];
}

- (void)startXTermOnDirectory:(NSString *)dirPath
{
  if (teminalService) {
    NSPasteboard *pboard = [NSPasteboard pasteboardWithUniqueName];
    NSArray *types = [NSArray arrayWithObject: NSFilenamesPboardType];

    [pboard declareTypes: types owner: self];
    [pboard setPropertyList: [NSArray arrayWithObject: dirPath]
									  forType: NSFilenamesPboardType];
                    
    NSPerformService(@"Terminal/Open shell here", pboard);  
                      
  } else {  
	  NSTask *task = [NSTask new];

	  AUTORELEASE (task);
	  [task setCurrentDirectoryPath: dirPath];			
	  [task setLaunchPath: defXterm];

    if (defXtermArgs) {
	    NSArray *args = [defXtermArgs componentsSeparatedByString: @" "];
	    [task setArguments: args];
    }

	  [task launch];
  }
}

- (int)defaultSortType
{
	return [fsnodeRep defaultSortOrder];
}

- (void)setDefaultSortType:(int)type
{
  [fsnodeRep setDefaultSortOrder: type];
}

- (void)createTabbedShelf
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  id entry;
  NSString *basePath;
  BOOL isdir;

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

- (TShelfWin *)tabbedShelf
{
  return tshelfWin;
}

- (StartAppWin *)startAppWin
{
  return startAppWin;
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)anItem
{	
	NSString *title = [anItem title];

	if ([title isEqual: NSLocalizedString(@"Show Recycler", @"")]) {
    return ([dtopManager isActive] == NO);

  } else if ([title isEqual: NSLocalizedString(@"Empty Recycler", @"")]) {
    if ([dtopManager isActive] || (recyclerApp != nil)) {
      CREATE_AUTORELEASE_POOL(arp);
      FSNode *node = [FSNode nodeWithPath: [self trashPath]];
      NSArray *subNodes = [node subNodes];
      int count = [subNodes count];
      int i;  
          
      for (i = 0; i < [subNodes count]; i++) {
        if ([[subNodes objectAtIndex: i] isReserved]) {
          count --;
        }
      }  
    
      RELEASE (arp);
      return (count != 0);
    }
    
	} else if ([title isEqual: NSLocalizedString(@"Check for disks", @"")]) {
    return [dtopManager isActive];
        
  } else if ([title isEqual: NSLocalizedString(@"Select Special Tab", @"")]
              || [title isEqual: NSLocalizedString(@"Remove Current Tab", @"")]
              || [title isEqual: NSLocalizedString(@"Rename Current Tab", @"")]
              || [title isEqual: NSLocalizedString(@"Add Tab...", @"")]) {
    return [tshelfWin isVisible];
  
  } else if ([title isEqual: NSLocalizedString(@"Logout", @"")]) {
    return !loggingout;
  }
  
	if ([title isEqual: NSLocalizedString(@"Cut", @"")]
          || [title isEqual: NSLocalizedString(@"Copy", @"")]
          || [title isEqual: NSLocalizedString(@"Paste", @"")]) {
    NSWindow *kwin = [NSApp keyWindow];

    if (kwin) {
      if ([kwin isKindOfClass: [TShelfWin class]]) {
        if ([tshelfWin isVisible] == NO) {
          return NO;
        } else {
          TShelfViewItem *item = [[tshelfWin shelfView] selectedTabItem];

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
    }
  }
  
	return YES;
}
           
- (void)fileSystemWillChange:(NSNotification *)notif
{
//  [[NSNotificationCenter defaultCenter]
// 				postNotificationName: @"GWFileSystemWillChangeNotification"
//	 								    object: [notif userInfo]];
}

- (void)fileSystemDidChange:(NSNotification *)notif
{
//	[[NSNotificationCenter defaultCenter]
// 				postNotificationName: @"GWFileSystemDidChangeNotification"
//	 								    object: [notif userInfo]];
}

- (void)setSelectedPaths:(NSArray *)paths
{
  if (paths && ([selectedPaths isEqualToArray: paths] == NO)) {
    ASSIGN (selectedPaths, paths);
    
    if ([[inspector win] isVisible]) {
      [inspector setCurrentSelection: paths];
    }
    
    [finder setCurrentSelection: paths];
    
	  [[NSNotificationCenter defaultCenter]
 				 postNotificationName: @"GWCurrentSelectionChangedNotification"
	 								     object: nil];      
  }
}

- (void)resetSelectedPaths
{
  if (selectedPaths == nil) {
    return;
  }
  
  if ([[inspector win] isVisible]) {
    [inspector setCurrentSelection: selectedPaths];
  }
				
  [[NSNotificationCenter defaultCenter]
 				 postNotificationName: @"GWCurrentSelectionChangedNotification"
	 								        object: nil];    
}

- (NSArray *)selectedPaths
{
  return selectedPaths;
}

- (void)openSelectedPaths:(NSArray *)paths newViewer:(BOOL)newv
{
  int i;
  
  [self setSelectedPaths: paths];      
      
  for (i = 0; i < [paths count]; i++) {
    NSString *apath = [paths objectAtIndex: i];
    
    if ([fm fileExistsAtPath: apath]) {
      NSString *defApp = nil, *type = nil;

      NS_DURING
        {
      [ws getInfoForFile: apath application: &defApp type: &type];     

      if (type != nil) {
        if ((type == NSDirectoryFileType) || (type == NSFilesystemFileType)) {
          if (newv) {    
            [self newViewerAtPath: apath];    
          }
        } else if ((type == NSPlainFileType) 
                            || ([type isEqual: NSShellCommandFileType])) {
          [self openFile: apath];

        } else if (type == NSApplicationFileType) {
          [ws launchApplication: apath];
        }
      }
        }
      NS_HANDLER
        {
          NSRunAlertPanel(NSLocalizedString(@"error", @""), 
              [NSString stringWithFormat: @"%@ %@!", 
               NSLocalizedString(@"Can't open ", @""), [apath lastPathComponent]],
                                            NSLocalizedString(@"OK", @""), 
                                            nil, 
                                            nil);                                     
        }
      NS_ENDHANDLER
    }
  }
}

- (void)openSelectedPathsWith
{
  BOOL canopen = YES;
  int i;

  for (i = 0; i < [selectedPaths count]; i++) {
    FSNode *node = [FSNode nodeWithPath: [selectedPaths objectAtIndex: i]];

    if (([node isPlain] == NO) 
          && (([node isPackage] == NO) || [node isApplication])) {
      canopen = NO;
      break;
    }
  }
  
  if (canopen) {
    [openWithController activate];
  }
}

- (BOOL)openFile:(NSString *)fullPath
{
	NSString *appName = nil;
  NSString *type = nil;
  BOOL success;
  
  [ws getInfoForFile: fullPath application: &appName type: &type];
  
	if (appName == nil) {
		appName = defEditor;
	}		
  
  NS_DURING
    {
  success = [ws openFile: fullPath withApplication: appName];
    }
  NS_HANDLER
    {
  NSRunAlertPanel(NSLocalizedString(@"error", @""), 
      [NSString stringWithFormat: @"%@ %@!", 
          NSLocalizedString(@"Can't open ", @""), [fullPath lastPathComponent]],
                                    NSLocalizedString(@"OK", @""), 
                                    nil, 
                                    nil);                                     
  success = NO;
    }
  NS_ENDHANDLER  
  
  return success;  
}

- (BOOL)application:(NSApplication *)theApplication 
           openFile:(NSString *)filename
{
  BOOL isDir;
  
  if ([filename isAbsolutePath] 
                    && [fm fileExistsAtPath: filename isDirectory: &isDir]) {
    if (isDir) {
      if ([[filename pathExtension] isEqual: @"lsf"]) {
        return [finder openLiveSearchFolderAtPath: filename];
      } else {
        [self newViewerAtPath: filename];
        return YES;
      }
    } else {
      [self selectFile: filename 
        inFileViewerRootedAtPath: [filename stringByDeletingLastPathComponent]];
      [self openFile: filename];
      return YES;
    }
  } 

  return NO;
}

- (NSArray *)getSelectedPaths
{
  return selectedPaths;
}

- (void)showPasteboardData:(NSData *)data 
                    ofType:(NSString *)type
                  typeIcon:(NSImage *)icon
{
  if ([[inspector win] isVisible]) {
    if ([inspector canDisplayDataOfType: type]) {
      [inspector showData: data ofType: type];
    }
  }
}

- (void)newObjectAtPath:(NSString *)basePath 
            isDirectory:(BOOL)directory
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
		NSString *msg = NSLocalizedString(@"You do not have write permission\nfor", @"");
		NSString *buttstr = NSLocalizedString(@"Continue", @"");
    NSRunAlertPanel(err, [NSString stringWithFormat: @"%@ \"%@\"!\n", msg, basePath], buttstr, nil, nil);   
		return;
	}

  if (directory) {
    fileName = @"NewFolder";
    operation = @"GWorkspaceCreateDirOperation";
  } else {
    fileName = @"NewFile";
    operation = @"GWorkspaceCreateFileOperation";
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
  [notifObj setObject: basePath forKey: @"source"];	
  [notifObj setObject: basePath forKey: @"destination"];	
  [notifObj setObject: [NSArray arrayWithObject: fileName] forKey: @"files"];	

  [self performFileOperation: notifObj];
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
		NSString *msg = NSLocalizedString(@"You do not have write permission\nfor", @"");
		NSString *buttstr = NSLocalizedString(@"Continue", @"");
    NSRunAlertPanel(err, [NSString stringWithFormat: @"%@ \"%@\"!\n", msg, basePath], buttstr, nil, nil);   
		return;
	}

  files = [NSMutableArray array];
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
		NSString *msg = NSLocalizedString(@"You do not have write permission\nfor", @"");
		NSString *buttstr = NSLocalizedString(@"Continue", @"");
    NSRunAlertPanel(err, [NSString stringWithFormat: @"%@ \"%@\"!\n", msg, basePath], buttstr, nil, nil);   
		return;
	}

  files = [NSMutableArray array];
  for (i = 0; i < [selectedPaths count]; i++) {
    [files addObject: [[selectedPaths objectAtIndex: i] lastPathComponent]];
  }

  [self performFileOperation: NSWorkspaceDestroyOperation 
              source: basePath destination: basePath files: files tag: &tag];
}

- (void)moveToTrash
{
  NSString *basePath;
  NSMutableArray *files;
  int tag, i;

  basePath = [NSString stringWithString: [selectedPaths objectAtIndex: 0]];
  basePath = [basePath stringByDeletingLastPathComponent];

	if ([fm isWritableFileAtPath: basePath] == NO) {
		NSString *err = NSLocalizedString(@"Error", @"");
		NSString *msg = NSLocalizedString(@"You do not have write permission\nfor", @"");
		NSString *buttstr = NSLocalizedString(@"Continue", @"");
    NSRunAlertPanel(err, [NSString stringWithFormat: @"%@ \"%@\"!\n", msg, basePath], buttstr, nil, nil);   
		return;
	}

  files = [NSMutableArray array];
  for (i = 0; i < [selectedPaths count]; i++) {
    [files addObject: [[selectedPaths objectAtIndex: i] lastPathComponent]];
  }

  [self performFileOperation: @"NSWorkspaceRecycleOperation"
                  source: basePath destination: [self trashPath] 
                                            files: files tag: &tag];
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
 					 postNotificationName: @"GWFileSystemWillChangeNotification"
	 									object: notifObj];

		[[NSNotificationCenter defaultCenter]
 				  postNotificationName: @"GWFileSystemDidChangeNotification"
	 									object: notifObj];
		return NO;
	}
	
	return YES;
}

- (void)setUsesThumbnails:(BOOL)value
{  
  if ([fsnodeRep usesThumbnails] == value) {
    return;
  }
  
  [fsnodeRep setUseThumbnails: value];
  
  [vwrsManager thumbnailsDidChangeInPaths: nil];
  [dtopManager thumbnailsDidChangeInPaths: nil];
  
  if ([tshelfWin isVisible]) {
    [tshelfWin updateIcons]; 
	}
}

- (void)thumbnailsDidChange:(NSNotification *)notif
{
  NSDictionary *info = [notif userInfo];
  NSArray *deleted = [info objectForKey: @"deleted"];	
  NSArray *created = [info objectForKey: @"created"];	
  NSMutableArray *tmbdirs = [NSMutableArray array];
  int i;

  [fsnodeRep thumbnailsDidChange: info];

  if ([fsnodeRep usesThumbnails] == NO) {
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

      [vwrsManager thumbnailsDidChangeInPaths: tmbdirs];
      [dtopManager thumbnailsDidChangeInPaths: tmbdirs];

      if ([tshelfWin isVisible]) {
        [tshelfWin updateIcons]; 
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

      [vwrsManager thumbnailsDidChangeInPaths: tmbdirs];
      [dtopManager thumbnailsDidChangeInPaths: tmbdirs];
      
      if ([tshelfWin isVisible]) {
        [tshelfWin updateIcons]; 
		  }
    }
  }
}

- (void)removableMediaPathsDidChange:(NSNotification *)notif
{
  [fsnodeRep setVolumes: [ws removableMediaPaths]];
  [dtopManager removableMediaPathsDidChange];
}

- (void)reservedMountNamesDidChange:(NSNotification *)notif
{

}

- (void)hideDotsFileDidChange:(NSNotification *)notif
{
  NSDictionary *info = [notif userInfo];
  BOOL hide = [[info objectForKey: @"hide"] boolValue];
  
  [fsnodeRep setHideSysFiles: hide];
  [vwrsManager hideDotsFileDidChange: hide];
  [dtopManager hideDotsFileDidChange: hide];

  [tshelfWin checkIconsAfterDotsFilesChange];
  
  if (fiend != nil) {
    [fiend checkIconsAfterDotsFilesChange];
  }
}

- (void)hiddenFilesDidChange:(NSArray *)paths
{
  [vwrsManager hiddenFilesDidChange: paths];
  [dtopManager hiddenFilesDidChange: paths];
  [tshelfWin checkIconsAfterHidingOfPaths: paths]; 

  if (fiend != nil) {
    [fiend checkIconsAfterHidingOfPaths: paths];
  }
}

- (void)customDirectoryIconDidChange:(NSNotification *)notif
{
  NSDictionary *info = [notif userInfo];
  NSString *dirpath = [info objectForKey: @"path"];
  NSString *imgpath = [info objectForKey: @"icon_path"];  
  NSArray *paths;	

  [fsnodeRep removeCachedIconsForKey: imgpath];
  
  if ([dirpath isEqual: path_separator()] == NO) {
    dirpath = [dirpath stringByDeletingLastPathComponent];
  }
  
  paths = [NSArray arrayWithObject: dirpath];
  
  [vwrsManager thumbnailsDidChangeInPaths: paths];
  [dtopManager thumbnailsDidChangeInPaths: paths];

  if ([tshelfWin isVisible]) {
    [tshelfWin updateIcons]; 
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

- (int)maxHistoryCache
{
  return maxHistoryCache;
}

- (void)setMaxHistoryCache:(int)value
{
  maxHistoryCache = value;
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
                                   
	    [fswatcher registerClient: (id <FSWClientProtocol>)self 
                isGlobalWatcher: NO];
      
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
                               operation: NSLocalizedString(@"starting:", @"")
                            maxProgValue: 40.0];

	      [NSTask launchedTaskWithLaunchPath: cmd arguments: nil];
        DESTROY (cmd);
        
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
        DESTROY (cmd);
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
  CREATE_AUTORELEASE_POOL(arp);
  NSDictionary *info = [NSUnarchiver unarchiveObjectWithData: dirinfo];

	[[NSNotificationCenter defaultCenter]
 				 postNotificationName: @"GWFileWatcherFileDidChangeNotification"
	 								     object: info];  
  RELEASE (arp);                       
}

- (void)connectRecycler
{
  if (recyclerApp == nil) {
    id rcl = [NSConnection rootProxyForConnectionWithRegisteredName: @"Recycler" 
                                                               host: @""];

    if (rcl) {
      NSMenu *menu = [[[NSApp mainMenu] itemWithTitle: NSLocalizedString(@"Tools", @"")] submenu];
      id item = [menu itemWithTitle: NSLocalizedString(@"Show Recycler", @"")];

      NSConnection *c = [rcl connectionForProxy];

	    [[NSNotificationCenter defaultCenter] addObserver: self
	                   selector: @selector(recyclerConnectionDidDie:)
		                     name: NSConnectionDidDieNotification
		                   object: c];
      
      recyclerApp = rcl;
	    [recyclerApp setProtocolForProxy: @protocol(RecyclerAppProtocol)];
      RETAIN (recyclerApp);
      
      if (item != nil) {
        [item setTitle: NSLocalizedString(@"Hide Recycler", @"")];
      }
      
	  } else {
	    static BOOL recursion = NO;
	  
      if (recursion == NO) {
        int i;
        
        [startAppWin showWindowWithTitle: @"GWorkspace"
                                 appName: @"Recycler"
                               operation: NSLocalizedString(@"starting:", @"")
                            maxProgValue: 80.0];

        [ws launchApplication: @"Recycler"];

        for (i = 1; i <= 80; i++) {
          [startAppWin updateProgressBy: 1.0];
	        [[NSRunLoop currentRunLoop] runUntilDate:
		                       [NSDate dateWithTimeIntervalSinceNow: 0.1]];
          rcl = [NSConnection rootProxyForConnectionWithRegisteredName: @"Recycler" 
                                                                  host: @""];                  
          if (rcl) {
            [startAppWin updateProgressBy: 80.0 - i];
            break;
          }
        }
        
        [[startAppWin win] close];
        
	      recursion = YES;
	      [self connectRecycler];
	      recursion = NO;
        
	    } else { 
	      recursion = NO;
        NSRunAlertPanel(nil,
                NSLocalizedString(@"unable to contact Recycler!", @""),
                NSLocalizedString(@"Ok", @""),
                nil, 
                nil);  
      }
	  }
  }
}

- (void)recyclerConnectionDidDie:(NSNotification *)notif
{
  id connection = [notif object];
  NSMenu *menu = [[[NSApp mainMenu] itemWithTitle: NSLocalizedString(@"Tools", @"")] submenu];
  id item = [menu itemWithTitle: NSLocalizedString(@"Hide Recycler", @"")];

  [[NSNotificationCenter defaultCenter] removeObserver: self
	                    name: NSConnectionDidDieNotification
	                  object: connection];

  NSAssert(connection == [recyclerApp connectionForProxy],
		                                  NSInternalInconsistencyException);
  RELEASE (recyclerApp);
  recyclerApp = nil;

  if (item != nil) {
    [item setTitle: NSLocalizedString(@"Show Recycler", @"")];
  }
    
  if (recyclerCanQuit == NO) {  
    if (NSRunAlertPanel(nil,
                      NSLocalizedString(@"The Recycler connection died.\nDo you want to restart it?", @""),
                      NSLocalizedString(@"Yes", @""),
                      NSLocalizedString(@"No", @""),
                      nil)) {
      [self connectRecycler]; 
    }    
  }
}

- (void)connectDDBd
{
  if (ddbd == nil) {
    id db = [NSConnection rootProxyForConnectionWithRegisteredName: @"ddbd" 
                                                              host: @""];

    if (db) {
      NSConnection *c = [db connectionForProxy];

	    [[NSNotificationCenter defaultCenter] addObserver: self
	                   selector: @selector(ddbdConnectionDidDie:)
		                     name: NSConnectionDidDieNotification
		                   object: c];
      
      ddbd = db;
	    [ddbd setProtocolForProxy: @protocol(DDBdProtocol)];
      RETAIN (ddbd);
                                         
	  } else {
	    static BOOL recursion = NO;
	    static NSString	*cmd = nil;

	    if (recursion == NO) {
        if (cmd == nil) {
            cmd = RETAIN ([[NSSearchPathForDirectoriesInDomains(
                      GSToolsDirectory, NSSystemDomainMask, YES) objectAtIndex: 0]
                            stringByAppendingPathComponent: @"ddbd"]);
		    }
      }
	  
      if (recursion == NO && cmd != nil) {
        int i;
        
        [startAppWin showWindowWithTitle: @"GWorkspace"
                                 appName: @"ddbd"
                               operation: NSLocalizedString(@"starting:", @"")
                            maxProgValue: 40.0];

	      [NSTask launchedTaskWithLaunchPath: cmd arguments: nil];
        DESTROY (cmd);
        
        for (i = 1; i <= 40; i++) {
          [startAppWin updateProgressBy: 1.0];
	        [[NSRunLoop currentRunLoop] runUntilDate:
		                       [NSDate dateWithTimeIntervalSinceNow: 0.1]];
                           
          db = [NSConnection rootProxyForConnectionWithRegisteredName: @"ddbd" 
                                                                 host: @""];                  
          if (db) {
            [startAppWin updateProgressBy: 40.0 - i];
            break;
          }
        }
        
        [[startAppWin win] close];
        
	      recursion = YES;
	      [self connectDDBd];
	      recursion = NO;
        
	    } else { 
        DESTROY (cmd);
	      recursion = NO;
        ddbd = nil;
        NSRunAlertPanel(nil,
                NSLocalizedString(@"unable to contact ddbd.", @""),
                NSLocalizedString(@"Ok", @""),
                nil, 
                nil);  
      }
	  }
  }
}

- (void)ddbdConnectionDidDie:(NSNotification *)notif
{
  id connection = [notif object];

  [[NSNotificationCenter defaultCenter] removeObserver: self
	                    name: NSConnectionDidDieNotification
	                  object: connection];

  NSAssert(connection == [ddbd connectionForProxy],
		                                  NSInternalInconsistencyException);
  RELEASE (ddbd);
  ddbd = nil;
  
  NSRunAlertPanel(nil,
                  NSLocalizedString(@"ddbd connection died.", @""),
                  NSLocalizedString(@"Ok", @""),
                  nil,
                  nil);                
}

- (BOOL)ddbdactive
{
  return ((terminating == NO) && (ddbd && [ddbd dbactive]));
}

- (void)ddbdInsertPath:(NSString *)path
{
  if (ddbd && [ddbd dbactive]) {
    [ddbd insertPath: path];
  }
}

- (void)ddbdRemovePath:(NSString *)path
{
  if (ddbd && [ddbd dbactive]) {
    [ddbd removePath: path];
  }
}

- (NSString *)ddbdGetAnnotationsForPath:(NSString *)path
{
  if (ddbd && [ddbd dbactive]) {
    return [ddbd annotationsForPath: path];
  }
  
  return nil;
}

- (void)ddbdSetAnnotations:(NSString *)annotations
                   forPath:(NSString *)path
{
  if (ddbd && [ddbd dbactive]) {
    [ddbd setAnnotations: annotations forPath: path];
  }
}

- (void)performFileOperationWithDictionary:(NSDictionary *)opdict
{
	NSString *operation = [opdict objectForKey: @"operation"];
	NSString *source = [opdict objectForKey: @"source"];
	NSString *destination = [opdict objectForKey: @"destination"];
	NSArray *files = [opdict objectForKey: @"files"];
	int tag;
	
	[self performFileOperation: operation source: source 
											destination: destination files: files tag: &tag];
}

- (void)slideImage:(NSImage *)image 
							from:(NSPoint)fromPoint 
								to:(NSPoint)toPoint
{
	[[NSWorkspace sharedWorkspace] slideImage: image from: fromPoint to: toPoint];
}


//
// NSServicesRequests protocol
//
- (id)validRequestorForSendType:(NSString *)sendType
                     returnType:(NSString *)returnType
{	
  BOOL sendOK = ((sendType == nil) || ([sendType isEqual: NSFilenamesPboardType]));
  BOOL returnOK = ((returnType == nil) 
                      || ([returnType isEqual: NSFilenamesPboardType] 
                                              && (selectedPaths != nil)));

  if (sendOK && returnOK) {
		return self;
	}
		
	return nil;
}
	
- (BOOL)readSelectionFromPasteboard:(NSPasteboard *)pboard
{
  return ([[pboard types] indexOfObject: NSFilenamesPboardType] != NSNotFound);
}

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard
                             types:(NSArray *)types
{
	if ([types containsObject: NSFilenamesPboardType]) {
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

- (void)logout:(id)sender
{
  [self startLogout];
}

- (void)showInfo:(id)sender
{
  NSMutableDictionary *d = AUTORELEASE ([NSMutableDictionary new]);
  
  [d setObject: @"GWorkspace" forKey: @"ApplicationName"];
  [d setObject: NSLocalizedString(@"GNUstep Workspace Manager", @"")
      	forKey: @"ApplicationDescription"];
  [d setObject: @"GWorkspace 0.8.2" forKey: @"ApplicationRelease"];
  [d setObject: @"03 2006" forKey: @"FullVersionID"];
  [d setObject: [NSArray arrayWithObjects: 
                    @"Enrico Sersale <enrico@dtedu.net>", nil]
        forKey: @"Authors"];
  [d setObject: NSLocalizedString(@"See http://www.gnustep.it/enrico/gworkspace", @"") forKey: @"URL"];
  [d setObject: @"Copyright (C) 2003, 2004, 2005, 2006 Free Software Foundation, Inc."
        forKey: @"Copyright"];
  [d setObject: NSLocalizedString(@"Released under the GNU General Public License 2.0", @"")
        forKey: @"CopyrightDescription"];
  
  [NSApp orderFrontStandardInfoPanelWithOptions: d];
}

- (void)showPreferences:(id)sender
{
  [prefController activate]; 
}

- (void)showViewer:(id)sender
{
  [vwrsManager showRootViewer];
}

- (void)showHistory:(id)sender
{
  [history activate];
}

- (void)showInspector:(id)sender
{
  [inspector activate];
  [inspector setCurrentSelection: selectedPaths];
}

- (void)showAttributesInspector:(id)sender
{
  [self showInspector: nil]; 
  [inspector showAttributes];
}

- (void)showContentsInspector:(id)sender
{
  [self showInspector: nil];  
  [inspector showContents];
}

- (void)showToolsInspector:(id)sender
{
  [self showInspector: nil]; 
  [inspector showTools];
}

- (void)showAnnotationsInspector:(id)sender
{
  [self showInspector: nil]; 
  [inspector showAnnotations];
}

- (void)showDesktop:(id)sender
{
  NSMenu *menu = [[[NSApp mainMenu] itemWithTitle: NSLocalizedString(@"Tools", @"")] submenu];
  id item;

  if ([dtopManager isActive] == NO) {
    [dtopManager activateDesktop];
    item = [menu itemWithTitle: NSLocalizedString(@"Show Desktop", @"")];
    [item setTitle: NSLocalizedString(@"Hide Desktop", @"")];
  } else {
    [dtopManager deactivateDesktop];
    item = [menu itemWithTitle: NSLocalizedString(@"Hide Desktop", @"")];
    [item setTitle: NSLocalizedString(@"Show Desktop", @"")];
  }
}

- (void)showRecycler:(id)sender
{
  NSMenu *menu = [[[NSApp mainMenu] itemWithTitle: NSLocalizedString(@"Tools", @"")] submenu];
  id item;

	if (recyclerApp == nil) {
    recyclerCanQuit = NO; 
    [self connectRecycler];
    item = [menu itemWithTitle: NSLocalizedString(@"Show Recycler", @"")];
    [item setTitle: NSLocalizedString(@"Hide Recycler", @"")];
  } else {
    recyclerCanQuit = YES;
    [recyclerApp terminateApplication];
    item = [menu itemWithTitle: NSLocalizedString(@"Hide Recycler", @"")];
    [item setTitle: NSLocalizedString(@"Show Recycler", @"")];
  }
}

- (void)showFinder:(id)sender
{
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

  [[menu itemAtIndex: 0] setTitle: NSLocalizedString(@"Hide Tabbed Shelf", @"")];
  [[menu itemAtIndex: 0] setAction: @selector(hideTShelf:)];

  [tshelfWin activate];
}

- (void)hideTShelf:(id)sender
{
	NSMenu *menu = [[[NSApp mainMenu] itemWithTitle: NSLocalizedString(@"Tools", @"")] submenu];
	menu = [[menu itemWithTitle: NSLocalizedString(@"Tabbed Shelf", @"")] submenu];

  [[menu itemAtIndex: 0] setTitle: NSLocalizedString(@"Show Tabbed Shelf", @"")];
  [[menu itemAtIndex: 0] setAction: @selector(showTShelf:)];

	if ([tshelfWin isVisible]) {
    [tshelfWin deactivate]; 
	}
}

- (void)selectSpecialTShelfTab:(id)sender
{
  if ([tshelfWin isVisible] == NO) {
    [tshelfWin activate];
  }
  [[tshelfWin shelfView] selectLastItem];
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
  NSWindow *kwin = [NSApp keyWindow];

  if (kwin) {
    if ([kwin isKindOfClass: [TShelfWin class]]) {
      TShelfViewItem *item = [[tshelfWin shelfView] selectedTabItem];

      if (item) {
        TShelfIconsView *iview = (TShelfIconsView *)[item view];
        [iview doCut];    
      }
      
    } else if ([vwrsManager hasViewerWithWindow: kwin]
                                  || [dtopManager hasWindow: kwin]) {
      id nodeView;
      NSArray *selection;
      NSArray *basesel;
      
      if ([vwrsManager hasViewerWithWindow: kwin]) {
        nodeView = [[vwrsManager viewerWithWindow: kwin] nodeView];
      } else {
        nodeView = [dtopManager desktopView];
      }
    
      selection = [nodeView selectedPaths];  
      basesel = [NSArray arrayWithObject: [[nodeView baseNode] path]];
      
      if ([selection count] && ([selection isEqual: basesel] == NO)) {
        NSPasteboard *pb = [NSPasteboard generalPasteboard];

        [pb declareTypes: [NSArray arrayWithObject: NSFilenamesPboardType]
                   owner: nil];

        if ([pb setPropertyList: selection forType: NSFilenamesPboardType]) {
          [fileOpsManager setFilenamesCutted: YES];
        }
      }
    } 
  }
}

- (void)copy:(id)sender
{
  NSWindow *kwin = [NSApp keyWindow];

  if (kwin) {
    if ([kwin isKindOfClass: [TShelfWin class]]) {
      TShelfViewItem *item = [[tshelfWin shelfView] selectedTabItem];

      if (item) {
        TShelfIconsView *iview = (TShelfIconsView *)[item view];
        [iview doCopy];    
      }
      
    } else if ([vwrsManager hasViewerWithWindow: kwin]
                                  || [dtopManager hasWindow: kwin]) {
      id nodeView;
      NSArray *selection;
      NSArray *basesel;
      
      if ([vwrsManager hasViewerWithWindow: kwin]) {
        nodeView = [[vwrsManager viewerWithWindow: kwin] nodeView];
      } else {
        nodeView = [dtopManager desktopView];
      }
    
      selection = [nodeView selectedPaths];  
      basesel = [NSArray arrayWithObject: [[nodeView baseNode] path]];
      
      if ([selection count] && ([selection isEqual: basesel] == NO)) {
        NSPasteboard *pb = [NSPasteboard generalPasteboard];

        [pb declareTypes: [NSArray arrayWithObject: NSFilenamesPboardType]
                   owner: nil];

        if ([pb setPropertyList: selection forType: NSFilenamesPboardType]) {
          [fileOpsManager setFilenamesCutted: NO];
        }
      }
    }
  }
}

- (void)paste:(id)sender
{
  NSWindow *kwin = [NSApp keyWindow];

  if (kwin) {
    if ([kwin isKindOfClass: [TShelfWin class]]) {
      TShelfViewItem *item = [[tshelfWin shelfView] selectedTabItem];

      if (item) {
        TShelfIconsView *iview = (TShelfIconsView *)[item view];
        [iview doPaste];    
      }
      
    } else if ([vwrsManager hasViewerWithWindow: kwin]
                                  || [dtopManager hasWindow: kwin]) {
      NSPasteboard *pb = [NSPasteboard generalPasteboard];

      if ([[pb types] containsObject: NSFilenamesPboardType]) {
        NSArray *sourcePaths = [pb propertyListForType: NSFilenamesPboardType];   

        if (sourcePaths) {
          BOOL cutted = [fileOpsManager filenamesWasCutted];
          id nodeView;

          if ([vwrsManager hasViewerWithWindow: kwin]) {
            nodeView = [[vwrsManager viewerWithWindow: kwin] nodeView];
          } else {
            nodeView = [dtopManager desktopView];
          }

          if ([nodeView validatePasteOfFilenames: sourcePaths
                                       wasCutted: cutted]) {
            NSMutableDictionary *opDict = [NSMutableDictionary dictionary];
            NSString *source = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];
            NSString *destination = [[nodeView shownNode] path];
            NSMutableArray *files = [NSMutableArray array];
            NSString *operation;
            int i;

            for (i = 0; i < [sourcePaths count]; i++) {  
              NSString *spath = [sourcePaths objectAtIndex: i];
              [files addObject: [spath lastPathComponent]];
            }  

            if (cutted) {
              if ([source isEqual: [self trashPath]]) {
                operation = @"GWorkspaceRecycleOutOperation";
              } else {
		            operation = NSWorkspaceMoveOperation;
              }
            } else {
		          operation = NSWorkspaceCopyOperation;
            }

	          [opDict setObject: operation forKey: @"operation"];
	          [opDict setObject: source forKey: @"source"];
	          [opDict setObject: destination forKey: @"destination"];
	          [opDict setObject: files forKey: @"files"];

	          [self performFileOperationWithDictionary: opDict];	
          }
        }
      }
    }    
  }
}

- (void)runCommand:(id)sender
{
  [runExtController activate];
}

- (void)checkRemovableMedia:(id)sender
{
  if ([dtopManager isActive]) {
    [dtopManager checkNewRemovableMedia];
  }	
}

- (void)emptyRecycler:(id)sender
{
  CREATE_AUTORELEASE_POOL(arp);
  NSString *trashPath = [self trashPath];
  FSNode *node = [FSNode nodeWithPath: trashPath];
  NSMutableArray *subNodes = [[node subNodes] mutableCopy];
  int count = [subNodes count];
  int i;  
  
  for (i = 0; i < count; i++) {
    FSNode *nd = [subNodes objectAtIndex: i];
  
    if ([nd isReserved]) {
      [subNodes removeObjectAtIndex: i];
      i--;
      count --;
    }
  }  
  
  if ([subNodes count]) {
    NSMutableArray *files = [NSMutableArray array];
    NSMutableDictionary *opinfo = [NSMutableDictionary dictionary];

    for (i = 0; i < [subNodes count]; i++) {
      [files addObject: [(FSNode *)[subNodes objectAtIndex: i] name]];
    }

    [opinfo setObject: @"GWorkspaceEmptyRecyclerOperation" forKey: @"operation"];
    [opinfo setObject: trashPath forKey: @"source"];
    [opinfo setObject: trashPath forKey: @"destination"];
    [opinfo setObject: files forKey: @"files"];

    [self performFileOperation: opinfo];
  }
  
  RELEASE (subNodes);
  RELEASE (arp);
}


//
// DesktopApplication protocol
//
- (void)selectionChanged:(NSArray *)newsel
{
  if (newsel && [newsel count]) {
    [self setSelectedPaths: newsel];
  }
}

- (void)openSelectionInNewViewer:(BOOL)newv
{
  if (selectedPaths && [selectedPaths count]) {
    [self openSelectedPaths: selectedPaths newViewer: newv];
  }  
}

- (void)openSelectionWithApp:(id)sender
{
  NSString *appName = (NSString *)[(NSMenuItem *)sender representedObject];
    
  if (selectedPaths && [selectedPaths count]) {
    int i;
    
    for (i = 0; i < [selectedPaths count]; i++) {
      NSString *path = [selectedPaths objectAtIndex: i];
    
      NS_DURING
        {
      [ws openFile: path withApplication: appName];
        }
      NS_HANDLER
        {
      NSRunAlertPanel(NSLocalizedString(@"error", @""), 
          [NSString stringWithFormat: @"%@ %@!", 
              NSLocalizedString(@"Can't open ", @""), [path lastPathComponent]],
                                        NSLocalizedString(@"OK", @""), 
                                        nil, 
                                        nil);                                     
        }
      NS_ENDHANDLER  
    }
  }
}

- (void)performFileOperation:(NSDictionary *)opinfo
{
  [self performFileOperationWithDictionary: opinfo];
}

- (BOOL)filenamesWasCutted
{
  return [fileOpsManager filenamesWasCutted];
}

- (void)setFilenamesCutted:(BOOL)value
{
  [fileOpsManager setFilenamesCutted: value];
}

- (void)lsfolderDragOperation:(NSData *)opinfo
              concludedAtPath:(NSString *)path
{
  [finder lsfolderDragOperation: opinfo concludedAtPath: path];
}     
                          
- (void)concludeRemoteFilesDragOperation:(NSData *)opinfo
                             atLocalPath:(NSString *)localPath
{
  NSDictionary *infoDict = [NSUnarchiver unarchiveObjectWithData: opinfo];
  NSArray *srcPaths = [infoDict objectForKey: @"paths"];
  BOOL bookmark = [[infoDict objectForKey: @"bookmark"] boolValue];
  NSString *connName = [infoDict objectForKey: @"dndconn"];
	NSArray *locContents = [fm directoryContentsAtPath: localPath];
  BOOL samename = NO;
  int i;

  if (locContents) {
    NSConnection *conn;
    id remote;
  
    for (i = 0; i < [srcPaths count]; i++) {
      NSString *name = [[srcPaths objectAtIndex: i] lastPathComponent];

      if ([locContents containsObject: name]) {
        samename = YES;
        break;
      }
    }
    
    conn = [NSConnection connectionWithRegisteredName: connName host: @""];
  
    if (conn) {
      remote = [conn rootProxy];
      
      if (remote) {
        NSMutableDictionary *reply = [NSMutableDictionary dictionary];
        NSData *rpdata;
      
        [reply setObject: localPath forKey: @"destination"];
        [reply setObject: srcPaths forKey: @"paths"];
        [reply setObject: [NSNumber numberWithBool: bookmark] forKey: @"bookmark"];  
        [reply setObject: [NSNumber numberWithBool: !samename] forKey: @"dndok"];
        rpdata = [NSArchiver archivedDataWithRootObject: reply];
      
        [remote setProtocolForProxy: @protocol(GWRemoteFilesDraggingInfo)];
        remote = (id <GWRemoteFilesDraggingInfo>)remote;
      
        [remote remoteDraggingDestinationReply: rpdata];
      }
    }
  }
}

- (void)addWatcherForPath:(NSString *)path
{
  if (fswnotifications) {
    [self connectFSWatcher];
    [fswatcher client: (id <FSWClientProtocol>)self addWatcherForPath: path];
  }
}

- (void)removeWatcherForPath:(NSString *)path
{
  if (fswnotifications) {
    [self connectFSWatcher];
    [fswatcher client: (id <FSWClientProtocol>)self removeWatcherForPath: path];
  }
}

- (NSString *)trashPath
{
	static NSString *tpath = nil; 
  
  if (tpath == nil) {
    tpath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    tpath = [tpath stringByAppendingPathComponent: @"Desktop"];
    tpath = [tpath stringByAppendingPathComponent: @".Trash"];
    RETAIN (tpath);
  }
  
  return tpath;
}

- (id)workspaceApplication
{
  return [GWorkspace gworkspace];
}

- (oneway void)terminateApplication
{
  [NSApp terminate: self];
}

- (BOOL)terminating
{
  return terminating;
}

@end

