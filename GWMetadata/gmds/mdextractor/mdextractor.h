/* mdextractor.h
 *  
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@dtedu.net>
 * Date: February 2006
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

#ifndef MDEXTRACTOR_H
#define MDEXTRACTOR_H

#include <Foundation/Foundation.h>
#include "MDKQuery.h"
#include "SQLite.h"
#include "DBKPathsTree.h"

@class GMDSIndexablePath;

@protocol	FSWClientProtocol

- (oneway void)watchedPathDidChange:(NSData *)info;

- (oneway void)globalWatchedPathDidChange:(NSDictionary *)info;

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


@protocol	DDBdProtocol

- (NSArray *)userMetadataForPath:(NSString *)apath;

@end


@protocol	ExtractorsProtocol

- (id)initForExtractor:(id)extr;

- (NSArray *)pathExtensions;

- (BOOL)canExtractFromFileType:(NSString *)type
                 withExtension:(NSString *)ext
                    attributes:(NSDictionary *)attributes
                      testData:(NSData *)testdata;

- (BOOL)extractMetadataAtPath:(NSString *)path
                       withID:(int)path_id
                   attributes:(NSDictionary *)attributes;

@end


@interface GMDSExtractor: NSObject 
{
  NSMutableArray *indexablePaths;
  pcomp *includePathsTree;  
  pcomp *excludedPathsTree;  
  NSMutableSet *excludedSuffixes;  
  BOOL indexingEnabled;
  BOOL extracting;
  BOOL subpathsChanged;  
  NSString *dbdir;
  NSString *dbpath;
  SQLite *sqlite;
  
	NSMutableDictionary *extractors;
  id textExtractor;
  
  NSConnection *conn;

  NSString *indexedStatusPath;
  NSDistributedLock *indexedStatusLock;
  NSTimer *statusTimer;
  NSFileHandle *errHandle;
  
  NSFileManager *fm;
  id ws;
  NSNotificationCenter *nc; 
  NSNotificationCenter *dnc;  

  //
  // fswatcher_update  
  //
  id fswatcher;
  NSMutableArray *fswupdatePaths;
  NSMutableDictionary *fswupdateSkipBuff;
  NSMutableArray *lostPaths;
  NSTimer *fswupdateTimer;
  NSTimer *lostPathsTimer;

  //
  // ddbd_update
  //
  id ddbd;
  
  //
  // scheduled_update  
  //
  NSMutableArray *directories;
  int dirpos;
  NSTimer *schedupdateTimer;
  
  //
  // update_notifications
  //
  NSTimer *notificationsTimer;
  NSDate *notifDate;
}

- (void)indexedDirectoriesChanged:(NSNotification *)notification;

- (BOOL)synchronizePathsStatus:(BOOL)onstart;

- (NSArray *)readPathsStatus;

- (void)writePathsStatus:(id)sender;

- (NSDictionary *)infoOfPath:(NSString *)path 
               inSavedStatus:(NSArray *)status;

- (void)updateStatusOfPath:(GMDSIndexablePath *)indpath
                 startTime:(NSDate *)stime
                   endTime:(NSDate *)etime
                filesCount:(unsigned long)count
               indexedDone:(BOOL)indexed;

- (GMDSIndexablePath *)indexablePathWithPath:(NSString *)path;

- (GMDSIndexablePath *)ancestorOfAddedPath:(NSString *)path;

- (GMDSIndexablePath *)ancestorForAddingPath:(NSString *)path;

- (void)startExtracting;

- (void)stopExtracting;

- (BOOL)extractFromPath:(GMDSIndexablePath *)indpath;

- (int)insertOrUpdatePath:(NSString *)path
                   ofType:(NSString *)type
           withAttributes:(NSDictionary *)attributes;

- (BOOL)setMetadata:(NSDictionary *)mddict
            forPath:(NSString *)path
             withID:(int)path_id;

- (id)extractorForPath:(NSString *)path
                ofType:(NSString *)type
        withAttributes:(NSDictionary *)attributes;

- (void)loadExtractors;

- (BOOL)opendb;

- (void)logError:(NSString *)err;

- (BOOL)connection:(NSConnection *)ancestor
            shouldMakeNewConnection:(NSConnection *)newConn;

- (void)connectionDidDie:(NSNotification *)notification;

@end


@interface GMDSExtractor (updater)

- (void)setupUpdaters;

- (BOOL)addPath:(NSString *)path;

- (BOOL)updatePath:(NSString *)path;

- (BOOL)updateRenamedPath:(NSString *)path 
                  oldPath:(NSString *)oldpath
              isDirectory:(BOOL)isdir;

- (BOOL)removePath:(NSString *)path;

- (void)checkLostPaths:(id)sender;

- (NSArray *)filteredDirectoryContentsAtPath:(NSString *)path
                               escapeEntries:(BOOL)escape;

@end


@interface GMDSExtractor (fswatcher_update)

- (void)setupFswatcherUpdater;

- (oneway void)globalWatchedPathDidChange:(NSDictionary *)info;

- (void)processPendingChanges:(id)sender;

- (void)connectFSWatcher:(id)sender;

- (void)fswatcherConnectionDidDie:(NSNotification *)notif;

@end


@interface GMDSExtractor (ddbd_update)

- (void)setupDDBdUpdater;

- (void)connectDDBd;

- (void)ddbdConnectionDidDie:(NSNotification *)notif;

- (void)userAttributeModified:(NSNotification *)notif;

@end


@interface GMDSExtractor (scheduled_update)

- (void)setupScheduledUpdater;

- (void)checkNextDir:(id)sender;

@end


@interface GMDSExtractor (update_notifications)

- (void)setupUpdateNotifications;

- (void)notifyUpdates:(id)sender;

@end


@interface GMDSIndexablePath: NSObject 
{
  NSString *path;
  unsigned long filescount;
  BOOL indexed;
  NSDate *startTime;
  NSDate *endTime;
  NSMutableArray *subpaths;
  GMDSIndexablePath *ancestor;
}

- (id)initWithPath:(NSString *)apath
          ancestor:(GMDSIndexablePath *)prepath;

- (NSString *)path;

- (NSArray *)subpaths;

- (GMDSIndexablePath *)subpathWithPath:(NSString *)apath;

- (BOOL)acceptsSubpath:(NSString *)subpath;

- (GMDSIndexablePath *)addSubpath:(NSString *)apath;

- (void)removeSubpath:(NSString *)apath;

- (BOOL)isSubpath;

- (GMDSIndexablePath *)ancestor;

- (unsigned long)filescount;

- (void)setFilesCount:(unsigned long)count;

- (NSDate *)startTime;

- (void)setStartTime:(NSDate *)date;

- (NSDate *)endTime;

- (void)setEndTime:(NSDate *)date;

- (BOOL)indexed;

- (void)setIndexed:(BOOL)value;

- (void)checkIndexingDone;

- (NSDictionary *)info;

@end


void setUpdating(BOOL value);

BOOL isDotFile(NSString *path);

BOOL subPathOfPath(NSString *p1, NSString *p2);

NSString *path_separator(void);

#endif // MDEXTRACTOR_H










