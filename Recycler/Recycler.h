/* Recycler.h
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

#ifndef RECYCLER_H
#define RECYCLER_H

#include <Foundation/Foundation.h>

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

- (oneway void)registerClient:(id <FSWClientProtocol>)client;

- (oneway void)unregisterClient:(id <FSWClientProtocol>)client;

- (oneway void)client:(id <FSWClientProtocol>)client
                          addWatcherForPath:(NSString *)path;

- (oneway void)client:(id <FSWClientProtocol>)client
                          removeWatcherForPath:(NSString *)path;

@end


@protocol	OperationProtocol

- (oneway void)performOperation:(NSData *)opinfo;

- (oneway void)setFilenamesCutted:(BOOL)value;

- (BOOL)filenamesWasCutted;

@end


@interface Recycler : NSObject <FSWClientProtocol>
{
  NSString *trashPath;
  RecyclerView *recview;
  BOOL docked;
  RecyclerPrefs *preferences;
  StartAppWin *startAppWin;
  
  id fswatcher;
  BOOL fswnotifications;
  id operationsApp;  
  id workspaceApplication;

  NSFileManager *fm;
  id ws;
  NSNotificationCenter *nc; 
}

+ (Recycler *)recycler;

- (void)setDocked:(BOOL)value;

- (BOOL)isDocked;

- (void)fileSystemDidChange:(NSNotification *)notif;

- (void)watchedPathDidChange:(NSData *)dirinfo;

- (void)updateDefaults;

- (void)contactWorkspaceApp;

- (void)workspaceAppConnectionDidDie:(NSNotification *)notif;

- (void)connectFSWatcher;

- (void)fswatcherConnectionDidDie:(NSNotification *)notif;

- (void)connectOperation;

- (void)operationConnectionDidDie:(NSNotification *)notif;


//
// Menu Operations
//
- (void)emptyTrash:(id)sender;

- (void)paste:(id)sender;

- (void)showPreferences:(id)sender;

- (void)showInfo:(id)sender;


//
// DesktopApplication protocol
//
- (void)selectionChanged:(NSArray *)newsel;

- (void)openSelectionInNewViewer:(BOOL)newv;

- (void)openSelectionWithApp:(id)sender;

- (void)performFileOperation:(NSDictionary *)opinfo;

- (void)concludeRemoteFilesDragOperation:(NSData *)opinfo
                             atLocalPath:(NSString *)localdest;

- (void)addWatcherForPath:(NSString *)path;

- (void)removeWatcherForPath:(NSString *)path;

- (NSString *)trashPath;

- (id)workspaceApplication;

@end

#endif // RECYCLER_H
