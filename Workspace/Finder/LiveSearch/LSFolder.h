/* LSFolder.h
 *  
 * Copyright (C) 2004-2013 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: October 2004
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

#ifndef LS_FOLDER_H
#define LS_FOLDER_H

#import <Foundation/Foundation.h>
#import "FSNodeRep.h"

@class NSWindow;
@class NSView;
@class NSPopUpButton;
@class NSButton;
@class ResultsTableView;
@class NSTableColumn;
@class FSNPathComponentsViewer;
@class NSImage;
@class ProgrView;

@protocol LSFUpdaterProtocol

+ (void)newUpdater:(NSDictionary *)info;

- (oneway void)setFolderInfo:(NSData *)data;

- (oneway void)updateSearchCriteria:(NSData *)data;

- (oneway void)ddbdInsertTrees;

- (oneway void)setAutoupdate:(unsigned)value;

- (oneway void)fastUpdate;

- (oneway void)terminate;

@end


@interface LSFolder : NSObject 
{
  FSNode *node;

  NSMutableDictionary *lsfinfo;
  
  id finder;
  id gworkspace;
  id editor;
  
  BOOL watcherSuspended;

  NSConnection *conn;
  NSConnection *updaterconn;
  id <LSFUpdaterProtocol> updater;
  BOOL waitingUpdater;
  SEL nextSelector;
  BOOL actionPending;
  BOOL updaterbusy;
  unsigned autoupdate;
  
  NSFileManager *fm;
  NSNotificationCenter *nc;
  
  IBOutlet NSWindow *win;
  BOOL forceclose;

  IBOutlet NSBox *topBox;
  IBOutlet NSBox *progBox; 
  ProgrView *progView;
  IBOutlet NSTextField *elementsLabel;
  NSString *elementsStr;
  IBOutlet NSButton *editButt;
  IBOutlet NSPopUpButton *autoupdatePopUp;
  IBOutlet NSButton *updateButt;
    
  IBOutlet NSScrollView *resultsScroll;
  ResultsTableView *resultsView;
  NSTableColumn *nameColumn;
  NSTableColumn *parentColumn;
  NSTableColumn *dateColumn;
  NSTableColumn *sizeColumn;
  NSTableColumn *kindColumn;  
    
  IBOutlet NSBox *pathBox;     
  FSNPathComponentsViewer *pathViewer;
  int visibleRows;

  NSMutableArray *foundObjects;
  FSNInfoType currentOrder;
}

- (id)initForFinder:(id)fndr
           withNode:(FSNode *)anode
      needsIndexing:(BOOL)index;

- (void)setNode:(FSNode *)anode;

- (FSNode *)node;

- (NSString *)infoPath;

- (NSString *)foundPath;

- (BOOL)watcherSuspended;

- (void)setWatcherSuspended:(BOOL)value;

- (BOOL)isOpen;

- (IBAction)setAutoupdateCycle:(id)sender;

- (IBAction)updateIfNeeded:(id)sender;

- (void)startUpdater;
          
- (void)checkUpdater:(id)sender;

- (void)setUpdater:(id)anObject;

- (void)updaterDidEndAction;

- (void)updaterError:(NSString *)err;

- (void)addFoundPath:(NSString *)path;

- (void)removeFoundPath:(NSString *)path;

- (void)clearFoundPaths;

- (void)endUpdate;

- (void)connectionDidDie:(NSNotification *)notification;

- (void)loadInterface;

- (void)closeWindow;

- (NSDictionary *)getSizes;

- (void)saveSizes;

- (void)updateShownData;

- (void)setCurrentOrder:(FSNInfoType)order;

- (NSArray *)selectedObjects;

- (void)selectObjects:(NSArray *)objects;

- (void)doubleClickOnResultsView:(id)sender;

- (IBAction)openEditor:(id)sender;

- (NSArray *)searchPaths;

- (NSDictionary *)searchCriteria;

- (BOOL)recursive;

- (void)setSearchCriteria:(NSDictionary *)criteria 
                recursive:(BOOL)rec;

- (void)fileSystemDidChange:(NSNotification *)notif;

@end


@interface ProgrView : NSView 
{
  NSMutableArray *images;
  unsigned index;
  NSTimeInterval rfsh;
  NSTimer *progTimer;
  BOOL animating;
}

- (id)initWithFrame:(NSRect)frameRect 
    refreshInterval:(NSTimeInterval)refresh;

- (void)start;

- (void)stop;

- (void)animate:(id)sender;

@end

#endif // LS_FOLDER_H
