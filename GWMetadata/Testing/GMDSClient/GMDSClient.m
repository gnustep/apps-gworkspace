/* GMDSClient.m
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "MDKQuery.h"
#include <FSNode/FSNodeRep.h>
#include <FSNode/FSNTextCell.h>
#include "GMDSClient.h"

#define CELLS_HEIGHT (28.0)
#define WORD_MAX 40
#define WORD_MIN 3

static GMDSClient *gmdsclient = nil;
static NSString *nibName = @"GMDSClient";

@implementation GMDSClient

+ (GMDSClient *)gmdsclient
{
	if (gmdsclient == nil) {
		gmdsclient = [[GMDSClient alloc] init];
	}	
  return gmdsclient;
}

- (void)dealloc
{
  DESTROY (gmds);
  RELEASE (progView);
  TEST_RELEASE (queryWords);
  RELEASE (currentQuery);
  TEST_RELEASE (skipSet);
  RELEASE (foundObjects);
  TEST_RELEASE (win);
  
	[super dealloc];
}

- (id)init
{
  self = [super init];

  if (self) {
    fm = [NSFileManager defaultManager];
    nc = [NSNotificationCenter defaultCenter];
  }

  return self;
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
  NSCharacterSet *set;
  NSRect r;
  
  if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
    NSLog(@"failed to load %@!", nibName);
    [NSApp terminate: self];
  } 

  [win setDelegate: self];
  [win setFrameUsingName: @"gmdsclient"];

  progView = [[ProgrView alloc] initWithFrame: NSMakeRect(0, 0, 16, 16)
                              refreshInterval: 0.1];
  [(NSBox *)progBox setContentView: progView]; 
  RELEASE (progView);
  
  [searchField setAllowsEditingTextAttributes: NO];
  [searchField setImportsGraphics: NO];
  [searchField setDelegate: self];
  
  [pathsScroll setBorderType: NSBezelBorder];
  [pathsScroll setHasHorizontalScroller: YES];
  [pathsScroll setHasVerticalScroller: YES]; 
  
  r = [[pathsScroll contentView] frame];
  
  resultsView = [[NSTableView alloc] initWithFrame: r];
  [resultsView setDrawsGrid: NO];
  [resultsView setAllowsColumnSelection: NO];
  [resultsView setAllowsColumnReordering: NO];
  [resultsView setAllowsColumnResizing: YES];
  [resultsView setAllowsEmptySelection: YES];
  [resultsView setAllowsMultipleSelection: NO];
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
  [nameColumn setWidth: 180];
  [resultsView addTableColumn: nameColumn];
  RELEASE (nameColumn);
  
  dateColumn = [[NSTableColumn alloc] initWithIdentifier: @"date"];
  [dateColumn setDataCell: AUTORELEASE ([[FSNTextCell alloc] init])];
  [dateColumn setEditable: NO];
  [dateColumn setResizable: YES];
  [[dateColumn headerCell] setStringValue: NSLocalizedString(@"Date Modified", @"")];
  [[dateColumn headerCell] setAlignment: NSLeftTextAlignment];
  [dateColumn setMinWidth: 60];
  [dateColumn setWidth: 70];
  [resultsView addTableColumn: dateColumn];
  RELEASE (dateColumn);
  
  kindColumn = [[NSTableColumn alloc] initWithIdentifier: @"kind"];
  [kindColumn setDataCell: AUTORELEASE ([[FSNTextCell alloc] init])];
  [kindColumn setEditable: NO];
  [kindColumn setResizable: YES];
  [[kindColumn headerCell] setStringValue: NSLocalizedString(@"Kind", @"")];
  [[kindColumn headerCell] setAlignment: NSLeftTextAlignment];
  [kindColumn setMinWidth: 60];
  [kindColumn setWidth: 60];
  [resultsView addTableColumn: kindColumn];
  RELEASE (kindColumn);

  [pathsScroll setDocumentView: resultsView];
  RELEASE (resultsView);
  
  [resultsView setDataSource: self]; 
  [resultsView setDelegate: self];
  [resultsView setTarget: self];
  [resultsView setDoubleAction: @selector(doubleClickOnResultsView:)];
  
  foundObjects = [NSMutableArray new];
    
  skipSet = [NSMutableCharacterSet new];

  set = [NSCharacterSet controlCharacterSet];
  [skipSet formUnionWithCharacterSet: set];

  set = [NSCharacterSet illegalCharacterSet];
  [skipSet formUnionWithCharacterSet: set];

//  set = [NSCharacterSet punctuationCharacterSet];
//  [skipSet formUnionWithCharacterSet: set];

  set = [NSCharacterSet symbolCharacterSet];
  [skipSet formUnionWithCharacterSet: set];

  set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  [skipSet formUnionWithCharacterSet: set];

//  set = [NSCharacterSet decimalDigitCharacterSet];
//  [skipSet formUnionWithCharacterSet: set];

  set = [NSCharacterSet characterSetWithCharactersInString: 
                                      @"~`@#$%^_-+\\{}:;\"\',/?"];
  [skipSet formUnionWithCharacterSet: set];  
  
  currentQuery = [NSMutableDictionary new];
  queryNumber = 0L;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  [win makeKeyAndOrderFront: nil];
  [self connectGMDs];
  
  
  
  
  
  
  
  
/*  

  {
    MDKQuery *query = [MDKQuery query];
    MDKQuery *q;
    
    // (
        
    [query appendSubqueryWithCompoundOperator: GMDCompoundOperatorNone
                                    attribute: @"GSMDItemExposureTimeSeconds"
                                  searchValue: @"0.9"
                                 operatorType: GMDLessThanOperatorType    
                                caseSensitive: NO];
    // (a 
         
    q = [query appendSubqueryWithCompoundOperator: GMDOrCompoundOperator];

    // (a OR (
    
    q = [q appendSubqueryWithCompoundOperator: GMDCompoundOperatorNone];

    // (a OR ((
    
    [q appendSubqueryWithCompoundOperator: GMDCompoundOperatorNone
                                attribute: @"GSMDItemExposureTimeSeconds"
                              searchValue: @"0.9"
                             operatorType: GMDLessThanOperatorType    
                            caseSensitive: NO];

    // (a OR ((b
    
    [q appendSubqueryWithCompoundOperator: GMDAndCompoundOperator
                                attribute: @"GSMDItemExposureTimeSeconds"
                              searchValue: @"0.01"
                             operatorType: GMDGreaterThanOperatorType    
                            caseSensitive: NO];    

    // (a OR ((b AND c
    
    [q closeSubqueries];

    // (a OR ((b AND c)
    
    q = [q parentQuery];
    
    q = [q appendSubqueryWithCompoundOperator: GMDAndCompoundOperator];
    
    // (a OR ((b AND c) AND (
    
    [q appendSubqueryWithCompoundOperator: GMDCompoundOperatorNone
                                attribute: @"GSMDItemFSExtension"
                              searchValue: @"jpeg"
                             operatorType: GMDEqualToOperatorType    
                            caseSensitive: NO];
    
    // (a OR ((b AND c) AND (d
    
    [q appendSubqueryWithCompoundOperator: GMDOrCompoundOperator
                                attribute: @"GSMDItemTextContent"
                              searchValue: @"tiff"
                             operatorType: GMDEqualToOperatorType    
                            caseSensitive: NO];
    
    // (a OR ((b AND c) AND (d OR e
    
    [q closeSubqueries];
    
    // (a OR ((b AND c) AND (d OR e)
    
    q = [q parentQuery];
    [q closeSubqueries];

    // (a OR ((b AND c) AND (d OR e))
    
    [query closeSubqueries];
    
    // (a OR ((b AND c) AND (d OR e)))
    
    [query buildQuery];
    
    
    NSLog([query description]);
    NSLog([[query sqldescription] description]);

//    NSString *str = @"GSMDItemExposureTimeSeconds < 0.9 "
//                    @"|| ( ( GSMDItemExposureTimeSeconds < 0.4 "
//                    @"&& GSMDItemExposureTimeSeconds > 0.01 ) "
//                    @"&& ( GSMDItemFSExtension == \"jpeg\"wc "
//                    @"|| GSMDItemTextContent == tiff ) )";
    
//    query = [MDKQuery queryFromString: str inDirectories: nil];
    
 //   NSLog([query description]);
 //   NSLog([[query sqldescription] description]);

  }

*/   
  
}

