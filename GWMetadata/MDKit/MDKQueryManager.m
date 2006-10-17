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

@protocol	GMDSClientProtocol

- (BOOL)queryResults:(NSData *)results;

- (oneway void)endOfQueryWithNumber:(NSData *)qnum;

@end


@protocol	GMDSProtocol

- (oneway void)registerClient:(id)remote;

- (oneway void)unregisterClient:(id)remote;

- (oneway void)performQuery:(NSData *)queryInfo;

@end


@implementation MDKQueryManager

static MDKQueryManager *queryManager = nil;

+ (id)allocWithZone:(NSZone *)zone
{
  [NSException raise: NSInvalidArgumentException
	            format: @"You may not allocate a query manager directly"];
  return nil;
}

+ (MDKQueryManager *)queryManager
{
  if (queryManager == nil) {
    queryManager = (MDKQueryManager *)NSAllocateObject(self, 0, NSDefaultMallocZone());
	  [queryManager init];
  }
    
  return queryManager;
}

- (void)dealloc
{  
  [NSException raise: NSInvalidArgumentException
	            format: @"Attempt to call dealloc for shared query manager"];
  GSNOSUPERDEALLOC;
}

- (id)init
{
  if (self != queryManager) {
    RELEASE (self);
    return RETAIN (queryManager);
  }
  
  queries = [NSMutableDictionary dictionary];
  
  tableNumber = 0L;
  queryNumber = 0L;
  gmds = nil;
  nc = [NSNotificationCenter defaultCenter];

  return self;
}

- (BOOL)startQuery:(MDKQuery *)query
{
  if ([query isRoot] == NO) {
    [NSException raise: NSInvalidArgumentException
	              format: @"\"%@\" is not the root query.", [query description]];
  }
  
  if ([[queries allValues] containsObject: query]) { 
    [NSException raise: NSInvalidArgumentException
	              format: @"\"%@\" is already started.", [query description]];
  }
  
  [self connectGMDs];
  
  if (gmds) {
    NSNumber *qnum = [self nextQueryNumber];
    NSDictionary *dict;
    
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
        NSLog(@"unable to build \"%@\"", [query description]); 
        return NO;
	    }
    NS_ENDHANDLER

    [query setQueryNumber: qnum];
    [queries setObject: query forKey: qnum];

  // waitResults ???????
  // queryStopped ???????

    dict = [query sqldescription];
    [gmds performQuery: [NSArchiver archivedDataWithRootObject: dict]];


  } else {
    [NSException raise: NSInternalInconsistencyException
	              format: @"The query manager is unable to contact the gmds daemon."];  
  }
  
  return YES;
}

- (BOOL)queryResults:(NSData *)results
{


  return NO;
}

- (oneway void)endOfQueryWithNumber:(NSData *)qnum
{

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
