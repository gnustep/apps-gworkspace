/* Recycler.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: June 2004
 *
 * This file is part of the GNUstep Recycler application
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
#include "Recycler.h"
#include "RecyclerView.h"
#include "Preferences/RecyclerPrefs.h"
#include "Dialogs/StartAppWin.h"
#include "FSNode.h"
#include "FSNodeRep.h"
#include "FSNFunctions.h"
#include "GNUstep.h"

static Recycler *recycler = nil;

@implementation Recycler

+ (Recycler *)recycler
{
	if (recycler == nil) {
		recycler = [[Recycler alloc] init];
	}	
  return recycler;
}

+ (void)initialize
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject: @"Recycler" 
               forKey: @"DesktopApplicationName"];
  [defaults setObject: @"recycler" 
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
  DESTROY (workspaceApplication);
  DESTROY (operationsApp);
  RELEASE (trashPath);
  RELEASE (recview);
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
	NSString *basePath;
  NSString *tpath; 
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
      NSLog(@"Can't create the Recycler directory! Quiting now.");
      [NSApp terminate: self];
    }
	} else {
		if (isdir == NO) {
			NSLog (@"Warning - %@ is not a directory - quiting now!", tpath);			
			[NSApp terminate: self];
		}
  }
  
  ASSIGN (trashPath, tpath);

  fswatcher = nil;
  fswnotifications = YES;
  [self connectFSWatcher];
     
  docked = [[NSUserDefaults standardUserDefaults] boolForKey: @"docked"];

  if (docked) {
    recview = [[RecyclerView alloc] init];
    [[[NSApp iconWindow] contentView] addSubview: recview];
  } else {
    [NSApp setApplicationIconImage: [NSApp applicationIconImage]];
    recview = [[RecyclerView alloc] initWithWindow];
    [recview activate];
  }
  
  preferences = [RecyclerPrefs new];

  startAppWin = [[StartAppWin alloc] init];
  
  [self addWatcherForPath: trashPath];
  
  [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                				selector: @selector(fileSystemDidChange:) 
                					  name: @"GWFileSystemDidChangeNotification"
                					object: nil];
}

- (BOOL)applicationShouldTerminate:(NSApplication *)app 
{
  [self removeWatcherForPath: trashPath];

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

  [self updateDefaults];
	return YES;
}

- (void)setDocked:(BOOL)value
{
  docked = value;

  if (docked) {
    [[recview window] close];
    DESTROY (recview);
    recview = [[RecyclerView alloc] init];
    [[[NSApp iconWindow] contentView] addSubview: recview];

  } else {
    DESTROY (recview);
    recview = [[RecyclerView alloc] initWithWindow];
    [recview activate];
  }
}

- (BOOL)isDocked
{
  return docked;
}

- (void)fileSystemDidChange:(NSNotification *)notif
{
  NSDictionary *dict = [notif userInfo];  
  [recview nodeContentsDidChange: dict];  
}

- (void)watchedPathDidChange:(NSData *)dirinfo
{
  NSDictionary *info = [NSUnarchiver unarchiveObjectWithData: dirinfo];
  [recview watchedPathChanged: info];  
}

- (void)updateDefaults
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  [defaults setBool: docked forKey: @"docked"];
  [defaults synchronize];
  [recview updateDefaults];
  [preferences updateDefaults];
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

        for (i = 1; i <= 80; i++) {
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
        
        [startAppWin showWindowWithTitle: @"Recycler"
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
        
        [startAppWin showWindowWithTitle: @"Recycler"
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


//
// NSServicesRequests protocol
//
- (id)validRequestorForSendType:(NSString *)sendType
                     returnType:(NSString *)returnType
{	
  BOOL sendOK = ((sendType == nil) || ([sendType isEqual: NSFilenamesPboardType]));
  BOOL returnOK = ((returnType == nil) || [returnType isEqual: NSFilenamesPboardType]);

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
	return NO;
}


//
// DesktopApplication protocol
//
- (void)selectionChanged:(NSArray *)newsel
{
}

- (void)openSelectionInNewViewer:(BOOL)newv
{
}

- (void)openSelectionWithApp:(id)sender
{
}

- (void)performFileOperation:(NSDictionary *)opinfo
{
  [self connectOperation];

  if (operationsApp) {  
    NSData *data = [NSArchiver archivedDataWithRootObject: opinfo];
    [(id <OperationProtocol>)operationsApp performOperation: data];
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


//
// Menu Operations
//
- (void)emptyTrash:(id)sender
{
  FSNode *node = [FSNode nodeWithPath: trashPath];
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

- (void)paste:(id)sender
{
  NSPasteboard *pb = [NSPasteboard generalPasteboard];

  if ([[pb types] containsObject: NSFilenamesPboardType]) {
    NSArray *sourcePaths = [pb propertyListForType: NSFilenamesPboardType];   

    if (sourcePaths) {
      [self connectOperation];

      if (operationsApp) {
        BOOL cutted = [(id <OperationProtocol>)operationsApp filenamesWasCutted];
        
        if ([recview validatePasteOfFilenames: sourcePaths wasCutted: cutted]) {
          NSMutableDictionary *opDict = [NSMutableDictionary dictionary];
          NSString *source = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];
          NSString *destination = trashPath;
          NSMutableArray *files = [NSMutableArray array];
          NSString *operation;
          int i;
        
          for (i = 0; i < [sourcePaths count]; i++) {  
            NSString *spath = [sourcePaths objectAtIndex: i];
            [files addObject: [spath lastPathComponent]];
          }  
        
          if (cutted) {
            if ([source isEqual: trashPath]) {
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

	        [self performFileOperation: opDict];	
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

- (void)showPreferences:(id)sender
{
  [preferences activate];
}

- (void)showInfo:(id)sender
{
  NSMutableDictionary *d = AUTORELEASE ([NSMutableDictionary new]);
  [d setObject: @"Recycler" forKey: @"ApplicationName"];
  [d setObject: NSLocalizedString(@"-----------------------", @"")
      	forKey: @"ApplicationDescription"];
  [d setObject: @"Desktop 0.7" forKey: @"ApplicationRelease"];
  [d setObject: @"06 2004" forKey: @"FullVersionID"];
  [d setObject: [NSArray arrayWithObjects: @"Enrico Sersale <enrico@imago.ro>.", nil]
        forKey: @"Authors"];
  [d setObject: NSLocalizedString(@"See http://www.gnustep.it/enrico/gworkspace", @"") forKey: @"URL"];
  [d setObject: @"Copyright (C) 2004 Free Software Foundation, Inc."
        forKey: @"Copyright"];
  [d setObject: NSLocalizedString(@"Released under the GNU General Public License 2.0", @"")
        forKey: @"CopyrightDescription"];
  
  [NSApp orderFrontStandardInfoPanelWithOptions: d];
}

@end


