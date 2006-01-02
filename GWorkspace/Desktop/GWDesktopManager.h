/* GWDesktopManager.h
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#ifndef GW_DESKTOP_MANAGER
#define GW_DESKTOP_MANAGER

#include <Foundation/Foundation.h>
#include "FSNodeRep.h"

typedef enum DockPosition {   
  DockPositionLeft = 0,
  DockPositionRight = 1
} DockPosition;

@class GWorkspace;
@class GWDesktopView;
@class Dock;

@interface GWDesktopManager : NSObject
{
  FSNode *dskNode;
  id win;
  BOOL usexbundle;
  
  Dock *dock;
  BOOL hidedock;
  DockPosition dockPosition;
  
  NSRect dockReservedFrame;
  NSRect tshelfReservedFrame;
  NSRect tshelfActivateFrame;
  
  GWorkspace *gworkspace;
  FSNodeRep *fsnodeRep;
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

- (Dock *)dock;

- (DockPosition)dockPosition;

- (void)setDockPosition:(DockPosition)pos;

- (void)setDockActive:(BOOL)value;

- (BOOL)dockActive;

- (void)setReservedFrames;

- (NSRect)dockReservedFrame;

- (NSRect)tshelfReservedFrame;

- (NSRect)tshelfActivateFrame;

- (NSImage *)tabbedShelfBackground;

- (void)mouseEnteredTShelfActivateFrame;

- (void)mouseExitedTShelfActiveFrame;

- (void)deselectAllIcons;

- (void)deselectInSpatialViewers;

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

- (void)hideDotsFileDidChange:(BOOL)hide;

- (void)hiddenFilesDidChange:(NSArray *)paths;

- (void)newVolumeMounted:(NSNotification *)notif;

- (void)mountedVolumeWillUnmount:(NSNotification *)notif;

- (void)mountedVolumeDidUnmount:(NSNotification *)notif;

- (void)mountThreadWillExit:(NSNotification *)notif;

- (void)updateDefaults;

@end


//
// GWDesktopWindow Delegate Methods
//
@interface GWDesktopManager (GWDesktopWindowDelegateMethods)

- (BOOL)validateItem:(id)menuItem;
- (void)openSelectionInNewViewer:(BOOL)newv;
- (void)openSelectionAsFolder;
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


@interface GWMounter : NSObject
{
}

+ (void)mountRemovableMedia;

- (void)mountRemovableMedia;

@end

#endif // GW_DESKTOP_MANAGER
