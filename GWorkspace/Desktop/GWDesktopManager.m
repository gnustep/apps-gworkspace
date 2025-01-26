/* GWDesktopManager.m
 *  
 * Copyright (C) 2005-2021 Free Software Foundation, Inc.
 *
 * Authors: Enrico Sersale <enrico@imago.ro>
 *          Riccardo Mottola <rm@gnu.org>
 *
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
 * Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
 */

#import <AppKit/AppKit.h>
#import "GWDesktopManager.h"
#import "GWDesktopWindow.h"
#import "GWDesktopView.h"
#import "Dock.h"
#import "FSNFunctions.h"
#import "GWorkspace.h"
#import "GWViewersManager.h"
#import "TShelf/TShelfWin.h"
#import "Thumbnailer/GWThumbnailer.h"

#define RESV_MARGIN 10

static GWDesktopManager *desktopManager = nil;

@implementation GWDesktopManager

+ (GWDesktopManager *)desktopManager
{
  if (desktopManager == nil)
    {
      desktopManager = [[GWDesktopManager alloc] init];
    }
  return desktopManager;
}

- (void)dealloc
{
  [[ws notificationCenter] removeObserver: self];
  [nc removeObserver: self];
  RELEASE (dskNode);
  RELEASE (win);
  RELEASE (dock);
  RELEASE (mpointWatcher);

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

    fm = [NSFileManager defaultManager];
    nc = [NSNotificationCenter defaultCenter];
    ws = [NSWorkspace sharedWorkspace];
    gworkspace = [GWorkspace gworkspace];
    fsnodeRep = [FSNodeRep sharedInstance];
    mpointWatcher = [[MPointWatcher alloc] initForManager: self];
    
    [self checkDesktopDirs];

    path = [NSHomeDirectory() stringByAppendingPathComponent: @"Desktop"];  
    ASSIGN (dskNode, [FSNode nodeWithPath: path]);

    defaults = [NSUserDefaults standardUserDefaults];	

    singleClickLaunch = [defaults boolForKey: @"singleclicklaunch"];
    defentry = [defaults objectForKey: @"dockposition"];
    dockPosition = defentry ? [defentry intValue] : DockPositionRight;

    [self setReservedFrames];
    
    usexbundle = [defaults boolForKey: @"xbundle"];

    if (usexbundle) {
      window = [self loadXWinBundle];
      [window retain];
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

    [self setContextHelp];
  }
  
  return self;
}

- (void)activateDesktop
{
  [win activate];
  [desktopView showMountedVolumes];
  [desktopView showContentsOfNode: dskNode];
  [self addWatcherForPath: [dskNode path]];
    
  if ((hidedock == NO) && ([dock superview] == nil)) {
    [desktopView addSubview: dock];
    [dock tile];
  }
  
  [mpointWatcher startWatching];  
}

- (void)deactivateDesktop
{
  [win deactivate];
  [self removeWatcherForPath: [dskNode path]];  
  [mpointWatcher stopWatching];
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

  path = [NSHomeDirectory() stringByAppendingPathComponent: @".Trash"]; 

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
  NSEnumerator	*enumerator;
  NSString *bpath;
  NSBundle *bundle;
  
  enumerator = [NSSearchPathForDirectoriesInDomains
    (NSLibraryDirectory, NSAllDomainsMask, YES) objectEnumerator];
  while ((bpath = [enumerator nextObject]) != nil)
    {
      bpath = [bpath stringByAppendingPathComponent: @"Bundles"];
      bpath = [bpath stringByAppendingPathComponent: @"XDesktopWindow.bundle"];

      bundle = [NSBundle bundleWithPath: bpath];
  
      if (bundle) {
        id pC;

        pC = [[[bundle principalClass] alloc] init];
        [pC autorelease];
	return pC;
      }
    }

  return nil;
}

- (BOOL)hasWindow:(id)awindow
{
  return (win && (win == awindow));
}

