/* Recycler.h
 *  
 * Copyright (C) 2004-2013 Free Software Foundation, Inc.
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

@class FSNodeRep;
@class FSNode;
@class RecyclerView;
@class RecyclerPrefs;
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

- (oneway void)registerClient:(id <FSWClientProtocol>)client
              isGlobalWatcher:(BOOL)global;

- (oneway void)unregisterClient:(id <FSWClientProtocol>)client;

- (oneway void)client:(id <FSWClientProtocol>)client
                          addWatcherForPath:(NSString *)path;

- (oneway void)client:(id <FSWClientProtocol>)client
                          removeWatcherForPath:(NSString *)path;

@end


@protocol	OperationProtocol

- (oneway void)performOperation:(NSData *)opinfo;

- (oneway void)setFilenamesCut:(BOOL)value;

- (BOOL)filenamesWasCut;

@end


@interface Recycler : NSObject <FSWClientProtocol>
{
  FSNodeRep *fsnodeRep;
  NSString *trashPath;
  RecyclerView *recview;
  BOOL docked;
  RecyclerPrefs *preferences;
  StartAppWin *startAppWin;
  
  id fswatcher;
  BOOL fswnotifications;
  id operationsApp;  
  id workspaceApplication;
  
  BOOL terminating;

  NSFileManager *fm;
  id ws;
  NSNotificationCenter *nc; 
}

+ (Recycler *)recycler;

- (oneway void)emptyTrash;

- (void)setDocked:(BOOL)value;

- (BOOL)isDocked;

- (void)fileSystemDidChange:(NSNotification *)notif;

- (void)watchedPathDidChange:(NSData *)dirinfo;

- (void)updateDefaults;

- (void)contactWorkspaceApp;

- (void)workspaceAppConnectionDidDie:(NSNotification *)notif;

- (void)connectFSWatcher;

- (void)fswatcherConnectionDidDie:(NSNotification *)notif;


//
// Menu Operations
//
- (void)emptyTrashFromMenu:(id)sender;

- (void)paste:(id)sender;

- (void)showPreferences:(id)sender;

- (void)showInfo:(id)sender;


//
// DesktopApplication protocol
//
- (void)selectionChanged:(NSArray *)newsel;

- (void)openSelectionInNewViewer:(BOOL)newv;

- (void)openSelectionWithApp:(id)sender;

- (void)performFileOperation:(NSString *)operation
		                  source:(NSString *)source
		             destination:(NSString *)destination
		                   files:(NSArray *)files;

- (void)concludeRemoteFilesDragOperation:(NSData *)opinfo
                             atLocalPath:(NSString *)localdest;

- (void)addWatcherForPath:(NSString *)path;

- (void)removeWatcherForPath:(NSString *)path;

- (NSString *)trashPath;

- (id)workspaceApplication;

@end

