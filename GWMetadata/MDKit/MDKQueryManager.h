/* MDKQueryManager.h
 *  
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@dtedu.net>
 * Date: October 2006
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

#ifndef MDK_QUERY_MANAGER_H
#define MDK_QUERY_MANAGER_H

#include <Foundation/Foundation.h>
#include "MDKQuery.h"

@class FSNode;

@interface MDKQueryManager : NSObject
{  
  NSMutableArray *queries;
  NSMutableArray *liveQueries;
  unsigned long tableNumber;
  unsigned long queryNumber;
  id gmds;

  NSNotificationCenter *nc; 
  NSNotificationCenter *dnc;
}

+ (MDKQueryManager *)queryManager;

- (BOOL)startQuery:(MDKQuery *)query;

- (BOOL)queryResults:(NSData *)results;

- (oneway void)endOfQueryWithNumber:(NSNumber *)qnum;

- (MDKQuery *)queryWithNumber:(NSNumber *)qnum;

- (MDKQuery *)nextQuery;

- (unsigned long)tableNumber;

- (unsigned long)queryNumber;

- (void)connectGMDs;

- (void)gmdsConnectionDidDie:(NSNotification *)notif;

@end


@interface MDKQueryManager (updates)

- (void)startUpdateForQuery:(MDKQuery *)query;

- (void)metadataDidUpdate:(NSNotification *)notif;

@end


@interface MDKQueryManager (results_filtering)

- (NSString *)categoryNameForNode:(FSNode *)node;

- (BOOL)filterNode:(FSNode *)node
     withFSFilters:(NSArray *)filters;

@end

#endif // MDK_QUERY_MANAGER_H
