/* Desktop.h
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

#ifndef DESKTOP_H
#define DESKTOP_H

#include <Foundation/Foundation.h>

typedef enum DockPosition {   
  DockPositionLeft = 0,
  DockPositionRight = 1
} DockPosition;

@class NSWindow;
@class DesktopWindow;
@class DesktopView;
@class Dock;
@class DesktopPrefs;
@class FSNode;
@class StartAppWin;

@protocol workspaceAppProtocol

- (void)showRootViewer;

- (BOOL)openFile:(NSString *)fullPath;

- (BOOL)selectFile:(NSString *)fullPath
				  inFileViewerRootedAtPath:(NSString *)rootFullpath;

@end


@protocol	FSWClientProtocol

- (void)watchedPathDidChange:(NSData *)dirinfo;

@end


@protocol	FSWatcherProtocol

- (oneway void)registerClient:(id <FSWClientProtocol>)client;

- (oneway void)unregisterClient:(id <FSWClientProtocol>)client;

- (oneway void)client:(id <FSWClientProtocol>)client
                          addWatcherForPath:(NSString *)path;

- (oneway void)client:(id <FSWClientProtocol>)client
                          removeWatcherForPath:(NSString *)path;

@end


@protocol	InspectorProtocol

- (oneway void)addViewerWithBundleData:(NSData *)bundleData;

- (oneway void)setPathsData:(NSData *)data;

- (oneway void)showWindow;

- (oneway void)showAttributes;

- (oneway void)showContents;

- (oneway void)showTools;

- (BOOL)canDisplayDataOfType:(NSString *)type;

- (oneway void)showData:(NSData *)data 
                 ofType:(NSString *)type;

@end


@protocol	OperationProtocol

- (oneway void)performFileOperation:(NSData *)opinfo;

@end


@interface Desktop : NSObject <FSWClientProtocol>
{
  FSNode *desktopDir;
  
  DesktopWindow *win;
  Dock *dock;
  DockPosition dockPosition;
  NSRect dockReservedFrame;
  NSRect tshelfReservedFrame;
  
  NSFileManager *fm;
  id ws;
  NSNotificationCenter *nc; 

  DesktopPrefs *preferences;

  StartAppWin *startAppWin;
  
  NSString *trashPath;
  
  id fswatcher;
  BOOL fswnotifications;

  id inspectorApp;  
  id operationsApp;  
  id workspaceApplication;
}

+ (Desktop *)desktop;

+ (void)registerForServices;

- (NSWindow *)desktopWindow;

- (DesktopView *)desktopView;

- (Dock *)dock;

- (DockPosition)dockPosition;

- (void)setDockPosition:(DockPosition)pos;

- (NSRect)dockReservedFrame;

- (NSRect)tshelfReservedFrame;

- (void)setReservedFrames;

- (NSData *)tabbedShelfBackground;

- (void)contactWorkspaceApp;

- (void)workspaceAppConnectionDidDie:(NSNotification *)notif;

- (void)connectFSWatcher;

- (void)fswatcherConnectionDidDie:(NSNotification *)notif;

- (void)connectInspector;

- (void)inspectorConnectionDidDie:(NSNotification *)notif;

- (void)connectOperation;

- (void)operationConnectionDidDie:(NSNotification *)notif;

- (void)fileSystemWillChange:(NSNotification *)notif;

- (void)fileSystemDidChange:(NSNotification *)notif;

- (void)watchedPathDidChange:(NSData *)dirinfo;

- (void)newVolumeMounted:(NSNotification *)notif;

- (void)mountedVolumeWillUnmount:(NSNotification *)notif;

- (void)mountedVolumeDidUnmount:(NSNotification *)notif;

- (void)thumbnailsDidChange:(NSNotification *)notif;

- (void)createTrashPath;

- (void)updateDefaults;


//
// NSServicesRequests protocol
//
- (id)validRequestorForSendType:(NSString *)sendType
                     returnType:(NSString *)returnType;

- (BOOL)readSelectionFromPasteboard:(NSPasteboard *)pboard;


- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard
                             types:(NSArray *)types;


//
// Menu Operations
//
- (void)openSelection:(id)sender;

- (void)openSelectionWithApp:(id)sender;

- (void)openSelectionWith:(id)sender;

- (void)newFolder:(id)sender;

- (void)duplicateFiles:(id)sender;

- (void)moveToTrash:(id)sender;

- (void)emptyTrash:(id)sender;

- (void)showInspector:(id)sender;

- (void)showAttributesInspector:(id)sender;

- (void)showContentsInspector:(id)sender;

- (void)showToolsInspector:(id)sender;

- (void)checkNewRemovableMedia:(id)sender;

- (void)showPreferences:(id)sender;

- (void)showInfo:(id)sender;

#ifndef GNUSTEP
- (void)terminate:(id)sender;
#endif


//
// DesktopApplication protocol
//
- (void)selectionChanged:(NSArray *)newsel;

- (void)openSelectionInNewViewer:(BOOL)newv;

- (void)performFileOperation:(NSDictionary *)opinfo;

- (void)concludeRemoteFilesDragOperation:(NSData *)opinfo
                             atLocalPath:(NSString *)localdest;

- (void)addWatcherForPath:(NSString *)path;

- (void)removeWatcherForPath:(NSString *)path;

- (NSString *)trashPath;

- (id)workspaceApplication;

@end


@interface NSWorkspace (mounting)

- (BOOL)getFileSystemInfoForPath:(NSString *)fullPath
		                 isRemovable:(BOOL *)removableFlag
		                  isWritable:(BOOL *)writableFlag
		               isUnmountable:(BOOL *)unmountableFlag
		                 description:(NSString **)description
			                      type:(NSString **)fileSystemType;
                            
- (NSArray *)mountedLocalVolumePaths;

- (NSArray *)mountedRemovableMedia;

- (NSArray *)mountNewRemovableMedia;

- (BOOL)unmountAndEjectDeviceAtPath:(NSString *)path;

@end

#endif // DESKTOP_H
