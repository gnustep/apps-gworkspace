/* LSFolder.m
 *  
 * Copyright (C) 2004-2014 Free Software Foundation, Inc.
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

#include <math.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#import "LSFolder.h"
#import "ResultsTableView.h"
#import "FSNTextCell.h"
#import "FSNPathComponentsViewer.h"
#import "LSFEditor.h"
#import "Finder.h"
#import "FinderModulesProtocol.h"
#import "GWorkspace.h"
#import "GWFunctions.h"

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

  if (updaterconn != nil) {
    if (updater != nil) {
      [updater terminate];
    }
    DESTROY (updater);    
    DESTROY (updaterconn);
  }
        
  if (watcherSuspended == NO) {
    [gworkspace removeWatcherForPath: [node path]];
  }
  
  RELEASE (node);
  RELEASE (lsfinfo);
  RELEASE (win);
  RELEASE (foundObjects);
  RELEASE (editor);      
  RELEASE (elementsStr);
  DESTROY (conn);
   
  [super dealloc];
}

- (id)initForFinder:(id)fndr
           withNode:(FSNode *)anode
      needsIndexing:(BOOL)index
{
  self = [super init];

  if (self) {
    NSDictionary *dict = nil;

    ASSIGN (node, anode);
    
    updater = nil;
    actionPending = NO;
    updaterbusy = NO;
    waitingUpdater = NO;
    autoupdate = 0;
    
    win = nil;
    forceclose = NO;

    finder = fndr;
    
    fm = [NSFileManager defaultManager];
    nc = [NSNotificationCenter defaultCenter];
    gworkspace = [GWorkspace gworkspace];
    
    ASSIGN (elementsStr, NSLocalizedString(@"elements", @""));
        
    if ([anode isValid] && [anode isDirectory]) {
      NSString *dpath = LSF_INFO([anode path]);
      
      if ([fm fileExistsAtPath: dpath]) {
        dict = [NSDictionary dictionaryWithContentsOfFile: dpath];
      }
    }
    
    if (dict) {
      id entry = [dict objectForKey: @"autoupdate"];
      
      if (entry) {
        autoupdate = [entry unsignedLongValue];
      }
      
      lsfinfo = [dict mutableCopy];

      watcherSuspended = NO;      
      [gworkspace addWatcherForPath: [node path]];

      if (index || (autoupdate > 0)) {
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
    [gworkspace removeWatcherForPath: [node path]];
  }
  ASSIGN (node, anode);
  [gworkspace addWatcherForPath: [node path]];
  
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

- (IBAction)setAutoupdateCycle:(id)sender
{
  id item = [sender selectedItem];
  unsigned cycle = [[item representedObject] unsignedLongValue];
  [updater setAutoupdate: cycle];
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
    visibleRows = (int)([resultsScroll bounds].size.height / CELLS_HEIGHT + 1);
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

    [resultsView noteNumberOfRowsChanged];
    [updateButt setEnabled: NO];
    [autoupdatePopUp setEnabled: NO];
    [progView start];
    updaterbusy = YES;
    [updater fastUpdate];
  }
}

- (void)startUpdater
{
  NSString *cname;
  NSString *cmd;

  cname = [NSString stringWithFormat: @"search_%lu", (unsigned long)self];

  if (conn == nil) {
    conn = [[NSConnection alloc] initWithReceivePort: (NSPort *)[NSPort port] 
																			      sendPort: nil];
    [conn setRootObject: self];
    [conn registerName: cname];
    [conn setDelegate: self];

    [nc addObserver: self
           selector: @selector(connectionDidDie:)
               name: NSConnectionDidDieNotification
             object: conn];    
  }

  if (updaterconn != nil) {
    if (updater != nil) {
      [updater terminate];
    }
        
    DESTROY (updater);
    
    [nc removeObserver: self
	                name: NSConnectionDidDieNotification 
                object: updaterconn];
    
    [updaterconn invalidate];
    DESTROY (updaterconn);
  }
  
  updater = nil;
  waitingUpdater = YES;  

  [NSTimer scheduledTimerWithTimeInterval: 5.0 
	   target: self
	   selector: @selector(checkUpdater:) 
	   userInfo: nil 
	   repeats: NO];
  
  cmd = [NSTask launchPathForTool: @"lsfupdater"];

  [NSTask launchedTaskWithLaunchPath: cmd 
                           arguments: [NSArray arrayWithObject: cname]];
}

- (void)checkUpdater:(id)sender
{
  if (waitingUpdater && (updater == nil)) {
    NSRunAlertPanel(nil, 
                    NSLocalizedString(@"unable to launch the updater task.", @""), 
                    NSLocalizedString(@"Continue", @""), 
                    nil, 
                    nil);
  }
}
  
- (void)setUpdater:(id)anObject
{
  NSData *info = [NSArchiver archivedDataWithRootObject: lsfinfo];
    
  [anObject setProtocolForProxy: @protocol(LSFUpdaterProtocol)];
  updater = (id <LSFUpdaterProtocol>)[anObject retain];
  [updater setFolderInfo: info];   
  [updater setAutoupdate: autoupdate];
  
  if (actionPending) {
    actionPending = NO;
    updaterbusy = YES;
    if (nextSelector == @selector(fastUpdate)) {
      [updateButt setEnabled: NO];
      [autoupdatePopUp setEnabled: NO];
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
  [autoupdatePopUp setEnabled: YES];
  
  if (actionPending) {
    actionPending = NO;
    updaterbusy = YES;
    
    if (nextSelector == @selector(fastUpdate)) {
      [resultsView noteNumberOfRowsChanged];
      [updateButt setEnabled: NO];
      [autoupdatePopUp setEnabled: NO];
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
  CREATE_AUTORELEASE_POOL(pool);
  FSNode *nd = [FSNode nodeWithPath: path];
  
  if ([foundObjects containsObject: nd] == NO) {
    [foundObjects addObject: nd];

    if ([foundObjects count] <= visibleRows) {
      [resultsView noteNumberOfRowsChanged];
    }

    [elementsLabel setStringValue: [NSString stringWithFormat: @"%lu %@", 
                                             (unsigned long)[foundObjects count], elementsStr]];
  } 

  RELEASE (pool);
}

- (void)removeFoundPath:(NSString *)path
{
  CREATE_AUTORELEASE_POOL(pool);
  [foundObjects removeObject: [FSNode nodeWithPath: path]];
  [elementsLabel setStringValue: [NSString stringWithFormat: @"%lu %@", 
                                           (unsigned long)[foundObjects count], elementsStr]];
  [resultsView noteNumberOfRowsChanged];
  [pathViewer showComponentsOfSelection: [self selectedObjects]];
  RELEASE (pool);
}

- (void)clearFoundPaths
{
  [foundObjects removeAllObjects];
  [elementsLabel setStringValue: [NSString stringWithFormat: @"%lu %@", 
                                           (unsigned long)[foundObjects count], elementsStr]];
  [resultsView noteNumberOfRowsChanged];
  [pathViewer showComponentsOfSelection: nil];
}

- (void)endUpdate
{
  if (updater) {
    [nc removeObserver: self
	                name: NSConnectionDidDieNotification 
                object: updaterconn];
    [updater terminate];
    DESTROY (updater);
    DESTROY (updaterconn);
    actionPending = NO;
    updaterbusy = NO;
    [progView stop];
  }
}
         
- (BOOL)connection:(NSConnection*)ancestor 
shouldMakeNewConnection:(NSConnection*)newConn
{
  if (ancestor == conn)
    {
    ASSIGN (updaterconn, newConn);
    [updaterconn setDelegate: self];

    [nc addObserver: self 
			     selector: @selector(connectionDidDie:)
	    		     name: NSConnectionDidDieNotification 
             object: updaterconn];
	}

  return YES;
}

- (void)connectionDidDie:(NSNotification *)notification
{
  id diedconn = [notification object];

  [nc removeObserver: self
	              name: NSConnectionDidDieNotification 
              object: diedconn];

  if ((diedconn == conn) || (updaterconn && (diedconn == updaterconn))) {
    DESTROY (updater);
    DESTROY (updaterconn);
    
    if (diedconn == conn) {
      DESTROY (conn);
    } 
    
    actionPending = NO;
    updaterbusy = NO;
    [progView stop];
    [updateButt setEnabled: YES];  
    [autoupdatePopUp setEnabled: YES];

    NSRunAlertPanel(nil, 
                    NSLocalizedString(@"updater connection died!", @""), 
                    NSLocalizedString(@"Continue", @""), 
                    nil, 
                    nil);
  }
}

- (void)loadInterface
{
#define MINUT 60
#define HOUR (MINUT * 60)
#define DAY (HOUR * 24)

  if ([NSBundle loadNibNamed: nibName owner: self]) {
    NSDictionary *sizesDict = [self getSizes];
    NSArray *items;
    id entry;
    NSRect r;
    int i;
    
    if (sizesDict) {
      entry = [sizesDict objectForKey: @"win_frame"];
      
      if (entry) {
        [win setFrameFromString: entry];
      }
    }
    
    [win setTitle: [node name]];
    [win setReleasedWhenClosed: NO];
    [win setAcceptsMouseMovedEvents: YES];
    [win setDelegate: self];

    progView = [[ProgrView alloc] initWithFrame: NSMakeRect(0, 0, 16, 16)
                                refreshInterval: 0.1];
    [progBox setContentView: progView]; 
    RELEASE (progView);

    [elementsLabel setStringValue: @""];
    
    [editButt setTitle: NSLocalizedString(@"Edit", @"")];
    
    while ([[autoupdatePopUp itemArray] count] > 0) {
      [autoupdatePopUp removeItemAtIndex: 0];
    }

    [autoupdatePopUp addItemWithTitle: NSLocalizedString(@"no autoupdate", @"")];
    [[autoupdatePopUp lastItem] setRepresentedObject: [NSNumber numberWithLong: 0]];    
    [autoupdatePopUp addItemWithTitle: NSLocalizedString(@"one minute", @"")];
    [[autoupdatePopUp lastItem] setRepresentedObject: [NSNumber numberWithLong: MINUT]];
    [autoupdatePopUp addItemWithTitle: NSLocalizedString(@"5 minutes", @"")];
    [[autoupdatePopUp lastItem] setRepresentedObject: [NSNumber numberWithLong: MINUT * 5]];
    [autoupdatePopUp addItemWithTitle: NSLocalizedString(@"10 minutes", @"")];
    [[autoupdatePopUp lastItem] setRepresentedObject: [NSNumber numberWithLong: MINUT * 10]];
    [autoupdatePopUp addItemWithTitle: NSLocalizedString(@"30 minutes", @"")];
    [[autoupdatePopUp lastItem] setRepresentedObject: [NSNumber numberWithLong: MINUT * 30]];
    [autoupdatePopUp addItemWithTitle: NSLocalizedString(@"one hour", @"")];
    [[autoupdatePopUp lastItem] setRepresentedObject: [NSNumber numberWithLong: HOUR]];
    [autoupdatePopUp addItemWithTitle: NSLocalizedString(@"2 hours", @"")];
    [[autoupdatePopUp lastItem] setRepresentedObject: [NSNumber numberWithLong: HOUR * 2]];
    [autoupdatePopUp addItemWithTitle: NSLocalizedString(@"3 hours", @"")];
    [[autoupdatePopUp lastItem] setRepresentedObject: [NSNumber numberWithLong: HOUR * 3]];
    [autoupdatePopUp addItemWithTitle: NSLocalizedString(@"6 hours", @"")];
    [[autoupdatePopUp lastItem] setRepresentedObject: [NSNumber numberWithLong: HOUR * 6]];
    [autoupdatePopUp addItemWithTitle: NSLocalizedString(@"12 hours", @"")];
    [[autoupdatePopUp lastItem] setRepresentedObject: [NSNumber numberWithLong: HOUR * 12]];
    [autoupdatePopUp addItemWithTitle: NSLocalizedString(@"a day", @"")];
    [[autoupdatePopUp lastItem] setRepresentedObject: [NSNumber numberWithLong: DAY]];

    items = [autoupdatePopUp itemArray];

    for (i = 0; i < [items count]; i++) {
      NSMenuItem * item = [items objectAtIndex: i];
      
      if ([[item representedObject] unsignedLongValue] == autoupdate) {
        [autoupdatePopUp selectItemAtIndex: i];
        break;
      }
    }

    [updateButt setTitle: NSLocalizedString(@"Update now", @"")];

    [resultsScroll setBorderType: NSBezelBorder];
    [resultsScroll setHasHorizontalScroller: YES];
    [resultsScroll setHasVerticalScroller: YES]; 
    
    r = [[resultsScroll contentView] bounds];

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
    [nameColumn setDataCell: AUTORELEASE ([[FSNTextCell alloc] init])];
    [nameColumn setEditable: NO];
    [nameColumn setResizable: YES];
    [[nameColumn headerCell] setStringValue: NSLocalizedString(@"Name", @"")];
    [[nameColumn headerCell] setAlignment: NSLeftTextAlignment];
    [nameColumn setMinWidth: 80];
    [nameColumn setWidth: 140];
    [resultsView addTableColumn: nameColumn];
    RELEASE (nameColumn);
    
    parentColumn = [[NSTableColumn alloc] initWithIdentifier: @"parent"];
    [parentColumn setDataCell: AUTORELEASE ([[FSNTextCell alloc] init])];
    [parentColumn setEditable: NO];
    [parentColumn setResizable: YES];
    [[parentColumn headerCell] setStringValue: NSLocalizedString(@"Parent", @"")];
    [[parentColumn headerCell] setAlignment: NSLeftTextAlignment];
    [parentColumn setMinWidth: 80];
    [parentColumn setWidth: 90];
    [resultsView addTableColumn: parentColumn];
    RELEASE (parentColumn);

    dateColumn = [[NSTableColumn alloc] initWithIdentifier: @"date"];
    [dateColumn setDataCell: AUTORELEASE ([[FSNTextCell alloc] init])];
    [dateColumn setEditable: NO];
    [dateColumn setResizable: YES];
    [[dateColumn headerCell] setStringValue: NSLocalizedString(@"Date Modified", @"")];
    [[dateColumn headerCell] setAlignment: NSLeftTextAlignment];
    [dateColumn setMinWidth: 80];
    [dateColumn setWidth: 90];
    [resultsView addTableColumn: dateColumn];
    RELEASE (dateColumn);

    sizeColumn = [[NSTableColumn alloc] initWithIdentifier: @"size"];
    [sizeColumn setDataCell: AUTORELEASE ([[FSNTextCell alloc] init])];
    [sizeColumn setEditable: NO];
    [sizeColumn setResizable: YES];
    [[sizeColumn headerCell] setStringValue: NSLocalizedString(@"Size", @"")];
    [[sizeColumn headerCell] setAlignment: NSLeftTextAlignment];
    [sizeColumn setMinWidth: 50];
    [sizeColumn setWidth: 50];
    [resultsView addTableColumn: sizeColumn];
    RELEASE (sizeColumn);

    kindColumn = [[NSTableColumn alloc] initWithIdentifier: @"kind"];
    [kindColumn setDataCell: AUTORELEASE ([[FSNTextCell alloc] init])];
    [kindColumn setEditable: NO];
    [kindColumn setResizable: YES];
    [[kindColumn headerCell] setStringValue: NSLocalizedString(@"Type", @"")];
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
    
    r = [[pathBox contentView] bounds];
    pathViewer = [[FSNPathComponentsViewer alloc] initWithFrame: r];
    [pathBox setContentView: pathViewer];
    RELEASE (pathViewer);

    [[NSDistributedNotificationCenter defaultCenter] addObserver: self
                        selector: @selector(fileSystemDidChange:) 
                					  name: @"GWFileSystemDidChangeNotification"
                					object: nil];    
  } else {
    NSLog(@"failed to load %@!", nibName);
  }
}

- (void)closeWindow
{
  if (win && [win isVisible]) {
    forceclose = YES;
    [win close]; 
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
  if (forceclose == NO) {
    NSMutableDictionary *columnsDict = [NSMutableDictionary dictionary];
    NSArray *columns = [resultsView tableColumns];
    NSString *dictpath = LSF_GEOM([node path]);
    NSMutableDictionary *sizesDict = nil;  
    int i;  

    if ([fm fileExistsAtPath: dictpath]) {
      NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: dictpath];
      if (dict) {
        sizesDict = [dict mutableCopy];
      }
    }

    if (sizesDict == nil) {
      sizesDict = [NSMutableDictionary new];
    }

    [sizesDict setObject: [win stringWithSavedFrame] 
                  forKey: @"win_frame"];

    if (editor) {
      [sizesDict setObject: [[editor win] stringWithSavedFrame] 
                    forKey: @"editor_win"];
    }

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

    [sizesDict writeToFile: dictpath atomically: YES];

    RELEASE (sizesDict);
  }
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

  [foundObjects sortUsingSelector: sortingSel];
  [resultsView setHighlightedTableColumn: column];
  [resultsView reloadData];
  [pathViewer showComponentsOfSelection: [self selectedObjects]];
}

- (void)setCurrentOrder:(FSNInfoType)order
{
  currentOrder = order;
}

- (NSArray *)selectedObjects
{
  NSMutableArray *selected = [NSMutableArray array];
  NSEnumerator *enumerator = [resultsView selectedRowEnumerator];
  NSNumber *row;
  
  while ((row = [enumerator nextObject])) {
	  FSNode *nd = [foundObjects objectAtIndex: [row intValue]];
    if ([nd isValid]) {
      [selected addObject: nd];
    } else {
      [foundObjects removeObject: nd];
      [resultsView noteNumberOfRowsChanged];
    }
  }

  return selected;  
}

- (void)selectObjects:(NSArray *)objects
{
  NSMutableIndexSet *set = [NSMutableIndexSet indexSet];
  NSUInteger i;

  for (i = 0; i < [foundObjects count]; i++) {
    FSNode *nd = [foundObjects objectAtIndex: i];
  
    if ([objects containsObject: nd]) {
      [set addIndex: i];
    }
  }

  if ([set count]) {
    [resultsView deselectAll: self];
    [resultsView selectRowIndexes: set byExtendingSelection: NO];
    [resultsView setNeedsDisplay: YES];
  }
}

- (void)doubleClickOnResultsView:(id)sender
{
  [finder openFoundSelection: [self selectedObjects]];
}

- (IBAction)openEditor:(id)sender
{
  if (editor == nil) {
    editor = [[LSFEditor alloc] initForFolder: self];
  }
  [editor activate];
}

- (NSArray *)searchPaths
{
  return [lsfinfo objectForKey: @"searchpaths"];
}

- (NSDictionary *)searchCriteria
{
  return [lsfinfo objectForKey: @"criteria"];
}

- (BOOL)recursive
{
  id recursion = [lsfinfo objectForKey: @"recursion"];
  return ((recursion == nil) || [recursion boolValue]);
}

- (void)setSearchCriteria:(NSDictionary *)criteria
                recursive:(BOOL)rec
{
  if (([[self searchCriteria] isEqual: criteria] == NO)
                                        || ([self recursive] != rec)) {  
    [lsfinfo setObject: criteria forKey: @"criteria"];
    [lsfinfo setObject: [NSNumber numberWithBool: rec]
                forKey: @"recursion"];

    if (updater) {
      NSData *info = [NSArchiver archivedDataWithRootObject: lsfinfo];
      [updater updateSearchCriteria: info];
    }
  }
}

- (void)fileSystemDidChange:(NSNotification *)notif
{
  NSDictionary *info = [notif object];
  NSString *operation = [info objectForKey: @"operation"];
  NSString *source = [info objectForKey: @"source"];
  NSString *destination = [info objectForKey: @"destination"];
  NSArray *files = [info objectForKey: @"files"];
  NSMutableArray *deletedObjects = [NSMutableArray array];
  NSUInteger i, j;

  if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
    files = [NSArray arrayWithObject: [destination lastPathComponent]];
    destination = [destination stringByDeletingLastPathComponent]; 
  }

  if ([operation isEqual: NSWorkspaceRecycleOperation]) {
		files = [info objectForKey: @"origfiles"];
  }	
  
  if ([operation isEqual: NSWorkspaceMoveOperation] 
        || [operation isEqual: NSWorkspaceDestroyOperation]
      || [operation isEqual: NSWorkspaceRecycleOperation]
      || [operation isEqual: @"GWorkspaceRecycleOutOperation"]
      || [operation isEqual: @"GWorkspaceEmptyRecyclerOperation"])
    {
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
  }
}


//
// NSWindow delegate
//
- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
  NSArray *selected = [self selectedObjects];

  if ([selected count]) {
    [finder foundSelectionChanged: selected];
  }
}

- (BOOL)windowShouldClose:(id)sender
{
  if (forceclose) {
    return YES;
  }
	return !updaterbusy;
}

- (void)windowWillClose:(NSNotification *)aNotification
{
  if (editor) {
    [[editor win] close];
  }
  [self saveSizes];
}


//
// NSTableDataSource protocol
//
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
  return [foundObjects count];
}

- (id)tableView:(NSTableView *)aTableView
          objectValueForTableColumn:(NSTableColumn *)aTableColumn
                                row:(NSInteger)rowIndex
{
  FSNode *nd = [foundObjects objectAtIndex: rowIndex];
    
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
  NSMutableArray *paths = [NSMutableArray array];
  NSMutableArray *parentPaths = [NSMutableArray array];
  NSUInteger i;

  for (i = 0; i < [rows count]; i++) {
    int index = [[rows objectAtIndex: i] intValue];
    FSNode *nd = [foundObjects objectAtIndex: index];        
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

  [pathViewer showComponentsOfSelection: selected];
  
  if ([selected count]) {
    [finder foundSelectionChanged: selected];
  }
}

- (void)tableView:(NSTableView *)aTableView 
  willDisplayCell:(id)aCell 
   forTableColumn:(NSTableColumn *)aTableColumn 
              row:(NSInteger)rowIndex
{
  if (aTableColumn == nameColumn) {
    FSNTextCell *cell = (FSNTextCell *)[nameColumn dataCell];
    FSNode *nd = [foundObjects objectAtIndex: rowIndex];

    [cell setIcon: [[FSNodeRep sharedInstance] iconOfSize: 24 forNode: nd]];
    
  } else if (aTableColumn == dateColumn) {
    [(FSNTextCell *)[dateColumn dataCell] setDateCell: YES];
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
    NSArray *selected = [self selectedObjects];
  
    currentOrder = newOrder;
    [self updateShownData];
    
    if ([selected count]) {
      id nd = [selected objectAtIndex: 0];
      NSUInteger index = [foundObjects indexOfObjectIdenticalTo: nd];
      
      [self selectObjects: selected];
      
      if (index != NSNotFound) {
        [resultsView scrollRowToVisible: index];
      }
    }    
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
    NSUInteger index = [[dragRows objectAtIndex: 0] unsignedIntegerValue];
    FSNode *nd = [foundObjects objectAtIndex: index];
    
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
    refreshInterval:(NSTimeInterval)refresh
{
  self = [super initWithFrame: frameRect];

  if (self) {
    unsigned i;
  
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
  if (animating) {
    animating = NO;
    if (progTimer && [progTimer isValid]) {
      [progTimer invalidate];
    }
    [self setNeedsDisplay: YES];
  }
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