- (BOOL)applicationShouldTerminate:(NSApplication *)app 
{
  [self updateDefaults];
  
  if (gmds) {
    [nc removeObserver: self
	                name: NSConnectionDidDieNotification
	              object: nil];
    [gmds unregisterClient: self];
  }
  
	return YES;
}

- (void)connectGMDs
{
  if (gmds == nil) {
    id gm = [NSConnection rootProxyForConnectionWithRegisteredName: @"gmds" 
                                                              host: @""];

    if (gm) {
      NSConnection *c = [gm connectionForProxy];

	    [nc addObserver: self
	           selector: @selector(connectionDidDie:)
		             name: NSConnectionDidDieNotification
		           object: c];
      
      gmds = gm;
	    [gmds setProtocolForProxy: @protocol(GMDSProtocol)];
      RETAIN (gmds);
      
      NSLog(@"gmds connected!");     

      [gmds registerClient: self];                              
                                         
	  } else {
	    static BOOL recursion = NO;
	    static NSString	*cmd = nil;

	    if (recursion == NO) {
        if (cmd == nil) {
            cmd = RETAIN ([[NSSearchPathForDirectoriesInDomains(
                      GSToolsDirectory, NSSystemDomainMask, YES) objectAtIndex: 0]
                            stringByAppendingPathComponent: @"gmds"]);
		    }
      }
	  
      if (recursion == NO && cmd != nil) {
        int i;
        
	      [NSTask launchedTaskWithLaunchPath: cmd arguments: nil];
        DESTROY (cmd);
        
        for (i = 1; i <= 40; i++) {
	        [[NSRunLoop currentRunLoop] runUntilDate:
		                       [NSDate dateWithTimeIntervalSinceNow: 0.1]];
                           
          gm = [NSConnection rootProxyForConnectionWithRegisteredName: @"gmds" 
                                                                 host: @""];                  
          if (gm) {
            break;
          }
        }
        
	      recursion = YES;
	      [self connectGMDs];
	      recursion = NO;
        
	    } else { 
        DESTROY (cmd);
	      recursion = NO;
        gmds = nil;
        NSRunAlertPanel(nil, @"unable to contact gmds.", @"OK", nil, nil);  
      }
	  }
  }
}

