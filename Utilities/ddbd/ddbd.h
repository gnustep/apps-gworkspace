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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#ifndef DDBD_H
#define DDBD_H

#include <Foundation/Foundation.h>

@protocol	DDBdProtocol

- (BOOL)dbactive;

- (BOOL)insertPath:(NSString *)path;

- (BOOL)removePath:(NSString *)path;

- (void)insertDirectoryTreesFromPaths:(NSData *)info;

- (void)removeTreesFromPaths:(NSData *)info;

- (NSData *)directoryTreeFromPath:(NSString *)apath;

- (NSString *)annotationsForPath:(NSString *)path;

- (oneway void)setAnnotations:(NSString *)annotations
                      forPath:(NSString *)path;

@end


@interface DDBd: NSObject <DDBdProtocol>
{
  NSConnection *conn;
  NSNotificationCenter *nc; 
}

- (void)prepareDb;
                                                     
- (void)connectionBecameInvalid:(NSNotification *)notification;

- (void)fileSystemDidChange:(NSNotification *)notif;

- (void)performDaylyUpdate:(id)sender;

- (void)threadWillExit:(NSNotification *)notification;
            
@end


@interface DBUpdater: NSObject
{
  id ddbd;
  NSDictionary *updinfo;
}

+ (void)updaterForTask:(NSDictionary *)info;

- (void)setUpdaterTask:(NSDictionary *)info;

- (void)done;

- (void)prepareDb;

- (void)insertTrees;

- (void)removeTrees;

- (void)fileSystemDidChange;

- (void)daylyUpdate;

@end

#endif // DDBD_H
