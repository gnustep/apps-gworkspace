/* SearchResults.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
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

#ifndef SEARCH_RESULTS_H
#define SEARCH_RESULTS_H

#include <Foundation/Foundation.h>
#include "FSNodeRep.h"

@class Finder;
@class NSWindow;
@class ResultsTableView;
@class NSTableColumn;
@class ResultsPathsView;
@class NSImage;
@class ProgressView;

@protocol SearchResultsProtocol

- (void)registerEngine:(id)anObject;
                            
- (oneway void)nextResult:(NSString *)path;

- (oneway void)endOfSearch;

@end


@protocol SearchEngineProtocol

- (void)setInterface:(NSArray *)ports;

- (oneway void)searchWithInfo:(NSData *)srcinfo;

- (void)stop;

- (oneway void)exitThread;

@end


@interface SearchResults : NSObject 
{
  IBOutlet id win;
  
  IBOutlet id topBox;
  IBOutlet id progBox; 
  ProgressView *progView;
  IBOutlet id elementsLabel;
  IBOutlet id stopButt;
  IBOutlet id restartButt;
  
  IBOutlet id splitView;
  
  IBOutlet id resultsScroll;
  ResultsTableView *resultsView;
  NSTableColumn *nameColumn;
  NSTableColumn *parentColumn;
  NSTableColumn *dateColumn;
  NSTableColumn *sizeColumn;
  NSTableColumn *kindColumn;  
  
  IBOutlet id pathsScroll;
  ResultsPathsView *pathsView;

  NSMutableArray *foundObjects;
  NSArray *sortedObjects;
  FSNInfoType currentOrder;
  
  Finder *finder;
  
  NSArray *searchPaths;
  NSDictionary *searchCriteria;
  NSConnection *engineConn;
  id <SearchEngineProtocol> engine;
  BOOL searchdone;
  
  NSFileManager *fm;
  id ws;
  NSNotificationCenter *nc;
}

- (void)activateForSelection:(NSArray *)selection
          withSearchCriteria:(NSDictionary *)criteria;

- (void)connectionDidDie:(NSNotification *)notification;

- (void)threadWillExit:(NSNotification *)notification;

- (void)registerEngine:(id)anObject;

- (void)nextResult:(NSString *)path;

- (void)endOfSearch;

- (IBAction)stopSearch:(id)sender;

- (IBAction)restartSearch:(id)sender;

- (void)updateShownData;

- (void)setCurrentOrder:(FSNInfoType)order;

- (NSArray *)selectedObjects;

- (void)doubleClickOnResultsView:(id)sender;

- (void)selectObjects:(NSArray *)objects;

- (void)fileSystemDidChange:(NSNotification *)notif;

- (void)setColumnsSizes;

- (void)saveColumnsSizes;

- (NSWindow *)win;

// ResultsTableView delegate
- (NSImage *)tableView:(NSTableView *)tableView 
      dragImageForRows:(NSArray *)dragRows;

@end


@interface SearchEngine : NSObject 
{
  NSConnection *interfaceConn;
  id <SearchResultsProtocol> interface;
  BOOL stopped;
  NSFileManager *fm;
}

+ (void)engineThreadWithPorts:(NSArray *)ports;

- (void)setInterface:(NSArray *)ports;

- (void)searchWithInfo:(NSData *)srcinfo;

- (void)stop;

- (void)done;

- (oneway void)exitThread;

@end


@interface ProgressView : NSView 
{
  NSImage *image;
  float orx;
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


#endif // SEARCH_RESULTS_H
