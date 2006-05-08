/* ddbd.h
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

#ifndef DDBD_H
#define DDBD_H

#include <Foundation/Foundation.h>
#include "sqlite.h"

@protocol	DDBdProtocol

- (oneway void)insertPath:(NSString *)path;

- (oneway void)removePath:(NSString *)path;

- (oneway void)insertDirectoryTreesFromPaths:(NSData *)info;

- (oneway void)removeTreesFromPaths:(NSData *)info;

- (NSData *)directoryTreeFromPath:(NSString *)path;

- (NSString *)annotationsForPath:(NSString *)path;

- (oneway void)setAnnotations:(NSString *)annotations
                      forPath:(NSString *)path;

- (NSTimeInterval)timestampOfPath:(NSString *)path;

- (void)registerUpdater:(id)anObject;

@end


@protocol	DBUpdaterProtocol

- (BOOL)openDbAtPath:(NSString *)dbpath;

- (oneway void)insertTrees:(NSData *)info;

- (oneway void)removeTrees:(NSData *)info;

- (oneway void)fileSystemDidChange:(NSData *)info;

- (oneway void)scheduledUpdate;

@end

    
@interface DDBd: NSObject 
{
  NSString *dbdir;
  NSString *dbpath;
  sqlite3 *db;
  SQLiteQueryManager *qmanager;
  
  NSConnection *updaterconn;
  id <DBUpdaterProtocol> updater;
  
  NSConnection *conn;
  NSNotificationCenter *nc; 
  NSFileManager *fm;
}

- (void)registerUpdater:(id)anObject;

- (oneway void)insertPath:(NSString *)path;
      
- (oneway void)removePath:(NSString *)path;

- (oneway void)insertDirectoryTreesFromPaths:(NSData *)info;

- (oneway void)removeTreesFromPaths:(NSData *)info;

- (NSData *)directoryTreeFromPath:(NSString *)apath;

- (NSData *)attributeForKey:(NSString *)key
                     atPath:(NSString *)path;

- (BOOL)setAttribute:(NSData *)attribute
              forKey:(NSString *)key
              atPath:(NSString *)path;

- (NSTimeInterval)timestampOfPath:(NSString *)path;

- (NSString *)annotationsForPath:(NSString *)path;

- (oneway void)setAnnotations:(NSString *)annotations
                      forPath:(NSString *)path;
                                                     
- (void)fileSystemDidChange:(NSNotification *)notif;

- (void)performScheduledUpdate:(id)sender;

- (BOOL)opendb;

- (void)connectionBecameInvalid:(NSNotification *)notification;

- (BOOL)connection:(NSConnection *)ancestor
            shouldMakeNewConnection:(NSConnection *)newConn;
            
@end


@interface DBUpdater: NSObject
{
  sqlite3 *db;
  SQLiteQueryManager *qmanager;
  NSFileManager *fm;
}

+ (void)newUpdater:(NSArray *)ports;

- (BOOL)openDbAtPath:(NSString *)dbpath;

- (oneway void)insertTrees:(NSData *)info;

- (oneway void)removeTrees:(NSData *)info;

- (oneway void)fileSystemDidChange:(NSData *)info;

- (oneway void)scheduledUpdate;

@end


int insertPathIfNeeded(NSString *path, sqlite3 *db, SQLiteQueryManager *qmanager);

BOOL removePath(NSString *path, SQLiteQueryManager *qmanager);

BOOL renamePath(NSString *path, NSString *oldpath, SQLiteQueryManager *qmanager);

BOOL copyPath(NSString *srcpath, NSString *dstpath, SQLiteQueryManager *qmanager);


BOOL subpath(NSString *p1, NSString *p2);

NSString *pathsep(void);

NSString *removePrefix(NSString *path, NSString *prefix);


static void path_exists(sqlite3_context *context, int argc, sqlite3_value **argv);

static void path_moved(sqlite3_context *context, int argc, sqlite3_value **argv);

static void time_stamp(sqlite3_context *context, int argc, sqlite3_value **argv);

#endif // DDBD_H
