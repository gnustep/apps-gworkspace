/* fswatcher.h
 *  
 * Copyright (C) 2004-2013 Free Software Foundation, Inc.
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

#import <Foundation/Foundation.h>
#import "DBKPathsTree.h"

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

- (BOOL)isWatchingPath:(NSString *)path;

- (NSSet *)watchedPaths;

- (void)setGlobal:(BOOL)value;

- (BOOL)isGlobal;

@end


@interface FSWatcher: NSObject 
{
  NSConnection *conn;
  NSMutableArray *clientsInfo;
  NSMapTable *watchers;

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

- (void)watcherTimeOut:(NSTimer *)sender;

- (void)removeWatcher:(Watcher *)awatcher;

- (pcomp *)includePathsTree;

- (pcomp *)excludePathsTree;  

- (NSSet *)excludedSuffixes;

- (BOOL)isGlobalValidPath:(NSString *)path;

- (void)notifyClients:(NSDictionary *)info;

- (void)notifyGlobalWatchingClients:(NSDictionary *)info;
      
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

- (BOOL)isWatchingPath:(NSString *)apath;

- (NSString *)watchedPath;

- (BOOL)isOld;

- (NSTimer *)timer;

@end


#endif // FSWATCHER_H