- (id)desktopView
{
  return desktopView;
}


- (BOOL)singleClickLaunch
{
  return singleClickLaunch;
}

- (void)setSingleClickLaunch:(BOOL)value
{
  singleClickLaunch = value;
  [dock setSingleClickLaunch:singleClickLaunch];
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
  [desktopView dockPositionDidChange];
}

- (void)setDockActive:(BOOL)value
{
  hidedock = !value;
  
  if (hidedock && [dock superview]) {
    [dock removeFromSuperview];
    [desktopView setNeedsDisplayInRect: dockReservedFrame];
    
  } else if ([dock superview] == nil) {
    [desktopView addSubview: dock];
    [dock tile];
    [desktopView setNeedsDisplayInRect: dockReservedFrame];
  }
}

- (BOOL)dockActive
{
  return !hidedock;
}

- (void)setReservedFrames
{
  NSRect screenFrame = [[NSScreen mainScreen] frame];
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
  NSString *menuStyle = [defaults objectForKey: @"NSMenuInterfaceStyle"];
  
  macmenuReservedFrame = NSZeroRect;

  if (menuStyle && [menuStyle isEqual: @"NSMacintoshInterfaceStyle"]) {
    macmenuReservedFrame.size.width = screenFrame.size.width;
    macmenuReservedFrame.size.height = 25;
    macmenuReservedFrame.origin.x = 0;
    macmenuReservedFrame.origin.y = screenFrame.size.height - 25;    
  }

  dockReservedFrame.size.height = screenFrame.size.height;
  dockReservedFrame.size.width = 64 + RESV_MARGIN;
  dockReservedFrame.origin.x = 0;
  dockReservedFrame.origin.y = 0;
  
  if (dockPosition == DockPositionRight) {
    dockReservedFrame.origin.x = screenFrame.size.width - 64 - RESV_MARGIN;
  }
  
  tshelfReservedFrame = NSMakeRect(0, 0, screenFrame.size.width, 106 + RESV_MARGIN);
  tshelfActivateFrame = NSMakeRect(0, 0, screenFrame.size.width, 20);
}

- (NSRect)macmenuReservedFrame
{
  return macmenuReservedFrame;
}

- (NSRect)dockReservedFrame
{
  return dockReservedFrame;
}

- (NSRect)tshelfReservedFrame
{
  return tshelfReservedFrame;
}

- (NSRect)tshelfActivateFrame
{
  return tshelfActivateFrame;
}

- (NSImage *)tabbedShelfBackground
{
  return [desktopView tshelfBackground];
}

- (void)mouseEnteredTShelfActivateFrame
{
  [[gworkspace tabbedShelf] animateShowing];
}

- (void)mouseExitedTShelfActiveFrame
{
  [[gworkspace tabbedShelf] animateHiding];
}

- (void)deselectAllIcons
{
  [desktopView unselectOtherReps: nil];
  [desktopView selectionDidChange];
  [desktopView stopRepNameEditing];
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
    NSLog(@"Error! A fatal error occurred while detaching the thread.");
  }
  NS_ENDHANDLER
}

- (void)makeThumbnails:(id)sender
{
  NSString *path;

  path = [dskNode path];
  path = [path stringByResolvingSymlinksInPath];
  if (path)
    {
      Thumbnailer *t;
      
      t = [Thumbnailer sharedThumbnailer];
      [t makeThumbnails:path];
      [t release];
    }
}

- (void)removeThumbnails:(id)sender
{
  NSString *path;

  path = [dskNode path];
  path = [path stringByResolvingSymlinksInPath];
  if (path)
    {
      Thumbnailer *t;
      
      t = [Thumbnailer sharedThumbnailer];
      [t removeThumbnails:path];
      [t release];
    }
}

- (void)fileSystemWillChange:(NSNotification *)notif
{
  NSDictionary *opinfo = (NSDictionary *)[notif object];  

  if ([dskNode involvedByFileOperation: opinfo]) {
    [[self desktopView] nodeContentsWillChange: opinfo];
  }
}

