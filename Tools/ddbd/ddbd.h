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

#import <Foundation/Foundation.h>

@protocol	DDBdProtocol

- (BOOL)dbactive;

- (oneway void)insertPath:(NSString *)path;

- (oneway void)removePath:(NSString *)path;

- (void)insertDirectoryTreesFromPaths:(NSData *)info;

- (void)removeTreesFromPaths:(NSData *)info;

- (NSData *)directoryTreeFromPath:(NSString *)apath;

- (NSArray *)userMetadataForPath:(NSString *)apath;

- (NSString *)annotationsForPath:(NSString *)path;

- (oneway void)setAnnotations:(NSString *)annotations
                      forPath:(NSString *)path;

- (NSTimeInterval)timestampOfPath:(NSString *)path;

- (oneway void)fileSystemDidChange:(NSData *)info;

- (oneway void)synchronize;

@end

    
@interface DDBd: NSObject <DDBdProtocol>
{
  NSString *dbdir;
  NSConnection *conn;
  NSNotificationCenter *nc; 
}
                                                     
- (void)connectionBecameInvalid:(NSNotification *)notification;

- (void)threadWillExit:(NSNotification *)notification;
            
@end


@interface DBUpdater: NSObject
{
  NSDictionary *updinfo;
}

+ (void)updaterForTask:(NSDictionary *)info;

- (void)setUpdaterTask:(NSDictionary *)info;

- (void)insertTrees;

- (void)removeTrees;

- (void)fileSystemDidChange;

@end


BOOL subpath(NSString *p1, NSString *p2);
NSString *pathsep(void);
NSString *removePrefix(NSString *path, NSString *prefix);

#endif // DDBD_H
