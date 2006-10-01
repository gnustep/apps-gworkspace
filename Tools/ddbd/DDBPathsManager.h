/* DDBPathsManager.h
 *  
 * Copyright (C) 2005 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: July 2005
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

#ifndef DDBD_PATHS_MANAGER_H
#define DDBD_PATHS_MANAGER_H

#include <Foundation/Foundation.h>
#include "DBKBTree.h"

@class DDBPath;
@class DDBMDStorage;

@interface DDBPathsManager: NSObject <DBKBTreeDelegate>
{
  DDBMDStorage *mdstorage;
  DBKBTree *tree;
  DBKVarLenRecordsFile *vlfile;
   
  DDBPath *dummyPaths[2];
  NSNumber *dummyOffsets[2];
  
  NSMutableDictionary *mdmodules;
     
  unsigned ulen;
  unsigned llen;
  
  NSFileManager *fm;
}

- (id)initWithBasePath:(NSString *)bpath;

- (void)synchronize;

- (DDBPath *)ddbpathForPath:(NSString *)path;
                
- (DDBPath *)addPath:(NSString *)path;

- (void)removePath:(NSString *)path;

- (void)setMetadata:(id)mdata
             ofType:(NSString *)mdtype
            forPath:(NSString *)apath;

- (id)metadataOfType:(NSString *)mdtype
             forPath:(NSString *)apath;

- (NSArray *)metadataForPath:(NSString *)apath;

- (NSTimeInterval)timestampOfPath:(NSString *)path;

- (void)metadataDidChangeForPath:(DDBPath *)ddbpath;

- (void)duplicateDataOfPath:(NSString *)srcpath
                    forPath:(NSString *)dstpath;

- (void)duplicateDataOfPaths:(NSArray *)srcpaths
                    forPaths:(NSArray *)dstpaths;

- (NSArray *)subpathsFromPath:(NSString *)path;

- (id)mdmoduleForMDType:(NSString *)type;
                                 
@end


@interface DDBPath: NSObject <NSCoding>
{
  NSString *path;
  NSString *mdpath;
  NSTimeInterval timestamp;
}

- (id)initForPath:(NSString *)apath;

- (id)initWithCoder:(NSCoder *)decoder;

- (void)encodeWithCoder:(NSCoder *)encoder;

- (void)setPath:(NSString *)apath;

- (NSString *)path;

- (void)setMDPath:(NSString *)apath;

- (NSString *)mdpath;

- (void)setTimestamp:(NSTimeInterval)stamp;

- (NSTimeInterval)timestamp;

- (NSComparisonResult)compare:(DDBPath *)apath;
                                                               
@end

#endif // DDBD_PATHS_MANAGER_H
