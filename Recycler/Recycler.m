/* Recycler.m
 *  
 * Copyright (C) 2004-2016 Free Software Foundation, Inc.
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <GNUstepBase/GNUstep.h>

#import "Recycler.h"
#import "RecyclerView.h"
#import "Preferences/RecyclerPrefs.h"
#import "Dialogs/StartAppWin.h"
#import "FSNode.h"
#import "FSNodeRep.h"
#import "FSNFunctions.h"


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
  RELEASE (trashPath);
  RELEASE (recview);
  RELEASE (preferences);
  RELEASE (startAppWin);
    
	[super dealloc];
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	id entry;

  fm = [NSFileManager defaultManager];
  ws = [NSWorkspace sharedWorkspace];
  nc = [NSNotificationCenter defaultCenter];
  fsnodeRep = [FSNodeRep sharedInstance];
  workspaceApplication = nil;

	entry = [defaults objectForKey: @"reserved_names"];
	if (entry) {
    [fsnodeRep setReservedNames: entry];
	} else {
    [fsnodeRep setReservedNames: [NSArray arrayWithObjects: @".gwdir", @".gwsort", nil]];
  }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  NSString *tpath; 
	BOOL isdir;

  tpath = [NSHomeDirectory() stringByAppendingPathComponent: @".Trash"]; 

	if ([fm fileExistsAtPath: tpath isDirectory: &isdir] == NO) {
    if ([fm createDirectoryAtPath: tpath attributes: nil] == NO) {
      NSLog(@"Can't create the Recycler directory! Quitting now.");
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
  
  terminating = NO;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)app 
{
  terminating = YES;
  
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
	return NSTerminateNow;
}

- (oneway void)emptyTrash
{
  [self emptyTrashFromMenu: nil];
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
    [recview removeFromSuperview];
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
  if (workspaceApplication == nil) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *appName = [defaults stringForKey: @"GSWorkspaceApplication"];

    if (appName == nil) {
      appName = @"GWorkspace";
    }
  
    workspaceApplication = [NSConnection rootProxyForConnectionWithRegisteredName: appName
                                                                             host: @""];
    if (workspaceApplication == nil) {
      int i;
  
      [ws launchApplication: appName];  
  
      for (i = 0; i < 80; i++) {
	      [[NSRunLoop currentRunLoop] runUntilDate:
		                     [NSDate dateWithTimeIntervalSinceNow: 0.1]];

        workspaceApplication = [NSConnection rootProxyForConnectionWithRegisteredName: appName 
                                                                                 host: @""];                  
        if (workspaceApplication) {
          break;
        }
      }
    }  
    
    if (workspaceApplication) {
      [workspaceApplication setProtocolForProxy: @protocol(workspaceAppProtocol)];
      RETAIN (workspaceApplication);
    
	    [nc addObserver: self
	           selector: @selector(workspaceAppConnectionDidDie:)
		             name: NSConnectionDidDieNotification
		           object: [workspaceApplication connectionForProxy]];
    } else {
      NSRunAlertPanel(nil,
              NSLocalizedString(@"unable to contact the workspace application!", @""),
              NSLocalizedString(@"Ok", @""),
              nil, 
              nil);  
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
    fswatcher = [NSConnection rootProxyForConnectionWithRegisteredName: @"fswatcher" 
                                                                  host: @""];

    if (fswatcher == nil) {
	    NSString *cmd;
      int i;
    
      cmd = [NSTask launchPathForTool: @"fswatcher"];    
                
      [startAppWin showWindowWithTitle: @"Recycler"
                               appName: @"fswatcher"
                          maxProgValue: 40.0];
    
      [NSTask launchedTaskWithLaunchPath: cmd arguments: nil];
   
      for (i = 1; i <= 40; i++) {
        [startAppWin updateProgressBy: 1.0];
	      [[NSRunLoop currentRunLoop] runUntilDate:
		                     [NSDate dateWithTimeIntervalSinceNow: 0.1]];

        fswatcher = [NSConnection rootProxyForConnectionWithRegisteredName: @"fswatcher" 
                                                                      host: @""];                  
        if (fswatcher) {
          [startAppWin updateProgressBy: 40.0 - i];
          break;
        }
      }

      [[startAppWin win] close];
    }
    
    if (fswatcher) {
      RETAIN (fswatcher);
      [fswatcher setProtocolForProxy: @protocol(FSWatcherProtocol)];
    
	    [[NSNotificationCenter defaultCenter] addObserver: self
	                   selector: @selector(fswatcherConnectionDidDie:)
		                     name: NSConnectionDidDieNotification
		                   object: [fswatcher connectionForProxy]];
                       
	    [fswatcher registerClient: (id <FSWClientProtocol>)self 
                isGlobalWatcher: NO];
    } else {
      fswnotifications = NO;
      NSRunAlertPanel(nil,
              NSLocalizedString(@"unable to contact fswatcher\nfswatcher notifications disabled!", @""),
              NSLocalizedString(@"Ok", @""),
              nil, 
              nil);  
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

- (void)performFileOperation:(NSString *)operation
		                  source:(NSString *)source
		             destination:(NSString *)destination
		                   files:(NSArray *)files
{
  NSInteger tag;

  if ([ws performFileOperation: operation 
                        source: source
                   destination: destination
                         files: files
                           tag: &tag] == NO)
    {
      NSRunAlertPanel(nil, 
                      NSLocalizedString(@"Unable to contact GWorkspace", @""), 
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

- (oneway void)terminateApplication
{
  [NSApp terminate: self];
}

- (BOOL)terminating
{
  return terminating;
}


//
// Menu Operations
//
- (void)emptyTrashFromMenu:(id)sender
{
  CREATE_AUTORELEASE_POOL(arp);
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

    for (i = 0; i < [subNodes count]; i++) {
      [files addObject: [(FSNode *)[subNodes objectAtIndex: i] name]];
    }
    
    [self performFileOperation: @"GWorkspaceEmptyRecyclerOperation"
		                    source: trashPath
		               destination: trashPath
		                     files: files];
  }

  RELEASE (subNodes);
  RELEASE (arp);
}

- (void)paste:(id)sender
{
  NSPasteboard *pb = [NSPasteboard generalPasteboard];

  if ([[pb types] containsObject: NSFilenamesPboardType]) {
    NSArray *sourcePaths = [pb propertyListForType: NSFilenamesPboardType];   

      [self contactWorkspaceApp];

      if (workspaceApplication) {
        BOOL cut = [(id <OperationProtocol>)workspaceApplication filenamesWasCut];
        
        if ([recview validatePasteOfFilenames: sourcePaths wasCut: cut]) {
          NSString *source = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];
          NSString *destination = trashPath;
          NSMutableArray *files = [NSMutableArray array];
          NSString *operation;
          int i;
        
          for (i = 0; i < [sourcePaths count]; i++) {  
            NSString *spath = [sourcePaths objectAtIndex: i];
            [files addObject: [spath lastPathComponent]];
          }  
        
          if (cut) {
            if ([source isEqual: trashPath]) {
              operation = @"GWorkspaceRecycleOutOperation";
            } else {
		          operation = NSWorkspaceMoveOperation;
            }
          } else {
		        operation = NSWorkspaceCopyOperation;
          }

          [self performFileOperation: operation
		                          source: source
		                     destination: destination
		                           files: files];
        }
        
      } else {
        NSRunAlertPanel(nil, 
            NSLocalizedString(@"File operations disabled!", @""), 
                                NSLocalizedString(@"OK", @""), nil, nil); 
        return;                                    
      }

  }
}

- (void)showPreferences:(id)sender
{
  [preferences activate];
}

- (void)showInfo:(id)sender
{
  [NSApp orderFrontStandardInfoPanel: self];
}

@end


