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
#include "GWFunctions.h"
#include "GWNotifications.h"
#include "FSNodeRep.h"
#include "FSNFunctions.h"
#include "GWorkspace.h"
#include "Dialogs/Dialogs.h"
#include "Dialogs/OpenWithController.h"
#include "Dialogs/RunExternalController.h"
#include "Dialogs/StartAppWin.h"
#include "Preferences/PrefController.h"
#include "Fiend/Fiend.h"
#include "GWViewersManager.h"
#include "GWViewer.h"
#include "GWSpatialViewer.h"
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
  NSMutableDictionary *opdict = [NSMutableDictionary dictionary];
  NSData *data;

  [self connectOperation];

  if (operationsApp == nil) {  
    NSRunAlertPanel(nil, 
        NSLocalizedString(@"File operations disabled!", @""), 
                            NSLocalizedString(@"OK", @""), nil, nil);                                     
    return NO;
  }

  [opdict setObject: operation forKey: @"operation"];
  [opdict setObject: source forKey: @"source"];
  [opdict setObject: destination forKey: @"destination"];
  [opdict setObject: files forKey: @"files"];

  data = [NSArchiver archivedDataWithRootObject: opdict];

  [operationsApp performOperation: data];
  
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
      [self newViewerAtPath: filename];
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
	NSString *appName;
  NSString *type;
  
  [ws getInfoForFile: fullPath application: &appName type: &type];
  
	if (appName == nil) {
		appName = defEditor;
	}		
  
  return [ws openFile: fullPath withApplication: appName];
}

