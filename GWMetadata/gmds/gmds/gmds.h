/* gmsd.h
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

#ifndef GMDS_H
#define GMDS_H

#include <Foundation/Foundation.h>
#include "sqlite.h"

@protocol	GMDSClientProtocol

- (BOOL)queryResults:(NSData *)results;

- (oneway void)endOfQueryWithNumber:(NSNumber *)qnum;

@end


@protocol	GMDSProtocol

- (oneway void)registerClient:(id)remote;

- (oneway void)unregisterClient:(id)remote;

- (oneway void)performQuery:(NSDictionary *)queryInfo;

@end


@interface GMDS: NSObject <GMDSProtocol>
{
  NSString *dbdir;
  NSString *dbpath;
  sqlite3 *db;
  NSMutableArray *touchQueries;
  int touchind;

  NSConnection *conn;
  NSString *connectionName;
  NSMutableDictionary *clientInfo;

  NSFileManager *fm;
  NSNotificationCenter *nc; 
}

- (BOOL)connection:(NSConnection *)parentConnection
            shouldMakeNewConnection:(NSConnection *)newConnnection;

- (void)connectionDidDie:(NSNotification *)notification;
      
- (BOOL)performSubquery:(NSString *)query;

- (BOOL)performPreQueries:(NSArray *)queries;

- (void)performPostQueries:(NSArray *)queries;
          
- (BOOL)sendResults:(NSArray *)lines
           forQueryWithNumber:(NSNumber *)qnum;

- (void)endOfQueryWithNumber:(NSNumber *)qnum;
           
- (BOOL)opendb;

- (void)touchTables:(id)sender;

- (BOOL)isBaseServer;

- (void)terminate;

@end

#endif // GMDS_H