- (void)fileSystemDidChange:(NSNotification *)notif
{
  NSDictionary *opinfo = (NSDictionary *)[notif object];  

  if ([dskNode isValid] == NO) {
    NSRunAlertPanel(nil, 
                    NSLocalizedString(@"The Desktop directory has been deleted! Quitting now!", @""),
                    NSLocalizedString(@"OK", @""), 
                    nil, 
                    nil);                                     
    [NSApp terminate: self];
  }

  /* update the desktop view, but only if it is visible */
  if ([self isActive] && [dskNode involvedByFileOperation: opinfo])
    {
      [[self desktopView] nodeContentsDidChange: opinfo];  
    }
  
  if ([self dockActive])
    {
      [dock nodeContentsDidChange: opinfo];
    }
}

- (void)watcherNotification:(NSNotification *)notif
{
  NSDictionary *info = (NSDictionary *)[notif object];
  NSString *path = [info objectForKey: @"path"];
  NSString *event = [info objectForKey: @"event"];
  
  if ([path isEqual: [dskNode path]])
    {
      if ([event isEqual: @"GWWatchedPathDeleted"])
        {
          NSRunAlertPanel(nil, 
                          NSLocalizedString(@"The Desktop directory has been deleted! Quitting now!", @""),
                          NSLocalizedString(@"OK", @""), 
                          nil, 
                          nil);                                     
          [NSApp terminate: self];
        }
      /* update the desktop view, but only if active */
      else if ([self isActive]) 
        {
          [[self desktopView] watchedPathChanged: info];
        }
    }
  /* update the dock, if active */
  if ([self dockActive])
    [dock watchedPathChanged: info];  
}

- (void)thumbnailsDidChangeInPaths:(NSArray *)paths
{
  [[self desktopView] updateIcons];
}

- (void)removableMediaPathsDidChange
{
  [[self desktopView] showMountedVolumes];
  [mpointWatcher startWatching];
}

- (void)hideDotsFileDidChange:(BOOL)hide
{
  [[self desktopView] reloadFromNode: dskNode];
}

- (void)hiddenFilesDidChange:(NSArray *)paths
{
  [[self desktopView] reloadFromNode: dskNode];
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

    [fsnodeRep lockPaths: [NSArray arrayWithObject: volpath]];
    [[self desktopView] workspaceWillUnmountVolumeAtPath: volpath];
  }
}

- (void)mountedVolumeDidUnmount:(NSNotification *)notif
{
  if (win && [win isVisible]) {
    NSDictionary *dict = [notif userInfo];  
    NSString *volpath = [dict objectForKey: @"NSDevicePath"];

    [fsnodeRep unlockPaths: [NSArray arrayWithObject: volpath]];
    [[self desktopView] workspaceDidUnmountVolumeAtPath: volpath];
  }
}

- (void)unlockVolumeAtPath:(NSString *)volpath
{
  [fsnodeRep unlockPaths: [NSArray arrayWithObject: volpath]];
  [[self desktopView] unlockVolumeAtPath: volpath];
}

- (void)mountedVolumesDidChange
{
  [[self desktopView] showMountedVolumes];
}

- (void)updateDefaults
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  [defaults setObject: [NSNumber numberWithInt: dockPosition]
               forKey: @"dockposition"];

  [defaults setBool: singleClickLaunch forKey: @"singleclicklaunch"];

  [defaults setBool: usexbundle forKey: @"xbundle"];
  [defaults setBool: hidedock forKey: @"hidedock"];
  
  [dock updateDefaults];
  [desktopView updateDefaults];
}

- (void)setContextHelp
{
  NSHelpManager *manager = [NSHelpManager sharedHelpManager];
  NSString *help;

  help = @"Desktop.rtfd";
  [manager setContextHelp: (NSAttributedString *)help 
               withObject: [self desktopView]];

  help = @"Dock.rtfd";
  [manager setContextHelp: (NSAttributedString *)help withObject: dock];
  
  help = @"Recycler.rtfd";
  [manager setContextHelp: (NSAttributedString *)help 
               withObject: [dock trashIcon]];
}

