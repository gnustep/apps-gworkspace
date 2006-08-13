/* DDBDirsManager.h
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

#ifndef DDBD_DIRS_MANAGER_H
#define DDBD_DIRS_MANAGER_H

#include <Foundation/Foundation.h>
#include "DBKBTree.h"

@interface DDBDirsManager: NSObject <DBKBTreeDelegate>
{
  DBKBTree *tree;
  DBKVarLenRecordsFile *vlfile;
   
  NSString *dummyPaths[2];
  NSNumber *dummyOffsets[2];
     
  unsigned ulen;
  unsigned llen;
  
  NSFileManager *fm;
}

- (id)initWithBasePath:(NSString *)bpath;

- (void)synchronize;
                
- (void)addDirectory:(NSString *)dir;

- (void)removeDirectory:(NSString *)dir;

- (void)insertDirsFromPaths:(NSArray *)paths;

- (void)removeDirsFromPaths:(NSArray *)paths;

- (NSArray *)dirsFromPath:(NSString *)path;
                                                               
@end

#endif // DDBD_DIRS_MANAGER_H
