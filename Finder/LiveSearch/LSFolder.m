/* LSFolder.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: October 2004
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <math.h>
#include "LSFolder.h"
#include "LSFUpdater.h"
#include "ResultsTableView.h"
#include "ResultsTextCell.h"
#include "ResultsPathsView.h"
#include "Finder.h"
#include "FinderModulesProtocol.h"
#include "Functions.h"
#include "config.h"

#define CELLS_HEIGHT (28.0)

#define LSF_INFO(x) [x stringByAppendingPathComponent: @"lsf.info"]
#define LSF_FOUND(x) [x stringByAppendingPathComponent: @"lsf.found"]
#define LSF_GEOM(x) [x stringByAppendingPathComponent: @"lsf.geometry"]

static NSString *nibName = @"LSFolder";

BOOL isPathInResults(NSString *path, NSArray *results);


@implementation LSFolder

- (void)dealloc
{
  [[NSDistributedNotificationCenter defaultCenter] removeObserver: self];
	[nc removeObserver: self];

  if (updater) {
    [updater exitThread];
    DESTROY (updater);
    DESTROY (updaterconn);
  }
    
  if (watcherSuspended == NO) {
    [finder removeWatcherForPath: [node path]];
  }
  
  TEST_RELEASE (node);
  TEST_RELEASE (lsfinfo);

  TEST_RELEASE (win);
  
  TEST_RELEASE (foundObjects);
  TEST_RELEASE (sortedObjects);
         
  [super dealloc];
}

- (id)initForNode:(FSNode *)anode
    needsIndexing:(BOOL)index
{
	self = [super init];

  if (self) {
    NSDictionary *dict = nil;

    updater = nil;
    actionPending = NO;
    updaterbusy = NO;
    autoupdate = NO;
    
    win = nil;
    
    fm = [NSFileManager defaultManager];
    
    if ([anode isValid] && [anode isDirectory]) {
      NSString *dpath = LSF_INFO([anode path]);
      
      if ([fm fileExistsAtPath: dpath]) {
        dict = [NSDictionary dictionaryWithContentsOfFile: dpath];
      }
    }
    
    if (dict) {
      id entry = [dict objectForKey: @"autoupdate"];
      
      if (entry) {
        autoupdate = [entry boolValue];
      }
      
      ASSIGN (node, anode);
      ASSIGN (lsfinfo, dict);
      
      finder = [Finder finder];
      [finder addWatcherForPath: [node path]];
      watcherSuspended = NO;
      nc = [NSNotificationCenter defaultCenter];

      if (index || autoupdate) {
        if (index) {
          nextSelector = @selector(ddbdInsertTrees);
          actionPending = YES;   
        } 
        [self startUpdater];
      }

    } else {
      DESTROY (self);
    }    
  }
  
	return self;
}

- (void)setNode:(FSNode *)anode
{
  if (watcherSuspended == NO) {
    [finder removeWatcherForPath: [node path]];
  }
  ASSIGN (node, anode);
  [finder addWatcherForPath: [node path]];
  
  if (win) {
    [win setTitle: [node name]];
  }
}

- (FSNode *)node
{
  return node;
}

- (NSString *)infoPath
{
  return LSF_INFO([node path]);
}

- (NSString *)foundPath
{
  return LSF_FOUND([node path]);
}

- (BOOL)watcherSuspended
{
  return watcherSuspended;
}

- (void)setWatcherSuspended:(BOOL)value
{
  watcherSuspended = value;
}

- (BOOL)isOpen
{
  return (win && ([win isVisible]));
}

- (IBAction)setAutoupdate:(id)sender
{
  autoupdate = ([sender state] == NSOnState);
  [updater setAutoupdate: autoupdate];
}

- (IBAction)updateIfNeeded:(id)sender
{
  BOOL needupdate;
  
  if (sender == nil) {  
    if (win) {
      needupdate = NO;
    } else {
      [self loadInterface];
      needupdate = YES;
    }
    [win makeKeyAndOrderFront: nil];
  } else {  
    needupdate = YES;
  }

  if (needupdate && (actionPending == NO)) {
    if ((updater == nil) || updaterbusy) {
      nextSelector = @selector(fastUpdate);
      actionPending = YES; 
      if (updater == nil) {  
        [self startUpdater];
      }
      return;
    }

 //   [foundObjects removeAllObjects];
 //   ASSIGN (sortedObjects, [NSArray array]);
    [resultsView noteNumberOfRowsChanged];
    [updateButt setEnabled: NO];
    [progView start];
    [updater fastUpdate];
  }
}

- (void)startUpdater
{
  NSMutableDictionary *info = [NSMutableDictionary dictionary];
  NSPort *port[2];
  NSArray *ports;

  port[0] = (NSPort *)[NSPort port];
  port[1] = (NSPort *)[NSPort port];

  ports = [NSArray arrayWithObjects: port[1], port[0], nil];

  updaterconn = [[NSConnection alloc] initWithReceivePort: port[0]
				                                         sendPort: port[1]];
  [updaterconn setRootObject: self];
  [updaterconn setDelegate: self];

  [nc addObserver: self
         selector: @selector(connectionDidDie:)
             name: NSConnectionDidDieNotification
           object: updaterconn];    

  [info setObject: ports forKey: @"ports"];
  [info setObject: lsfinfo forKey: @"lsfinfo"];
  
  [nc addObserver: self
         selector: @selector(threadWillExit:)
             name: NSThreadWillExitNotification
           object: nil];     
  
  NS_DURING
    {
      [NSThread detachNewThreadSelector: @selector(newUpdater:)
		                           toTarget: [LSFUpdater class]
		                         withObject: info];
    }
  NS_HANDLER
    {
      NSRunAlertPanel(nil, 
                      NSLocalizedString(@"A fatal error occured while detaching the thread!", @""), 
                      NSLocalizedString(@"Continue", @""), 
                      nil, 
                      nil);
      [self endUpdate];
    }
  NS_ENDHANDLER
}

- (void)setUpdater:(id)anObject
{
  [anObject setProtocolForProxy: @protocol(LSFUpdaterProtocol)];
  updater = (id <LSFUpdaterProtocol>)[anObject retain];
  
  NSLog(@"updater registered");
  
  [updater setAutoupdate: autoupdate];

  if (actionPending) {
    actionPending = NO;
    updaterbusy = YES;
    if (nextSelector == @selector(fastUpdate)) {
      [updateButt setEnabled: NO];
      [progView start];
    }
    [(id)updater performSelector: nextSelector];
  }
}

- (void)updaterDidEndAction
{
  updaterbusy = NO;
  [progView stop];
  [updateButt setEnabled: YES];  
  
  if (actionPending) {
    actionPending = NO;
    updaterbusy = YES;
    
    if (nextSelector == @selector(fastUpdate)) {
  //    [foundObjects removeAllObjects];
  //    ASSIGN (sortedObjects, [NSArray array]);
      [resultsView noteNumberOfRowsChanged];
      [updateButt setEnabled: NO];
      [progView start];
    }
    
    [(id)updater performSelector: nextSelector];
  }
  
  if ([self isOpen]) {
    [self updateShownData];
  }
}

- (void)updaterError:(NSString *)err
{
  NSRunAlertPanel(nil, err, NSLocalizedString(@"Continue", @""), nil, nil);
  [self endUpdate];
}

- (void)addFoundPath:(NSString *)path
{
  FSNode *nd = [FSNode nodeWithPath: path];
  
  if ([foundObjects containsObject: nd] == NO) {
    NSString *elmstr = NSLocalizedString(@"elements", @"");
  
    [foundObjects addObject: nd];
    elmstr = [NSString stringWithFormat: @"%i %@", [foundObjects count], elmstr];
    [elementsLabel setStringValue: elmstr];
    [resultsView noteNumberOfRowsChanged];
  } 
}

- (void)removeFoundPath:(NSString *)path
{
  FSNode *nd = [FSNode nodeWithPath: path];
  NSString *elmstr = NSLocalizedString(@"elements", @"");
    
  [foundObjects removeObject: nd];
  elmstr = [NSString stringWithFormat: @"%i %@", [foundObjects count], elmstr];
  [elementsLabel setStringValue: elmstr];
  [resultsView noteNumberOfRowsChanged];
}

- (void)endUpdate
{
  if (updater) {
    [nc removeObserver: self
	                name: NSConnectionDidDieNotification 
                object: updaterconn];
    [updater exitThread];
    DESTROY (updater);
    DESTROY (updaterconn);
    
    [nc removeObserver: self
	                name: NSThreadWillExitNotification 
                object: nil];
  }

  actionPending = NO;
  updaterbusy = NO;
}
         
- (BOOL)connection:(NSConnection*)ancestor 
								shouldMakeNewConnection:(NSConnection*)newConn
{
	if (ancestor == updaterconn) {
  	[newConn setDelegate: self];
  	[nc addObserver: self 
					 selector: @selector(connectionDidDie:)
	    				 name: NSConnectionDidDieNotification 
             object: newConn];
  	return YES;
	}
		
  return NO;
}

- (void)connectionDidDie:(NSNotification *)notification
{
  [nc removeObserver: self
	              name: NSConnectionDidDieNotification 
              object: [notification object]];

  NSRunAlertPanel(nil, 
                  NSLocalizedString(@"updater connection died!", @""), 
                  NSLocalizedString(@"Continue", @""), 
                  nil, 
                  nil);
  [self endUpdate];
}

- (void)threadWillExit:(NSNotification *)notification
{
  NSLog(@"lsf update thread will exit");
}

- (void)loadInterface
{
  if ([NSBundle loadNibNamed: nibName owner: self]) {
    NSDictionary *sizesDict = [self getSizes];
    id entry;
    NSRect r;
    int srh;
    
    if (sizesDict) {
      entry = [sizesDict objectForKey: @"win_frame"];
      
      if (entry) {
        [win setFrameFromString: entry];
      }
    }
    
    [win setTitle: [node name]];
    
    [win setDelegate: self];

    progView = [[ProgrView alloc] initWithFrame: NSMakeRect(0, 0, 16, 16)
                                refreshInterval: 0.05];
    [(NSBox *)progBox setContentView: progView]; 
    RELEASE (progView);

    [elementsLabel setStringValue: @""];

    [autoupdateSwch setState: (autoupdate ? NSOnState: NSOffState)];

    [splitView setDelegate: self];

    [resultsScroll setBorderType: NSBezelBorder];
    [resultsScroll setHasHorizontalScroller: YES];
    [resultsScroll setHasVerticalScroller: YES]; 
    
    r = [[resultsScroll contentView] frame];

    resultsView = [[ResultsTableView alloc] initWithFrame: r];
    [resultsView setDrawsGrid: NO];
    [resultsView setAllowsColumnSelection: NO];
    [resultsView setAllowsColumnReordering: YES];
    [resultsView setAllowsColumnResizing: YES];
    [resultsView setAllowsEmptySelection: YES];
    [resultsView setAllowsMultipleSelection: YES];
    [resultsView setRowHeight: CELLS_HEIGHT];
    [resultsView setIntercellSpacing: NSZeroSize];
    [resultsView sizeLastColumnToFit];

    nameColumn = [[NSTableColumn alloc] initWithIdentifier: @"name"];
    [nameColumn setDataCell: AUTORELEASE ([[ResultsTextCell alloc] init])];
    [nameColumn setEditable: NO];
    [nameColumn setResizable: YES];
    [[nameColumn headerCell] setStringValue: NSLocalizedString(@"Name", @"")];
    [[nameColumn headerCell] setAlignment: NSLeftTextAlignment];
    [nameColumn setMinWidth: 80];
    [nameColumn setWidth: 140];
    [resultsView addTableColumn: nameColumn];
    RELEASE (nameColumn);
    
    parentColumn = [[NSTableColumn alloc] initWithIdentifier: @"parent"];
    [parentColumn setDataCell: AUTORELEASE ([[ResultsTextCell alloc] init])];
    [parentColumn setEditable: NO];
    [parentColumn setResizable: YES];
    [[parentColumn headerCell] setStringValue: NSLocalizedString(@"Parent", @"")];
    [[parentColumn headerCell] setAlignment: NSLeftTextAlignment];
    [parentColumn setMinWidth: 80];
    [parentColumn setWidth: 90];
    [resultsView addTableColumn: parentColumn];
    RELEASE (parentColumn);

    dateColumn = [[NSTableColumn alloc] initWithIdentifier: @"date"];
    [dateColumn setDataCell: AUTORELEASE ([[ResultsTextCell alloc] init])];
    [dateColumn setEditable: NO];
    [dateColumn setResizable: YES];
    [[dateColumn headerCell] setStringValue: NSLocalizedString(@"Date Modified", @"")];
    [[dateColumn headerCell] setAlignment: NSLeftTextAlignment];
    [dateColumn setMinWidth: 80];
    [dateColumn setWidth: 90];
    [resultsView addTableColumn: dateColumn];
    RELEASE (dateColumn);

    sizeColumn = [[NSTableColumn alloc] initWithIdentifier: @"size"];
    [sizeColumn setDataCell: AUTORELEASE ([[ResultsTextCell alloc] init])];
    [sizeColumn setEditable: NO];
    [sizeColumn setResizable: YES];
    [[sizeColumn headerCell] setStringValue: NSLocalizedString(@"Size", @"")];
    [[sizeColumn headerCell] setAlignment: NSLeftTextAlignment];
    [sizeColumn setMinWidth: 50];
    [sizeColumn setWidth: 50];
    [resultsView addTableColumn: sizeColumn];
    RELEASE (sizeColumn);

    kindColumn = [[NSTableColumn alloc] initWithIdentifier: @"kind"];
    [kindColumn setDataCell: AUTORELEASE ([[ResultsTextCell alloc] init])];
    [kindColumn setEditable: NO];
    [kindColumn setResizable: YES];
    [[kindColumn headerCell] setStringValue: NSLocalizedString(@"Kind", @"")];
    [[kindColumn headerCell] setAlignment: NSLeftTextAlignment];
    [kindColumn setMinWidth: 80];
    [kindColumn setWidth: 80];
    [resultsView addTableColumn: kindColumn];
    RELEASE (kindColumn);

    [resultsScroll setDocumentView: resultsView];
    RELEASE (resultsView);
    
    if (sizesDict) {
      entry = [sizesDict objectForKey: @"columns_sizes"];
    
      if (entry) {
        NSArray *columns = [resultsView tableColumns];
        NSMutableArray *sortedCols = [NSMutableArray array];
        NSArray *keys = [entry keysSortedByValueUsingSelector: @selector(compareColInfo:)];
        int i;
    
        for (i = 0; i < [keys count]; i++) {
          NSString *identifier = [keys objectAtIndex: i];
          int col = [resultsView columnWithIdentifier: identifier];
          NSTableColumn *column = [columns objectAtIndex: col];
          NSDictionary *cdict = [entry objectForKey: identifier];
          float width = [[cdict objectForKey: @"width"] floatValue];

          [column setWidth: width];
          [sortedCols insertObject: column atIndex: [sortedCols count]];
        }

        for (i = 0; i < [sortedCols count]; i++) {
          [resultsView removeTableColumn: [sortedCols objectAtIndex: i]];
        }            

        for (i = 0; i < [sortedCols count]; i++) {
          [resultsView addTableColumn: [sortedCols objectAtIndex: i]];
        }    
      }
    }    
        
    [resultsView setDataSource: self]; 
    [resultsView setDelegate: self];
    [resultsView setTarget: self];
    [resultsView setDoubleAction: @selector(doubleClickOnResultsView:)];

    foundObjects = [NSMutableArray new];
    sortedObjects = [NSArray new];

    if (sizesDict) {
      entry = [sizesDict objectForKey: @"sorting_order"];
      
      if (entry) {
        [self setCurrentOrder: [entry intValue]];
      } else {
        [self setCurrentOrder: FSNInfoNameType];
      }
    } else {
      [self setCurrentOrder: FSNInfoNameType];
    }
    
    r = [pathsScroll frame];
    srh = 0;
    
    if (sizesDict) {
      entry = [sizesDict objectForKey: @"paths_scr_h"];
  
      if (entry) {
        srh = [entry intValue];
      }
    }
    
    if (srh == 0) {
      srh = [finder searchResultsHeight];
    }

    if (srh != 0) {
      r.size.height = srh;
      [pathsScroll setFrame: r];
    } 

    [pathsScroll setBorderType: NSBezelBorder];
    [pathsScroll setHasHorizontalScroller: NO];
    [pathsScroll setHasVerticalScroller: YES]; 

    r = [[pathsScroll contentView] frame];
    pathsView = [[ResultsPathsView alloc] initWithFrame: r];
    [pathsScroll setDocumentView: pathsView];
    RELEASE (pathsView);

    [[NSDistributedNotificationCenter defaultCenter] addObserver: self
                        selector: @selector(fileSystemDidChange:) 
                					  name: @"GWFileSystemDidChangeNotification"
                					object: nil];    

  } else {
    NSLog(@"failed to load %@!", nibName);
  }
}

- (NSDictionary *)getSizes
{
  NSString *dictPath = LSF_GEOM([node path]);

  if ([fm fileExistsAtPath: dictPath]) {
    return [NSDictionary dictionaryWithContentsOfFile: dictPath];
  }
  
  return nil;
}

- (void)saveSizes
{
  NSMutableDictionary *sizesDict = [NSMutableDictionary dictionary];
  NSMutableDictionary *columnsDict = [NSMutableDictionary dictionary];
  NSArray *columns = [resultsView tableColumns];
  int i;  

  [sizesDict setObject: [win stringWithSavedFrame] 
                forKey: @"win_frame"];

  [sizesDict setObject: [NSNumber numberWithInt: ceil(NSHeight([pathsScroll frame]))] 
                forKey: @"paths_scr_h"];

  [sizesDict setObject: [NSNumber numberWithInt: currentOrder] 
                forKey: @"sorting_order"];

  for (i = 0; i < [columns count]; i++) {
    NSTableColumn *column = [columns objectAtIndex: i];
    NSString *identifier = [column identifier];
    NSNumber *cwidth = [NSNumber numberWithFloat: [column width]];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    [dict setObject: [NSNumber numberWithInt: i] forKey: @"position"];
    [dict setObject: cwidth forKey: @"width"];
    
    [columnsDict setObject: dict forKey: identifier];
  }

  [sizesDict setObject: columnsDict forKey: @"columns_sizes"];

  [sizesDict writeToFile: LSF_GEOM([node path]) atomically: YES];
}

- (void)updateShownData
{
  SEL sortingSel;
  NSTableColumn *column;

  switch(currentOrder) {
    case FSNInfoNameType:
      sortingSel = @selector(compareAccordingToName:);
      column = nameColumn;
      break;
    case FSNInfoParentType:
      sortingSel = @selector(compareAccordingToParent:);
      column = parentColumn;
      break;
    case FSNInfoKindType:
      sortingSel = @selector(compareAccordingToKind:);
      column = kindColumn;
      break;
    case FSNInfoDateType:
      sortingSel = @selector(compareAccordingToDate:);
      column = dateColumn;
      break;
    case FSNInfoSizeType:
      sortingSel = @selector(compareAccordingToSize:);
      column = sizeColumn;
      break;
    default:
      sortingSel = @selector(compareAccordingToName:);
      column = nameColumn;
      break;
  }

  ASSIGN (sortedObjects, [foundObjects sortedArrayUsingSelector: sortingSel]);
  [resultsView setHighlightedTableColumn: column];
  [resultsView reloadData];
}

- (void)setCurrentOrder:(FSNInfoType)order
{
  currentOrder = order;
}

- (NSArray *)selectedObjects
{
  NSArray *nodes = updaterbusy ? foundObjects : sortedObjects;
  NSMutableArray *selected = [NSMutableArray array];
  NSEnumerator *enumerator = [resultsView selectedRowEnumerator];
  NSNumber *row;
  
  while ((row = [enumerator nextObject])) {
	  FSNode *nd = [nodes objectAtIndex: [row intValue]];
    if ([nd isValid]) {
      [selected addObject: nd];
    } else {
      [foundObjects removeObject: nd];
      [resultsView noteNumberOfRowsChanged];
    }
  }

  return selected;  
}

- (void)doubleClickOnResultsView:(id)sender
{
  [finder openFoundSelection: [self selectedObjects]];
}

- (void)fileSystemDidChange:(NSNotification *)notif
{
  NSDictionary *info = [notif userInfo];
  NSString *operation = [info objectForKey: @"operation"];
  NSString *source = [info objectForKey: @"source"];
  NSString *destination = [info objectForKey: @"destination"];
  NSArray *files = [info objectForKey: @"files"];
  NSMutableArray *deletedObjects = [NSMutableArray array];
  int i, j;

  if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
    files = [NSArray arrayWithObject: [destination lastPathComponent]];
    destination = [destination stringByDeletingLastPathComponent]; 
  }

  if ([operation isEqual: @"NSWorkspaceRecycleOperation"]) {
		files = [info objectForKey: @"origfiles"];
  }	
  
  if ([operation isEqual: @"NSWorkspaceMoveOperation"] 
        || [operation isEqual: @"NSWorkspaceDestroyOperation"]
				|| [operation isEqual: @"NSWorkspaceRecycleOperation"]
				|| [operation isEqual: @"GWorkspaceRecycleOutOperation"]
				|| [operation isEqual: @"GWorkspaceEmptyRecyclerOperation"]) {
    for (i = 0; i < [files count]; i++) {
      NSString *fname = [files objectAtIndex: i];
      NSString *fullPath = [source stringByAppendingPathComponent: fname];
      
      for (j = 0; j < [foundObjects count]; j++) {
        FSNode *nd = [foundObjects objectAtIndex: j];
        NSString *path = [nd path];
      
        if ([fullPath isEqual: path]) {
          [deletedObjects addObject: nd];
        }
      }
    }
    
  } else if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
    for (i = 0; i < [foundObjects count]; i++) {
      FSNode *nd = [foundObjects objectAtIndex: i];
      NSString *path = [nd path];

      if ([source isEqual: path]) {
        [deletedObjects addObject: nd];
      }
    }
  }
  
  if ([deletedObjects count]) {
    for (i = 0; i < [deletedObjects count]; i++) {
      [foundObjects removeObject: [deletedObjects objectAtIndex: i]];
    }
    
    [resultsView deselectAll: self];
    [self updateShownData];
    [resultsView reloadData];
  }
}


//
// NSWindow delegate
//
- (void)windowWillClose:(NSNotification *)aNotification
{
  [self saveSizes];
}


//
// NSSplitView delegate methods
//
#define MIN_PATHS_H 30
#define MIN_RESULTS_H 30

- (void)splitView:(NSSplitView *)sender 
                  resizeSubviewsWithOldSize:(NSSize)oldSize
{
  NSRect spBounds = [splitView bounds];
  float dvt = [splitView dividerThickness];
  float ptsHeight = NSHeight([pathsScroll frame]);
  float	resHeight;
  NSRect newFrame;
  
  if ((ptsHeight + dvt) > (NSHeight(spBounds) - MIN_RESULTS_H)) {
    ptsHeight = MIN_PATHS_H;
  }
  
  resHeight = NSHeight(spBounds) - ptsHeight - dvt;
  
  newFrame = NSMakeRect(0, 0, NSWidth(spBounds), resHeight);
  [resultsScroll setFrame: newFrame];

  newFrame = NSMakeRect(0, resHeight + dvt, NSWidth(spBounds), ptsHeight);
  [pathsScroll setFrame: newFrame];
  
  [resultsView sizeLastColumnToFit];
  
  [finder setSearchResultsHeight: ceil(NSHeight([pathsScroll frame]))];  
}

- (float)splitView:(NSSplitView *)sender 
            constrainMaxCoordinate:(float)proposedMax 
                       ofSubviewAt:(int)offset
{
  float spHeight = NSHeight([splitView bounds]);
  float dvt = [splitView dividerThickness];

  if (proposedMax > (spHeight - dvt - MIN_PATHS_H)) {
    return (spHeight - dvt - MIN_PATHS_H);
  }
  
  return proposedMax;
}

- (float)splitView:(NSSplitView *)sender 
            constrainMinCoordinate:(float)proposedMin 
                       ofSubviewAt:(int)offset
{
  if (proposedMin < MIN_RESULTS_H) {
    return MIN_RESULTS_H;
  }

  return proposedMin;
}

- (void)splitViewDidResizeSubviews:(NSNotification *)aNotification
{
  [finder setSearchResultsHeight: ceil(NSHeight([pathsScroll frame]))]; 
}


//
// NSTableDataSource protocol
//
- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
  NSArray *nodes = updaterbusy ? foundObjects : sortedObjects;
  return [nodes count];
}

- (id)tableView:(NSTableView *)aTableView
          objectValueForTableColumn:(NSTableColumn *)aTableColumn
                                row:(int)rowIndex
{
  NSArray *nodes = updaterbusy ? foundObjects : sortedObjects;
  FSNode *nd = [nodes objectAtIndex: rowIndex];
  
  if (aTableColumn == nameColumn) {
    return [nd name];
  } else if (aTableColumn == parentColumn) {
    return [[nd parentPath] lastPathComponent];
  } else if (aTableColumn == dateColumn) {
    return [nd modDateDescription];
  } else if (aTableColumn == sizeColumn) {
    return [nd sizeDescription];
  } else if (aTableColumn == kindColumn) {
    return [nd typeDescription];
  }
    
  return [NSString string];
}

- (BOOL)tableView:(NSTableView *)aTableView
	      writeRows:(NSArray *)rows
     toPasteboard:(NSPasteboard *)pboard
{
  NSArray *nodes = updaterbusy ? foundObjects : sortedObjects;
  NSMutableArray *paths = [NSMutableArray array];
  NSMutableArray *parentPaths = [NSMutableArray array];
  int i;

  for (i = 0; i < [rows count]; i++) {
    int index = [[rows objectAtIndex: i] intValue];
    FSNode *nd = [nodes objectAtIndex: index];        
    NSString *parentPath = [nd parentPath];
    
    if (([parentPaths containsObject: parentPath] == NO) && (i != 0)) {
      NSString *msg = NSLocalizedString(@"You can't move objects with multiple parent paths!", @"");
      NSRunAlertPanel(nil, msg, NSLocalizedString(@"Continue", @""), nil, nil);
      return NO;
    }
    
    if ([nd isValid]) {
      [paths addObject: [nd path]];
      [parentPaths addObject: parentPath];
    }
  }

  [pboard declareTypes: [NSArray arrayWithObject: NSFilenamesPboardType] 
                                           owner: nil];
  [pboard setPropertyList: paths forType: NSFilenamesPboardType];

  return YES;
}


//
// NSTableView delegate methods
//
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
  NSArray *selected = [self selectedObjects];

  NSLog(@"selected %i", [selected count]);
  
  if ([selected count]) {
    [pathsView showComponentsOfSelection: selected];
  }
}

- (void)tableView:(NSTableView *)aTableView 
  willDisplayCell:(id)aCell 
   forTableColumn:(NSTableColumn *)aTableColumn 
              row:(int)rowIndex
{
  if (aTableColumn == nameColumn) {
    ResultsTextCell *cell = (ResultsTextCell *)[nameColumn dataCell];
    NSArray *nodes = updaterbusy ? foundObjects : sortedObjects;
    FSNode *nd = [nodes objectAtIndex: rowIndex];

    [cell setIcon: [[FSNodeRep sharedInstance] iconOfSize: 24 forNode: nd]];
    
  } else if (aTableColumn == dateColumn) {
    [(ResultsTextCell *)[dateColumn dataCell] setDateCell: YES];
  }
}

- (void)tableView:(NSTableView *)tableView 
            mouseDownInHeaderOfTableColumn:(NSTableColumn *)tableColumn
{
  NSString *newOrderStr = [tableColumn identifier]; 
  FSNInfoType newOrder = FSNInfoNameType;

  if ([newOrderStr isEqual: @"name"]) {
    newOrder = FSNInfoNameType;
  } else if ([newOrderStr isEqual: @"parent"]) {
    newOrder = FSNInfoParentType;
  } else if ([newOrderStr isEqual: @"kind"]) {
    newOrder = FSNInfoKindType;
  } else if ([newOrderStr isEqual: @"date"]) {
    newOrder = FSNInfoDateType;
  } else if ([newOrderStr isEqual: @"size"]) {
    newOrder = FSNInfoSizeType;
  }

  if (newOrder != currentOrder) {
    currentOrder = newOrder;
    [self updateShownData];
    [resultsView reloadData];
  }

  [tableView setHighlightedTableColumn: tableColumn];
}

// ResultsTableView
- (NSImage *)tableView:(NSTableView *)tableView 
      dragImageForRows:(NSArray *)dragRows
{
  if ([dragRows count] > 1) {
    return [[FSNodeRep sharedInstance] multipleSelectionIconOfSize: 24];
  } else {
    int index = [[dragRows objectAtIndex: 0] intValue];
    NSArray *nodes = updaterbusy ? foundObjects : sortedObjects;
    FSNode *nd = [nodes objectAtIndex: index];
    
    return [[FSNodeRep sharedInstance] iconOfSize: 24 forNode: nd];
  }

  return nil;
}

@end


@implementation ProgrView

#define IMAGES 8

- (void)dealloc
{
  RELEASE (images);
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect 
    refreshInterval:(float)refresh
{
  self = [super initWithFrame: frameRect];

  if (self) {
    int i;
  
    images = [NSMutableArray new];
  
    for (i = 0; i < IMAGES; i++) {
      NSString *imname = [NSString stringWithFormat: @"anim-logo-%d.tiff", i];
      [images addObject: [NSImage imageNamed: imname]];    
    }
  
    rfsh = refresh;
    animating = NO;
  }

  return self;
}

- (void)start
{
  index = 0;
  animating = YES;
  progTimer = [NSTimer scheduledTimerWithTimeInterval: rfsh 
						            target: self selector: @selector(animate:) 
																					userInfo: nil repeats: YES];
}

- (void)stop
{
  animating = NO;
  if (progTimer && [progTimer isValid]) {
    [progTimer invalidate];
  }
  [self setNeedsDisplay: YES];
}

- (void)animate:(id)sender
{
  [self setNeedsDisplay: YES];
  index++;
  if (index == [images count]) {
    index = 0;
  }
}

- (void)drawRect:(NSRect)rect
{
  [super drawRect: rect];
  
  if (animating) {
    [[images objectAtIndex: index] compositeToPoint: NSMakePoint(0, 0) 
                                          operation: NSCompositeSourceOver];
  }
}

@end
