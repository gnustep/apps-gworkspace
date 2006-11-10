/* MDKQueryManager.m
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

#include "MDKQueryManager.h"

static MDKQueryManager *queryManager = nil;


@protocol	GMDSClientProtocol

- (BOOL)queryResults:(NSData *)results;

- (oneway void)endOfQueryWithNumber:(NSNumber *)qnum;

@end


@protocol	GMDSProtocol

- (oneway void)registerClient:(id)remote;

- (oneway void)unregisterClient:(id)remote;

- (oneway void)performQuery:(NSDictionary *)queryInfo;

@end


@implementation MDKQueryManager

+ (MDKQueryManager *)queryManager
{
  if (queryManager == nil) {
    queryManager = [MDKQueryManager new];
  }
  return queryManager;
}

- (void)dealloc
{  
  RELEASE (queries);
  
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
    queries = [NSMutableArray new];
  
    tableNumber = 0L;
    queryNumber = 0L;
    gmds = nil;
    nc = [NSNotificationCenter defaultCenter];
  }
  
  return self;
}

- (BOOL)startQuery:(MDKQuery *)query
{
  if ([query isRoot] == NO) {
    [NSException raise: NSInvalidArgumentException
	              format: @"\"%@\" is not the root query.", [query description]];
  }
  
  if ([queries containsObject: query]) { 
    [NSException raise: NSInvalidArgumentException
	              format: @"\"%@\" is already started.", [query description]];
  }
  
  [self connectGMDs];
  
  if (gmds) {
    NSNumber *qnum = [self nextQueryNumber];
    unsigned count = [queries count];
    unsigned i;

    for (i = 0; i < count; i++) {
      MDKQuery *q = [queries objectAtIndex: i];
      
      if (([q isStarted] == NO) && [q isStopped]) {
        [queries removeObjectAtIndex: i];
        i--;
        count--;
      }
    }
    
    NS_DURING
	    {
        if ([query isClosed] == NO) {
          [query closeSubqueries];
        }
        if ([query isBuilt] == NO) {
          [query buildQuery];
        }
	    }
    NS_HANDLER
	    {
        NSLog(@"%@", localException); 
        return NO;
	    }
    NS_ENDHANDLER
        
    [query setQueryNumber: qnum];
    [queries insertObject: query atIndex: 0];
    
    if ([queries count] == 1) {
      [query setStarted];
      [gmds performQuery: [query sqlDescription]];
    }
      
  } else {
    [NSException raise: NSInternalInconsistencyException
	              format: @"The query manager is unable to contact the gmds daemon."];  
  }
  
  return YES;
}

- (BOOL)queryResults:(NSData *)results
{
  CREATE_AUTORELEASE_POOL(arp);
  NSDictionary *dict = [NSUnarchiver unarchiveObjectWithData: results];
  NSNumber *qnum = [dict objectForKey: @"qnumber"];
  MDKQuery *query = [self queryWithNumber: qnum];
  BOOL resok = NO;
  
  if (query && ([query isStopped] == NO)) {
    [query appendResults: [dict objectForKey: @"lines"]];
    resok = YES;
  }

  RELEASE (arp);

  return resok;
}

- (oneway void)endOfQueryWithNumber:(NSNumber *)qnum
{
  MDKQuery *query = [self queryWithNumber: qnum];
    
  if (query) {
    [query endQuery];
    [queries removeObject: query];
  }

  query = [self nextQuery];

  if (query && ([query isStarted] == NO)) {
    if ([query isStopped] == NO) {
      [query setStarted];
      [gmds performQuery: [query sqlDescription]];
    } else {
      [queries removeObject: query];
    }
  }
}

- (MDKQuery *)queryWithNumber:(NSNumber *)qnum
{
  unsigned i;

  for (i = 0; i < [queries count]; i++) {
    MDKQuery *query = [queries objectAtIndex: i];
    
    if ([[query queryNumber] isEqual: qnum]) {
      return query;
    }
  }

  return nil;
}

- (MDKQuery *)nextQuery
{
  unsigned count = [queries count];
  
  if (count) {
    return [queries objectAtIndex: count -1];
  }

  return nil;
}

- (unsigned long)nextTableNumber
{
  return tableNumber++;
}

- (NSNumber *)nextQueryNumber
{
  return [NSNumber numberWithUnsignedLong: queryNumber++];  
}

- (void)connectGMDs
{
  if (gmds == nil) {
    gmds = [NSConnection rootProxyForConnectionWithRegisteredName: @"gmds" 
                                                             host: @""];

    if (gmds == nil) {
	    NSString *cmd;
      int i;
    
      cmd = [[NSSearchPathForDirectoriesInDomains(
                GSToolsDirectory, NSSystemDomainMask, YES) objectAtIndex: 0]
                                      stringByAppendingPathComponent: @"gmds"];    
                    
      [NSTask launchedTaskWithLaunchPath: cmd arguments: nil];
   
      for (i = 0; i < 40; i++) {
	      [[NSRunLoop currentRunLoop] runUntilDate:
		                     [NSDate dateWithTimeIntervalSinceNow: 0.1]];

        gmds = [NSConnection rootProxyForConnectionWithRegisteredName: @"gmds" 
                                                                 host: @""];                  
        if (gmds) {
          break;
        }
      }
    }
    
    if (gmds) {
      RETAIN (gmds);
      [gmds setProtocolForProxy: @protocol(GMDSProtocol)];
    
	    [[NSNotificationCenter defaultCenter] addObserver: self
	                   selector: @selector(gmdsConnectionDidDie:)
		                     name: NSConnectionDidDieNotification
		                   object: [gmds connectionForProxy]];

      [gmds registerClient: self];                              
      NSLog(@"gmds connected!");     
                       
    } else {
      NSLog(@"unable to contact gmds.");  
    }
  }  
}

- (void)gmdsConnectionDidDie:(NSNotification *)notif
{
  [nc removeObserver: self
	                    name: NSConnectionDidDieNotification
	                  object: [notif object]];
  DESTROY (gmds);
  NSLog(@"gmds connection died!");  
  [[NSRunLoop currentRunLoop] runUntilDate:
		                    [NSDate dateWithTimeIntervalSinceNow: 1.0]];
  [self connectGMDs];
}

@end
