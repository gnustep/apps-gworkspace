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

@class MDKQuery;
@class ProgrView;

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
  
  NSMutableCharacterSet *skipSet;  
  NSArray *queryWords;
  MDKQuery *currentQuery;
  BOOL validResults;
  
  NSMutableArray *foundObjects;
  
  NSFileManager *fm;  
}

+ (GMDSClient *)gmdsclient;

- (void)prepareQuery;

- (void)queryDidStartGathering:(MDKQuery *)query;

- (void)appendRawResults:(NSArray *)lines;

- (void)queryDidUpdateResults:(MDKQuery *)query;

- (void)queryDidEndGathering:(MDKQuery *)query;

- (IBAction)stopQuery:(id)sender;

- (void)doubleClickOnResultsView:(id)sender;

- (void)updateDefaults;

- (void)showInfo:(id)sender;

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
