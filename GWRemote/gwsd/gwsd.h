/* gwsd.h
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
 *
 * This file is part of the GNUstep gwsd tool
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

#ifndef GWSD_H
#define GWSD_H

#include <Foundation/Foundation.h>

@class NSWorkspace;
@class GWSd;
@class LocalFileOp;
@class Watcher;
@class ShellTask;

@protocol GWSdClientProtocol

- (void)setServerConnection:(NSConnection *)conn;

- (NSString *)userName;

- (NSString *)userPassword;

- (oneway void)connectionRefused;

- (int)requestUserConfirmationWithMessage:(NSString *)message 
                                    title:(NSString *)title;

- (int)showErrorAlertWithMessage:(NSString *)message;

- (oneway void)showProgressForFileOperationWithName:(NSString *)name
                                         sourcePath:(NSString *)source
                                    destinationPath:(NSString *)destination
                                       operationRef:(int)ref
                                           onServer:(id)server;

- (void)endOfFileOperationWithRef:(int)ref onServer:(id)server;

- (oneway void)server:(id)aserver fileSystemDidChange:(NSDictionary *)info;

- (oneway void)exitedShellTaskWithRef:(NSNumber *)ref;

- (oneway void)remoteShellWithRef:(NSNumber *)ref 
                 hasAvailableData:(NSData *)data;

@end

@protocol GWSDProtocol

- (void)registerRemoteClient:(id<GWSdClientProtocol>)remote;

- (NSString *)homeDirectory;

- (BOOL)existsFileAtPath:(NSString *)path;

- (BOOL)existsAndIsDirectoryFileAtPath:(NSString *)path;

- (NSString *)typeOfFileAt:(NSString *)path;

- (BOOL)isPakageAtPath:(NSString *)path;

- (NSDictionary *)fileSystemAttributesAtPath:(NSString *)path;

- (BOOL)isWritableFileAtPath:(NSString *)path;

- (NSDate *)modificationDateForPath:(NSString *)path;

- (int)sortTypeForDirectoryAtPath:(NSString *)aPath;

- (void)setSortType:(int)type forDirectoryAtPath:(NSString *)aPath;

- (NSDictionary *)directoryContentsAtPath:(NSString *)path;

- (NSString *)contentsOfFileAt:(NSString *)path;

- (BOOL)saveString:(NSString *)str atPath:(NSString *)path;

- (void)addWatcherForPath:(NSString *)path;

- (void)removeWatcherForPath:(NSString *)path;

- (oneway void)performLocalFileOperationWithDictionary:(id)opdict;

- (BOOL)pauseFileOpeRationWithRef:(int)ref;

- (BOOL)continueFileOpeRationWithRef:(int)ref;

- (BOOL)stopFileOpeRationWithRef:(int)ref;

- (oneway void)renamePath:(NSString *)oldname toNewName:(NSString *)newname;

- (oneway void)newObjectAtPath:(NSString *)basePath isDirectory:(BOOL)directory;       
        
- (oneway void)duplicateFiles:(NSArray *)files inDirectory:(NSString *)basePath;

- (oneway void)deleteFiles:(NSArray *)files inDirectory:(NSString *)basePath;

- (oneway void)openShellOnPath:(NSString *)path refNumber:(NSNumber *)ref;

- (oneway void)remoteShellWithRef:(NSNumber *)ref 
                   newCommandLine:(NSString *)line;

- (oneway void)closedRemoteTerminalWithRefNumber:(NSNumber *)ref;

@end 

@interface GWSd: NSObject <GWSDProtocol>
{
  BOOL hideSysFiles;
  int defSortType;
  
  NSString *userName;
  NSString *userPassword;
  
  GWSd *sharedIstance;
  NSConnection *firstConn;
  NSConnection *conn;  
  id<GWSdClientProtocol> gwsdClient;
  NSRecursiveLock *clientLock;
  
  NSMutableArray *watchers;
  NSMutableArray *watchTimers;
  
  NSMutableArray *operations;
  int oprefnum;

  NSMutableArray *shellTasks;
  NSString *shellCommand;
  
  NSNotificationCenter *nc;
  NSNotificationCenter *dnc;
  NSFileManager *fm;
  NSWorkspace *ws;
}

+ (void)initialize;

+ (GWSd *)sharedGWSd;

- (id)initWithRemote:(id)remote 
          connection:(NSConnection *)aConnection;

+ (void)newThreadWithRemote:(id<GWSdClientProtocol>)remote;

- (void)_registerRemoteClient:(id<GWSdClientProtocol>)remote;

- (id<GWSdClientProtocol>)gwsdClient;

- (NSRecursiveLock *)clientLock;

- (void)connectionDidDie:(NSNotification *)notification;

- (NSMutableDictionary *)cachedRepresentationForPath:(NSString *)path;

- (void)removeCachedRepresentation;

- (BOOL)hideSysFiles;

- (NSArray *)checkHiddenFiles:(NSArray *)files atPath:(NSString *)path;

- (BOOL)verifyFileAtPath:(NSString *)path;

@end

@interface GWSd (FileOperations)

- (int)fileOperationRef;

- (LocalFileOp *)fileOpWithRef:(int)ref;

- (void)endOfFileOperation:(LocalFileOp *)op;

- (void)fileSystemDidChange:(NSNotification *)notif;

@end

@interface GWSd (Watchers)

- (void)_addWatcherForPath:(NSString *)path;

- (void)_removeWatcherForPath:(NSString *)path;

- (void)suspendWatchingForPath:(NSString *)path;

- (void)restartWatchingForPath:(NSString *)path;

- (Watcher *)watcherForPath:(NSString *)path;

- (NSTimer *)timerForPath:(NSString *)path;

- (void)watcherTimeOut:(id)sender;

- (void)removeWatcher:(Watcher *)awatcher;

- (void)watcherNotification:(NSDictionary *)dict;

@end

@interface GWSd (shellTasks)

- (void)_openShellOnPath:(NSString *)path refNumber:(NSNumber *)ref;

- (void)_remoteShellWithRef:(NSNumber *)ref 
             newCommandLine:(NSString *)line;

- (void)_closedRemoteTerminalWithRefNumber:(NSNumber *)ref;

- (ShellTask *)taskWithRefNumber:(NSNumber *)ref;

- (void)shellDone:(ShellTask *)atask;

@end

#endif // GWSD_H