@end


//
// GWDesktopWindow Delegate Methods
//
@implementation GWDesktopManager (GWDesktopWindowDelegateMethods)

- (BOOL)validateItem:(id)menuItem
{
  if ([self isActive]) {
    SEL action = [menuItem action];

    if (sel_isEqual(action, @selector(duplicateFiles:))
                || sel_isEqual(action, @selector(recycleFiles:))
                      || sel_isEqual(action, @selector(deleteFiles:))) {
      return ([[desktopView selectedNodes] count] > 0);

    } else if (sel_isEqual(action, @selector(openSelection:))) {
      NSArray *selection = [desktopView selectedNodes];
     
      return (selection && [selection count] 
            && ([selection isEqual: [NSArray arrayWithObject: dskNode]] == NO));
    
    } else if (sel_isEqual(action, @selector(openWith:))) {
      NSArray *selection = [desktopView selectedNodes];
      BOOL canopen = YES;
      int i;

      if (selection && [selection count]
            && ([selection isEqual: [NSArray arrayWithObject: dskNode]] == NO)) {
        for (i = 0; i < [selection count]; i++) {
          FSNode *node = [selection objectAtIndex: i];

          if (([node isPlain] == NO) 
                && (([node isPackage] == NO) || [node isApplication])) {
            canopen = NO;
            break;
          }
        }
      } else {
        canopen = NO;
      }

      return canopen;
      
    } else if (sel_isEqual(action, @selector(openSelectionAsFolder:))) {
      NSArray *selection = [desktopView selectedNodes];
    
      if (selection && ([selection count] == 1)) {  
        return [[selection objectAtIndex: 0] isDirectory];
      }
    
      return NO;
    }
         
    return YES;
  }
  
  return NO;
}

- (void)openSelectionInNewViewer:(BOOL)newv
{
  NSArray *selreps = [desktopView selectedReps];
  NSUInteger i;
    
  for (i = 0; i < [selreps count]; i++) {
    FSNode *node = [[selreps objectAtIndex: i] node];
        
    if ([node hasValidPath]) {           
      NS_DURING
        {
      if ([node isDirectory]) {
        if ([node isPackage]) {    
          if ([node isApplication] == NO) {
            [gworkspace openFile: [node path]];
          } else {
            [ws launchApplication: [node path]];
          }
        } else {
          [gworkspace newViewerAtPath: [node path]];
        } 
      } else if ([node isPlain]) {        
        [gworkspace openFile: [node path]];
      }
        }
      NS_HANDLER
        {
          NSRunAlertPanel(NSLocalizedString(@"error", @""), 
              [NSString stringWithFormat: @"%@ %@!", 
                        NSLocalizedString(@"Can't open ", @""), [node name]],
                                            NSLocalizedString(@"OK", @""), 
                                            nil, 
                                            nil);                                     
        }
      NS_ENDHANDLER
      
    } else {
      NSRunAlertPanel(NSLocalizedString(@"error", @""), 
          [NSString stringWithFormat: @"%@ %@!", 
                    NSLocalizedString(@"Can't open ", @""), [node name]],
                                        NSLocalizedString(@"OK", @""), 
                                        nil, 
                                        nil);                                     
    }
  }
}

- (void)openSelectionAsFolder
{
  NSArray *selnodes = [desktopView selectedNodes];
  unsigned i;
    
  for (i = 0; i < [selnodes count]; i++) {
    FSNode *node = [selnodes objectAtIndex: i];
        
    if ([node isDirectory]) {
      [gworkspace newViewerAtPath: [node path]];
    } else if ([node isPlain]) {        
      [gworkspace openFile: [node path]];
    }
  }
}

