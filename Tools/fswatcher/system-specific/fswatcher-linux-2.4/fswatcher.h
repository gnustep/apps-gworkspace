/* fswatcher.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: February 2004
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

#ifndef FSWATCHER_H
#define FSWATCHER_H

#include <Foundation/Foundation.h>
#include "pathutils.h"

@class Watcher;

@protocol	FSWClientProtocol

- (oneway void)watchedPathDidChange:(NSData *)dirinfo;

- (oneway void)globalWatchedPathDidChange:(NSDictionary *)dirinfo;

@end


@protocol	FSWatcherProtocol

- (oneway void)setGlobalIncludePaths:(NSArray *)ipaths
                        excludePaths:(NSArray *)epaths;

- (oneway void)addGlobalIncludePath:(NSString *)path;

- (oneway void)removeGlobalIncludePath:(NSString *)path;

- (oneway void)addGlobalExcludePath:(NSString *)path;

- (oneway void)removeGlobalExcludePath:(NSString *)path;

- (oneway void)registerClient:(id <FSWClientProtocol>)client
              isGlobalWatcher:(BOOL)global;

- (oneway void)unregisterClient:(id <FSWClientProtocol>)client;

- (oneway void)client:(id <FSWClientProtocol>)client
                          addWatcherForPath:(NSString *)path;

- (oneway void)client:(id <FSWClientProtocol>)client
                          removeWatcherForPath:(NSString *)path;
                          

- (oneway void)deviceDataReady:(NSData *)data;

@end


@interface FSWClientInfo: NSObject 
{
  NSConnection *conn;
  id <FSWClientProtocol> client;
  NSCountedSet *wpaths;
  BOOL global;
}

- (void)setConnection:(NSConnection *)connection;

- (NSConnection *)connection;

- (void)setClient:(id <FSWClientProtocol>)clnt;

- (id <FSWClientProtocol>)client;

- (void)addWatchedPath:(NSString *)path;

- (void)removeWatchedPath:(NSString *)path;

- (BOOL)isWathchingPath:(NSString *)path;

- (NSSet *)watchedPaths;

- (void)setGlobal:(BOOL)value;

- (BOOL)isGlobal;

@end


@interface FSWatcher: NSObject 
{
  NSConnection *conn;
  NSMutableSet *clientsInfo;  
  NSMutableSet *watchers;
  
  NSCountedSet *watchedPaths;
  pcomp *includePathsTree;
  pcomp *excludePathsTree;
  NSConnection *devReadConn;
  
  NSFileManager *fm;
  NSNotificationCenter *nc; 
}

- (BOOL)connection:(NSConnection *)ancestor
            shouldMakeNewConnection:(NSConnection *)newConn;

- (void)connectionBecameInvalid:(NSNotification *)notification;

- (void)setDefaultGlobalPaths;

- (oneway void)setGlobalIncludePaths:(NSArray *)ipaths
                        excludePaths:(NSArray *)epaths;

- (oneway void)addGlobalIncludePath:(NSString *)path;

- (oneway void)removeGlobalIncludePath:(NSString *)path;

- (NSArray *)globalIncludePaths;

- (oneway void)addGlobalExcludePath:(NSString *)path;

- (oneway void)removeGlobalExcludePath:(NSString *)path;

- (NSArray *)globalExcludePaths;

- (oneway void)registerClient:(id <FSWClientProtocol>)client
              isGlobalWatcher:(BOOL)global;

- (oneway void)unregisterClient:(id <FSWClientProtocol>)client;

- (FSWClientInfo *)clientInfoWithConnection:(NSConnection *)connection;

- (FSWClientInfo *)clientInfoWithRemote:(id)remote;

- (oneway void)client:(id <FSWClientProtocol>)client
                                addWatcherForPath:(NSString *)path;

- (oneway void)client:(id <FSWClientProtocol>)client
                                removeWatcherForPath:(NSString *)path;
                                
- (Watcher *)watcherForPath:(NSString *)path;
                                
- (void)watcherTimeOut:(NSTimer *)sender;

- (void)removeWatcher:(Watcher *)awatcher;                                
                                
- (void)notifyClients:(NSDictionary *)info;

- (void)notifyGlobalWatchingClients:(NSDictionary *)info;

- (oneway void)deviceDataReady:(NSData *)data;
      
@end


@interface Watcher: NSObject
{
  NSString *watchedPath;  
  BOOL isdir;
  NSArray *pathContents;
  int listeners;
  NSDate *date;
	BOOL isOld;
	NSFileManager *fm;
  FSWatcher *fswatcher;
  NSTimer *timer;
}

- (id)initWithWatchedPath:(NSString *)path
                fswatcher:(id)fsw;

- (void)watchFile;

- (void)addListener;

- (void)removeListener;

- (BOOL)isWathcingPath:(NSString *)apath;

- (NSString *)watchedPath;

- (BOOL)isOld;

- (NSTimer *)timer;

@end


@interface FSWDeviceReader: NSObject
{
  NSFileHandle *devHandle;
  id fsw;
}

+ (void)deviceReader:(NSArray *)ports;

- (id)initWithPorts:(NSArray *)ports;

- (void)readDeviceData;

@end

#endif // FSWATCHER_H