- (BOOL)selectFile:(NSString *)fullPath
											inFileViewerRootedAtPath:(NSString *)rootFullpath
{
  FSNode *node = [FSNode nodeWithPath: fullPath];
  
  if (node && [node isValid]) {
    FSNode *base;
  
    if ((rootFullpath == nil) || ([rootFullpath length] == 0)) {
      base = [FSNode nodeWithPath: path_separator()];
    } else {
      base = [FSNode nodeWithPath: rootFullpath];
    }
  
    if (base && [base isValid]) {
      if (([base isDirectory] == NO) || [base isPackage]) {
        return NO;
      }
    
      [vwrsManager selectRepOfNode: node inViewerWithBaseNode: base];
      return YES;
    }
  }
   
  return NO;
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

      if ((fileType != NSPlainFileType) && (fileType != NSShellCommandFileType)) {
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

- (NSArray *)getSelectedPaths
{
  return selectedPaths;
}

- (NSString *)trashPath
{
	NSString *tpath; 

  tpath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
  tpath = [tpath stringByAppendingPathComponent: @"Desktop"];
  return [tpath stringByAppendingPathComponent: @".Trash"];
}

- (BOOL)animateChdir
{
  return animateChdir;
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
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject: @"GWorkspace" 
               forKey: @"DesktopApplicationName"];
  [defaults setObject: @"gworkspace" 
               forKey: @"DesktopApplicationSelName"];
  [defaults synchronize];
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
  DESTROY (inspectorApp);
  DESTROY (finderApp);
  DESTROY (operationsApp);
  DESTROY (desktopApp);
  DESTROY (recyclerApp);
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
  TEST_RELEASE (tshelfBackground);
  
	[super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSString *processName;
	NSUserDefaults *defaults;
	id entry;
  BOOL boolentry;
  NSArray *extendedInfo;
  NSMenu *menu;
  int i;
  
	[isa registerForServices];
    
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
	processName = [[NSProcessInfo processInfo] processName];    
	[defaults setObject: processName forKey: @"GSWorkspaceApplication"];
        
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
  
	entry = [defaults objectForKey: @"shelfcellswidth"];
	if (entry == nil) {
    shelfCellsWidth = 90;
	} else {
    shelfCellsWidth = [entry intValue];
  }
		
	entry = [defaults objectForKey: @"default_sortorder"];	
	if (entry == nil) { 
		[defaults setObject: @"0" forKey: @"default_sortorder"];
    [fsnodeRep setDefaultSortOrder: byname];
	} else {
    [fsnodeRep setDefaultSortOrder: [entry intValue]];
	}

  entry = [defaults objectForKey: @"GSFileBrowserHideDotFiles"];
  if (entry) {
    boolentry = [entry boolValue];
  } else {  
    NSDictionary *domain = [defaults persistentDomainForName: NSGlobalDomain];
    
    entry = [domain objectForKey: @"GSFileBrowserHideDotFiles"];
    if (entry) {
      boolentry = [entry boolValue];
    } else {  
      boolentry = NO;
    }
  }
  [fsnodeRep setHideSysFiles: boolentry];

	entry = [defaults objectForKey: @"hiddendirs"];
	if (entry) {
    [fsnodeRep setHiddenPaths: entry];
	} 

  animateChdir = ![defaults boolForKey: @"nochdiranim"];
  animateSlideBack = ![defaults boolForKey: @"noslidebackanim"];
  
  contestualMenu = [defaults boolForKey: @"UsesContestualMenu"];

  dontWarnOnQuit = [defaults boolForKey: @"NoWarnOnQuit"];

  boolentry = [defaults boolForKey: @"use_thumbnails"];
  [fsnodeRep setUseThumbnails: boolentry];
  
	selectedPaths = [[NSArray alloc] initWithObjects: NSHomeDirectory(), nil];

  startAppWin = [[StartAppWin alloc] init];
  fswatcher = nil;
  fswnotifications = YES;
  [self connectFSWatcher];
  
  operationsApp = nil;
  
	history = [[History alloc] init];
  prefController = [[PrefController alloc] init];  
  fiend = nil;

  tshelfBackground = nil; 
  
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
  
  openWithController = [[OpenWithController alloc] init];
  runExtController = [[RunExternalController alloc] init];
  	
  vwrsManager = [GWViewersManager viewersManager];
  [vwrsManager showViewers];
        
  inspectorApp = nil;
  if ([defaults boolForKey: @"uses_inspector"]) {  
    [self connectInspector];
  }
  
  finderApp = nil;
  
  desktopApp = nil;
  if ([defaults boolForKey: @"uses_desktop"]) {  
    [self connectDesktop];
  }  

  recyclerApp = nil;
  if ([defaults boolForKey: @"uses_recycler"]) {  
    [self connectRecycler];
  }  
  
	[defaults synchronize];

  [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                				selector: @selector(fileSystemWillChange:) 
                					  name: GWFileSystemWillChangeNotification
                					object: nil];

  [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                				selector: @selector(fileSystemDidChange:) 
                					  name: GWFileSystemDidChangeNotification
                					object: nil];

  [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                				selector: @selector(changeDefaultEditor:) 
                					  name: @"GWDefaultEditorChangedNotification"
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
  
  fswnotifications = NO;
  
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

  if (inspectorApp) {
    NSConnection *inspconn = [(NSDistantObject *)inspectorApp connectionForProxy];
  
    if (inspconn && [inspconn isValid]) {
      [[NSNotificationCenter defaultCenter] removeObserver: self
	                        name: NSConnectionDidDieNotification
	                      object: inspconn];
      DESTROY (inspectorApp);
    }
  }

  if (finderApp) {
    NSConnection *fndrconn = [(NSDistantObject *)finderApp connectionForProxy];
  
    if (fndrconn && [fndrconn isValid]) {
      [[NSNotificationCenter defaultCenter] removeObserver: self
	                        name: NSConnectionDidDieNotification
	                      object: fndrconn];
      DESTROY (finderApp);
    }
  }

  if (desktopApp) {
    NSConnection *dskconn = [(NSDistantObject *)desktopApp connectionForProxy];
  
    if (dskconn && [dskconn isValid]) {
      [[NSNotificationCenter defaultCenter] removeObserver: self
	                        name: NSConnectionDidDieNotification
	                      object: dskconn];
      DESTROY (desktopApp);
    }
  }

  if (recyclerApp) {
    NSConnection *rcconn = [(NSDistantObject *)recyclerApp connectionForProxy];
  
    if (rcconn && [rcconn isValid]) {
      [[NSNotificationCenter defaultCenter] removeObserver: self
	                        name: NSConnectionDidDieNotification
	                      object: rcconn];
      DESTROY (recyclerApp);
    }
  }

  if (operationsApp) {
    NSConnection *opspconn = [(NSDistantObject *)operationsApp connectionForProxy];
  
    if (opspconn && [opspconn isValid]) {
      [[NSNotificationCenter defaultCenter] removeObserver: self
	                        name: NSConnectionDidDieNotification
	                      object: opspconn];
      DESTROY (operationsApp);
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
  return nil;
}

- (void)newViewerAtPath:(NSString *)path
{
  FSNode *node = [FSNode nodeWithPath: path];
  unsigned type = [vwrsManager typeOfViewerForNode: node];

  [vwrsManager newViewerOfType: type 
                       forNode: node 
                 showSelection: NO
                closeOldViewer: nil
                      forceNew: NO];
}

- (NSImage *)tshelfBackground
{
  return tshelfBackground;
}

- (void)makeTshelfBackground
{
//  if (desktopApp) {
//    NSData *data = [desktopApp tabbedShelfBackground];
  
//    if (data) {
//      DESTROY (tshelfBackground);
//      tshelfBackground = [[NSImage alloc] initWithData: data];
//    }  
//  }
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
	NSMenu *menu = [[[NSApp mainMenu] itemWithTitle: NSLocalizedString(@"Tools", @"")] submenu];
  NSString *title = NSLocalizedString(@"XTerm", @"");
  id item;

  teminalService = value;

  if (teminalService) {
    item = [menu itemWithTitle: title];

    if (item) {
      [menu removeItem: item];
    }
  } else {
    item = [menu itemWithTitle: title];

    if (item == nil) {
	    [menu addItemWithTitle: title
											action: @selector(showTerminal:) 
               keyEquivalent: @"t"];	
    }
  }
}

- (void)updateDefaults
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  id entry;
   
	if ((tshelfWin != nil) && ([tshelfWin isVisible])) {
		[tshelfWin saveDefaults];  
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
      
	[defaults setObject: defEditor forKey: @"defaulteditor"];
	[defaults setObject: defXterm forKey: @"defxterm"];
  if (defXtermArgs != nil) {
	  [defaults setObject: defXtermArgs forKey: @"defaultxtermargs"];
  }

  [defaults setBool: teminalService forKey: @"terminal_services"];
	
  [defaults setObject: [NSString stringWithFormat: @"%i", shelfCellsWidth]
               forKey: @"shelfcellswidth"];

  [defaults setBool: !animateChdir forKey: @"nochdiranim"];
  [defaults setBool: !animateSlideBack forKey: @"noslidebackanim"];

  [defaults setBool: [fsnodeRep usesThumbnails]  
             forKey: @"use_thumbnails"];

  [defaults setBool: (inspectorApp != nil) forKey: @"uses_inspector"];

  [defaults setBool: (desktopApp != nil) forKey: @"uses_desktop"];

  [defaults setBool: (recyclerApp != nil) forKey: @"uses_recycler"];

	[defaults synchronize];
}

- (void)startXTermOnDirectory:(NSString *)dirPath
{
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

- (int)defaultSortType
{
	return [fsnodeRep defaultSortOrder];
}

- (void)setDefaultSortType:(int)type
{
  [fsnodeRep setDefaultSortOrder: type];
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
    return ((desktopApp != nil) || (recyclerApp != nil));

	} else if ([title isEqual: NSLocalizedString(@"Check for disks", @"")]) {
    return (desktopApp != nil);
  
  } else if ([title isEqual: NSLocalizedString(@"Open With...", @"")]) {
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
    NSWindow *kwin = [NSApp keyWindow];

    if (kwin) {
      if ([kwin isKindOfClass: [TShelfWin class]]) {
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
    }
  }
  
	return YES;
}

- (void)checkViewersAfterHidingOfPaths:(NSArray *)paths
{
//  int i = [viewers count] - 1;
  
//	while (i >= 0) {
//		id viewer = [viewers objectAtIndex: i];
    
//    [viewer checkRootPathAfterHidingOfPaths: paths];
//    i--;
//	}
  
//  [rootViewer checkRootPathAfterHidingOfPaths: paths];
    
  if (tshelfWin != nil) {
    [tshelfWin checkIconsAfterHidingOfPaths: paths]; 
	}
}

- (void)iconAnimationChanged:(NSNotification *)notif
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];     
  
  animateChdir = ![defaults boolForKey: @"nochdiranim"];
  animateSlideBack = ![defaults boolForKey: @"noslidebackanim"];
}
           
- (void)fileSystemWillChange:(NSNotification *)notif
{
  NSDictionary *info = [notif userInfo];
  NSString *operation = [info objectForKey: @"operation"];
  NSString *source = [info objectForKey: @"source"];
  NSString *destination = [info objectForKey: @"destination"];
  NSArray *files = [info objectForKey: @"files"];
  NSMutableArray *paths = [NSMutableArray array];
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];		
  NSString *opPtr = nil;
  int i;
  
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
  } else if ([operation isEqual: GWorkspaceRenameOperation]) {
    opPtr = GWorkspaceRenameOperation;  
  } else if ([operation isEqual: GWorkspaceCreateFileOperation]) {
    opPtr = GWorkspaceCreateFileOperation;  
  } else if ([operation isEqual: GWorkspaceCreateDirOperation]) {
    opPtr = GWorkspaceCreateDirOperation;  
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
    for (i = 0; i < [files count]; i++) {
      NSString *fname = [files objectAtIndex: i];
      NSString *fullpath = [destination stringByAppendingPathComponent: fname];
      [paths addObject: fullpath];
    }
  }

  if (opPtr == NSWorkspaceMoveOperation 
        || opPtr == NSWorkspaceDestroyOperation
				|| opPtr == NSWorkspaceRecycleOperation
				|| opPtr == GWorkspaceRecycleOutOperation
				|| opPtr == GWorkspaceEmptyRecyclerOperation) {
    for (i = 0; i < [files count]; i++) {
      NSString *fname = [files objectAtIndex: i];
      NSString *fullpath = [source stringByAppendingPathComponent: fname];
      [paths addObject: fullpath];
    }
  }

  [fsnodeRep lockPaths: paths];

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
  NSMutableArray *paths = [NSMutableArray array];
  NSArray *origfiles = [info objectForKey: @"origfiles"];
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];		
  NSString *opPtr = nil;
  int i;
  
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
  } else if ([operation isEqual: GWorkspaceRenameOperation]) {        
    opPtr = GWorkspaceRenameOperation;                                
  } else if ([operation isEqual: GWorkspaceCreateFileOperation]) {    
    opPtr = GWorkspaceCreateFileOperation;                            
  } else if ([operation isEqual: GWorkspaceCreateDirOperation]) {     
    opPtr = GWorkspaceCreateDirOperation;                             
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
    for (i = 0; i < [origfiles count]; i++) {
      NSString *fname = [origfiles objectAtIndex: i];
      NSString *fullpath = [destination stringByAppendingPathComponent: fname];
      [paths addObject: fullpath];
    }
  }

  if (opPtr == NSWorkspaceMoveOperation 
        || opPtr == NSWorkspaceDestroyOperation
				|| opPtr == NSWorkspaceRecycleOperation
				|| opPtr == GWorkspaceRecycleOutOperation
				|| opPtr == GWorkspaceEmptyRecyclerOperation) {        
    for (i = 0; i < [origfiles count]; i++) {
      NSString *fname = [origfiles objectAtIndex: i];
      NSString *fullpath = [source stringByAppendingPathComponent: fname];
      [paths addObject: fullpath];
    }
  }

  [fsnodeRep unlockPaths: paths];

	[dict setObject: opPtr forKey: @"operation"];	
  [dict setObject: source forKey: @"source"];	
  [dict setObject: destination forKey: @"destination"];	
  [dict setObject: files forKey: @"files"];	
  if (origfiles) {
    [dict setObject: origfiles forKey: @"origfiles"];	
  }
  
	[[NSNotificationCenter defaultCenter]
 				postNotificationName: GWFileSystemDidChangeNotification
	 								    object: dict];
}

