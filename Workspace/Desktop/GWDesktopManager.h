/* GWDesktopManager.h
 *  
 * Copyright (C) 2005-2021 Free Software Foundation, Inc.
 *
 * Authors: Enrico Sersale <enrico@imago.ro>
 *          Riccardo Mottola <rm@gnu.org>
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */


#import <Foundation/Foundation.h>
#import "FSNodeRep.h"

typedef enum DockPosition {   
  DockPositionLeft = 0,
  DockPositionRight = 1
} DockPosition;


@class GWorkspace;
@class GWDesktopView;
@class Dock;
@class MPointWatcher;

@interface GWDesktopManager : NSObject
{
  FSNode *dskNode;
  id win;
  BOOL usexbundle;
  
  GWDesktopView *desktopView;

  BOOL singleClickLaunch;
  Dock *dock;
  BOOL hidedock;
  DockPosition dockPosition;
  
  NSRect dockReservedFrame;
  NSRect macmenuReservedFrame;
  NSRect tshelfReservedFrame;
  NSRect tshelfActivateFrame;
  
  GWorkspace *gworkspace;
  FSNodeRep *fsnodeRep;
  MPointWatcher *mpointWatcher;
  id ws;
  NSFileManager *fm;
  NSNotificationCenter *nc;      
}

+ (GWDesktopManager *)desktopManager;

- (void)activateDesktop;

- (void)deactivateDesktop;

- (BOOL)isActive;

- (void)checkDesktopDirs;

- (void)setUsesXBundle:(BOOL)value;

- (BOOL)usesXBundle;

- (id)loadXWinBundle;

- (BOOL)hasWindow:(id)awindow;

- (id)desktopView;

- (BOOL)singleClickLaunch;

- (void)setSingleClickLaunch:(BOOL)value;

- (Dock *)dock;

- (DockPosition)dockPosition;

- (void)setDockPosition:(DockPosition)pos;

- (void)setDockActive:(BOOL)value;

- (BOOL)dockActive;

- (void)setReservedFrames;

- (NSRect)macmenuReservedFrame;

- (NSRect)dockReservedFrame;

- (NSRect)tshelfReservedFrame;

- (NSRect)tshelfActivateFrame;

- (NSImage *)tabbedShelfBackground;

- (void)mouseEnteredTShelfActivateFrame;

- (void)mouseExitedTShelfActiveFrame;

- (void)deselectAllIcons;

- (void)addWatcherForPath:(NSString *)path;

- (void)removeWatcherForPath:(NSString *)path;

- (void)showRootViewer;

- (BOOL)selectFile:(NSString *)fullPath
inFileViewerRootedAtPath:(NSString *)rootFullpath;

- (void)performFileOperation:(NSDictionary *)opinfo;
                      
- (NSString *)trashPath;

- (void)moveToTrash;

- (void)checkNewRemovableMedia;

- (void)fileSystemWillChange:(NSNotification *)notif;

- (void)fileSystemDidChange:(NSNotification *)notif;

- (void)watcherNotification:(NSNotification *)notif;

- (void)thumbnailsDidChangeInPaths:(NSArray *)paths;

- (void)removableMediaPathsDidChange;

- (void)hideDotsFileDidChange:(BOOL)hide;

- (void)hiddenFilesDidChange:(NSArray *)paths;

- (void)newVolumeMounted:(NSNotification *)notif;

- (void)mountedVolumeWillUnmount:(NSNotification *)notif;

- (void)mountedVolumeDidUnmount:(NSNotification *)notif;

- (void)mountedVolumesDidChange;

- (void)unlockVolumeAtPath:(NSString *)volpath;

- (void)updateDefaults;

- (void)setContextHelp;

@end


//
// GWDesktopWindow Delegate Methods
//
@interface GWDesktopManager (GWDesktopWindowDelegateMethods)

- (BOOL)validateItem:(id)menuItem;
- (void)openSelectionInNewViewer:(BOOL)newv;
- (void)openSelectionAsFolder;
- (void)openSelectionWith;
- (void)newFolder;
- (void)newFile;
- (void)duplicateFiles;
- (void)recycleFiles;
- (void)emptyTrash;
- (void)deleteFiles;
- (void)setShownType:(id)sender;
- (void)setExtendedShownType:(id)sender;
- (void)setIconsSize:(id)sender;
- (void)setIconsPosition:(id)sender;
- (void)setLabelSize:(id)sender;
- (void)selectAllInViewer;
- (void)showTerminal;

@end


@interface MPointWatcher : NSObject
{
  NSArray *mountedRemovableVolumes;
  NSTimer *timer;
  BOOL active;
  GWDesktopManager *manager;
  NSFileManager *fm;
}

- (id)initForManager:(GWDesktopManager *)mngr;

- (void)startWatching;

- (void)stopWatching;

- (void)watchMountPoints:(id)sender;

@end


@interface GWMounter : NSObject
{
}

+ (void)mountRemovableMedia;

@end
