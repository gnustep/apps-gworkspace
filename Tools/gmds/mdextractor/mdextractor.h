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
#include "SQLite.h"
#include "DBKPathsTree.h"

@class GMDSIndexablePath;

@protocol	FSWClientProtocol

- (oneway void)watchedPathDidChange:(NSData *)dirinfo;

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


@protocol	ExtractorsProtocol

- (id)initForExtractor:(id)extr;

- (NSString *)fileType;

- (NSArray *)pathExtensions;

- (BOOL)canExtractFromFileType:(NSString *)type
                 withExtension:(NSString *)ext
                    attributes:(NSDictionary *)attributes
                      testData:(NSData *)testdata;

- (BOOL)extractMetadataAtPath:(NSString *)path
                       withID:(int)path_id
                   attributes:(NSDictionary *)attributes
                 usingStemmer:(id)stemmer
                    stopWords:(NSSet *)stopwords;

@end


@protocol	StemmerProtocol

- (BOOL)setLanguage:(NSString *)lang;

- (NSString *)language;

- (NSArray *)stopWords;

- (NSString *)stemWord:(NSString *)word;

@end


@interface GMDSExtractor: NSObject 
{
  NSMutableArray *indexablePaths;
  pcomp *excludedPathsTree;  
  BOOL indexingEnabled;
  BOOL extracting;
  BOOL subpathsChanged;  
  NSString *dbpath;
  SQLite *sqlite;
  
	NSMutableArray *extractors;
  id textExtractor;
	id stemmer;
  NSSet *stopWords;
  
  NSConnection *conn;

  NSString *indexedStatusPath;
  NSDistributedLock *indexedStatusLock;
  NSTimer *statusTimer;

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
  // scheduled_update  
  //
  NSMutableArray *directories;
  int dirpos;
  NSTimer *schedupdateTimer;
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
           withAttributes:(NSDictionary *)attributes;

- (BOOL)setMetadata:(NSDictionary *)mddict
            forPath:(NSString *)path
             withID:(int)path_id;

- (id)extractorForPath:(NSString *)path
        withAttributes:(NSDictionary *)attributes;

- (void)loadExtractors;

- (void)setStemmingLanguage:(NSString *)language;

- (void)loadStemmer;

- (BOOL)opendb;

- (BOOL)connection:(NSConnection *)ancestor
            shouldMakeNewConnection:(NSConnection *)newConn;

- (void)connectionDidDie:(NSNotification *)notification;

@end


@interface GMDSExtractor (updater)

- (void)setupUpdaters;

- (BOOL)addPath:(NSString *)path;

- (BOOL)updatePath:(NSString *)path;

- (BOOL)updateRenamedPath:(NSString *)path 
                  oldPath:(NSString *)oldpath;

- (BOOL)removePath:(NSString *)path;

- (void)checkLostPaths:(id)sender;

- (NSArray *)filteredDirectoryContentsAtPath:(NSString *)path;

@end


@interface GMDSExtractor (fswatcher_update)

- (void)setupFswatcherUpdater;

- (oneway void)globalWatchedPathDidChange:(NSDictionary *)info;

- (void)processPendingChanges:(id)sender;

- (void)connectFSWatcher;

- (void)fswatcherConnectionDidDie:(NSNotification *)notif;

@end


@interface GMDSExtractor (scheduled_update)

- (void)setupScheduledUpdater;

- (void)checkNextDir:(id)sender;

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


BOOL isDotFile(NSString *path);

BOOL subPathOfPath(NSString *p1, NSString *p2);

NSString *path_separator(void);

#endif // MDEXTRACTOR_H










