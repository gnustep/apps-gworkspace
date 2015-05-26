/* fswatcher-inotify.h
 *  
 * Copyright (C) 2007-2015 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@fibernet.ro>
 * Date: January 2007
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

#ifndef FSWATCHER_INOTIFY_H
#define FSWATCHER_INOTIFY_H

#include <sys/types.h>
#include <sys/inotify.h>
#import <Foundation/Foundation.h>
#include "DBKPathsTree.h"

@class Watcher;

@protocol	FSWClientProtocol <NSObject>

- (oneway void)watchedPathDidChange:(NSData *)dirinfo;

- (oneway void)globalWatchedPathDidChange:(NSDictionary *)dirinfo;

@end


@protocol	FSWatcherProtocol

- (oneway void)registerClient:(id <FSWClientProtocol>)client
              isGlobalWatcher:(BOOL)global;

- (oneway void)unregisterClient:(id <FSWClientProtocol>)client;

- (oneway void)client:(id <FSWClientProtocol>)client
                          addWatcherForPath:(NSString *)path;

- (oneway void)client:(id <FSWClientProtocol>)client
                          removeWatcherForPath:(NSString *)path;

- (oneway void)logDataReady:(NSData *)data;

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
  NSMutableArray *clientsInfo;  
  NSMapTable *watchers;
  NSMapTable *watchDescrMap;
  
  NSFileHandle *inotifyHandle;
  uint32_t filemask;
  uint32_t dirmask;
  NSString *lastMovedPath;
  uint32_t moveCookie;
  
  pcomp *includePathsTree;
  pcomp *excludePathsTree;  
  NSMutableSet *excludedSuffixes;
     
  NSFileManager *fm;
  NSNotificationCenter *nc;
  NSNotificationCenter *dnc;
}

- (BOOL)connection:(NSConnection *)ancestor
            shouldMakeNewConnection:(NSConnection *)newConn;

- (void)connectionBecameInvalid:(NSNotification *)notification;

- (void)setDefaultGlobalPaths;

- (void)globalPathsChanged:(NSNotification *)notification;

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

- (Watcher *)watcherWithWatchDescriptor:(int)wd;
                                
- (void)removeWatcher:(Watcher *)awatcher;                                
                                
- (void)notifyClients:(NSDictionary *)info;

- (void)notifyGlobalWatchingClients:(NSDictionary *)info;

- (void)checkLastMovedPath:(id)sender;

- (void)inotifyDataReady:(NSNotification *)notif;

@end


@interface Watcher: NSObject
{
  NSString *watchedPath;  
  int watchDescriptor;
  BOOL isdir;  
  int listeners;
  FSWatcher *fswatcher;
}

- (id)initWithWatchedPath:(NSString *)path
          watchDescriptor:(int)wdesc
                fswatcher:(id)fsw;

- (void)addListener;

- (void)removeListener;

- (BOOL)isWathcingPath:(NSString *)apath;

- (NSString *)watchedPath;

- (int)watchDescriptor;

- (BOOL)isDirWatcher;

@end

#endif // FSWATCHER_INOTIFY_H

