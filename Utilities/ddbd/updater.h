/* updater.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: October 2004
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#ifndef DDBD_UPDATER_H
#define DDBD_UPDATER_H

#include <Foundation/Foundation.h>
#include "SQLite.h"

@interface DDBdUpdater: NSObject
{
  sqlite3 *db;
  id ddbd;
  NSDictionary *updinfo;
  NSDistributedLock *lock;
  NSFileManager *fm;
}

+ (void)updaterForTask:(NSDictionary *)info;

- (void)setUpdaterTask:(NSDictionary *)info;

- (void)done;

- (BOOL)checkPath:(NSString *)path;

- (NSData *)infoOfType:(NSString *)type
               forPath:(NSString *)path;
               
- (void)connectDDBd;

- (void)ddbdConnectionDidDie:(NSNotification *)notif;

- (void)insertDirectoryTrees;

- (void)removeTrees;

- (void)fileSystemDidChange;

- (void)daylyUpdate;

@end

#endif // DDBD_UPDATER_H