- (void)openSelectionWith
{
  [gworkspace openSelectedPathsWith];
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
  if ([[desktopView selectedNodes] count]) {
    [gworkspace duplicateFiles];
  }
}

- (void)recycleFiles
{
  if ([[desktopView selectedNodes] count]) {
    [gworkspace moveToTrash];
  }
}

- (void)emptyTrash
{
  [gworkspace emptyRecycler: nil];
}

- (void)deleteFiles
{
  if ([[desktopView selectedNodes] count]) {
    [gworkspace deleteFiles];
  }
}

- (void)setShownType:(id)sender
{
  NSString *title = [sender title];
  FSNInfoType type = FSNInfoNameType;

  if ([title isEqual: NSLocalizedString(@"Name", @"")]) {
    type = FSNInfoNameType;
  } else if ([title isEqual: NSLocalizedString(@"Type", @"")]) {
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

  [desktopView setShowType: type];  
}

- (void)setExtendedShownType:(id)sender
{
  [desktopView setExtendedShowType: [sender title]]; 
}

- (void)setIconsSize:(id)sender
{
  [desktopView setIconSize: [[sender title] intValue]];
}

- (void)setIconsPosition:(id)sender
{
  NSString *title = [sender title];

  if ([title isEqual: NSLocalizedString(@"Left", @"")]) {
    [desktopView setIconPosition: NSImageLeft];
  } else {
    [desktopView setIconPosition: NSImageAbove];
  }
}

- (void)setLabelSize:(id)sender
{
  [desktopView setLabelTextSize: [[sender title] intValue]];
}

- (void)selectAllInViewer
{
  [desktopView selectAll];
}

- (void)showTerminal
{
  [gworkspace startXTermOnDirectory: [dskNode path]];
}

@end


@implementation MPointWatcher

- (void)dealloc
{
  if (timer && [timer isValid])
    {
      [timer invalidate];
    }

  RELEASE (mountedRemovableVolumes);
  [super dealloc];
}

- (id)initForManager:(GWDesktopManager *)mngr
{
  self = [super init];
  
  if (self)
    {
      manager = mngr;
      active = NO;
      fm = [NSFileManager defaultManager];

      timer = [NSTimer scheduledTimerWithTimeInterval: 1.5
					       target: self
					     selector: @selector(watchMountPoints:)
					     userInfo: nil
					      repeats: YES];
    }
  
  return self;
}

- (void)startWatching
{
  [mountedRemovableVolumes release];
  mountedRemovableVolumes = [[NSWorkspace sharedWorkspace] mountedRemovableMedia];
  [mountedRemovableVolumes retain];
  active = YES;
}

- (void)stopWatching
{
  active = NO;
  [mountedRemovableVolumes release];
  mountedRemovableVolumes = nil;
}

- (void)watchMountPoints:(id)sender
{
  if (active)
    {
      BOOL removed = NO;
      BOOL added = NO;
      NSUInteger i;
      NSArray *newVolumes = [[NSWorkspace sharedWorkspace] mountedRemovableMedia];

      for (i = 0; i < [mountedRemovableVolumes count]; i++)
	{
	  NSString *vol;

	  vol = [mountedRemovableVolumes objectAtIndex:i];
	  if (![newVolumes containsObject:vol])
	    removed |= YES;
	}

      for (i = 0; i < [newVolumes count]; i++)
	{
	  NSString *vol;

	  vol = [newVolumes objectAtIndex:i];
	  if (![mountedRemovableVolumes containsObject:vol])
	    added |= YES;
	}

      if (added || removed)
	[manager mountedVolumesDidChange];

      [mountedRemovableVolumes release];
      mountedRemovableVolumes = newVolumes;
      [mountedRemovableVolumes retain];
    }
}

@end


@implementation GWMounter

+ (void)mountRemovableMedia
{
  CREATE_AUTORELEASE_POOL(pool);
  [[NSWorkspace sharedWorkspace] mountNewRemovableMedia];
  RELEASE (pool);  
}

@end
