/* GWDesktopManager.m
 *  
 * Copyright (C) 2005 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2005
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

#include <AppKit/AppKit.h>
#include "GWDesktopManager.h"
#include "GWDesktopWindow.h"
#include "GWDesktopView.h"
#include "Dock.h"
#include "FSNFunctions.h"
#include "FileAnnotationsManager.h"
#include "GWorkspace.h"
#include "GWViewersManager.h"

static GWDesktopManager *desktopManager = nil;

@implementation GWDesktopManager

+ (GWDesktopManager *)desktopManager
{
	if (desktopManager == nil) {
		desktopManager = [[GWDesktopManager alloc] init];
	}	
  return desktopManager;
}

- (void)dealloc
{
  [[ws notificationCenter] removeObserver: self];
  [nc removeObserver: self];
  TEST_RELEASE (dskNode);
  TEST_RELEASE (win);
  TEST_RELEASE (dock);
    
	[super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
    NSUserDefaults *defaults;	
    id defentry;
    NSString *path;
    id window = nil;
    GWDesktopView *desktopView;

    fm = [NSFileManager defaultManager];
    nc = [NSNotificationCenter defaultCenter];
    ws = [NSWorkspace sharedWorkspace];
    gworkspace = [GWorkspace gworkspace];
    
    [self checkDesktopDirs];

    path = [NSHomeDirectory() stringByAppendingPathComponent: @"Desktop"];  
    ASSIGN (dskNode, [FSNode nodeWithPath: path]);

    defaults = [NSUserDefaults standardUserDefaults];	

    defentry = [defaults objectForKey: @"dockposition"];
    dockPosition = defentry ? [defentry intValue] : DockPositionRight;

    [self setReservedFrames];
    
    usexbundle = [defaults boolForKey: @"xbundle"];

    if (usexbundle) {
      window = [self loadXWinBundle];
    }

    if (window == nil) {
      usexbundle = NO;
      window = [GWDesktopWindow new];
    }

    [window setDelegate: self];

    desktopView = [[GWDesktopView alloc] initForManager: self];
    [(NSWindow *)window setContentView: desktopView];
    RELEASE (desktopView);

    win = RETAIN (window);
    RELEASE (window);

    hidedock = [defaults boolForKey: @"hidedock"];
    dock = [[Dock alloc] initForManager: self];
        
    [nc addObserver: self 
           selector: @selector(fileSystemWillChange:) 
               name: @"GWFileSystemWillChangeNotification"
             object: nil];

    [nc addObserver: self 
           selector: @selector(fileSystemDidChange:) 
               name: @"GWFileSystemDidChangeNotification"
             object: nil];

    [nc addObserver: self 
           selector: @selector(watcherNotification:) 
               name: @"GWFileWatcherFileDidChangeNotification"
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

    [nc addObserver: self
           selector: @selector(mountThreadWillExit:)
               name: NSThreadWillExitNotification
             object: nil];
  }
  
  return self;
}

- (void)activateDesktop
{  
  [win activate];
  [[win desktopView] showMountedVolumes];
  [[win desktopView] showContentsOfNode: dskNode];
  [self addWatcherForPath: [dskNode path]];
    
  if ((hidedock == NO) && ([dock superview] == nil)) {
    [[win desktopView] addSubview: dock];
    [dock tile];
  }
}

- (void)deactivateDesktop
{
  [win deactivate];
  [self removeWatcherForPath: [dskNode path]];
}

- (BOOL)isActive
{
  return [win isVisible];
}

- (void)checkDesktopDirs
{
  NSString *path;
  BOOL isdir;

  path = [NSHomeDirectory() stringByAppendingPathComponent: @"Desktop"]; 

  if (([fm fileExistsAtPath: path isDirectory: &isdir] && isdir) == NO) {
    NSString *hiddenNames = @".gwsort\n.gwdir\n.hidden\n";

    if ([fm createDirectoryAtPath: path attributes: nil] == NO) {
      NSRunAlertPanel(NSLocalizedString(@"error", @""), 
             NSLocalizedString(@"Can't create the Desktop directory!", @""), 
                                        NSLocalizedString(@"OK", @""), nil, nil);                                     
      [NSApp terminate: self];
    }

    [hiddenNames writeToFile: [path stringByAppendingPathComponent: @".hidden"]
                  atomically: YES];
  }

  path = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
  path = [path stringByAppendingPathComponent: @"Desktop"];

  if (([fm fileExistsAtPath: path isDirectory: &isdir] && isdir) == NO) {
    if ([fm createDirectoryAtPath: path attributes: nil] == NO) {
      NSLog(@"Can't create the Recycler directory! Quitting now.");
      [NSApp terminate: self];
    }
  }

	path = [path stringByAppendingPathComponent: @".Trash"];

	if ([fm fileExistsAtPath: path isDirectory: &isdir] == NO) {
    if ([fm createDirectoryAtPath: path attributes: nil] == NO) {
      NSLog(@"Can't create the Recycler directory! Quitting now.");
      [NSApp terminate: self];
    }
	}
}

- (void)setUsesXBundle:(BOOL)value
{
  usexbundle = value;
  
  if ([self isActive]) { 
    GWDesktopView *desktopView = [win desktopView];
    id window = nil;  
    BOOL changed = NO;
    
    if (usexbundle) {
      if ([win isKindOfClass: [GWDesktopWindow class]]) {
        window = [self loadXWinBundle];
        changed = (window != nil);
      }
    } else {
      if ([win isKindOfClass: [GWDesktopWindow class]] == NO) {
        window = [GWDesktopWindow new];
        changed = YES;
      }
    }
    
    if (changed) {
      RETAIN (desktopView);
      [desktopView removeFromSuperview];

      [win close];
      DESTROY (win);
      
      [window setDelegate: self];
      [(NSWindow *)window setContentView: desktopView];
      RELEASE (desktopView);

      win = RETAIN (window);
      RELEASE (window);
      
      [win activate];
    }
  }
}

- (BOOL)usesXBundle
{
  return usexbundle;
}

- (id)loadXWinBundle
{
  NSString *bpath;
  NSBundle *bundle;
  
  bpath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSSystemDomainMask, YES) lastObject];
  bpath = [bpath stringByAppendingPathComponent: @"Bundles"];
  bpath = [bpath stringByAppendingPathComponent: @"XDesktopWindow.bundle"];

  bundle = [NSBundle bundleWithPath: bpath];
  
  if (bundle) {
    return [[[bundle principalClass] alloc] init];
  }

  return nil;
}

- (BOOL)hasWindow:(id)awindow
{
  return (win && (win == awindow));
}

- (id)desktopView
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

- (void)setDockActive:(BOOL)value
{
  hidedock = !value;
  
  if (hidedock && [dock superview]) {
    [dock removeFromSuperview];
    [[win desktopView] setNeedsDisplayInRect: dockReservedFrame];
    
  } else if ([dock superview] == nil) {
    [[win desktopView] addSubview: dock];
    [[win desktopView] setNeedsDisplayInRect: dockReservedFrame];
  }
}

- (BOOL)dockActive
{
  return !hidedock;
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

- (NSRect)dockReservedFrame
{
  return dockReservedFrame;
}

- (NSRect)tshelfReservedFrame
{
  return tshelfReservedFrame;
}

- (NSImage *)tabbedShelfBackground
{
  return [[win desktopView] tshelfBackground];
}

- (void)deselectAllIcons
{
  [[win desktopView] unselectOtherReps: nil];
  [[win desktopView] stopRepNameEditing];
}

- (void)deselectInSpatialViewers
{
  [[gworkspace viewersManager] selectedSpatialViewerChanged: nil];
}

- (void)addWatcherForPath:(NSString *)path
{
  [gworkspace addWatcherForPath: path];
}

- (void)removeWatcherForPath:(NSString *)path
{
  [gworkspace removeWatcherForPath: path];
}

- (void)showRootViewer
{
  [gworkspace newViewerAtPath: path_separator()];
}

- (BOOL)selectFile:(NSString *)fullPath
											inFileViewerRootedAtPath:(NSString *)rootFullpath
{
  return [gworkspace selectFile: fullPath inFileViewerRootedAtPath: rootFullpath];
}

- (void)performFileOperation:(NSDictionary *)opinfo
{
  [gworkspace performFileOperation: opinfo];
}
                      
- (NSString *)trashPath
{
  return [gworkspace trashPath];
}

- (void)moveToTrash
{
  [gworkspace moveToTrash];
}

- (void)checkNewRemovableMedia
{
  NS_DURING
  {
    [NSThread detachNewThreadSelector: @selector(mountRemovableMedia)
                             toTarget: [GWMounter class]
                           withObject: nil];
  }
  NS_HANDLER
  {
    NSLog(@"Error! A fatal error occured while detaching the thread.");
  }
  NS_ENDHANDLER
}

- (void)fileSystemWillChange:(NSNotification *)notif
{
  NSDictionary *opinfo = (NSDictionary *)[notif object];  

  if ([dskNode involvedByFileOperation: opinfo]) {
    dskWatcherSuspended = YES;
    [[self desktopView] nodeContentsWillChange: opinfo];
  }
}

- (void)fileSystemDidChange:(NSNotification *)notif
{
  NSDictionary *opinfo = (NSDictionary *)[notif object];  

  if ([dskNode isValid] == NO) {
    NSRunAlertPanel(nil, 
                    NSLocalizedString(@"The Desktop directory has been deleted! Quiting now!", @""), 
                    NSLocalizedString(@"OK", @""), 
                    nil, 
                    nil);                                     
    [NSApp terminate: self];
  }

  if ([dskNode involvedByFileOperation: opinfo]) {
    [[self desktopView] nodeContentsDidChange: opinfo];  
  }
  
  [dock nodeContentsDidChange: opinfo];  
  dskWatcherSuspended = NO;
}

- (void)watcherNotification:(NSNotification *)notif
{
  NSDictionary *info = (NSDictionary *)[notif object];
  NSString *path = [info objectForKey: @"path"];
  NSString *event = [info objectForKey: @"event"];
  
  if ([event isEqual: @"GWWatchedDirectoryDeleted"]) {
    if ([path isEqual: [dskNode path]]) {
      NSRunAlertPanel(nil, 
                      NSLocalizedString(@"The Desktop directory has been deleted! Quiting now!", @""), 
                      NSLocalizedString(@"OK", @""), 
                      nil, 
                      nil);                                     
      [NSApp terminate: self];
    }
    
  } else if ([event isEqual: @"GWWatchedFileModified"]) {
    [[self desktopView] watchedPathChanged: info];
    
  } else if ([path isEqual: [dskNode path]] && (dskWatcherSuspended == NO)) {
    [[self desktopView] watchedPathChanged: info];
  }    

  [dock watchedPathChanged: info];  
}

- (void)thumbnailsDidChangeInPaths:(NSArray *)paths
{
  [[self desktopView] updateIcons];
}

- (void)newVolumeMounted:(NSNotification *)notif
{
  if (win && [win isVisible]) {
    NSDictionary *dict = [notif userInfo];  
    NSString *volpath = [dict objectForKey: @"NSDevicePath"];

    [[self desktopView] newVolumeMountedAtPath: volpath];
  }
}

- (void)mountedVolumeWillUnmount:(NSNotification *)notif
{
  if (win && [win isVisible]) {
    NSDictionary *dict = [notif userInfo];  
    NSString *volpath = [dict objectForKey: @"NSDevicePath"];

    [[FSNodeRep sharedInstance] lockPaths: [NSArray arrayWithObject: volpath]];
    [[self desktopView] workspaceWillUnmountVolumeAtPath: volpath];
  }
}

- (void)mountedVolumeDidUnmount:(NSNotification *)notif
{
  if (win && [win isVisible]) {
    NSDictionary *dict = [notif userInfo];  
    NSString *volpath = [dict objectForKey: @"NSDevicePath"];

    [[FSNodeRep sharedInstance] unlockPaths: [NSArray arrayWithObject: volpath]];
    [[self desktopView] workspaceDidUnmountVolumeAtPath: volpath];
  }
}

- (void)mountThreadWillExit:(NSNotification *)notif
{
  NSLog(@"mount thread will exit");
}

- (void)updateDefaults
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  [defaults setObject: [NSNumber numberWithInt: dockPosition]
               forKey: @"dockposition"];

  [defaults setBool: usexbundle forKey: @"xbundle"];
  [defaults setBool: hidedock forKey: @"hidedock"];
  
  [dock updateDefaults];
  [[win desktopView] updateDefaults];
}

@end


//
// GWDesktopWindow Delegate Methods
//
@implementation GWDesktopManager (GWDesktopWindowDelegateMethods)

- (BOOL)validateItem:(id)menuItem
{
  if ([self isActive]) {
    NSString *itemTitle = [menuItem title];
    GWDesktopView *desktopView = [win desktopView];

    if ([itemTitle isEqual: NSLocalizedString(@"Duplicate", @"")]
        || [itemTitle isEqual: NSLocalizedString(@"Move to Recycler", @"")]
        || [itemTitle isEqual: NSLocalizedString(@"File Annotations", @"")]) {
      return ([[desktopView selectedNodes] count] > 0);
    }

    return YES;
  }
  
  return NO;
}

- (void)openSelectionInNewViewer:(BOOL)newv
{
  NSArray *selreps = [[win desktopView] selectedReps];
  int i;
    
  for (i = 0; i < [selreps count]; i++) {
    FSNode *node = [[selreps objectAtIndex: i] node];
    NSString *path = [node path];
        
    if ([node isDirectory]) {
      if ([node isPackage]) {    
        if ([node isApplication] == NO) {
          [gworkspace openFile: path];
        } else {
          [ws launchApplication: path];
        }
      } else {
        [gworkspace newViewerAtPath: [node path]];
      } 
    } else if ([node isPlain]) {        
      [gworkspace openFile: path];
    }
  }
}

- (void)openSelectionAsFolder
{
  NSArray *selnodes = [[win desktopView] selectedNodes];
  int i;
    
  for (i = 0; i < [selnodes count]; i++) {
    FSNode *node = [selnodes objectAtIndex: i];
        
    if ([node isDirectory]) {
      [gworkspace newViewerAtPath: [node path]];
    } else if ([node isPlain]) {        
      [gworkspace openFile: [node path]];
    }
  }
}

- (void)newFolder
{
  [gworkspace newObjectAtPath: [dskNode path] isDirectory: YES];
}

- (void)newFile
{
  [gworkspace newObjectAtPath: [dskNode path] isDirectory: NO];
}

- (void)duplicateFiles
{
  if ([[[win desktopView] selectedNodes] count]) {
    [gworkspace duplicateFiles];
  }
}

- (void)deleteFiles
{
  if ([[[win desktopView] selectedNodes] count]) {
    [gworkspace moveToTrash];
  }
}

- (void)emptyTrash
{
  [gworkspace emptyRecycler: nil];
}

- (void)setShownType:(id)sender
{
  NSString *title = [sender title];
  FSNInfoType type = FSNInfoNameType;

  if ([title isEqual: NSLocalizedString(@"Name", @"")]) {
    type = FSNInfoNameType;
  } else if ([title isEqual: NSLocalizedString(@"Kind", @"")]) {
    type = FSNInfoKindType;
  } else if ([title isEqual: NSLocalizedString(@"Size", @"")]) {
    type = FSNInfoSizeType;
  } else if ([title isEqual: NSLocalizedString(@"Modification date", @"")]) {
    type = FSNInfoDateType;
  } else if ([title isEqual: NSLocalizedString(@"Owner", @"")]) {
    type = FSNInfoOwnerType;
  } else {
    type = FSNInfoNameType;
  } 

  [(id <FSNodeRepContainer>)[win desktopView] setShowType: type];  
}

- (void)setExtendedShownType:(id)sender
{
  [(id <FSNodeRepContainer>)[win desktopView] setExtendedShowType: [sender title]]; 
}

- (void)setIconsSize:(id)sender
{
  [(id <FSNodeRepContainer>)[win desktopView] setIconSize: [[sender title] intValue]];
}

- (void)setIconsPosition:(id)sender
{
  NSString *title = [sender title];

  if ([title isEqual: NSLocalizedString(@"Left", @"")]) {
    [(id <FSNodeRepContainer>)[win desktopView] setIconPosition: NSImageLeft];
  } else {
    [(id <FSNodeRepContainer>)[win desktopView] setIconPosition: NSImageAbove];
  }
}

- (void)setLabelSize:(id)sender
{
  [[win desktopView] setLabelTextSize: [[sender title] intValue]];
}

- (void)selectAllInViewer
{
	[[win desktopView] selectAll];
}

- (void)showAnnotationWindows
{
  NSArray *selection = [[win desktopView] selectedNodes];

  if ([selection count]) {
    [[FileAnnotationsManager fannmanager] showAnnotationsForNodes: selection];
  }
}

- (void)showTerminal
{
  [gworkspace startXTermOnDirectory: [dskNode path]];
}

@end


@implementation GWMounter

+ (void)mountRemovableMedia
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	GWMounter *mounter = [GWMounter new];  
  
  [mounter mountRemovableMedia];
  
  [[NSRunLoop currentRunLoop] run];
  [pool release];
}

- (void)mountRemovableMedia
{
  [[NSWorkspace sharedWorkspace] mountNewRemovableMedia];
  [NSThread exit];
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
      
      if ([task terminationStatus] == 0) {
        NSDictionary *userinfo = [NSDictionary dictionaryWithObject: media 
                                                      forKey: @"NSDevicePath"];

        [[self notificationCenter] postNotificationName: NSWorkspaceDidMountNotification
                                  object: self
                                userInfo: userinfo];

        [newlyMountedMedia addObject: media];
      }
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


