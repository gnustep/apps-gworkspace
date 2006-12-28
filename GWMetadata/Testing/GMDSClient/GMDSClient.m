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
  RELEASE (progView);
  RELEASE (queryWords);
  RELEASE (currentQuery);
  TEST_RELEASE (skipSet);
  TEST_RELEASE (win);
  
	[super dealloc];
}

- (id)init
{
  self = [super init];

  if (self) {
    fm = [NSFileManager defaultManager];
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

  progView = [[ProgrView alloc] initWithFrame: NSMakeRect(0, 0, 16, 16)];
  [(NSBox *)progBox setContentView: progView]; 
  RELEASE (progView);
  
  [searchField setAllowsEditingTextAttributes: NO];
  [searchField setImportsGraphics: NO];
  [searchField setDelegate: self];
  
  [pathsScroll setBorderType: NSBezelBorder];
  [pathsScroll setHasHorizontalScroller: YES];
  [pathsScroll setHasVerticalScroller: YES]; 
  
  r = [[pathsScroll contentView] bounds];
  
  resultsView = [[NSTableView alloc] initWithFrame: r];
  [resultsView setDrawsGrid: NO];
  [resultsView setAllowsColumnSelection: NO];
  [resultsView setAllowsColumnReordering: NO];
  [resultsView setAllowsColumnResizing: YES];
  [resultsView setAllowsEmptySelection: YES];
  [resultsView setAllowsMultipleSelection: NO];
  [resultsView setRowHeight: CELLS_HEIGHT];
  [resultsView setIntercellSpacing: NSZeroSize];
  [resultsView setAutoresizesAllColumnsToFit: YES];
    
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
  [kindColumn setResizable: NO];
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
      
  skipSet = [NSMutableCharacterSet new];

  set = [NSCharacterSet controlCharacterSet];
  [skipSet formUnionWithCharacterSet: set];

  set = [NSCharacterSet illegalCharacterSet];
  [skipSet formUnionWithCharacterSet: set];

  set = [NSCharacterSet symbolCharacterSet];
  [skipSet formUnionWithCharacterSet: set];

  set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  [skipSet formUnionWithCharacterSet: set];

  set = [NSCharacterSet characterSetWithCharactersInString: 
                                      @"~`@#$%^_-+\\{}:;\"\',/?"];
  [skipSet formUnionWithCharacterSet: set];  
  
  ASSIGN (currentQuery, [MDKQuery query]);
  ASSIGN (queryWords, [NSArray array]);
  validResults = NO;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
/*
  MDKQuery *query;

  query = [MDKQuery query];
  [query appendSubqueryWithCompoundOperator: MDKCompoundOperatorNone
                                         attribute: @"GSMDItemTextContent"
                                       searchValue: @"NSString"
                                      operatorType: MDKEqualToOperatorType    
                                     caseSensitive: YES];
  [query appendSubqueryWithCompoundOperator: GMDAndCompoundOperator
                                    attribute: @"GSMDItemTextContent"
                                  searchValue: @"Enrico"
                                 operatorType: MDKEqualToOperatorType    
                                caseSensitive: YES];
  [query appendSubqueryWithCompoundOperator: GMDAndCompoundOperator
                                    attribute: @"GSMDItemTextContent"
                                  searchValue: @"FSNode"
                                 operatorType: MDKEqualToOperatorType    
                                caseSensitive: YES];
  [query setUpdatesEnabled: YES];
  [query setDelegate: self];
  [query setReportRawResults: NO];
  [query startGathering];

  query = [MDKQuery query];
  [query appendSubqueryWithCompoundOperator: MDKCompoundOperatorNone
                                  attribute: @"GSMDItemFSExtension"
                                searchValue: @"jpg"
                               operatorType: MDKEqualToOperatorType   
                              caseSensitive: YES];
  [query appendSubqueryWithCompoundOperator: GMDAndCompoundOperator
                                  attribute: @"GSMDItemFSName"
                                searchValue: @"06*"
                               operatorType: MDKEqualToOperatorType    
                              caseSensitive: YES];
  [query setUpdatesEnabled: YES];
  [query setDelegate: self];
  [query setReportRawResults: NO];
  [query startGathering];

  query = [MDKQuery query];
  [query appendSubqueryWithCompoundOperator: MDKCompoundOperatorNone
                                  attribute: @"GSMDItemFSExtension"
                                searchValue: @"m"
                               operatorType: MDKEqualToOperatorType   
                              caseSensitive: YES];
  [query appendSubqueryWithCompoundOperator: GMDAndCompoundOperator
                                  attribute: @"GSMDItemTextContent"
                                searchValue: @"NSImage"
                               operatorType: MDKEqualToOperatorType    
                              caseSensitive: YES];
  [query setUpdatesEnabled: YES];
  [query setDelegate: self];
  [query setReportRawResults: NO];
  [query startGathering];
*/
    
  {
    unsigned mask = MDKAttributeSearchable | MDKAttributeFSType;    
 //   unsigned mask = MDKAttributeAll & ~MDKAttributeFSType;
    
    NSLog([[[MDKQuery attributesWithMask: mask] allKeys] description]);
  }
  
  [win makeKeyAndOrderFront: nil];
}

- (BOOL)applicationShouldTerminate:(NSApplication *)app 
{
  [self updateDefaults];
  
	return YES;
}

- (void)prepareQuery
{
  CREATE_AUTORELEASE_POOL(arp);
  unsigned count = [queryWords count];
  int i;

  [currentQuery setUpdatesEnabled: NO];
  [currentQuery stopQuery];
  
  [progView stop];  
  [foundField setStringValue: @"0"];
  validResults = NO; 
  [resultsView noteNumberOfRowsChanged];
  [resultsView setNeedsDisplayInRect: [resultsView visibleRect]];
  
  ASSIGN (currentQuery, [MDKQuery query]);
  [currentQuery setUpdatesEnabled: YES];
  [currentQuery setDelegate: self];
  
  [currentQuery appendSubqueryWithCompoundOperator: MDKCompoundOperatorNone
                                         attribute: @"GSMDItemTextContent"
                                       searchValue: [queryWords objectAtIndex: 0]
                                      operatorType: MDKEqualToOperatorType    
                                     caseSensitive: YES];
    
  for (i = 1; i < count; i++) {
    [currentQuery appendSubqueryWithCompoundOperator: GMDAndCompoundOperator
                                    attribute: @"GSMDItemTextContent"
                                  searchValue: [queryWords objectAtIndex: i]
                                 operatorType: MDKEqualToOperatorType    
                                caseSensitive: YES];
  }
  
  [currentQuery closeSubqueries];
  
  if ([currentQuery buildQuery] == NO) {
    NSLog(@"unable to build \"%@\"", [currentQuery description]); 
    [NSApp terminate: self];
  } 
  
  validResults = YES;  
  [currentQuery startGathering];
    
  RELEASE (arp);
}

- (void)queryDidStartGathering:(MDKQuery *)query
{
  [progView start];   
}

- (void)appendRawResults:(NSArray *)lines
{
}

- (void)queryDidUpdateResults:(MDKQuery *)query
                forCategories:(NSArray *)catnames
{
  [resultsView noteNumberOfRowsChanged];
  [resultsView setNeedsDisplayInRect: [resultsView visibleRect]];
  [foundField setStringValue: [NSString stringWithFormat: @"%i", [currentQuery resultsCount]]];  
}

- (void)queryDidEndGathering:(MDKQuery *)query
{
  if (query == currentQuery) {
  //  [query stopQuery];
    [progView stop];
    [foundField setStringValue: [NSString stringWithFormat: @"%i", [currentQuery resultsCount]]];  
  } 
}

- (void)queryDidStartUpdating:(MDKQuery *)query
{
  if (query == currentQuery) {
    [progView start];
  }
}

- (void)queryDidEndUpdating:(MDKQuery *)query
{
  if (query == currentQuery) {
    [progView stop];
    [foundField setStringValue: [NSString stringWithFormat: @"%i", [currentQuery resultsCount]]];  
  }
}

- (IBAction)stopQuery:(id)sender
{
  [currentQuery setUpdatesEnabled: NO];
  [currentQuery stopQuery];
  validResults = NO;
  [progView stop];  
  [resultsView noteNumberOfRowsChanged];
  [resultsView setNeedsDisplayInRect: [resultsView visibleRect]];
  [foundField setStringValue: @"0"];
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
    [self stopQuery: nil];
  }

  if (newquery) {
    [self prepareQuery];
  }
}

