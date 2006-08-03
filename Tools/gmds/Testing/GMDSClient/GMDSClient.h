/* GMDSClient.h
 *  
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@dtedu.net>
 * Date: April 2006
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

#ifndef GMDS_CLIENT_H
#define GMDS_CLIENT_H

#include <Foundation/Foundation.h>

@class ProgrView;

@protocol	GMDSClientProtocol

- (BOOL)queryResults:(NSData *)results;

- (oneway void)endOfQuery;

@end


@protocol	GMDSProtocol

- (oneway void)registerClient:(id)remote;

- (oneway void)unregisterClient:(id)remote;

- (oneway void)performQuery:(NSData *)queryInfo;

@end


@interface GMDSClient: NSObject 
{
  IBOutlet id win;
  IBOutlet id progBox;   
  ProgrView *progView;
  IBOutlet id searchField;
  IBOutlet id imview;
  IBOutlet id stopButt;
  IBOutlet id foundField;
  IBOutlet id pathsScroll;

  NSTableView *resultsView;
  NSTableColumn *nameColumn;
  NSTableColumn *dateColumn;
  NSTableColumn *kindColumn;  
  
  NSArray *queryWords;
  NSMutableDictionary *currentQuery;
  unsigned long queryNumber;
  BOOL waitResults;
  BOOL pendingQuery;
  BOOL queryStopped;
  
  NSMutableCharacterSet *skipSet;
  NSMutableArray *foundObjects;
  
  NSFileManager *fm;  
  NSNotificationCenter *nc; 
  
  id gmds;
}

+ (GMDSClient *)gmdsclient;

- (void)connectGMDs;

- (void)connectionDidDie:(NSNotification *)notif;

- (void)doubleClickOnResultsView:(id)sender;

- (void)updateDefaults;

- (void)showInfo:(id)sender;

@end


@interface GMDSClient (queries) <GMDSClientProtocol>

- (void)prepareQuery;

- (BOOL)queryResults:(NSData *)results;

- (void)endOfQuery;

- (IBAction)stopQuery:(id)sender;

- (NSNumber *)nextQueryNumber;

@end


@interface GMDSClient (text_contents_queries)

- (NSString *)tcCreateTempTable:(int)table;

- (NSString *)tcTriggerForTable:(int)table;

- (NSString *)tcDropTempTable:(int)table;
                                                                  
- (NSString *)tcInsertIntoTempTable:(int)table
                     resultsForWord:(NSString *)word
                      caseSensitive:(BOOL)csens
                      rightWildcard:(BOOL)rwild
                       leftWildcard:(BOOL)lwild
                         searchPath:(NSString *)path;

- (NSString *)tcGetResults:(int)wcount;

@end


@interface ProgrView : NSView 
{
  NSMutableArray *images;
  int index;
  float rfsh;
  NSTimer *progTimer;
  BOOL animating;
}

- (id)initWithFrame:(NSRect)frameRect 
    refreshInterval:(float)refresh;

- (void)start;

- (void)stop;

- (void)animate:(id)sender;

@end

#endif // GMDS_CLIENT_H