- (void)connectionDidDie:(NSNotification *)notif
{
  id connection = [notif object];

  [nc removeObserver: self
	                    name: NSConnectionDidDieNotification
	                  object: connection];

  NSAssert(connection == [gmds connectionForProxy],
		                                  NSInternalInconsistencyException);
  RELEASE (gmds);
  gmds = nil;

  NSRunAlertPanel(nil, @"gmds connection died!", @"OK", nil, nil);  
}

- (void)doubleClickOnResultsView:(id)sender
{
  NSEnumerator *enumerator = [resultsView selectedRowEnumerator];
  NSNumber *row;
  
  while ((row = [enumerator nextObject])) {
	  FSNode *node = [foundObjects objectAtIndex: [row intValue]];
    
    if ([node isValid]) {
      [[NSWorkspace sharedWorkspace] openFile: [node path]];
    } else {
      [foundObjects removeObject: node];
      [resultsView noteNumberOfRowsChanged];
    }
  }
}

- (void)updateDefaults
{
  [win saveFrameUsingName: @"gmdsclient"];
}
  
- (BOOL)windowShouldClose:(id)sender
{
  [win saveFrameUsingName: @"gmdsclient"];
	return YES;
}

- (void)showInfo:(id)sender
{
  [NSApp orderFrontStandardInfoPanelWithOptions: nil];
}


//
// NSTableDataSource protocol
//
- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
  return [foundObjects count];
}

- (id)tableView:(NSTableView *)aTableView
          objectValueForTableColumn:(NSTableColumn *)aTableColumn
                                row:(int)rowIndex
{
  FSNode *nd = [foundObjects objectAtIndex: rowIndex];
    
  if (aTableColumn == nameColumn) {
    return [nd name];
  } else if (aTableColumn == dateColumn) {
    return [nd modDateDescription];
  } else if (aTableColumn == kindColumn) {
    return [nd typeDescription];
  }
    
  return [NSString string];
}

- (BOOL)tableView:(NSTableView *)aTableView
	      writeRows:(NSArray *)rows
     toPasteboard:(NSPasteboard *)pboard
{
  return NO;
}

//
// NSTableView delegate methods
//
- (void)tableViewSelectionange:(NSNotification *)aNotification
{
}

- (void)tableView:(NSTableView *)aTableView 
  willDisplayCell:(id)aCell 
   forTableColumn:(NSTableColumn *)aTableColumn 
              row:(int)rowIndex
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
  [tableView setHighlightedTableColumn: tableColumn];
}

@end


@implementation GMDSClient (queries)