- (void)doubleClickOnResultsView:(id)sender
{
  NSEnumerator *enumerator = [resultsView selectedRowEnumerator];
  NSNumber *row;
  
  while ((row = [enumerator nextObject])) {
    unsigned rowind = [row intValue];
    
    if (rowind < [currentQuery resultsCount]) {
      FSNode *node = [[currentQuery resultNodes] objectAtIndex: rowind];
    
      if ([node isValid]) {
        [[NSWorkspace sharedWorkspace] openFile: [node path]];
      } else {
        [currentQuery removeNode: node];
        [resultsView noteNumberOfRowsChanged];
      }
    
    } else {
      [resultsView noteNumberOfRowsChanged];
      break;
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
  if (validResults) {
    return [currentQuery resultsCount];
  }
  return 0;
}

- (id)tableView:(NSTableView *)aTableView
          objectValueForTableColumn:(NSTableColumn *)aTableColumn
                                row:(int)rowIndex
{
  FSNode *nd = [[currentQuery resultNodes] objectAtIndex: rowIndex];
    
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
    FSNode *nd = [[currentQuery resultNodes] objectAtIndex: rowIndex];

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


@implementation ProgrView

#define IMAGES 8

- (void)dealloc
{
  RELEASE (images);
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect 
{
  self = [super initWithFrame: frameRect];

  if (self) {
    int i;
  
    images = [NSMutableArray new];
  
    for (i = 0; i < IMAGES; i++) {
      NSString *imname = [NSString stringWithFormat: @"anim-logo-%d.tiff", i];
      [images addObject: [NSImage imageNamed: imname]];    
    }
  
    rfsh = 0.1;
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







