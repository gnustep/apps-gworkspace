/* lsfd.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: September 2004
 *
 * This file is part of the GNUstep Finder application
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

#ifndef FSWATCHER_H
#define FSWATCHER_H

#include <Foundation/Foundation.h>

@protocol	LSFdClientProtocol

//- (oneway void)watchedPathDidChange:(NSData *)dirinfo;

@end


@protocol	LSFdProtocol

- (void)registerFinder:(id <LSFdClientProtocol>)fndr;

- (void)unregisterFinder:(id <LSFdClientProtocol>)fndr;

- (void)addLiveSearchFolderWithPath:(NSString *)path;

@end


@interface LSFd: NSObject <LSFdProtocol>
{
  NSConnection *conn;
  NSConnection *finderconn;
  id <LSFdClientProtocol> finder;

  NSMutableArray *modules;
  NSMutableArray *lsfolders;
  
  NSFileManager *fm;
  NSNotificationCenter *nc; 
}

- (void)loadModules;

- (NSArray *)bundlesWithExtension:(NSString *)extension 
													 inPath:(NSString *)path;

- (BOOL)connection:(NSConnection *)ancestor
            shouldMakeNewConnection:(NSConnection *)newConn;

- (void)connectionBecameInvalid:(NSNotification *)notification;
      
@end

#endif // FSWATCHER_H