- (void)prepareQuery
{
  CREATE_AUTORELEASE_POOL(arp);
  unsigned count = [queryWords count];
  MDKQuery *query = [MDKQuery query];
  NSArray *prequeries;
  NSArray *postqueries;
  NSString *querystr;
  int i;

  [query appendSubqueryWithCompoundOperator: GMDCompoundOperatorNone
                                  attribute: @"GSMDItemTextContent"
                                searchValue: [queryWords objectAtIndex: 0]
                               operatorType: GMDEqualToOperatorType    
                              caseSensitive: YES];
    
  for (i = 1; i < count; i++) {
    [query appendSubqueryWithCompoundOperator: GMDAndCompoundOperator
                                    attribute: @"GSMDItemTextContent"
                                  searchValue: [queryWords objectAtIndex: i]
                                 operatorType: GMDEqualToOperatorType    
                                caseSensitive: YES];
  }
  
  [query closeSubqueries];
  
  if ([query buildQuery]) {    
    NSDictionary *dict = [query sqldescription];
       
    prequeries = [dict objectForKey: @"pre"];
    postqueries = [dict objectForKey: @"post"];
    querystr = [dict objectForKey: @"join"];
  }

  [currentQuery removeAllObjects];
  [currentQuery setObject: prequeries forKey: @"pre_queries"];
  [currentQuery setObject: querystr forKey: @"query"];
  [currentQuery setObject: postqueries forKey: @"post_queries"];
  [currentQuery setObject: [self nextQueryNumber] forKey: @"query_number"];
    
  [foundObjects removeAllObjects];
  [resultsView noteNumberOfRowsChanged];
  [resultsView setNeedsDisplayInRect: [resultsView visibleRect]];
  [foundField setStringValue: @"0"];

         //   NSLog([currentQuery description]);
            NSLog([query description]);

  if (waitResults == NO) {
    waitResults = YES;
    queryStopped = NO;
    [progView start];

    [gmds performQuery: [NSArchiver archivedDataWithRootObject: currentQuery]];

  } else {
    pendingQuery = YES;
  }
  
  RELEASE (arp);
}

- (BOOL)queryResults:(NSData *)results
{
  CREATE_AUTORELEASE_POOL(arp);
  NSDictionary *dict = [NSUnarchiver unarchiveObjectWithData: results];
  NSNumber *qnum = [dict objectForKey: @"query_number"];
  NSArray *lines = [dict objectForKey: @"lines"];
  BOOL resok = NO;
  int i;
  
  if ((queryStopped == NO) 
            && [[currentQuery objectForKey: @"query_number"] isEqual: qnum]) {
    for (i = 0; i < [lines count]; i++) {
      NSArray *line = [lines objectAtIndex: i];
      NSString *path = [line objectAtIndex: 0];
      FSNode *node = [FSNode nodeWithPath: path];

      [foundObjects addObject: node];
    }

    [resultsView noteNumberOfRowsChanged];
    [resultsView setNeedsDisplayInRect: [resultsView visibleRect]];
    [foundField setStringValue: [NSString stringWithFormat: @"%i", [foundObjects count]]];
    resok = YES;
  } 
  
  RELEASE (arp);
    
  return resok;
}

- (void)endOfQuery
{
  [progView stop];
  [foundField setStringValue: [NSString stringWithFormat: @"%i", [foundObjects count]]];
  
  queryStopped = NO;
  
  if (pendingQuery) {
    pendingQuery = NO;
    waitResults = YES;
    [foundObjects removeAllObjects];
    [resultsView noteNumberOfRowsChanged];
    [resultsView setNeedsDisplayInRect: [resultsView visibleRect]];
    [foundField setStringValue: @"0"];
    
    [gmds performQuery: [NSArchiver archivedDataWithRootObject: currentQuery]];
    
  } else {
    waitResults = NO;
  }
}

- (IBAction)stopQuery:(id)sender
{
  queryStopped = YES;
}

- (NSNumber *)nextQueryNumber
{
  NSLog(@"set number to %i", queryNumber + 1);
  return [NSNumber numberWithUnsignedLong: queryNumber++];  
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
  NSString *str = [searchField stringValue];
  BOOL newquery = NO;
    
  if ([str length]) {
    CREATE_AUTORELEASE_POOL(arp);
    NSScanner *scanner = [NSScanner scannerWithString: str];
    NSMutableArray *words = [NSMutableArray array];
        
    while ([scanner isAtEnd] == NO) {
      NSString *word;
            
      [scanner scanUpToCharactersFromSet: skipSet intoString: &word];
            
      if (word) {
        unsigned wl = [word length];

        if ((wl >= WORD_MIN) && (wl < WORD_MAX)) { 
          [words addObject: word];
        }
      }
    }

    if ([words count] && ([words isEqual: queryWords] == NO)) {
      ASSIGN (queryWords, words);
      newquery = YES;
    }      
    
    RELEASE (arp);
    
  } else {
    queryStopped = YES;
  }

  if (newquery) {
    [self prepareQuery];
  }
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
  if (animating == NO) {
    index = 0;
    animating = YES;
    progTimer = [NSTimer scheduledTimerWithTimeInterval: rfsh 
						              target: self selector: @selector(animate:) 
																					  userInfo: nil repeats: YES];
  }
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







