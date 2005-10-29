/* SearchResults.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
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

#ifndef SEARCH_RESULTS_H
#define SEARCH_RESULTS_H

#include <Foundation/Foundation.h>
#include "FSNodeRep.h"

@class Finder;
@class NSWindow;
@class NSView;
@class ResultsTableView;
@class NSTableColumn;
@class FSNPathComponentsViewer;
@class NSImage;
@class ProgressView;
@class DocumentIcon;


@protocol SearchToolProtocol

- (oneway void)searchWithInfo:(NSData *)srcinfo;

- (void)stop;

- (oneway void)terminate;

@end


@interface SearchResults : NSObject 
{
  IBOutlet id win;
  
  IBOutlet id topBox;
  IBOutlet id progBox; 
  ProgressView *progView;
  IBOutlet id elementsLabel;
  NSString *elementsStr;
  IBOutlet id stopButt;
  IBOutlet id restartButt;
  IBOutlet id dragIconBox;
  DocumentIcon *documentIcon;
    
  IBOutlet id resultsScroll;
  ResultsTableView *resultsView;
  NSTableColumn *nameColumn;
  NSTableColumn *parentColumn;
  NSTableColumn *dateColumn;
  NSTableColumn *sizeColumn;
  NSTableColumn *kindColumn;  
  
  IBOutlet id pathBox;   
  FSNPathComponentsViewer *pathViewer;
  
  int visibleRows;
  
  NSMutableArray *foundObjects;
  FSNInfoType currentOrder;
  
  Finder *finder;
  
  NSArray *searchPaths;
  NSDictionary *searchCriteria;
  BOOL recursive;
  NSConnection *conn;
  NSConnection *toolConn;
  id <SearchToolProtocol> searchtool;
  BOOL searching;
    
  NSFileManager *fm;
  id ws;
  NSNotificationCenter *nc;
}

- (void)activateForSelection:(NSArray *)selection
          withSearchCriteria:(NSDictionary *)criteria
                   recursive:(BOOL)rec;

- (void)connectionDidDie:(NSNotification *)notification;

- (void)checkSearchTool:(id)sender;

- (void)registerSearchTool:(id)tool;

- (void)nextResult:(NSString *)path;

- (void)endOfSearch;

- (BOOL)searching;

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

- (unsigned long)memAddress;

- (void)createLiveSearchFolderAtPath:(NSString *)path;

// ResultsTableView delegate
- (NSImage *)tableView:(NSTableView *)tableView 
      dragImageForRows:(NSArray *)dragRows;

@end


@interface ProgressView : NSView 
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


@interface DocumentIcon : NSView 
{
  NSImage *icon;
  id searchResult;
}

- (id)initWithFrame:(NSRect)frameRect 
       searchResult:(id)sres;

- (void)startExternalDragOnEvent:(NSEvent *)event;

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag;

- (BOOL)ignoreModifierKeysWhileDragging;

@end

#endif // SEARCH_RESULTS_H
