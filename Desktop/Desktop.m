/* Desktop.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: May 2004
 *
 * This file is part of the GNUstep Desktop application
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
#include "Desktop.h"
#include "DesktopWindow.h"
#include "DesktopView.h"
#include "Dock.h"
#include "Preferences/DesktopPrefs.h"
#include "Dialogs/StartAppWin.h"
#include "FSNode.h"
#include "FSNodeRep.h"
#include "FSNFunctions.h"
#include "GNUstep.h"

#define CHECKSIZE(sz) \
if (sz.width < 0) sz.width = 0; \
if (sz.height < 0) sz.height = 0

static Desktop *desktop = nil;

@implementation Desktop

+ (Desktop *)desktop
{
	if (desktop == nil) {
		desktop = [[Desktop alloc] init];
	}	
  return desktop;
}

+ (void)initialize
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject: @"Desktop" 
               forKey: @"DesktopApplicationName"];
  [defaults setObject: @"desktop" 
               forKey: @"DesktopApplicationSelName"];
  [defaults synchronize];
}

- (void)dealloc
{
  if (fswatcher && [[(NSDistantObject *)fswatcher connectionForProxy] isValid]) {
    [fswatcher unregisterClient: (id <FSWClientProtocol>)self];
    DESTROY (fswatcher);
  }
  [[NSDistributedNotificationCenter defaultCenter] removeObserver: self];
  [[ws notificationCenter] removeObserver: self];
  DESTROY (workspaceApplication);
  DESTROY (inspectorApp);
  DESTROY (operationsApp);
  RELEASE (trashPath);
  TEST_RELEASE (desktopDir);
  DESTROY (workspaceApplication);
  RELEASE (dock);
  RELEASE (win);
  RELEASE (preferences);
  RELEASE (startAppWin);
    
	[super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
    fm = [NSFileManager defaultManager];
    ws = [NSWorkspace sharedWorkspace];
    nc = [NSNotificationCenter defaultCenter];
    workspaceApplication = nil;
  }
  
  return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  NSString *home;
  BOOL isdir;
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
  id defentry;

  home = NSHomeDirectory();
  home = [home stringByAppendingPathComponent: @"Desktop"];  

  if (([fm fileExistsAtPath: home isDirectory: &isdir] && isdir) == NO) {
    if ([fm createDirectoryAtPath: home attributes: nil] == NO) {
      NSRunAlertPanel(NSLocalizedString(@"error", @""), 
             NSLocalizedString(@"Can't create the Desktop directory! Quiting now.", @""), 
                                    NSLocalizedString(@"OK", @""), nil, nil);                                     
      [NSApp terminate: self];
    }
  }

  ASSIGN (desktopDir, [FSNode nodeWithRelativePath: home parent: nil]);

  defentry = [defaults objectForKey: @"dockposition"];
  dockPosition = defentry ? [defentry intValue] : DockPositionRight;
  
  [self setReservedFrames];

  fswatcher = nil;
  fswnotifications = YES;
  [self connectFSWatcher];

  if ([defaults boolForKey: @"uses_inspector"]) {  
    [self connectInspector];
  }
     
  win = [DesktopWindow new];
  [win activate];
  [[win desktopView] showMountedVolumes];
  [[win desktopView] showContentsOfNode: desktopDir];
  
  [self createTrashPath];
  
  dock = [Dock new];
  [dock activate];
  
  preferences = [DesktopPrefs new];

  startAppWin = [[StartAppWin alloc] init];
  
  [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                				selector: @selector(fileSystemWillChange:) 
                					  name: @"GWFileSystemWillChangeNotification"
                					object: nil];

  [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                				selector: @selector(fileSystemDidChange:) 
                					  name: @"GWFileSystemDidChangeNotification"
                					object: nil];

  [[ws notificationCenter] addObserver: self 
                				selector: @selector(newVolumeMounted:) 
                					  name: NSWorkspaceDidMountNotification
                					object: nil];

  [[ws notificationCenter] addObserver: self 
                				selector: @selector(mountedVolumeWillUnmount:) 
                					  name: NSWorkspaceWillUnmountNotification
                					object: nil];

  [[ws notificationCenter] addObserver: self 
                				selector: @selector(mountedVolumeDidUnmount:) 
                					  name: NSWorkspaceDidUnmountNotification
                					object: nil];
}

- (BOOL)applicationShouldTerminate:(NSApplication *)app 
{
  [self updateDefaults];

  if (workspaceApplication) {
    NSConnection *c = [(NSDistantObject *)workspaceApplication connectionForProxy];
  
    if (c && [c isValid]) {
      [nc removeObserver: self
	                  name: NSConnectionDidDieNotification
	                object: c];
      DESTROY (workspaceApplication);
    }
  }

  if (fswatcher) {
    NSConnection *fswconn = [(NSDistantObject *)fswatcher connectionForProxy];
  
    if ([fswconn isValid]) {
      [nc removeObserver: self
	                  name: NSConnectionDidDieNotification
	                object: fswconn];
      [fswatcher unregisterClient: (id <FSWClientProtocol>)self];  
      DESTROY (fswatcher);
    }
  }

  if (inspectorApp) {
    NSConnection *inspconn = [(NSDistantObject *)inspectorApp connectionForProxy];
  
    if (inspconn && [inspconn isValid]) {
      [nc removeObserver: self
	                  name: NSConnectionDidDieNotification
	                object: inspconn];
      DESTROY (inspectorApp);
    }
  }

  if (operationsApp) {
    NSConnection *opspconn = [(NSDistantObject *)operationsApp connectionForProxy];
  
    if (opspconn && [opspconn isValid]) {
      [nc removeObserver: self
	                  name: NSConnectionDidDieNotification
	                object: opspconn];
      DESTROY (operationsApp);
    }
  }
    		
	return YES;
}

- (NSWindow *)desktopWindow
{
  return win;
}

- (DesktopView *)desktopView
{
  return [win desktopView];
}

- (Dock *)dock
{
  return dock;
}

- (DockPosition)dockPosition
{
  return dockPosition;
}

- (void)setDockPosition:(DockPosition)pos
{
  dockPosition = pos;
  [dock setPosition: pos];
  [self setReservedFrames];
  [[win desktopView] dockPositionDidChange];
}

- (NSRect)dockReservedFrame
{
  return dockReservedFrame;
}

- (NSRect)tshelfReservedFrame
{
  return tshelfReservedFrame;
}

- (void)setReservedFrames
{
  NSRect screenFrame = [[NSScreen mainScreen] frame];

  dockReservedFrame.size.height = screenFrame.size.height;
  dockReservedFrame.size.width = 64 + 10;
  dockReservedFrame.origin.x = 0;
  dockReservedFrame.origin.y = 0;
  
  if (dockPosition == DockPositionRight) {
    dockReservedFrame.origin.x = screenFrame.size.width - 64 - 10;
  }
  
  tshelfReservedFrame = NSMakeRect(0, 0, screenFrame.size.width, 106 + 10);
}

- (void)contactWorkspaceApp
{
  id app = nil;

  if (workspaceApplication == nil) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *appName = [defaults stringForKey: @"GSWorkspaceApplication"];

    if (appName == nil) {
      appName = @"GWorkspace";
    }

    app = [NSConnection rootProxyForConnectionWithRegisteredName: appName
                                                            host: @""];

    if (app) {
      NSConnection *c = [app connectionForProxy];

	    [nc addObserver: self
	           selector: @selector(workspaceAppConnectionDidDie:)
		             name: NSConnectionDidDieNotification
		           object: c];

      workspaceApplication = app;
      [workspaceApplication setProtocolForProxy: @protocol(workspaceAppProtocol)];
      RETAIN (workspaceApplication);
      
	  } else {
	    static BOOL recursion = NO;
	  
      if (recursion == NO) {
        int i;
        
        [ws launchApplication: appName];

        for (i = 1; i <= 40; i++) {
          NSDate *limit = [[NSDate alloc] initWithTimeIntervalSinceNow: 0.1];
          [[NSRunLoop currentRunLoop] runUntilDate: limit];
          RELEASE(limit);
        
          app = [NSConnection rootProxyForConnectionWithRegisteredName: appName 
                                                                   host: @""];                  
          if (app) {
            break;
          }
        }
                
	      recursion = YES;
	      [self contactWorkspaceApp];
	      recursion = NO;
        
	    } else { 
	      recursion = NO;
        NSRunAlertPanel(nil,
                NSLocalizedString(@"unable to contact the workspace application!", @""),
                NSLocalizedString(@"Ok", @""),
                nil, 
                nil);  
      }
	  }
  }
}

- (void)workspaceAppConnectionDidDie:(NSNotification *)notif
{
  id connection = [notif object];

  [nc removeObserver: self
	              name: NSConnectionDidDieNotification
	            object: connection];

  NSAssert(connection == [workspaceApplication connectionForProxy],
		                                      NSInternalInconsistencyException);
  DESTROY (workspaceApplication);
}

- (void)connectFSWatcher
{
  if (fswatcher == nil) {
    id fsw = [NSConnection rootProxyForConnectionWithRegisteredName: @"fswatcher" 
                                                               host: @""];

    if (fsw) {
      NSConnection *c = [fsw connectionForProxy];

	    [nc addObserver: self
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
        
        [startAppWin showWindowWithTitle: @"Desktop"
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

  [nc removeObserver: self
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

- (void)connectInspector
{
  if (inspectorApp == nil) {
    id insp = [NSConnection rootProxyForConnectionWithRegisteredName: @"Inspector" 
                                                                host: @""];

    if (insp) {
      NSConnection *c = [insp connectionForProxy];

	    [nc addObserver: self
	           selector: @selector(inspectorConnectionDidDie:)
		             name: NSConnectionDidDieNotification
		           object: c];
      
      inspectorApp = insp;
	    [inspectorApp setProtocolForProxy: @protocol(InspectorProtocol)];
      RETAIN (inspectorApp);
      
    //  if (selectedPaths) {
   //     NSData *data = [NSArchiver archivedDataWithRootObject: selectedPaths];
   //     [inspectorApp setPathsData: data];
   //   }
      
	  } else {
	    static BOOL recursion = NO;
	  
      if (recursion == NO) {
        int i;
        
        [startAppWin showWindowWithTitle: @"Desktop"
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

  [nc removeObserver: self
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
  //    NSData *data = [NSArchiver archivedDataWithRootObject: selectedPaths];
  //    [inspectorApp setPathsData: data];
    }
  }
}

- (void)connectOperation
{
  if (operationsApp == nil) {
    id opr = [NSConnection rootProxyForConnectionWithRegisteredName: @"Operation" 
                                                               host: @""];

    if (opr) {
      NSConnection *c = [opr connectionForProxy];

	    [nc addObserver: self
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
        
        [startAppWin showWindowWithTitle: @"Desktop"
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

  [nc removeObserver: self
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

- (void)fileSystemWillChange:(NSNotification *)notif
{
  NSDictionary *dict = [notif userInfo];  
  NSString *operation = [dict objectForKey: @"operation"];
  NSString *source = [dict objectForKey: @"source"];
  NSString *destination = [dict objectForKey: @"destination"];
  NSString *desktopPath = [desktopDir path];
    
  if ([destination isEqual: desktopPath] || [source isEqual: desktopPath]) {
    NSArray *files = [dict objectForKey: @"files"];
    NSMutableArray *paths = [NSMutableArray array];
    NSString *basePath = nil;
    int i;

    if ([destination isEqual: desktopPath]
            && ([operation isEqual: @"NSWorkspaceMoveOperation"]   
                || [operation isEqual: @"NSWorkspaceCopyOperation"]
                || [operation isEqual: @"NSWorkspaceLinkOperation"]
                || [operation isEqual: @"NSWorkspaceDuplicateOperation"]
				        || [operation isEqual: @"NSWorkspaceRecycleOperation"]
				        || [operation isEqual: @"GWorkspaceRecycleOutOperation"])) { 
      basePath = destination;
      
    } else if ([source isEqual: desktopPath]
          && ([operation isEqual: @"NSWorkspaceMoveOperation "]
              || [operation isEqual: @"NSWorkspaceDestroyOperation"]
			        || [operation isEqual: @"NSWorkspaceRecycleOperation"]
			        || [operation isEqual: @"GWorkspaceRecycleOutOperation"]
			        || [operation isEqual: @"GWorkspaceEmptyRecyclerOperation"])) {
      basePath = source;
    }
    
    if (basePath) {
      for (i = 0; i < [files count]; i++) {
        NSString *fname = [files objectAtIndex: i];
        NSString *fullpath = [basePath stringByAppendingPathComponent: fname];
        [paths addObject: fullpath];
      }
    
      [FSNodeRep lockPaths: paths];
      [[self desktopView] fileSystemWillChange: dict];
    }
  }  
}

- (void)fileSystemDidChange:(NSNotification *)notif
{
  NSDictionary *dict = [notif userInfo];  
  NSString *operation = [dict objectForKey: @"operation"];
  NSString *source = [dict objectForKey: @"source"];
  NSString *destination = [dict objectForKey: @"destination"];
  NSArray *files = [dict objectForKey: @"files"];
  NSString *desktopPath = [desktopDir path];

  if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
    files = [NSArray arrayWithObject: [source lastPathComponent]];
    source = [source stringByDeletingLastPathComponent]; 
  }

  if ([destination isEqual: desktopPath] || [source isEqual: desktopPath]) {
    NSMutableArray *paths = [NSMutableArray array];
    NSString *basePath = nil;
    int i;

    if ([destination isEqual: desktopPath]
            && ([operation isEqual: @"NSWorkspaceMoveOperation"]   
                || [operation isEqual: @"NSWorkspaceCopyOperation"]
                || [operation isEqual: @"NSWorkspaceLinkOperation"]
                || [operation isEqual: @"NSWorkspaceDuplicateOperation"]
				        || [operation isEqual: @"GWorkspaceRecycleOutOperation"])) { 
      basePath = destination;
      
    } else if ([source isEqual: desktopPath]
          && ([operation isEqual: @"NSWorkspaceMoveOperation"]
              || [operation isEqual: @"NSWorkspaceDestroyOperation"]
			        || [operation isEqual: @"NSWorkspaceRecycleOperation"]
			        || [operation isEqual: @"GWorkspaceRenameOperation"]
			        || [operation isEqual: @"GWorkspaceRecycleOutOperation"])) {
      basePath = source;
    }
    
    if (basePath) {
      for (i = 0; i < [files count]; i++) {
        NSString *fname = [files objectAtIndex: i];
        NSString *fullpath = [basePath stringByAppendingPathComponent: fname];
        [paths addObject: fullpath];
      }
    
      [FSNodeRep unlockPaths: paths];
      [[self desktopView] fileSystemDidChange: dict];
    }
  }  
  
  [dock fileSystemDidChange: dict];  
}

- (void)watchedPathDidChange:(NSData *)dirinfo
{
  NSDictionary *info = [NSUnarchiver unarchiveObjectWithData: dirinfo];
  NSString *path = [info objectForKey: @"path"];
  NSString *event = [info objectForKey: @"event"];
  
  if ([event isEqual: @"GWWatchedDirectoryDeleted"]) {
    if ([path isEqual: [desktopDir path]]) {
      NSRunAlertPanel(nil, 
                      NSLocalizedString(@"The Desktop directory has been deleted! Quiting now!", @""), 
                      NSLocalizedString(@"OK", @""), 
                      nil, 
                      nil);                                     
      [NSApp terminate: self];
    }
    
  } else if ([event isEqual: @"GWWatchedFileModified"]) {
    [[self desktopView] watchedPathDidChange: info];
    
  } else if ([path isEqual: [desktopDir path]]) {
    [[self desktopView] watchedPathDidChange: info];
  }    

  [dock watchedPathDidChange: info];  
}

- (void)newVolumeMounted:(NSNotification *)notif
{
  NSDictionary *dict = [notif userInfo];  
  NSString *volpath = [dict objectForKey: @"NSDevicePath"];

  [[self desktopView] newVolumeMountedAtPath: volpath];
}

- (void)mountedVolumeWillUnmount:(NSNotification *)notif
{
  NSDictionary *dict = [notif userInfo];  
  NSString *volpath = [dict objectForKey: @"NSDevicePath"];

  [FSNodeRep lockPaths: [NSArray arrayWithObject: volpath]];
  [[self desktopView] workspaceWillUnmountVolumeAtPath: volpath];
}

- (void)mountedVolumeDidUnmount:(NSNotification *)notif
{
  NSDictionary *dict = [notif userInfo];  
  NSString *volpath = [dict objectForKey: @"NSDevicePath"];

  [FSNodeRep unlockPaths: [NSArray arrayWithObject: volpath]];
  [[self desktopView] workspaceDidUnmountVolumeAtPath: volpath];
}

- (void)createTrashPath
{
	NSString *basePath, *tpath; 
	BOOL isdir;

  basePath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
  basePath = [basePath stringByAppendingPathComponent: @"Desktop"];

  if (([fm fileExistsAtPath: basePath isDirectory: &isdir] && isdir) == NO) {
    if ([fm createDirectoryAtPath: basePath attributes: nil] == NO) {
      NSLog(@"Can't create the Recycler directory! Quitting now.");
      [NSApp terminate: self];
    }
  }
  
	tpath = [basePath stringByAppendingPathComponent: @".Trash"];

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
}

- (void)updateDefaults
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  [defaults setObject: [NSNumber numberWithInt: dockPosition]
               forKey: @"dockposition"];
               
  [defaults setBool: (inspectorApp != nil) forKey: @"uses_inspector"];
               
  [defaults synchronize];
  
  [dock updateDefaults];
  [[win desktopView] updateDefaults];
  [preferences updateDefaults];
}


//
// Menu Operations
//
- (BOOL)validateMenuItem:(NSMenuItem *)anItem 
{	
	NSString *title = [anItem title];
	
	if ([title isEqual: NSLocalizedString(@"Open", @"")]
        || [title isEqual: NSLocalizedString(@"Duplicate", @"")]
        || [title isEqual: NSLocalizedString(@"Move to Recycler", @"")]) {
    return [[[win desktopView] selectedPaths] count] ? YES : NO;
    
  } else if ([title isEqual: NSLocalizedString(@"Empty Recycler", @"")]) {
    return [[FSNodeRep directoryContentsAtPath: trashPath] count] ? YES : NO;

  } else if ([title isEqual: NSLocalizedString(@"New Folder", @"")]) {
    return ([[[win desktopView] selectedPaths] count] == 0);
    
  } else if ([title isEqual: NSLocalizedString(@"Open With...", @"")]) {
    NSArray *selnodes = [[win desktopView] selectedNodes];
    BOOL found = NO;
    int i;
    
    for (i = 0; i < [selnodes count]; i++) {
      FSNode *snode = [selnodes objectAtIndex: i];
      
      if ([snode isDirectory] == NO) {
        if ([snode isPlain] == NO) {
          found = YES;
        }
      } else {
        if (([snode isPackage] == NO) || [snode isApplication]) {
          found = YES;
        } 
      }
      
      if (found) {
        break;
      }
    }
    
    return !found;
  }

	return YES;
}

- (void)openSelection:(id)sender
{
  [self openSelectionInNewViewer: YES];
}

- (void)openSelectionWithApp:(id)sender
{
  NSString *appName = (NSString *)[sender representedObject];
  NSArray *selpaths = [[win desktopView] selectedPaths];
    
  if ([selpaths count]) {
    int i;
    
    for (i = 0; i < [selpaths count]; i++) {
      [ws openFile: [selpaths objectAtIndex: i] withApplication: appName];
    }
  }
}

- (void)openSelectionWith:(id)sender
{
//  [[GWLib workspaceApp] openSelectedPathsWith];
}

- (void)newFolder:(id)sender
{
  NSString *desktopPath = [desktopDir path];
	NSString *fileName = NSLocalizedString(@"NewFolder", @"");
  NSString *filePath = [desktopPath stringByAppendingPathComponent: fileName];
  int suff = 1;
  NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];

  if ([fm fileExistsAtPath: filePath]) {    
    while (1) {    
      NSString *s = [fileName stringByAppendingFormat: @"%i", suff];
      filePath = [desktopPath stringByAppendingPathComponent: s];
      if ([fm fileExistsAtPath: filePath] == NO) {
        fileName = [NSString stringWithString: s];
        break;      
      }      
      suff++;
    }     
  }

	[userInfo setObject: @"GWorkspaceCreateDirOperation" 
               forKey: @"operation"];	
  [userInfo setObject: desktopPath forKey: @"source"];	
  [userInfo setObject: desktopPath forKey: @"destination"];	
  [userInfo setObject: [NSArray arrayWithObjects: fileName, nil] 
               forKey: @"files"];	

	[[NSDistributedNotificationCenter defaultCenter]
 				postNotificationName: @"GWFileSystemWillChangeNotification"
	 								    object: nil 
                    userInfo: userInfo];

  [fm createDirectoryAtPath: filePath attributes: nil];

	[[NSDistributedNotificationCenter defaultCenter]
 				postNotificationName: @"GWFileSystemDidChangeNotification"
	 								    object: nil 
                    userInfo: userInfo];
}

- (void)duplicateFiles:(id)sender
{
  NSMutableArray *selpaths = [[[win desktopView] selectedPaths] mutableCopy];
  int count = [selpaths count];
  int i;
  
  for (i = 0; i < count; i++) {
    NSString *spath = [selpaths objectAtIndex: i];
    FSNode *node = [FSNode nodeWithRelativePath: spath parent: nil];
    
    if ([node isMountPoint] || [spath isEqual: path_separator()]) {
      [selpaths removeObject: spath];
      count--;
      i--;
    }
  }
  
  if ([selpaths count]) {
    NSString *desktopPath = [desktopDir path];
    NSMutableArray *files = [NSMutableArray array];
    NSMutableDictionary *opinfo = [NSMutableDictionary dictionary];
    int i;

    for (i = 0; i < [selpaths count]; i++) {
      NSString *path = [selpaths objectAtIndex: i];
      [files addObject: [path lastPathComponent]];
    }

    [opinfo setObject: @"NSWorkspaceDuplicateOperation" forKey: @"operation"];
    [opinfo setObject: desktopPath forKey: @"source"];
    [opinfo setObject: desktopPath forKey: @"destination"];
    [opinfo setObject: files forKey: @"files"];

    [self performFileOperation: opinfo];
  }
  
  RELEASE (selpaths);
}

- (void)moveToTrash:(id)sender
{
  NSMutableArray *selpaths = [[[win desktopView] selectedPaths] mutableCopy];
  int count = [selpaths count];
  int i;
  
  for (i = 0; i < count; i++) {
    NSString *spath = [selpaths objectAtIndex: i];
    FSNode *node = [FSNode nodeWithRelativePath: spath parent: nil];
    
    if ([node isMountPoint] || [spath isEqual: path_separator()]) {
      [selpaths removeObject: spath];
      count--;
      i--;
    }
  }
    
  if ([selpaths count]) {
    NSString *desktopPath = [desktopDir path];
    NSMutableArray *files = [NSMutableArray array];
    NSMutableDictionary *opinfo = [NSMutableDictionary dictionary];
    int i;

    for (i = 0; i < [selpaths count]; i++) {
      NSString *path = [selpaths objectAtIndex: i];
      [files addObject: [path lastPathComponent]];
    }

    [opinfo setObject: @"NSWorkspaceRecycleOperation" forKey: @"operation"];
    [opinfo setObject: desktopPath forKey: @"source"];
    [opinfo setObject: trashPath forKey: @"destination"];
    [opinfo setObject: files forKey: @"files"];

    [self performFileOperation: opinfo];
  }
  
  RELEASE (selpaths);
}

- (void)emptyTrash:(id)sender
{
  FSNode *node = [FSNode nodeWithRelativePath: trashPath parent: nil];
  NSArray *subNodes = [node subNodes];
  
  if ([subNodes count]) {
    NSMutableArray *files = [NSMutableArray array];
    NSMutableDictionary *opinfo = [NSMutableDictionary dictionary];
    int i;  

    for (i = 0; i < [subNodes count]; i++) {
      [files addObject: [(FSNode *)[subNodes objectAtIndex: i] name]];
    }

    [opinfo setObject: @"GWorkspaceEmptyRecyclerOperation" forKey: @"operation"];
    [opinfo setObject: trashPath forKey: @"source"];
    [opinfo setObject: trashPath forKey: @"destination"];
    [opinfo setObject: files forKey: @"files"];

    [self performFileOperation: opinfo];
  }
}

- (void)showInspector:(id)sender
{
	if (inspectorApp == nil) {
    [self connectInspector];
    if (inspectorApp) {
      NSArray *selpaths = [[win desktopView] selectedPaths];
    
      if ([selpaths count]) {
        NSData *data = [NSArchiver archivedDataWithRootObject: selpaths];
        [inspectorApp setPathsData: data];
      }
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
      NSArray *selpaths = [[win desktopView] selectedPaths];
    
      if ([selpaths count]) {
        NSData *data = [NSArchiver archivedDataWithRootObject: selpaths];
        [inspectorApp setPathsData: data];
      }
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
      NSArray *selpaths = [[win desktopView] selectedPaths];
    
      if ([selpaths count]) {
        NSData *data = [NSArchiver archivedDataWithRootObject: selpaths];
        [inspectorApp setPathsData: data];
      }
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
      NSArray *selpaths = [[win desktopView] selectedPaths];
    
      if ([selpaths count]) {
        NSData *data = [NSArchiver archivedDataWithRootObject: selpaths];
        [inspectorApp setPathsData: data];
      }
    }
  }
  if (inspectorApp) {  
    [inspectorApp showTools];
  } 
}

- (void)showPreferences:(id)sender
{
  [preferences activate];
}

- (void)showInfo:(id)sender
{
  NSMutableDictionary *d = AUTORELEASE ([NSMutableDictionary new]);
  [d setObject: @"Desktop" forKey: @"ApplicationName"];
  [d setObject: NSLocalizedString(@"-----------------------", @"")
      	forKey: @"ApplicationDescription"];
  [d setObject: @"Desktop 0.7" forKey: @"ApplicationRelease"];
  [d setObject: @"04 2004" forKey: @"FullVersionID"];
  [d setObject: [NSArray arrayWithObjects: @"Enrico Sersale <enrico@imago.ro>.", nil]
        forKey: @"Authors"];
  [d setObject: NSLocalizedString(@"See http://www.gnustep.it/enrico/gworkspace", @"") forKey: @"URL"];
  [d setObject: @"Copyright (C) 2004 Free Software Foundation, Inc."
        forKey: @"Copyright"];
  [d setObject: NSLocalizedString(@"Released under the GNU General Public License 2.0", @"")
        forKey: @"CopyrightDescription"];
  
#ifdef GNUSTEP	
  [NSApp orderFrontStandardInfoPanelWithOptions: d];
#else
	[NSApp orderFrontStandardAboutPanel: d];
#endif
}

#ifndef GNUSTEP
- (void)terminate:(id)sender
{
  [NSApp terminate: self];
}
#endif


//
// DesktopApplication protocol
//
- (void)selectionChanged:(NSArray *)newsel
{
  if (inspectorApp) {
    NSData *data = [NSArchiver archivedDataWithRootObject: newsel];
    [inspectorApp setPathsData: data];
  }
}

- (void)openSelectionInNewViewer:(BOOL)newv
{
  NSArray *selection = [[win desktopView] selectedNodes];
  id <workspaceAppProtocol> workspaceApp = [self workspaceApplication];
  int i;
  
  for (i = 0; i < [selection count]; i++) {
    FSNode *node = [selection objectAtIndex: i];
  
    if ([node isDirectory]) {
      if ([node isPackage]) {
        if (newv && workspaceApp) {
          [workspaceApp selectFile: [node path] inFileViewerRootedAtPath: [node path]];
        } else {
          if ([node isApplication] == NO) {
            [ws openFile: [node path]];
          } else {
            [ws launchApplication: [node path]];
          }
        }
      } else if (workspaceApp) {
        [workspaceApp selectFile: [node path] inFileViewerRootedAtPath: [node path]];
      }
    } else if ([node isPlain]) {
      [ws openFile: [node path]];
    }
  }
}

- (void)performFileOperation:(NSDictionary *)opinfo
{
  [self connectOperation];

  if (operationsApp) {  
    NSData *data = [NSArchiver archivedDataWithRootObject: opinfo];
    [(id <OperationProtocol>)operationsApp performFileOperation: data];
  } else {
    NSRunAlertPanel(nil, 
        NSLocalizedString(@"File operations disabled!", @""), 
                            NSLocalizedString(@"OK", @""), nil, nil);                                     
  }
}

- (void)concludeRemoteFilesDragOperation:(NSData *)opinfo
                             atLocalPath:(NSString *)localdest
{
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

- (NSString *)trashPath
{
  return trashPath;
}

- (id)workspaceApplication
{
  if (workspaceApplication == nil) {
    [self contactWorkspaceApp];
  }
  return workspaceApplication;
}

@end


@implementation NSWorkspace (mounting)

- (BOOL)getFileSystemInfoForPath:(NSString *)fullPath
		                 isRemovable:(BOOL *)removableFlag
		                  isWritable:(BOOL *)writableFlag
		               isUnmountable:(BOOL *)unmountableFlag
		                 description:(NSString **)description
			                      type:(NSString **)fileSystemType
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *mtabpath = [defaults stringForKey: @"GSMtabPath"];
  NSArray *removables = [defaults arrayForKey: @"GSRemovableMediaPaths"];
  NSString *mtab;
  NSArray *mounts;
  int i;
   
  if (mtabpath == nil) {
    mtabpath = @"/etc/mtab";
  }

  if (removables == nil) {
    removables = [NSArray arrayWithObjects: @"/mnt/floppy", @"/mnt/cdrom", nil];
  }
  
  mtab = [NSString stringWithContentsOfFile: mtabpath];
  mounts = [mtab componentsSeparatedByString: @"\n"];

  for (i = 0; i < [mounts count]; i++) {
    NSString *mount = [mounts objectAtIndex: i];
    
    if ([mount length]) {
      NSArray	*parts = [mount componentsSeparatedByString: @" "];
      
      if ([parts count] == 6) {
     //   NSString *device = [parts objectAtIndex: 0];
        NSString *mountPoint = [parts objectAtIndex: 1];
        NSString *fsType = [parts objectAtIndex: 2];
        NSString *fsOptions = [parts objectAtIndex: 3];
    //    NSString *fsDump = [parts objectAtIndex: 4];      
    //    NSString *fsPass = [parts objectAtIndex: 5];      

        if ([mountPoint isEqual: fullPath]) {
          NSScanner *scanner = [NSScanner scannerWithString: fsOptions];
          
          *removableFlag = [removables containsObject: mountPoint];
          *writableFlag = [scanner scanString: @"rw" intoString: NULL];
          *unmountableFlag = YES;
          *description = fsType;
          *fileSystemType = fsType;
          
          return YES;
        }
      }
    }
  }

  return NO;
}

- (NSArray *)mountedLocalVolumePaths
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *mtabpath = [defaults stringForKey: @"GSMtabPath"];
  NSArray *reserved = [defaults arrayForKey: @"GSReservedMountPoints"];
  NSString *mtab;
  NSArray *mounts;
  NSMutableArray *names;
  int i;
   
  if (mtabpath == nil) {
    mtabpath = @"/etc/mtab";
  }

  if (reserved == nil) {
    reserved = [NSArray arrayWithObjects: @"proc", @"devpts", @"shm", 
                                    @"usbdevfs", @"devpts", 
                                    @"sysfs", @"tmpfs", nil];
  }

  mtab = [NSString stringWithContentsOfFile: mtabpath];
  mounts = [mtab componentsSeparatedByString: @"\n"];
  names = [NSMutableArray array];

  for (i = 0; i < [mounts count]; i++) {
    NSString *mount = [mounts objectAtIndex: i];
    
    if ([mount length]) {
      NSArray	*parts = [mount componentsSeparatedByString: @" "];
        
      if ([parts count] >= 2) {
        NSString *type = [parts objectAtIndex: 2];
        
        if ([reserved containsObject: type] == NO) {
	        [names addObject: [parts objectAtIndex: 1]];
	      }
      }
    } 
  }

  return names;
}

- (NSArray *)mountedRemovableMedia
{
  NSArray	*volumes = [self mountedLocalVolumePaths];
  NSMutableArray *names = [NSMutableArray array];
  unsigned	i;

  for (i = 0; i < [volumes count]; i++) {
    BOOL removableFlag;
    BOOL writableFlag;
    BOOL unmountableFlag;
    NSString *description;
    NSString *fileSystemType;
    NSString *name = [volumes objectAtIndex: i];

    if ([self getFileSystemInfoForPath: name
		              isRemovable: &removableFlag
		              isWritable: &writableFlag
		              isUnmountable: &unmountableFlag
		              description: &description
		              type: &fileSystemType] && removableFlag) {
	    [names addObject: name];
	  }
  }

  return names;
}

- (NSArray *)mountNewRemovableMedia
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSArray *removables = [defaults arrayForKey: @"GSRemovableMediaPaths"];
  NSArray *mountedMedia = [self mountedRemovableMedia]; 
  NSMutableArray *willMountMedia = [NSMutableArray array];
  NSMutableArray *newlyMountedMedia = [NSMutableArray array];
  NSDictionary *userinfo;
  int i;

  if (removables == nil) {
    removables = [NSArray arrayWithObjects: @"/mnt/floppy", @"/mnt/cdrom", nil];
  }

  for (i = 0; i < [removables count]; i++) {
    NSString *removable = [removables objectAtIndex: i];
    
    if ([mountedMedia containsObject: removable] == NO) {
      [willMountMedia addObject: removable];
    }
  }  
  
  for (i = 0; i < [willMountMedia count]; i++) {
    NSString *media = [willMountMedia objectAtIndex: i];
    NSTask *task = [NSTask launchedTaskWithLaunchPath: @"mount"
                                arguments: [NSArray arrayWithObject: media]];
      
    if (task) {
      [task waitUntilExit];
      
      if ([task terminationStatus] != 0) {
         return NO;
      } else {
        userinfo = [NSDictionary dictionaryWithObject: media 
                                               forKey: @"NSDevicePath"];

        [[self notificationCenter] postNotificationName: NSWorkspaceDidMountNotification
                                  object: self
                                userInfo: userinfo];

        [newlyMountedMedia addObject: media];
      }
    } else {
      return NO;
    }
  }

  return newlyMountedMedia;
}

- (BOOL)unmountAndEjectDeviceAtPath:(NSString *)path
{
  NSArray	*volumes = [self mountedLocalVolumePaths];

  if ([volumes containsObject: path]) {
    NSDictionary *userinfo;
    NSTask *task;

    userinfo = [NSDictionary dictionaryWithObject: path forKey: @"NSDevicePath"];

    [[self notificationCenter] postNotificationName: NSWorkspaceWillUnmountNotification
				                object: self
				              userInfo: userinfo];

    task = [NSTask launchedTaskWithLaunchPath: @"umount"
				                            arguments: [NSArray arrayWithObject: path]];

    if (task) {
      [task waitUntilExit];
      if ([task terminationStatus] != 0) {
	      return NO;
	    } 
    } else {
      return NO;
    }

    [[self notificationCenter] postNotificationName: NSWorkspaceDidUnmountNotification
				                object: self
				              userInfo: userinfo];

    task = [NSTask launchedTaskWithLaunchPath: @"eject"
				                            arguments: [NSArray arrayWithObject: path]];

    return YES;
  }
  
  return NO;
}

@end