- (void)setSelectedPaths:(NSArray *)paths
{
  if (paths && ([selectedPaths isEqualToArray: paths] == NO)) {
    ASSIGN (selectedPaths, paths);

    if (inspectorApp || finderApp) {
      NSData *data = [NSArchiver archivedDataWithRootObject: selectedPaths];

      if (inspectorApp) {
        [inspectorApp setPathsData: data];
      }
      
      if (finderApp) {
        [finderApp setSelectionData: data];
      }
    }
    
	  [[NSNotificationCenter defaultCenter]
 				 postNotificationName: GWCurrentSelectionChangedNotification
	 								     object: nil];      
  }
}

- (void)resetSelectedPaths
{
  if (selectedPaths == nil) {
    return;
  }
  
  if (inspectorApp || finderApp) {
    NSData *data = [NSArchiver archivedDataWithRootObject: selectedPaths];

    if (inspectorApp) {
      [inspectorApp setPathsData: data];
    }

    if (finderApp) {
      [finderApp setSelectionData: data];
    }
  }
				
  [[NSNotificationCenter defaultCenter]
 				 postNotificationName: GWCurrentSelectionChangedNotification
	 								        object: nil];    
}

- (NSArray *)selectedPaths
{
  return selectedPaths;
}

- (void)showPasteboardData:(NSData *)data 
                    ofType:(NSString *)type
                  typeIcon:(NSImage *)icon
{
  if (inspectorApp) {
    if ([inspectorApp canDisplayDataOfType: type]) {
      [inspectorApp showData: data ofType: type];
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
  [notifObj setObject: basePath forKey: @"source"];	
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
  if ([fsnodeRep usesThumbnails] == value) {
    return;
  }
  
  [fsnodeRep setUseThumbnails: value];
  
  [vwrsManager thumbnailsDidChangeInPaths: nil];
  
  if ((tshelfWin != nil) && ([tshelfWin isVisible])) {
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

      if ((tshelfWin != nil) && ([tshelfWin isVisible])) {
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
      
      if ((tshelfWin != nil) && ([tshelfWin isVisible])) {
        [tshelfWin updateIcons]; 
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
  if (inspectorApp == nil) {
    id insp = [NSConnection rootProxyForConnectionWithRegisteredName: @"Inspector" 
                                                                host: @""];

    if (insp) {
      NSConnection *c = [insp connectionForProxy];

	    [[NSNotificationCenter defaultCenter] addObserver: self
	                   selector: @selector(inspectorConnectionDidDie:)
		                     name: NSConnectionDidDieNotification
		                   object: c];
      
      inspectorApp = insp;
	    [inspectorApp setProtocolForProxy: @protocol(InspectorProtocol)];
      RETAIN (inspectorApp);
      
      if (selectedPaths) {
        NSData *data = [NSArchiver archivedDataWithRootObject: selectedPaths];
        [inspectorApp setPathsData: data];
      }
      
	  } else {
	    static BOOL recursion = NO;
	  
      if (recursion == NO) {
        int i;
        
        [startAppWin showWindowWithTitle: @"GWorkspace"
                                 appName: @"Inspector"
                            maxProgValue: 80.0];

        [ws launchApplication: @"Inspector"];

        for (i = 1; i <= 80; i++) {
          [startAppWin updateProgressBy: 1.0];
	        [[NSRunLoop currentRunLoop] runUntilDate:
		                       [NSDate dateWithTimeIntervalSinceNow: 0.1]];
          insp = [NSConnection rootProxyForConnectionWithRegisteredName: @"Inspector" 
                                                                   host: @""];                  
          if (insp) {
            [startAppWin updateProgressBy: 80.0 - i];
            break;
          }
        }
        
        [[startAppWin win] close];
        
	      recursion = YES;
	      [self connectInspector];
	      recursion = NO;
        
	    } else { 
	      recursion = NO;
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

  NSAssert(connection == [inspectorApp connectionForProxy],
		                                  NSInternalInconsistencyException);
  RELEASE (inspectorApp);
  inspectorApp = nil;

  if (NSRunAlertPanel(nil,
                    NSLocalizedString(@"The Inspector connection died.\nDo you want to restart it?", @""),
                    NSLocalizedString(@"Yes", @""),
                    NSLocalizedString(@"No", @""),
                    nil)) {
    [self connectInspector]; 
     
    if (inspectorApp) {
      NSData *data = [NSArchiver archivedDataWithRootObject: selectedPaths];
      [inspectorApp setPathsData: data];
    }
  }
}

- (void)connectFinder
{
  if (finderApp == nil) {
    id fndr = [NSConnection rootProxyForConnectionWithRegisteredName: @"Finder" 
                                                                host: @""];

    if (fndr) {
      NSConnection *c = [fndr connectionForProxy];

	    [[NSNotificationCenter defaultCenter] addObserver: self
	                   selector: @selector(finderConnectionDidDie:)
		                     name: NSConnectionDidDieNotification
		                   object: c];
      
      finderApp = fndr;
	    [finderApp setProtocolForProxy: @protocol(FinderAppProtocol)];
      RETAIN (finderApp);
      
      if (selectedPaths) {
        NSData *data = [NSArchiver archivedDataWithRootObject: selectedPaths];
        [finderApp setSelectionData: data];
      }
      
	  } else {
	    static BOOL recursion = NO;
	  
      if (recursion == NO) {
        int i;
        
        [startAppWin showWindowWithTitle: @"GWorkspace"
                                 appName: @"Finder"
                            maxProgValue: 80.0];

        [ws launchApplication: @"Finder"];

        for (i = 1; i <= 80; i++) {
          [startAppWin updateProgressBy: 1.0];
	        [[NSRunLoop currentRunLoop] runUntilDate:
		                       [NSDate dateWithTimeIntervalSinceNow: 0.1]];
          fndr = [NSConnection rootProxyForConnectionWithRegisteredName: @"Finder" 
                                                                   host: @""];                  
          if (fndr) {
            [startAppWin updateProgressBy: 80.0 - i];
            break;
          }
        }
        
        [[startAppWin win] close];
        
	      recursion = YES;
	      [self connectFinder];
	      recursion = NO;
        
	    } else { 
	      recursion = NO;
        NSRunAlertPanel(nil,
                NSLocalizedString(@"unable to contact Finder!", @""),
                NSLocalizedString(@"Ok", @""),
                nil, 
                nil);  
      }
	  }
  }
}

- (void)finderConnectionDidDie:(NSNotification *)notif
{
  id connection = [notif object];

  [[NSNotificationCenter defaultCenter] removeObserver: self
	                    name: NSConnectionDidDieNotification
	                  object: connection];

  NSAssert(connection == [finderApp connectionForProxy],
		                                  NSInternalInconsistencyException);
  RELEASE (finderApp);
  finderApp = nil;

  if (NSRunAlertPanel(nil,
                    NSLocalizedString(@"The Finder connection died.\nDo you want to restart it?", @""),
                    NSLocalizedString(@"Yes", @""),
                    NSLocalizedString(@"No", @""),
                    nil)) {
    [self connectFinder]; 
     
    if (finderApp) {
      NSData *data = [NSArchiver archivedDataWithRootObject: selectedPaths];
      [finderApp setSelectionData: data];
    }
  }
}

- (void)connectDesktop
{
  if (desktopApp == nil) {
    id dsk = [NSConnection rootProxyForConnectionWithRegisteredName: @"Desktop" 
                                                               host: @""];

    if (dsk) {
      NSConnection *c = [dsk connectionForProxy];

	    [[NSNotificationCenter defaultCenter] addObserver: self
	                   selector: @selector(desktopConnectionDidDie:)
		                     name: NSConnectionDidDieNotification
		                   object: c];
      
      desktopApp = dsk;
	    [desktopApp setProtocolForProxy: @protocol(DesktopAppProtocol)];
      RETAIN (desktopApp);
      
	  } else {
	    static BOOL recursion = NO;
	  
      if (recursion == NO) {
        int i;
        
        [startAppWin showWindowWithTitle: @"GWorkspace"
                                 appName: @"Desktop"
                            maxProgValue: 80.0];

        [ws launchApplication: @"Desktop"];

        for (i = 1; i <= 80; i++) {
          [startAppWin updateProgressBy: 1.0];
	        [[NSRunLoop currentRunLoop] runUntilDate:
		                       [NSDate dateWithTimeIntervalSinceNow: 0.1]];
          dsk = [NSConnection rootProxyForConnectionWithRegisteredName: @"Desktop" 
                                                                  host: @""];                  
          if (dsk) {
            [startAppWin updateProgressBy: 80.0 - i];
            break;
          }
        }
        
        [[startAppWin win] close];
        
	      recursion = YES;
	      [self connectDesktop];
	      recursion = NO;
        
	    } else { 
	      recursion = NO;
        NSRunAlertPanel(nil,
                NSLocalizedString(@"unable to contact Desktop!", @""),
                NSLocalizedString(@"Ok", @""),
                nil, 
                nil);  
      }
	  }
  }
}

- (void)desktopConnectionDidDie:(NSNotification *)notif
{
  id connection = [notif object];

  [[NSNotificationCenter defaultCenter] removeObserver: self
	                    name: NSConnectionDidDieNotification
	                  object: connection];

  NSAssert(connection == [desktopApp connectionForProxy],
		                                  NSInternalInconsistencyException);
  RELEASE (desktopApp);
  desktopApp = nil;

  if (NSRunAlertPanel(nil,
                    NSLocalizedString(@"The Desktop connection died.\nDo you want to restart it?", @""),
                    NSLocalizedString(@"Yes", @""),
                    NSLocalizedString(@"No", @""),
                    nil)) {
    [self connectDesktop]; 
  }
}

- (void)connectRecycler
{
  if (recyclerApp == nil) {
    id rcl = [NSConnection rootProxyForConnectionWithRegisteredName: @"Recycler" 
                                                               host: @""];

    if (rcl) {
      NSConnection *c = [rcl connectionForProxy];

	    [[NSNotificationCenter defaultCenter] addObserver: self
	                   selector: @selector(recyclerConnectionDidDie:)
		                     name: NSConnectionDidDieNotification
		                   object: c];
      
      recyclerApp = rcl;
	    [recyclerApp setProtocolForProxy: @protocol(RecyclerAppProtocol)];
      RETAIN (recyclerApp);
      
	  } else {
	    static BOOL recursion = NO;
	  
      if (recursion == NO) {
        int i;
        
        [startAppWin showWindowWithTitle: @"GWorkspace"
                                 appName: @"Recycler"
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

  [[NSNotificationCenter defaultCenter] removeObserver: self
	                    name: NSConnectionDidDieNotification
	                  object: connection];

  NSAssert(connection == [recyclerApp connectionForProxy],
		                                  NSInternalInconsistencyException);
  RELEASE (recyclerApp);
  recyclerApp = nil;

  if (NSRunAlertPanel(nil,
                    NSLocalizedString(@"The Recycler connection died.\nDo you want to restart it?", @""),
                    NSLocalizedString(@"Yes", @""),
                    NSLocalizedString(@"No", @""),
                    nil)) {
    [self connectRecycler]; 
  }
}

- (void)connectOperation
{
  if (operationsApp == nil) {
    id opr = [NSConnection rootProxyForConnectionWithRegisteredName: @"Operation" 
                                                               host: @""];

    if (opr) {
      NSConnection *c = [opr connectionForProxy];

	    [[NSNotificationCenter defaultCenter] addObserver: self
	                   selector: @selector(operationConnectionDidDie:)
		                     name: NSConnectionDidDieNotification
		                   object: c];
      
      operationsApp = opr;
	    [operationsApp setProtocolForProxy: @protocol(OperationProtocol)];
      RETAIN (operationsApp);
      
	  } else {
	    static BOOL recursion = NO;
	  
      if (recursion == NO) {
        int i;
        
        [startAppWin showWindowWithTitle: @"GWorkspace"
                                 appName: @"Operation"
                            maxProgValue: 80.0];

        [ws launchApplication: @"Operation"];

        for (i = 1; i <= 80; i++) {
          [startAppWin updateProgressBy: 1.0];
	        [[NSRunLoop currentRunLoop] runUntilDate:
		                       [NSDate dateWithTimeIntervalSinceNow: 0.1]];
          opr = [NSConnection rootProxyForConnectionWithRegisteredName: @"Operation" 
                                                                  host: @""];                  
          if (opr) {
            [startAppWin updateProgressBy: 80.0 - i];
            break;
          }
        }
        
        [[startAppWin win] close];
        
	      recursion = YES;
	      [self connectOperation];
	      recursion = NO;
        
	    } else { 
	      recursion = NO;
        NSRunAlertPanel(nil,
                NSLocalizedString(@"unable to contact Operation!", @""),
                NSLocalizedString(@"Ok", @""),
                nil, 
                nil);  
      }
	  }
  }
}

- (void)operationConnectionDidDie:(NSNotification *)notif
{
  id connection = [notif object];

  [[NSNotificationCenter defaultCenter] removeObserver: self
	                    name: NSConnectionDidDieNotification
	                  object: connection];

  NSAssert(connection == [operationsApp connectionForProxy],
		                                  NSInternalInconsistencyException);
  RELEASE (operationsApp);
  operationsApp = nil;

  NSRunAlertPanel(nil, 
       NSLocalizedString(@"The Operation connection died. File operations disabled!", @""), 
                              NSLocalizedString(@"OK", @""), nil, nil);                                     
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

- (void)showInfo:(id)sender
{
  NSMutableDictionary *d = AUTORELEASE ([NSMutableDictionary new]);
  [d setObject: @"GWorkspace" forKey: @"ApplicationName"];
  [d setObject: NSLocalizedString(@"GNUstep Workspace Manager", @"")
      	forKey: @"ApplicationDescription"];
  [d setObject: @"GWorkspace 0.6.5" forKey: @"ApplicationRelease"];
  [d setObject: @"06 2004" forKey: @"FullVersionID"];
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
  [vwrsManager showRootViewer];
}

- (void)showHistory:(id)sender
{
  [history activate];
}

- (void)showInspector:(id)sender
{
	if (inspectorApp == nil) {
    [self connectInspector];
    if (inspectorApp) {
      NSData *data = [NSArchiver archivedDataWithRootObject: selectedPaths];
      [inspectorApp setPathsData: data];
    }    
  }
	if (inspectorApp) {
    [inspectorApp showWindow];
  } 
}

- (void)showAttributesInspector:(id)sender
{
	if (inspectorApp == nil) {
    [self connectInspector];
    if (inspectorApp) {
      NSData *data = [NSArchiver archivedDataWithRootObject: selectedPaths];
      [inspectorApp setPathsData: data];
    }
  }
  if (inspectorApp) {  
    [inspectorApp showAttributes];
  } 
}

- (void)showContentsInspector:(id)sender
{
	if (inspectorApp == nil) {
    [self connectInspector];
    if (inspectorApp) {
      NSData *data = [NSArchiver archivedDataWithRootObject: selectedPaths];
      [inspectorApp setPathsData: data];
    }
  }
  if (inspectorApp) {  
    [inspectorApp showContents];
  } 
}

- (void)showToolsInspector:(id)sender
{
	if (inspectorApp == nil) {
    [self connectInspector];
    if (inspectorApp) {
      NSData *data = [NSArchiver archivedDataWithRootObject: selectedPaths];
      [inspectorApp setPathsData: data];
    }
  }
  if (inspectorApp) {  
    [inspectorApp showTools];
  } 
}

- (void)showDesktop:(id)sender
{
	if (desktopApp == nil) {
    [self connectDesktop];
  }   
}

- (void)showRecycler:(id)sender
{
	if (recyclerApp == nil) {
    [self connectRecycler];
  }   
}

- (void)showFinder:(id)sender
{
	if (finderApp == nil) {
    [self connectFinder];
    if (finderApp) {
      NSData *data = [NSArchiver archivedDataWithRootObject: selectedPaths];
      [finderApp setSelectionData: data];
    }    
  }
	if (finderApp) {
    [finderApp showWindow];
  }   
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
  NSWindow *kwin = [NSApp keyWindow];

  if (kwin) {
    if ([kwin isKindOfClass: [TShelfWin class]]) {
      TShelfViewItem *item = [[tshelfWin shelfView] selectedTabItem];

      if (item) {
        TShelfIconsView *iview = (TShelfIconsView *)[item view];
        [iview doCut];    
      }
      
    } else if ([vwrsManager hasViewerWithWindow: kwin]) {
      id nodeView = [[vwrsManager viewerWithWindow: kwin] nodeView];
      NSArray *selection = [nodeView selectedPaths];  
      NSArray *basesel = [NSArray arrayWithObject: [[nodeView baseNode] path]];
      
      if ([selection count] && ([selection isEqual: basesel] == NO)) {
        NSPasteboard *pb = [NSPasteboard generalPasteboard];

        [pb declareTypes: [NSArray arrayWithObject: NSFilenamesPboardType]
                   owner: nil];

        if ([pb setPropertyList: selection forType: NSFilenamesPboardType]) {
          [self connectOperation];

          if (operationsApp) {
            [(id <OperationProtocol>)operationsApp setFilenamesCutted: YES];
          } else {
            NSRunAlertPanel(nil, 
                NSLocalizedString(@"File operations disabled!", @""), 
                                    NSLocalizedString(@"OK", @""), nil, nil);                                     
          }
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
      
    } else if ([vwrsManager hasViewerWithWindow: kwin]) {
      id nodeView = [[vwrsManager viewerWithWindow: kwin] nodeView];
      NSArray *selection = [nodeView selectedPaths];  
      NSArray *basesel = [NSArray arrayWithObject: [[nodeView baseNode] path]];
      
      if ([selection count] && ([selection isEqual: basesel] == NO)) {
        NSPasteboard *pb = [NSPasteboard generalPasteboard];

        [pb declareTypes: [NSArray arrayWithObject: NSFilenamesPboardType]
                   owner: nil];

        if ([pb setPropertyList: selection forType: NSFilenamesPboardType]) {
          [self connectOperation];

          if (operationsApp) {
            [(id <OperationProtocol>)operationsApp setFilenamesCutted: NO];
          } else {
            NSRunAlertPanel(nil, 
                NSLocalizedString(@"File operations disabled!", @""), 
                                    NSLocalizedString(@"OK", @""), nil, nil);                                     
          }
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
      
    } else if ([vwrsManager hasViewerWithWindow: kwin]) {
      NSPasteboard *pb = [NSPasteboard generalPasteboard];

      if ([[pb types] containsObject: NSFilenamesPboardType]) {
        NSArray *sourcePaths = [pb propertyListForType: NSFilenamesPboardType];   

        if (sourcePaths) {
          [self connectOperation];

          if (operationsApp) {
            id nodeView = [[vwrsManager viewerWithWindow: kwin] nodeView];
            BOOL cutted = [(id <OperationProtocol>)operationsApp filenamesWasCutted];
    
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
                  operation = GWorkspaceRecycleOutOperation;
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
          } else {
            NSRunAlertPanel(nil, 
                NSLocalizedString(@"File operations disabled!", @""), 
                                    NSLocalizedString(@"OK", @""), nil, nil); 
            return;                                    
          }
        }
      }
    }    
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

- (void)checkRemovableMedia:(id)sender
{
  if (desktopApp) {
    [desktopApp checkNewRemovableMedia: nil];
  }	
}

- (void)emptyRecycler:(id)sender
{
  if (desktopApp) {
    [desktopApp emptyTrash: nil];
  }	else if (recyclerApp) {
    [recyclerApp emptyTrash: nil];
  }
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
  NSString *appName = (NSString *)[sender representedObject];
    
  if (selectedPaths && [selectedPaths count]) {
    int i;
    
    for (i = 0; i < [selectedPaths count]; i++) {
      [ws openFile: [selectedPaths objectAtIndex: i] withApplication: appName];
    }
  }
}

- (void)performFileOperation:(NSDictionary *)opinfo
{
  [self performFileOperationWithDictionary: opinfo];
}

- (void)concludeRemoteFilesDragOperation:(NSData *)opinfo
                             atLocalPath:(NSString *)localdest
{

}

// - (void)addWatcherForPath:(NSString *)path // already in GWProtocol

// - (void)removeWatcherForPath:(NSString *)path // already in GWProtocol

// - (NSString *)trashPath // already in GWProtocol

- (id)workspaceApplication
{
  return [GWorkspace gworkspace];
}

@end



