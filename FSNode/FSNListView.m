/* FSNListView.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: December 2004
 *
 * This file is part of the GNUstep FSNode framework
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
#include "FSNListView.h"
#include "FSNTextCell.h"
#include "FSNFunctions.h"

#define ICNSIZE (24)
#define CELLS_HEIGHT (28.0)
#define HLIGHT_H_FACT (0.8125)

#define DOUBLE_CLICK_LIMIT 300
#define EDIT_CLICK_LIMIT 1000

static NSString *defaultColumns = @"{ \
  <*I0> = { \
    position = <*I0>; \
    identifier = <*I0>; \
    width = <*R140>; \
    minwidth = <*R80>; \
  }; \
  <*I2> = { \
    position = <*I1>; \
    identifier = <*I2>; \
    width = <*R90>; \
    minwidth = <*R80>; \
  }; \
  <*I3> = { \
    position = <*I2>; \
    identifier = <*I3>; \
    width = <*R50>; \
    minwidth = <*R50>; \
  }; \
  <*I1> = { \
    position = <*I3>; \
    identifier = <*I1>; \
    width = <*R90>; \
    minwidth = <*R80>; \
  }; \
}";


@implementation FSNListViewDataSource

- (void)dealloc
{
  TEST_RELEASE (node);
  TEST_RELEASE (extInfoType);
  RELEASE (nodeReps);
  RELEASE (nameEditor);
  TEST_RELEASE (lastSelection);

  [super dealloc];
}

- (id)initForListView:(FSNListView *)aview
{
  self = [super init];

  if (self) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
    NSString *appName = [defaults stringForKey: @"DesktopApplicationName"];
    NSString *selName = [defaults stringForKey: @"DesktopApplicationSelName"];
    id defentry;
    
    listView = aview;
    
    fsnodeRep = [FSNodeRep sharedInstance];
    
    if (appName && selName) {
		  Class desktopAppClass = [[NSBundle mainBundle] classNamed: appName];
      SEL sel = NSSelectorFromString(selName);
      desktopApp = [desktopAppClass performSelector: sel];
    }
    
    defentry = [defaults objectForKey: @"hligh_table_col"];
    hlighColId = defentry ? [defentry intValue] : FSNInfoNameType;
    
    extInfoType = nil;
    defentry = [defaults objectForKey: @"extended_info_type"];

    if (defentry) {
      NSArray *availableTypes = [fsnodeRep availableExtendedInfoNames];

      if ([availableTypes containsObject: defentry]) {
        ASSIGN (extInfoType, defentry);
      }
    }
    
    nodeReps = [NSMutableArray new];    

    nameEditor = [FSNListViewNameEditor new];
    [nameEditor setDelegate: self];  
    [nameEditor setEditable: YES];
    [nameEditor setSelectable: YES];	   
//	  [nameEditor setFont: [cellPrototype font]];
		[nameEditor setBezeled: NO];
		[nameEditor setAlignment: NSLeftTextAlignment];
    
    mouseFlags = 0;
    isDragTarget = NO;
  }
  
  return self;
}

- (FSNode *)infoNode
{
  return node;
}

- (BOOL)keepsColumnsInfo
{
  return NO;
}

- (void)createColumns:(NSDictionary *)info
{
  NSArray *keys = [info keysSortedByValueUsingSelector: @selector(compareTableColumnInfo:)];
  NSTableColumn *column; 
  int i;

  for (i = 0; i < [keys count]; i++) {
    [self addColumn: [info objectForKey: [keys objectAtIndex: i]]];
  }

  column = [listView tableColumnWithIdentifier: [NSNumber numberWithInt: hlighColId]];
  if (column) {
    [listView setHighlightedTableColumn: column];
  }
}

- (void)addColumn:(NSDictionary *)info
{
  NSNumber *identifier = [info objectForKey: @"identifier"];
  int type = [identifier intValue];
  float width = [[info objectForKey: @"width"] floatValue];
  float minwidth = [[info objectForKey: @"minwidth"] floatValue];
  NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier: identifier];
  
  [column setDataCell: AUTORELEASE ([[FSNTextCell alloc] init])];
  [column setEditable: NO];
  [column setResizable: YES];
  [[column headerCell] setAlignment: NSLeftTextAlignment];
  [column setMinWidth: minwidth];
  [column setWidth: width];

  switch(type) {
    case FSNInfoNameType:
      [[column headerCell] setStringValue: NSLocalizedString(@"Name", @"")];
      break;
    case FSNInfoKindType:
      [[column headerCell] setStringValue: NSLocalizedString(@"Kind", @"")];
      break;
    case FSNInfoDateType:
      [[column headerCell] setStringValue: NSLocalizedString(@"Date Modified", @"")];
      break;
    case FSNInfoSizeType:
      [[column headerCell] setStringValue: NSLocalizedString(@"Size", @"")];
      break;
    case FSNInfoOwnerType:
      [[column headerCell] setStringValue: NSLocalizedString(@"Owner", @"")];
      break;
    case FSNInfoParentType:
      [[column headerCell] setStringValue: NSLocalizedString(@"Parent", @"")];
      break;
    case FSNInfoExtendedType:
      [[column headerCell] setStringValue: NSLocalizedString(extInfoType, @"")];
      break;
    default:
      [[column headerCell] setStringValue: NSLocalizedString(@"Name", @"")];
      break;      
  }

  [listView addTableColumn: column];
  RELEASE (column);
}

- (void)removeColumnWithIdentifier:(NSNumber *)identifier
{
  if ([identifier intValue] != FSNInfoNameType) {
    NSTableColumn *column = [listView tableColumnWithIdentifier: identifier];

    if (column) {
      [listView removeTableColumn: column];
      hlighColId = FSNInfoNameType;
      [self sortNodeReps];
      [listView reloadData];
    }
  }
}

- (NSDictionary *)columnsDescription
{
  NSArray *columns = [listView tableColumns];
  NSMutableDictionary *colsinfo = [NSMutableDictionary dictionary];
  
  if (columns) { 
    int i;

    for (i = 0; i < [columns count]; i++) {
      NSTableColumn *column = [columns objectAtIndex: i];
      NSNumber *identifier = [column identifier];
      NSMutableDictionary *dict = [NSMutableDictionary dictionary];

      [dict setObject: [NSNumber numberWithInt: i] 
               forKey: @"position"];
      [dict setObject: identifier 
               forKey: @"identifier"];
      [dict setObject: [NSNumber numberWithFloat: [column width]] 
               forKey: @"width"];
      [dict setObject: [NSNumber numberWithFloat: [column minWidth]] 
               forKey: @"minwidth"];

      [colsinfo setObject: dict forKey: identifier];
    }
  }
   
  return colsinfo;
}

- (void)sortNodeReps
{
  NSTableColumn *column;

  if (hlighColId != FSNInfoExtendedType) {
    SEL sortingSel;
  
    switch(hlighColId) {
      case FSNInfoNameType:
        sortingSel = @selector(compareAccordingToName:);
        break;
      case FSNInfoKindType:
        sortingSel = @selector(compareAccordingToKind:);
        break;
      case FSNInfoDateType:
        sortingSel = @selector(compareAccordingToDate:);
        break;
      case FSNInfoSizeType:
        sortingSel = @selector(compareAccordingToSize:);
        break;
      case FSNInfoOwnerType:
        sortingSel = @selector(compareAccordingToOwner:);
        break;
      default:
        sortingSel = @selector(compareAccordingToName:);
        break;
    }
  
    [nodeReps sortUsingSelector: sortingSel];

  } else {
    [nodeReps sortUsingFunction: (int (*)(id, id, void*))compareWithExtType
                        context: (void *)NULL];
  }

  column = [listView tableColumnWithIdentifier: [NSNumber numberWithInt: hlighColId]];
  if (column) {
    [listView setHighlightedTableColumn: column];
  }
}

- (void)setMouseFlags:(unsigned int)flags
{
  mouseFlags = flags;
}

- (void)doubleClickOnListView:(id)sender
{
  [self openSelectionInNewViewer: NO];
}

- (void)selectRep:(id)aRep
{
  [self selectReps: [NSArray arrayWithObject: aRep]];
}

- (void)unselectRep:(id)aRep
{
  [listView deselectRow: [nodeReps indexOfObjectIdenticalTo: aRep]];
}

- (void)selectIconOfRep:(id)aRep
{
  if ([aRep selectIcon: YES]) {
    [self redisplayRep: aRep];
    [self unSelectIconsOfRepsDifferentFrom: aRep];    
  } 
}

- (void)unSelectIconsOfRepsDifferentFrom:(id)aRep
{
  int i;

  for (i = 0; i < [nodeReps count]; i++) {
    FSNListViewNodeRep *rep = [nodeReps objectAtIndex: i];  
  
    if ((rep != aRep) && [rep selectIcon: NO]) {
      [self redisplayRep: rep];
    }
  }
}

- (void)selectRepInPrevRow
{
  int row = [listView selectedRow];

  if ((row != -1) && (row > 0)) {
    row--;
    [listView selectRowIndexes: [NSIndexSet indexSetWithIndex: row] 
          byExtendingSelection: NO];
    [listView scrollRowToVisible: row];
  }
}

- (void)selectRepInNextRow
{
  int row = [listView selectedRow];

  if ((row != -1) && (row < ([nodeReps count] -1))) {
    row++;
    [listView selectRowIndexes: [NSIndexSet indexSetWithIndex: row] 
          byExtendingSelection: NO];
    [listView scrollRowToVisible: row];
  }
}

- (NSString *)selectRepWithPrefix:(NSString *)prefix
{
	int i;

	for (i = 0; i < [nodeReps count]; i++) {
    FSNListViewNodeRep *rep = [nodeReps objectAtIndex: i];  
    NSString *name = [[rep node] name];
    
		if ([name hasPrefix: prefix]) {
      [listView deselectAll: self];
      [self selectReps: [NSArray arrayWithObject: rep]];
      [listView scrollRowToVisible: i];
      
			return name;
		}
	}
  
  return nil;
}

- (void)redisplayRep:(id)aRep
{
  int row = [nodeReps indexOfObjectIdenticalTo: aRep];
  NSRect rect = [listView rectOfRow: row];
  [listView setNeedsDisplayInRect: rect];
}

- (id)desktopApp
{
  return desktopApp;
}

@end


@implementation FSNListViewDataSource (NSTableViewDataSource)

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
  return [nodeReps count];
}

- (id)tableView:(NSTableView *)aTableView
          objectValueForTableColumn:(NSTableColumn *)aTableColumn
                                row:(int)rowIndex
{
  int ident = [[aTableColumn identifier] intValue];
  FSNListViewNodeRep *rep = [nodeReps objectAtIndex: rowIndex];
  FSNode *nd = [rep node];

  switch(ident) {
    case FSNInfoNameType:
      return [nd name];
      break;
    case FSNInfoKindType:
      return [nd typeDescription];
      break;
    case FSNInfoDateType:
      return [nd modDateDescription];
      break;
    case FSNInfoSizeType:
      return [nd sizeDescription];
      break;
    case FSNInfoOwnerType:
      return [nd owner];
      break;
    case FSNInfoParentType:
      return [nd parentName];
      break;
    case FSNInfoExtendedType:
      return [rep shownInfo];
      break;
    default:
      return [nd name];
      break;
  }
    
  return [NSString string];
}

- (void)tableView:(NSTableView *)aTableView 
            setObjectValue:(id)anObject 
            forTableColumn:(NSTableColumn *)aTableColumn 
                       row:(int)rowIndex
{
}

- (BOOL)tableView:(NSTableView *)aTableView
	      writeRows:(NSArray *)rows
     toPasteboard:(NSPasteboard *)pboard
{
  NSMutableArray *paths = [NSMutableArray array];
  int i;

  for (i = 0; i < [rows count]; i++) {
    int index = [[rows objectAtIndex: i] intValue];
    FSNListViewNodeRep *rep = [nodeReps objectAtIndex: index];

    [paths addObject: [[rep node] path]];
  }

  [pboard declareTypes: [NSArray arrayWithObject: NSFilenamesPboardType] 
                                           owner: nil];
  [pboard setPropertyList: paths forType: NSFilenamesPboardType];

  return YES;
}

- (NSDragOperation)tableView:(NSTableView *)tableView 
                validateDrop:(id <NSDraggingInfo>)info 
                 proposedRow:(int)row 
       proposedDropOperation:(NSTableViewDropOperation)operation
{
  return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)tableView 
       acceptDrop:(id <NSDraggingInfo>)info 
              row:(int)row 
    dropOperation:(NSTableViewDropOperation)operation
{
  return NO;
}

//
// NSTableView delegate methods
//
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
  [self selectionDidChange];
}

- (BOOL)tableView:(NSTableView *)aTableView 
  shouldSelectRow:(int)rowIndex
{
  return ((rowIndex != -1) 
                && ([[nodeReps objectAtIndex: rowIndex] isLocked] == NO));
}

- (void)tableView:(NSTableView *)aTableView 
  willDisplayCell:(id)aCell 
   forTableColumn:(NSTableColumn *)aTableColumn 
              row:(int)rowIndex
{
  int ident = [[aTableColumn identifier] intValue];
  FSNTextCell *cell = (FSNTextCell *)[aTableColumn dataCell];
  FSNListViewNodeRep *rep = [nodeReps objectAtIndex: rowIndex];

  if (ident == FSNInfoNameType) {
    if ([rep iconSelected]) {
      [cell setIcon: [rep openIcon]];
    } else if ([rep isLocked]) {
      [cell setIcon: [rep lockedIcon]];
    } else if ([rep isOpened]) {
      [cell setIcon: [rep spatialOpenIcon]];
    } else {
      [cell setIcon: [rep icon]];
    }
  } else if (ident == FSNInfoDateType) {
    [cell setDateCell: YES];
  }

  if ([rep isLocked]) {
    [cell setTextColor: [NSColor disabledControlTextColor]];
  } else {
    [cell setTextColor: [NSColor controlTextColor]];
  }
}

- (void)tableView:(NSTableView *)tableView 
            mouseDownInHeaderOfTableColumn:(NSTableColumn *)tableColumn
{
  FSNInfoType newOrder = [[tableColumn identifier] intValue];

  if (newOrder != hlighColId) {
    NSArray *selected = [self selectedReps];
    
    [listView deselectAll: self];
    hlighColId = newOrder;
    [self sortNodeReps];
    [listView reloadData];
    
    if ([selected count]) {
      id rep = [selected objectAtIndex: 0];
      int index = [nodeReps indexOfObjectIdenticalTo: rep];
      
      [self selectReps: selected];
      [listView scrollRowToVisible: index];
    }
  }

  [listView setHighlightedTableColumn: tableColumn];
}

- (NSImage *)tableView:(NSTableView *)tableView 
      dragImageForRows:(NSArray *)dragRows
{
  if ([dragRows count] > 1) {
    return [[FSNodeRep sharedInstance] multipleSelectionIconOfSize: 24];
  } else {
    int index = [[dragRows objectAtIndex: 0] intValue];
    return [[nodeReps objectAtIndex: index] icon];
  }

  return nil;
}

- (BOOL)tableView:(NSTableView *)aTableView 
            shouldEditTableColumn:(NSTableColumn *)aTableColumn 
                              row:(int)rowIndex
{
  return NO;
}

@end


@implementation FSNListViewDataSource (NodeRepContainer)

- (void)showContentsOfNode:(FSNode *)anode
{
  NSDictionary *info = nil;
  NSDictionary *colsInfo = nil;
  NSDictionary *colsDescr;
  NSArray *nodes;
  BOOL keepinfo;
  int i;
  
  keepinfo = (node && ([self keepsColumnsInfo] || [node isEqual: anode]));
  
  ASSIGN (node, anode);
  
  if (keepinfo == NO) {
    info = [self readNodeInfo];
  
    if (info) {
      colsInfo = [info objectForKey: @"list_view_columns"];
    }

    if ((colsInfo == nil) || ([colsInfo count] == 0)) {
      colsInfo = [defaultColumns propertyList];
    }
    
    colsDescr = [self columnsDescription];

    if ([colsDescr count] == 0) {
      [self createColumns: colsInfo];

    } else if ([colsDescr isEqual: colsInfo] == NO) {
      while ([listView numberOfColumns] > 0) {
        [listView removeTableColumn: [[listView tableColumns] objectAtIndex: 0]];  
      }

      [self createColumns: colsInfo];
    }
  }
  
  [listView deselectAll: self];

  nodes = [anode subNodes];
  [nodeReps removeAllObjects];

  for (i = 0; i < [nodes count]; i++) {
    [self addRepForSubnode: [nodes objectAtIndex: i]];
  }
  
  [self sortNodeReps];
  [listView reloadData];  

  DESTROY (lastSelection);
  [self selectionDidChange];  
}

- (NSDictionary *)readNodeInfo
{
  FSNode *infoNode = [self infoNode];
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	      
  NSString *prefsname = [NSString stringWithFormat: @"viewer_at_%@", [infoNode path]];
  NSDictionary *nodeDict = nil;

  if ([infoNode isWritable]) {
    NSString *infoPath = [[infoNode path] stringByAppendingPathComponent: @".gwdir"];
  
    if ([[NSFileManager defaultManager] fileExistsAtPath: infoPath]) {
      NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: infoPath];

      if (dict) {
        nodeDict = [NSDictionary dictionaryWithDictionary: dict];
      }   
    }
  }
  
  if (nodeDict == nil) {
    id defEntry = [defaults dictionaryForKey: prefsname];

    if (defEntry) {
      nodeDict = [NSDictionary dictionaryWithDictionary: defEntry];
    }
  }

  if (nodeDict) {
    id entry = [nodeDict objectForKey: @"hligh_table_col"]; 
    hlighColId = entry ? [entry intValue] : hlighColId;

    entry = [nodeDict objectForKey: @"ext_info_type"];

    if (entry) {
      NSArray *availableTypes = [[FSNodeRep sharedInstance] availableExtendedInfoNames];

      if ([availableTypes containsObject: entry]) {
        ASSIGN (extInfoType, entry);
      }
    }
  }
        
  return nodeDict;
}

- (void)updateNodeInfo
{
  FSNode *infoNode = [self infoNode];

  if ([infoNode isValid]) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	      
    NSString *prefsname = [NSString stringWithFormat: @"viewer_at_%@", [infoNode path]];
    NSString *infoPath = [[infoNode path] stringByAppendingPathComponent: @".gwdir"];
    NSMutableDictionary *updatedInfo = nil;

    if ([infoNode isWritable]) {
      if ([[NSFileManager defaultManager] fileExistsAtPath: infoPath]) {
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: infoPath];

        if (dict) {
          updatedInfo = [dict mutableCopy];
        }   
      }
  
    } else { 
      NSDictionary *prefs = [defaults dictionaryForKey: prefsname];
  
      if (prefs) {
        updatedInfo = [prefs mutableCopy];
      }
    }

    if (updatedInfo == nil) {
      updatedInfo = [NSMutableDictionary new];
    }
	
    [updatedInfo setObject: [self columnsDescription] 
                    forKey: @"list_view_columns"];
  
    [updatedInfo setObject: [NSNumber numberWithInt: hlighColId] 
                    forKey: @"hligh_table_col"];

    if (extInfoType) {
      [updatedInfo setObject: extInfoType forKey: @"ext_info_type"];
    }
    
    [updatedInfo writeToFile: infoPath atomically: YES];
    RELEASE (updatedInfo);
  }
}

- (void)reloadContents
{
  CREATE_AUTORELEASE_POOL (pool);
  NSMutableArray *selection = [[self selectedNodes] mutableCopy];
  NSMutableArray *opennodes = [NSMutableArray array];
  int i, count;

  for (i = 0; i < [nodeReps count]; i++) {
    FSNListViewNodeRep *rep = [nodeReps objectAtIndex: i];

    if ([rep isOpened]) {
      [opennodes addObject: [rep node]];
    }
  }
  
  RETAIN (opennodes);

  [self showContentsOfNode: node];
  
  count = [selection count];
  
  for (i = 0; i < count; i++) {
    FSNode *nd = [selection objectAtIndex: i]; 
    
    if ([nd isValid] == NO) {
      [selection removeObjectAtIndex: i];
      count--;
      i--;
    }
  }
  
  for (i = 0; i < [opennodes count]; i++) {
    FSNode *nd = [opennodes objectAtIndex: i]; 
    
    if ([nd isValid]) { 
      FSNListViewNodeRep *rep = [self repOfSubnode: nd];
      
      if (rep) {
        [rep setOpened: YES];
      }
    }
  }
  
  RELEASE (opennodes);

  [self checkLockedReps];

  if ([selection count]) {
    [self selectRepsOfSubnodes: selection];
  }

  RELEASE (selection);
  [self selectionDidChange];

  RELEASE (pool);
}

- (void)reloadFromNode:(FSNode *)anode
{
  if ([node isEqual: anode]) {
    [self reloadContents];
    
  } else if ([node isSubnodeOfNode: anode]) {
    NSArray *components = [FSNode nodeComponentsFromNode: anode toNode: node];
    int i;
  
    for (i = 0; i < [components count]; i++) {
      FSNode *component = [components objectAtIndex: i];
    
      if ([component isValid] == NO) {
        component = [FSNode nodeWithPath: [component parentPath]];
        [self showContentsOfNode: component];
        break;
      }
    }
  }
}

- (FSNode *)baseNode
{
  return node;
}

- (FSNode *)shownNode
{
  return node;
}

- (BOOL)isShowingNode:(FSNode *)anode
{
  return [node isEqual: anode];
}

- (BOOL)isShowingPath:(NSString *)path
{
  return [[node path] isEqual: path];
}

- (void)sortTypeChangedAtPath:(NSString *)path
{
  if ((path == nil) || [[node path] isEqual: path]) {
    [self reloadContents];
  }
}

- (void)nodeContentsWillChange:(NSDictionary *)info
{
  [self checkLockedReps];
}

- (void)nodeContentsDidChange:(NSDictionary *)info
{
  NSString *operation = [info objectForKey: @"operation"];
  NSString *source = [info objectForKey: @"source"];
  NSString *destination = [info objectForKey: @"destination"];
  NSArray *files = [info objectForKey: @"files"];
  NSString *ndpath = [node path];
  BOOL needsreload = NO;
  int i; 

  [self stopRepNameEditing];

  if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
    files = [NSArray arrayWithObject: [source lastPathComponent]];
    source = [source stringByDeletingLastPathComponent]; 
  }

  if ([operation isEqual: @"NSWorkspaceRecycleOperation"]) {
		files = [info objectForKey: @"origfiles"];
  }	

  if (([ndpath isEqual: source] == NO) && ([ndpath isEqual: destination] == NO)) {    
    [self reloadContents];
    return;
  }
  
  if ([ndpath isEqual: source]) {
    if ([operation isEqual: @"NSWorkspaceMoveOperation"]
              || [operation isEqual: @"NSWorkspaceDestroyOperation"]
              || [operation isEqual: @"GWorkspaceRenameOperation"]
			        || [operation isEqual: @"GWorkspaceRecycleOutOperation"]) {
      for (i = 0; i < [files count]; i++) {
        NSString *fname = [files objectAtIndex: i];
        FSNode *subnode = [FSNode nodeWithRelativePath: fname parent: node];
        [self removeRepOfSubnode: subnode];
      }
      needsreload = YES;
    } else if ([operation isEqual: @"NSWorkspaceRecycleOperation"]) {
      [self reloadContents];
      return;
    }
  }

  if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
    files = [NSArray arrayWithObject: [destination lastPathComponent]];
    destination = [destination stringByDeletingLastPathComponent]; 
  }

  if ([ndpath isEqual: destination]
          && ([operation isEqual: @"NSWorkspaceMoveOperation"]   
              || [operation isEqual: @"NSWorkspaceCopyOperation"]
              || [operation isEqual: @"NSWorkspaceLinkOperation"]
              || [operation isEqual: @"NSWorkspaceDuplicateOperation"]
              || [operation isEqual: @"GWorkspaceCreateDirOperation"]
              || [operation isEqual: @"GWorkspaceCreateFileOperation"]
              || [operation isEqual: @"GWorkspaceRenameOperation"]
				      || [operation isEqual: @"GWorkspaceRecycleOutOperation"])) { 
    for (i = 0; i < [files count]; i++) {
      NSString *fname = [files objectAtIndex: i];
      FSNode *subnode = [FSNode nodeWithRelativePath: fname parent: node];
      FSNListViewNodeRep *rep = [self repOfSubnode: subnode];
      
      if (rep) {
        [rep setNode: subnode];
      } else {
        [self addRepForSubnode: subnode];
      }
    }
    needsreload = YES;
  }

  [self checkLockedReps];
  
  if (needsreload) {
    [self sortNodeReps];
    [listView reloadData];
    
    if ([[listView window] isKeyWindow]) {
      if ([operation isEqual: @"GWorkspaceRenameOperation"] 
            || [operation isEqual: @"GWorkspaceCreateDirOperation"]
            || [operation isEqual: @"GWorkspaceCreateFileOperation"]) {
        NSString *fname = [files objectAtIndex: 0];
        NSString *fpath = [destination stringByAppendingPathComponent: fname];
        FSNListViewNodeRep *rep = [self repOfSubnodePath: fpath]; 
        
        if (rep) {  
          int index = [nodeReps indexOfObjectIdenticalTo: rep];
        
          [self selectReps: [NSArray arrayWithObject: rep]];
          [listView scrollRowToVisible: index];
        }
      }
    }
  }  
  
  [listView setNeedsDisplay: YES];  
  [self selectionDidChange];
}

- (void)watchedPathChanged:(NSDictionary *)info
{
  NSString *event = [info objectForKey: @"event"];
  NSArray *files = [info objectForKey: @"files"];
  NSString *ndpath = [node path];
  BOOL needsreload = NO;  
  int i;

  if ([event isEqual: @"GWFileDeletedInWatchedDirectory"]) {
    for (i = 0; i < [files count]; i++) {  
      NSString *fname = [files objectAtIndex: i];
      NSString *fpath = [ndpath stringByAppendingPathComponent: fname];  
      [self removeRepOfSubnodePath: fpath];
    }
    needsreload = YES;
    
  } else if ([event isEqual: @"GWFileCreatedInWatchedDirectory"]) {
    for (i = 0; i < [files count]; i++) {  
      NSString *fname = [files objectAtIndex: i];
      FSNode *subnode = [FSNode nodeWithRelativePath: fname parent: node];
      FSNListViewNodeRep *rep = [self repOfSubnode: subnode];
      
      if (rep) {
        [rep setNode: subnode];
      } else {
        [self addRepForSubnode: subnode];
      }
    }
    needsreload = YES;
  }

  [self sortNodeReps];
  if (needsreload) {
    [listView deselectAll: self];
    [listView reloadData];
  }
  [listView setNeedsDisplay: YES];  
  [self selectionDidChange];
}

//
// Attenzione! I due metodi che seguono sono usati solo per aggiungere
// o togliere colonne. Non hanno nessuna relazione con "hlighColId",
// come invece avviene per gli altri NodeRepContainer. 
// "hlighColId" viene settato solo cliccando sulla headerCell
// di una colonna.
//

- (void)setShowType:(FSNInfoType)type
{
  NSNumber *num = [NSNumber numberWithInt: type];
  NSTableColumn *column = [listView tableColumnWithIdentifier: num];

  if (column == nil) {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    float width, minwidth;

    switch(type) {
      case FSNInfoKindType:
      case FSNInfoOwnerType:
        width = 80.0;
        minwidth = 80.0;
        break;
      case FSNInfoDateType:
      case FSNInfoParentType:
      case FSNInfoExtendedType:
        width = 90.0;
        minwidth = 80.0;
        break;
      case FSNInfoSizeType:
        width = 50.0;
        minwidth = 50.0;
        break;
      default:
        width = 80.0;
        minwidth = 80.0;
        break;      
    }

    [dict setObject: num forKey: @"identifier"];
    [dict setObject: [NSNumber numberWithFloat: width] 
             forKey: @"width"];
    [dict setObject: [NSNumber numberWithFloat: minwidth] 
             forKey: @"minwidth"];
    
    [self addColumn: dict];

  } else {
    [self removeColumnWithIdentifier: num];
  }
}

- (void)setExtendedShowType:(NSString *)type
{
  BOOL wasequal = (extInfoType && [extInfoType isEqual: type]);

  if (extInfoType) {
    NSNumber *num = [NSNumber numberWithInt: FSNInfoExtendedType];
    NSTableColumn *column = [listView tableColumnWithIdentifier: num];

    if (column) {
      [self removeColumnWithIdentifier: num];
    }
    
    DESTROY (extInfoType);
  }

  if (wasequal == NO) {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    int i;
    
    [dict setObject: [NSNumber numberWithInt: FSNInfoExtendedType]
             forKey: @"identifier"];
    [dict setObject: [NSNumber numberWithFloat: 90.0] 
             forKey: @"width"];
    [dict setObject: [NSNumber numberWithFloat: 80.0] 
             forKey: @"minwidth"];
    
    ASSIGN (extInfoType, type);

    for (i = 0; i < [nodeReps count]; i++) {
      FSNListViewNodeRep *rep = [nodeReps objectAtIndex: i];
      [rep setExtendedShowType: extInfoType];
    }

    [self addColumn: dict];
  }
}

- (FSNInfoType)showType
{
  return FSNInfoNameType;
}

- (id)repOfSubnode:(FSNode *)anode
{
  int i;
  
  for (i = 0; i < [nodeReps count]; i++) {
    FSNListViewNodeRep *rep = [nodeReps objectAtIndex: i];
  
    if ([[rep node] isEqual: anode]) {
      return rep;
    }
  }
  
  return nil;
}

- (id)repOfSubnodePath:(NSString *)apath
{
  int i;
  
  for (i = 0; i < [nodeReps count]; i++) {
    FSNListViewNodeRep *rep = [nodeReps objectAtIndex: i];
  
    if ([[[rep node] path] isEqual: apath]) {
      return rep;
    }
  }
  
  return nil;
}

- (id)addRepForSubnode:(FSNode *)anode
{
  FSNListViewNodeRep *rep = [[FSNListViewNodeRep alloc] initForNode: anode
                                                         dataSource: self];
  [nodeReps addObject: rep];
  RELEASE (rep);
  
  return rep;
}

- (void)removeRepOfSubnode:(FSNode *)anode
{
  FSNListViewNodeRep *rep = [self repOfSubnode: anode];
  
  if (rep) {
    [nodeReps removeObject: rep];
  }
}

- (void)removeRepOfSubnodePath:(NSString *)apath
{
  FSNListViewNodeRep *rep = [self repOfSubnodePath: apath];
  
  if (rep) {
    [nodeReps removeObject: rep];
  }
}

- (void)unloadFromNode:(FSNode *)anode
{
  FSNode *parent = [FSNode nodeWithPath: [anode parentPath]];
  [self showContentsOfNode: parent];
}

- (void)unselectOtherReps:(id)arep
{
  if (arep == nil) {
    [listView deselectAll: self];
    [listView setNeedsDisplay: YES];
  }
}

- (void)selectReps:(NSArray *)reps
{
  NSMutableIndexSet *set = [NSMutableIndexSet indexSet];
  int i;

  for (i = 0; i < [reps count]; i++) {
    FSNListViewNodeRep *rep = [reps objectAtIndex: i];
    unsigned int index = [nodeReps indexOfObjectIdenticalTo: rep];
  
    if (index != NSNotFound) {
      [set addIndex: index];
    }
  }
  
  if ([set count]) {
    [listView deselectAll: self];
    [listView selectRowIndexes: set byExtendingSelection: NO];
    [listView setNeedsDisplay: YES];
  }
}

- (void)selectRepsOfSubnodes:(NSArray *)nodes
{
  NSMutableIndexSet *set = [NSMutableIndexSet indexSet];
  unsigned int i;

  for (i = 0; i < [nodeReps count]; i++) {
    FSNListViewNodeRep *rep = [nodeReps objectAtIndex: i];
  
    if ([nodes containsObject: [rep node]]) {
      [set addIndex: i];
    }
  }

  if ([set count]) {
    [listView deselectAll: self];
    [listView selectRowIndexes: set byExtendingSelection: NO];
    [listView setNeedsDisplay: YES];
  }
}

- (void)selectRepsOfPaths:(NSArray *)paths
{
  NSMutableIndexSet *set = [NSMutableIndexSet indexSet];
  unsigned int i;

  for (i = 0; i < [nodeReps count]; i++) {
    FSNListViewNodeRep *rep = [nodeReps objectAtIndex: i];
  
    if ([paths containsObject: [[rep node] path]]) {
      [set addIndex: i];
    }
  }

  if ([set count]) {
    [listView deselectAll: self];
    [listView selectRowIndexes: set byExtendingSelection: NO];
    [listView setNeedsDisplay: YES];
  }
}

- (void)selectAll
{
  [listView selectAll: self];
  [listView setNeedsDisplay: YES];
}

- (void)scrollSelectionToVisible
{
  NSArray *selected = [self selectedReps];
    
  if ([selected count]) {
    id rep = [selected objectAtIndex: 0];
    int index = [nodeReps indexOfObjectIdenticalTo: rep];
    [listView scrollRowToVisible: index];
  } else if ([nodeReps count]) {
    [listView scrollRowToVisible: 0];
  }
}

- (NSArray *)reps
{
  return nodeReps;
}

- (NSArray *)selectedReps
{
  CREATE_AUTORELEASE_POOL (pool);
  NSIndexSet *set = [listView selectedRowIndexes];
  int count = [set count];
  NSRange range = NSMakeRange(0, NSNotFound -1);
  unsigned int *buf = NSZoneMalloc (NSDefaultMallocZone(), sizeof(unsigned int) * count);
  int selcount = [set getIndexes: buf maxCount: count inIndexRange: &range];
  NSMutableArray *selreps = [NSMutableArray array];
  int i;

  for (i = 0; i < selcount; i++) {
    [selreps addObject: [nodeReps objectAtIndex: buf[i]]];
  }

	NSZoneFree (NSDefaultMallocZone(), buf);
  RETAIN (selreps);
  RELEASE (pool);

  return AUTORELEASE (selreps);
}

- (NSArray *)selectedNodes
{
  CREATE_AUTORELEASE_POOL (pool);
  NSIndexSet *set = [listView selectedRowIndexes];
  int count = [set count];
  NSRange range = NSMakeRange(0, NSNotFound -1);
  unsigned int *buf = NSZoneMalloc (NSDefaultMallocZone(), sizeof(unsigned int) * count);
  int selcount = [set getIndexes: buf maxCount: count inIndexRange: &range];
  NSMutableArray *selnodes = [NSMutableArray array];
  int i;

  for (i = 0; i < selcount; i++) {
    [selnodes addObject: [[nodeReps objectAtIndex: buf[i]] node]];
  }

	NSZoneFree (NSDefaultMallocZone(), buf);
  RETAIN (selnodes);
  RELEASE (pool);

  return AUTORELEASE (selnodes);
}

- (NSArray *)selectedPaths
{
  CREATE_AUTORELEASE_POOL (pool);
  NSIndexSet *set = [listView selectedRowIndexes];
  int count = [set count];
  NSRange range = NSMakeRange(0, NSNotFound -1);
  unsigned int *buf = NSZoneMalloc (NSDefaultMallocZone(), sizeof(unsigned int) * count);
  int selcount = [set getIndexes: buf maxCount: count inIndexRange: &range];
  NSMutableArray *selpaths = [NSMutableArray array];
  int i;

  for (i = 0; i < selcount; i++) {
    [selpaths addObject: [[[nodeReps objectAtIndex: buf[i]] node] path]];
  }

	NSZoneFree (NSDefaultMallocZone(), buf);
  RETAIN (selpaths);
  RELEASE (pool);

  return AUTORELEASE (selpaths);
}

- (void)selectionDidChange
{
  NSArray *selection = [self selectedPaths];

  if ([selection count] == 0) {
    selection = [NSArray arrayWithObject: [node path]];
  }

  if ((lastSelection == nil) || ([selection isEqual: lastSelection] == NO)) {
    ASSIGN (lastSelection, selection);
    [desktopApp selectionChanged: selection];
  }
}

- (void)checkLockedReps
{
  int i;
  
  for (i = 0; i < [nodeReps count]; i++) {
    [[nodeReps objectAtIndex: i] checkLocked];
  }
}

- (void)openSelectionInNewViewer:(BOOL)newv
{
  [desktopApp openSelectionInNewViewer: newv];  
}

- (void)setLastShownNode:(FSNode *)anode
{
}

- (BOOL)needsDndProxy
{
  return YES;
}

- (BOOL)involvedByFileOperation:(NSDictionary *)opinfo
{
  return [node involvedByFileOperation: opinfo];
}

- (BOOL)validatePasteOfFilenames:(NSArray *)names
                       wasCutted:(BOOL)cutted
{
  NSString *nodePath = [node path];
  NSString *prePath = [NSString stringWithString: nodePath];
  NSString *basePath;
  
	if ([names count] == 0) {
		return NO;
  } 

  if ([node isWritable] == NO) {
    return NO;
  }
    
  basePath = [[names objectAtIndex: 0] stringByDeletingLastPathComponent];
  if ([basePath isEqual: nodePath]) {
    return NO;
  }  
    
  if ([names containsObject: nodePath]) {
    return NO;
  }

  while (1) {
    if ([names containsObject: prePath]) {
      return NO;
    }
    if ([prePath isEqual: path_separator()]) {
      break;
    }            
    prePath = [prePath stringByDeletingLastPathComponent];
  }

  return YES;
}

- (void)stopRepNameEditing
{
  if (nameEditor && [[listView subviews] containsObject: nameEditor]) {
    [nameEditor abortEditing];
    [nameEditor setEditable: NO];
    [nameEditor setSelectable: NO];
    [nameEditor setNode: nil stringValue: @"" index: -1];
    [nameEditor removeFromSuperview];
    [listView setNeedsDisplayInRect: [nameEditor frame]];
    [[NSCursor arrowCursor] set];
  }
}

@end


@implementation FSNListViewDataSource (RepNameEditing)

- (void)setEditorAtRow:(int)row
{
  if ([[listView selectedRowIndexes] count] == 1) {
    FSNListViewNodeRep *rep = [nodeReps objectAtIndex: row];  
    FSNode *nd = [rep node];
    BOOL canedit = (([rep isLocked] == NO) && ([nd isMountPoint] == NO));
    
    [self stopRepNameEditing];
  
    if (canedit) {   
      NSNumber *num = [NSNumber numberWithInt: FSNInfoNameType];
      unsigned col = [listView columnWithIdentifier: num];
      NSRect r = [listView frameOfCellAtColumn: col row: row];
      NSFont *edfont = [nameEditor font];
      float fnheight = [edfont defaultLineHeightForFont];  
      float xshift = [[rep icon] size].width + 4;
  
      r.origin.y += ((r.size.height - fnheight) / 2);
      r.size.height = fnheight;
      r.origin.x += xshift;
      r.size.width -= xshift;
      r = NSIntegralRect(r);  
      [nameEditor setFrame: r];

      [nameEditor setNode: nd stringValue: [nd name] index: 0];

      [nameEditor setEditable: YES];
      [nameEditor setSelectable: YES];	
      [listView addSubview: nameEditor];
    }
  }
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
  NSFileManager *fm = [NSFileManager defaultManager];
  FSNode *ednode = [nameEditor node];

#define CLEAREDITING \
  [self stopRepNameEditing]; \
  return 
    
  if ([ednode isWritable] == NO) {
    NSRunAlertPanel(NSLocalizedString(@"Error", @""), 
          [NSString stringWithFormat: @"%@\"%@\"!\n", 
              NSLocalizedString(@"You have not write permission for ", @""), 
                    [ednode name]], NSLocalizedString(@"Continue", @""), nil, nil);   
    CLEAREDITING;
    
  } else if ([fm isWritableFileAtPath: [ednode parentPath]] == NO) {
    NSRunAlertPanel(NSLocalizedString(@"Error", @""), 
          [NSString stringWithFormat: @"%@\"%@\"!\n", 
              NSLocalizedString(@"You have not write permission for ", @""), 
                  [ednode parentName]], NSLocalizedString(@"Continue", @""), nil, nil);   
    CLEAREDITING;
    
  } else {
    NSString *newname = [nameEditor stringValue];
    NSString *newpath = [[ednode parentPath] stringByAppendingPathComponent: newname];
    NSCharacterSet *notAllowSet = [NSCharacterSet characterSetWithCharactersInString: @"/\\*:?"];
    NSRange range = [newname rangeOfCharacterFromSet: notAllowSet];
    NSFileManager *fm = [NSFileManager defaultManager];    
    NSArray *dirContents = [fm directoryContentsAtPath: [ednode parentPath]];
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    
    if (range.length > 0) {
      NSRunAlertPanel(NSLocalizedString(@"Error", @""), 
                NSLocalizedString(@"Invalid char in name", @""), 
                          NSLocalizedString(@"Continue", @""), nil, nil);   
      CLEAREDITING;
    }	

    if ([dirContents containsObject: newname]) {
      if ([newname isEqual: [ednode name]]) {
        CLEAREDITING;
      } else {
        NSRunAlertPanel(NSLocalizedString(@"Error", @""), 
          [NSString stringWithFormat: @"%@\"%@\" %@ ", 
              NSLocalizedString(@"The name ", @""), 
              newname, NSLocalizedString(@" is already in use!", @"")], 
                            NSLocalizedString(@"Continue", @""), nil, nil);   
        CLEAREDITING;
      }
    }

	  [userInfo setObject: @"GWorkspaceRenameOperation" forKey: @"operation"];	
    [userInfo setObject: [ednode path] forKey: @"source"];	
    [userInfo setObject: newpath forKey: @"destination"];	
    [userInfo setObject: [NSArray arrayWithObject: @""] forKey: @"files"];	

    [desktopApp removeWatcherForPath: [node path]];

//    [[NSDistributedNotificationCenter defaultCenter]
// 				postNotificationName: @"GWFileSystemWillChangeNotification"
//	 								    object: nil 
//                    userInfo: userInfo];
    
    [fm movePath: [ednode path] toPath: newpath handler: self];
    
    [[NSDistributedNotificationCenter defaultCenter]
 				postNotificationName: @"GWFileSystemDidChangeNotification"
	 								    object: nil 
                    userInfo: userInfo];
                    
    [desktopApp addWatcherForPath: [node path]];

    CLEAREDITING;
  }
}

- (BOOL)fileManager:(NSFileManager *)manager 
              shouldProceedAfterError:(NSDictionary *)errorDict
{
	NSString *title = NSLocalizedString(@"Error", @"");
	NSString *msg1 = NSLocalizedString(@"Cannot rename ", @"");
  NSString *name = [[nameEditor node] name];
	NSString *msg2 = NSLocalizedString(@"Continue", @"");

  NSRunAlertPanel(title, [NSString stringWithFormat: @"%@'%@'!", msg1, name], msg2, nil, nil);   

	return NO;
}

- (void)fileManager:(NSFileManager *)manager 
    willProcessPath:(NSString *)path
{
}

@end


@implementation FSNListViewDataSource (DraggingDestination)

- (BOOL)checkDraggingLocation:(NSPoint)loc
{
  if (NSEqualRects(dndValidRect, NSZeroRect)) {
    NSNumber *num = [NSNumber numberWithInt: FSNInfoNameType];
    unsigned col = [listView columnWithIdentifier: num];
    
    dndValidRect = [listView rectOfColumn: col];
  }
  
  return NSPointInRect(loc, dndValidRect);
}

- (unsigned int)checkReturnValueForRep:(FSNListViewNodeRep *)arep
                      withDraggingInfo:(id <NSDraggingInfo>)sender
{
  if (dndTarget != arep) {
    dndTarget = arep;
    dragOperation = [dndTarget repDraggingEntered: sender];
    
    if (dragOperation != NSDragOperationNone) {
      [self selectIconOfRep: dndTarget];
    } else {
      [self unSelectIconsOfRepsDifferentFrom: nil];
    }
  }
  
  return dragOperation;
}

- (unsigned int)listViewDraggingEntered:(id <NSDraggingInfo>)sender
{
  NSPoint location;
  int row;
  
  isDragTarget = NO;
  dndTarget = nil;
  dragOperation = NSDragOperationNone;
  dndValidRect = NSZeroRect;
  
  location = [[listView window] mouseLocationOutsideOfEventStream];
  location = [listView convertPoint: location fromView: nil];
  row = [listView rowAtPoint: location];
  
  if (row != -1) {
    if ([self checkDraggingLocation: location]) {
      dndTarget = [nodeReps objectAtIndex: row];
      dragOperation = [dndTarget repDraggingEntered: sender];

      if (dragOperation != NSDragOperationNone) {
        [self selectIconOfRep: dndTarget];
      } else {
        [self unSelectIconsOfRepsDifferentFrom: nil];
      }
    } else {
      [self unSelectIconsOfRepsDifferentFrom: nil];
      dragOperation = NSDragOperationNone;
    }
  }     

  if (dragOperation == NSDragOperationNone) {
	  NSPasteboard *pb;
    NSDragOperation sourceDragMask;
	  NSArray *sourcePaths;
    NSString *basePath;
    NSString *nodePath;
    NSString *prePath;
	  int count;

    dndTarget = nil;
    isDragTarget = NO;

    pb = [sender draggingPasteboard];

    if (pb && [[pb types] containsObject: NSFilenamesPboardType]) {
      sourcePaths = [pb propertyListForType: NSFilenamesPboardType]; 

    } else if ([[pb types] containsObject: @"GWRemoteFilenamesPboardType"]) {
      NSData *pbData = [pb dataForType: @"GWRemoteFilenamesPboardType"]; 
      NSDictionary *pbDict = [NSUnarchiver unarchiveObjectWithData: pbData];

      sourcePaths = [pbDict objectForKey: @"paths"];

    } else if ([[pb types] containsObject: @"GWLSFolderPboardType"]) {
      NSData *pbData = [pb dataForType: @"GWLSFolderPboardType"]; 
      NSDictionary *pbDict = [NSUnarchiver unarchiveObjectWithData: pbData];

      sourcePaths = [pbDict objectForKey: @"paths"];

    } else {
      return NSDragOperationNone;
    }

	  count = [sourcePaths count];
	  if (count == 0) {
		  return NSDragOperationNone;
    } 

    if ([node isWritable] == NO) {
      return NSDragOperationNone;
    }

    nodePath = [node path];

    basePath = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];
    if ([basePath isEqual: nodePath]) {
      return NSDragOperationNone;
    }

    if ([sourcePaths containsObject: nodePath]) {
      return NSDragOperationNone;
    }

    prePath = [NSString stringWithString: nodePath];

    while (1) {
      if ([sourcePaths containsObject: prePath]) {
        return NSDragOperationNone;
      }
      if ([prePath isEqual: path_separator()]) {
        break;
      }            
      prePath = [prePath stringByDeletingLastPathComponent];
    }

    isDragTarget = YES;	
    forceCopy = NO;

	  sourceDragMask = [sender draggingSourceOperationMask];

	  if (sourceDragMask == NSDragOperationCopy) {
		  return NSDragOperationCopy;
	  } else if (sourceDragMask == NSDragOperationLink) {
		  return NSDragOperationLink;
	  } else {
      if ([[NSFileManager defaultManager] isWritableFileAtPath: basePath]) {
        return NSDragOperationAll;			
      } else {
        forceCopy = YES;
			  return NSDragOperationCopy;			
      }
	  }		
  }

  return dragOperation;
}

- (unsigned int)listViewDraggingUpdated:(id <NSDraggingInfo>)sender
{
  NSPoint location;
  int row;
  
  location = [[listView window] mouseLocationOutsideOfEventStream];
  location = [listView convertPoint: location fromView: nil];
  
  row = [listView rowAtPoint: location];
  
  if (row != -1) {
    if ([self checkDraggingLocation: location]) {
      [self checkReturnValueForRep: [nodeReps objectAtIndex: row] 
                  withDraggingInfo: sender];
    } else {
      [self unSelectIconsOfRepsDifferentFrom: nil];
      dndTarget = nil;
      dragOperation = NSDragOperationNone;
    }
  } else {
    dndTarget = nil;
    dragOperation = NSDragOperationNone;
  }
  
  if (dragOperation == NSDragOperationNone) {
    NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];

    dndTarget = nil;  

	  if (isDragTarget == NO) {
		  return NSDragOperationNone;
	  }

	  if (sourceDragMask == NSDragOperationCopy) {
		  return NSDragOperationCopy;
	  } else if (sourceDragMask == NSDragOperationLink) {
		  return NSDragOperationLink;
	  } else {
		  return forceCopy ? NSDragOperationCopy : NSDragOperationAll;
	  }
  }

  return dragOperation;
}

- (void)listViewDraggingExited:(id <NSDraggingInfo>)sender
{
  isDragTarget = NO;
  dndTarget = nil;
  dndValidRect = NSZeroRect;  
  [self unSelectIconsOfRepsDifferentFrom: nil];
}

- (BOOL)listViewPrepareForDragOperation:(id <NSDraggingInfo>)sender
{
  return ((dndTarget != nil) || isDragTarget);
}

- (BOOL)listViewPerformDragOperation:(id <NSDraggingInfo>)sender
{
  return ((dndTarget != nil) || isDragTarget);
}

- (void)listViewConcludeDragOperation:(id <NSDraggingInfo>)sender
{
  if (dndTarget) {
    [dndTarget repConcludeDragOperation: sender];
    [self unSelectIconsOfRepsDifferentFrom: nil];
  } else {
	  NSPasteboard *pb;
    NSDragOperation sourceDragMask;
	  NSArray *sourcePaths;
    NSString *operation, *source;
    NSMutableArray *files;
	  NSMutableDictionary *opDict;
	  NSString *trashPath;
    int i;

	  sourceDragMask = [sender draggingSourceOperationMask];
    pb = [sender draggingPasteboard];

    if ([[pb types] containsObject: @"GWRemoteFilenamesPboardType"]) {  
      NSData *pbData = [pb dataForType: @"GWRemoteFilenamesPboardType"]; 

      [desktopApp concludeRemoteFilesDragOperation: pbData
                                       atLocalPath: [node path]];
      isDragTarget = NO;
      dndTarget = nil;
      dndValidRect = NSZeroRect;
      return;
      
    } else if ([[pb types] containsObject: @"GWLSFolderPboardType"]) {  
      NSData *pbData = [pb dataForType: @"GWLSFolderPboardType"]; 

      [desktopApp lsfolderDragOperation: pbData
                        concludedAtPath: [node path]];
      isDragTarget = NO;
      dndTarget = nil;
      dndValidRect = NSZeroRect;
      return;
    }

    sourcePaths = [pb propertyListForType: NSFilenamesPboardType];

    if ([sourcePaths count] == 0) {
      isDragTarget = NO;
      dndTarget = nil;
      dndValidRect = NSZeroRect;
      return;
    }

    source = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];

    trashPath = [desktopApp trashPath];

    if ([source isEqual: trashPath]) {
      operation = @"GWorkspaceRecycleOutOperation";
	  } else {	
		  if (sourceDragMask == NSDragOperationCopy) {
			  operation = NSWorkspaceCopyOperation;
		  } else if (sourceDragMask == NSDragOperationLink) {
			  operation = NSWorkspaceLinkOperation;
		  } else {
        if ([[NSFileManager defaultManager] isWritableFileAtPath: source]) {
			    operation = NSWorkspaceMoveOperation;
        } else {
			    operation = NSWorkspaceCopyOperation;
        }
		  }
    }

    files = [NSMutableArray array];    
    for(i = 0; i < [sourcePaths count]; i++) {    
      [files addObject: [[sourcePaths objectAtIndex: i] lastPathComponent]];
    }  

	  opDict = [NSMutableDictionary dictionary];
	  [opDict setObject: operation forKey: @"operation"];
	  [opDict setObject: source forKey: @"source"];
	  [opDict setObject: [node path] forKey: @"destination"];
	  [opDict setObject: files forKey: @"files"];

    [desktopApp performFileOperation: opDict];
  }
  
  isDragTarget = NO;
  dndTarget = nil;
  dndValidRect = NSZeroRect;
}

@end


@implementation FSNListViewNodeRep

- (void)dealloc
{
  RELEASE (icon); 
  TEST_RELEASE (openicon); 
  TEST_RELEASE (lockedicon); 
  TEST_RELEASE (spopenicon); 
  RELEASE (extInfoStr); 
  [super dealloc];
}

- (id)initForNode:(FSNode *)anode
       dataSource:(FSNListViewDataSource *)fsnds
{
  self = [super init];
  
  if (self) {
    dataSource = fsnds;
    fsnodeRep = [FSNodeRep sharedInstance];

    ASSIGN (node, anode);
    ASSIGN (icon, [fsnodeRep iconOfSize: ICNSIZE forNode: node]);
    
    openicon = nil;
    lockedicon = nil;
    spopenicon = nil;
    
    ASSIGN (extInfoStr, [NSString string]);
    
    isLocked = NO;
    iconSelected = NO;
    isOpened = NO;
    wasOpened = NO;
    nameEdited = NO;
  }

  return self;
}

- (NSImage *)icon
{
  return icon;
}

- (NSImage *)openIcon
{
  return openicon;
}

- (NSImage *)lockedIcon
{
  return lockedicon;
}

- (NSImage *)spatialOpenIcon
{
  return spopenicon;
}

- (BOOL)selectIcon:(BOOL)value
{
  if ((iconSelected != value) || (isOpened != wasOpened)) {
    iconSelected = value;

    if (iconSelected && ((openicon == nil) || (isOpened != wasOpened))) {
      NSImage *opicn = [fsnodeRep openFolderIconOfSize: ICNSIZE forNode: node];

      if (isOpened) {
        DESTROY (openicon);
        openicon = [[NSImage alloc] initWithSize: [opicn size]];
        [openicon lockFocus];
        [opicn dissolveToPoint: NSZeroPoint fraction: 0.5];
        [openicon unlockFocus];
      } else {
        ASSIGN (openicon, opicn);
      }
    }
  }
  
  return YES;
}

- (BOOL)iconSelected
{
  return iconSelected;
}


//
// FSNodeRep protocol
//
- (void)setNode:(FSNode *)anode
{
  ASSIGN (node, anode);
  ASSIGN (icon, [fsnodeRep iconOfSize: ICNSIZE forNode: node]);  
  [self setLocked: [node isLocked]];
}

- (void)setNode:(FSNode *)anode
   nodeInfoType:(FSNInfoType)type
   extendedType:(NSString *)exttype
{
  [self setNode: anode];
}

- (FSNode *)node
{
  return node;
}

- (void)showSelection:(NSArray *)selnodes
{
}

- (BOOL)isShowingSelection
{
  return NO;
}

- (NSArray *)selection
{
  return nil;
}

- (NSArray *)pathsSelection
{
  return nil;
}

- (void)setFont:(NSFont *)fontObj
{
}

- (NSFont *)labelFont
{
  return nil;
}

- (void)setLabelTextColor:(NSColor *)acolor
{
}

- (NSColor *)labelTextColor
{
  return nil;
}

- (void)setIconSize:(int)isize
{
}

- (int)iconSize
{
  return ICNSIZE;
}

- (void)setIconPosition:(unsigned int)ipos
{
}

- (int)iconPosition
{
  return NSImageLeft;
}

- (NSRect)labelRect
{
  return NSZeroRect;
}

- (void)setNodeInfoShowType:(FSNInfoType)type
{
}

- (BOOL)setExtendedShowType:(NSString *)type
{
  NSDictionary *info = [fsnodeRep extendedInfoOfType: type forNode: node];

  if (info) {
    ASSIGN (extInfoStr, [info objectForKey: @"labelstr"]);
  }

  return YES;
}

- (FSNInfoType)nodeInfoShowType
{
  return FSNInfoNameType;
}

- (NSString *)shownInfo
{
  // we returns allways extInfoStr because
  // the other info is got from the node by
  // FSNListViewDataSource
  return extInfoStr;
}

- (void)setNameEdited:(BOOL)value
{
  nameEdited = value;
}

- (void)setLeaf:(BOOL)flag
{
}

- (BOOL)isLeaf
{
  return YES;
}

- (void)select
{
  [dataSource selectRep: self];
}

- (void)unselect
{
  [dataSource unselectRep: self];
}

- (BOOL)isSelected
{
  return NO;
}

- (void)setOpened:(BOOL)value
{
  wasOpened = isOpened;

  if (isOpened != value) {
    isOpened = value;

    if (isOpened && (spopenicon == nil)) {
      spopenicon = [[NSImage alloc] initWithSize: [icon size]];
      [spopenicon lockFocus];
      [icon dissolveToPoint: NSZeroPoint fraction: 0.5];
      [spopenicon unlockFocus];
    } 
    
    [self selectIcon: iconSelected];
    [dataSource redisplayRep: self];
  }
}

- (BOOL)isOpened
{
  return isOpened;
}

- (void)setLocked:(BOOL)value
{
  if (isLocked != value) {
    isLocked = value;

    if (isLocked && (lockedicon == nil)) {
      lockedicon = [[NSImage alloc] initWithSize: [icon size]];
      [lockedicon lockFocus];
      [icon dissolveToPoint: NSZeroPoint fraction: 0.3];
      [lockedicon unlockFocus];
    }
    
    [dataSource redisplayRep: self];
  }
}

- (BOOL)isLocked
{
  return isLocked;
}

- (void)checkLocked
{
  [self setLocked: [node isLocked]];
}

- (void)setGridIndex:(int)index
{
}

- (int)gridIndex
{
  return 0;
}

- (int)compareAccordingToName:(id)aObject
{
  return [node compareAccordingToName: [aObject node]];
}

- (int)compareAccordingToKind:(id)aObject;
{
  return [node compareAccordingToKind: [aObject node]];
}

- (int)compareAccordingToDate:(id)aObject
{
  return [node compareAccordingToDate: [aObject node]];
}

- (int)compareAccordingToSize:(id)aObject
{
  return [node compareAccordingToSize: [aObject node]];
}

- (int)compareAccordingToOwner:(id)aObject
{
  return [node compareAccordingToOwner: [aObject node]];
}

- (int)compareAccordingToGroup:(id)aObject
{
  return [node compareAccordingToGroup: [aObject node]];
}

- (int)compareAccordingToIndex:(id)aObject
{
  return NSOrderedSame;
}

@end


@implementation FSNListViewNodeRep (DraggingDestination)

- (unsigned int)repDraggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb;
  NSDragOperation sourceDragMask;
	NSArray *sourcePaths;
	NSString *fromPath;
  NSString *nodePath;
  NSString *prePath;
	int count;

  isDragTarget = NO;
	
  if (isLocked || ([node isDirectory] == NO) 
                    || [node isPackage] || ([node isWritable] == NO)) {
    return NSDragOperationNone;
  }
  	
	pb = [sender draggingPasteboard];

  if ([[pb types] containsObject: NSFilenamesPboardType]) {
    sourcePaths = [pb propertyListForType: NSFilenamesPboardType]; 
       
  } else if ([[pb types] containsObject: @"GWRemoteFilenamesPboardType"]) {
    NSData *pbData = [pb dataForType: @"GWRemoteFilenamesPboardType"]; 
    NSDictionary *pbDict = [NSUnarchiver unarchiveObjectWithData: pbData];
    
    sourcePaths = [pbDict objectForKey: @"paths"];

  } else if ([[pb types] containsObject: @"GWLSFolderPboardType"]) {
    NSData *pbData = [pb dataForType: @"GWLSFolderPboardType"]; 
    NSDictionary *pbDict = [NSUnarchiver unarchiveObjectWithData: pbData];
    
    sourcePaths = [pbDict objectForKey: @"paths"];

  } else {
    return NSDragOperationNone;
  }
  
	count = [sourcePaths count];
	if (count == 0) {
		return NSDragOperationNone;
  } 
  
  nodePath = [node path];

	fromPath = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];

	if ([nodePath isEqual: fromPath]) {
		return NSDragOperationNone;
  }  

  if ([sourcePaths containsObject: nodePath]) {
    return NSDragOperationNone;
  }

  prePath = [NSString stringWithString: nodePath];

  while (1) {
    if ([sourcePaths containsObject: prePath]) {
      return NSDragOperationNone;
    }
    if ([prePath isEqual: path_separator()]) {
      break;
    }            
    prePath = [prePath stringByDeletingLastPathComponent];
  }

  isDragTarget = YES;
  forceCopy = NO;

	sourceDragMask = [sender draggingSourceOperationMask];

	if (sourceDragMask == NSDragOperationCopy) {
		return NSDragOperationCopy;
	} else if (sourceDragMask == NSDragOperationLink) {
		return NSDragOperationLink;
	} else {
    if ([[NSFileManager defaultManager] isWritableFileAtPath: fromPath]) {
      return NSDragOperationAll;			
    } else {
      forceCopy = YES;
			return NSDragOperationCopy;			
    }
	}
    
  return NSDragOperationNone;
}

- (void)repConcludeDragOperation:(id <NSDraggingInfo>)sender
{
  id <DesktopApplication> desktopApp = [dataSource desktopApp];
	NSPasteboard *pb = [sender draggingPasteboard];
  NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
	NSArray *sourcePaths;
  NSString *operation, *source;
  NSMutableArray *files;
	NSMutableDictionary *opDict;
	NSString *trashPath;
  int i;

  if ([[pb types] containsObject: @"GWRemoteFilenamesPboardType"]) {  
    NSData *pbData = [pb dataForType: @"GWRemoteFilenamesPboardType"]; 

    [desktopApp concludeRemoteFilesDragOperation: pbData
                                     atLocalPath: [node path]];
    return;
    
  } else if ([[pb types] containsObject: @"GWLSFolderPboardType"]) {  
    NSData *pbData = [pb dataForType: @"GWLSFolderPboardType"]; 

    [desktopApp lsfolderDragOperation: pbData
                      concludedAtPath: [node path]];
    return;
  }

  sourcePaths = [pb propertyListForType: NSFilenamesPboardType];

  source = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];
  
  trashPath = [desktopApp trashPath];

  if ([source isEqual: trashPath]) {
    operation = @"GWorkspaceRecycleOutOperation";
	} else {	
		if (sourceDragMask == NSDragOperationCopy) {
			operation = NSWorkspaceCopyOperation;
		} else if (sourceDragMask == NSDragOperationLink) {
			operation = NSWorkspaceLinkOperation;
		} else {
      if ([[NSFileManager defaultManager] isWritableFileAtPath: source]) {
			  operation = NSWorkspaceMoveOperation;
      } else {
			  operation = NSWorkspaceCopyOperation;
      }
		}
  }
  
  files = [NSMutableArray arrayWithCapacity: 1];    
  for(i = 0; i < [sourcePaths count]; i++) {    
    [files addObject: [[sourcePaths objectAtIndex: i] lastPathComponent]];
  }  

	opDict = [NSMutableDictionary dictionaryWithCapacity: 4];
	[opDict setObject: operation forKey: @"operation"];
	[opDict setObject: source forKey: @"source"];
	[opDict setObject: [node path] forKey: @"destination"];
	[opDict setObject: files forKey: @"files"];

  [desktopApp performFileOperation: opDict];
}

@end


@implementation FSNListViewNameEditor

- (void)dealloc
{
  TEST_RELEASE (node);
  [super dealloc];
}

- (void)setNode:(FSNode *)anode 
    stringValue:(NSString *)str
          index:(int)idx
{
  DESTROY (node);
  if (anode) {
    ASSIGN (node, anode);
  } 
  [self setStringValue: str];
  index = idx;
}

- (FSNode *)node
{
  return node;
}

- (int)index
{
  return index;
}

- (void)mouseDown:(NSEvent*)theEvent
{
  if ([self isEditable]) {
    [[self window] makeFirstResponder: self];
  }
  [super mouseDown: theEvent];
}

@end


@implementation FSNListView

- (void)dealloc
{
  TEST_RELEASE (charBuffer);  
  RELEASE (dsource);  
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect
    dataSourceClass:(Class)dsclass
{
  self = [super initWithFrame: frameRect];

  if (self) {
    [self setDrawsGrid: NO];
    [self setAllowsColumnSelection: NO];
    [self setAllowsColumnReordering: YES];
    [self setAllowsColumnResizing: YES];
    [self setAllowsEmptySelection: YES];
    [self setAllowsMultipleSelection: YES];
    [self setRowHeight: CELLS_HEIGHT];
    [self setIntercellSpacing: NSZeroSize];

    dsource = [[dsclass alloc] initForListView: self];

    [self setDataSource: dsource]; 
    [self setDelegate: dsource];
    [self setTarget: dsource];
    [self setDoubleAction: @selector(doubleClickOnListView:)];
  
    editstamp = 0.0;
    editindex = -1;

		lastKeyPressed = 0.;
    charBuffer = nil;
  
    [self registerForDraggedTypes: [NSArray arrayWithObjects: 
                                                NSFilenamesPboardType, 
                                                @"GWLSFolderPboardType", 
                                                @"GWRemoteFilenamesPboardType", 
                                                nil]];    
  }
  
  return self;
}

- (void)checkSize
{
  id sview = [self superview];
  if (sview && ([self frame].size.width < [sview frame].size.width)) {
    [self sizeLastColumnToFit];  
  }
}

- (void)mouseDown:(NSEvent*)theEvent
{
  NSPoint location;
  int clickCount;
  int row;
  
  [dsource setMouseFlags: [theEvent modifierFlags]];
    
  [dsource stopRepNameEditing];
  
  [super mouseDown: theEvent];
  
  clickCount = [theEvent clickCount];
  
  if (clickCount >= 2) {
    editindex = -1;
    return;
  }

  if ([theEvent modifierFlags] & NSShiftKeyMask) {
    editindex = -1;
    return;
  }
  
  location = [theEvent locationInWindow];
  location = [self convertPoint: location fromView: nil];
  row = [self rowAtPoint: location];
  
  if (row != -1) {
    if (editindex != row) {
      editindex = row;
            
    } else {
      NSTimeInterval interval = ([theEvent timestamp] - editstamp);
          
      if ((interval > DOUBLE_CLICK_LIMIT)
                                && (interval < EDIT_CLICK_LIMIT)) {
        [dsource setEditorAtRow: row];
      }
    }
    
    editstamp = [theEvent timestamp];   
  }
}

- (void)keyDown:(NSEvent *)theEvent
{
	NSString *characters = [theEvent characters];
	unichar character = 0;
	NSRect vRect, hiddRect;
	NSPoint p;
	float x, y, w, h;

  if ([characters length] > 0) {
		character = [characters characterAtIndex: 0];
	}

  switch (character) {
    case NSPageUpFunctionKey:
		  vRect = [self visibleRect];
		  p = vRect.origin;
		  x = p.x;
		  y = p.y - vRect.size.height;
		  w = vRect.size.width;
		  h = vRect.size.height;
		  hiddRect = NSMakeRect(x, y, w, h);
		  [self scrollRectToVisible: hiddRect];
	    return;

    case NSPageDownFunctionKey:
		  vRect = [self visibleRect];
		  p = vRect.origin;    
		  x = p.x;
		  y = p.y + vRect.size.height;
		  w = vRect.size.width;
		  h = vRect.size.height;
		  hiddRect = NSMakeRect(x, y, w, h);
		  [self scrollRectToVisible: hiddRect];
	    return;

    case NSUpArrowFunctionKey:
	    [dsource selectRepInPrevRow];
      return;

    case NSDownArrowFunctionKey:
	    [dsource selectRepInNextRow];
      return;
  
		case NSCarriageReturnCharacter:
      {
        unsigned flags = [theEvent modifierFlags];
        BOOL closesndr = ((flags == NSAlternateKeyMask) 
                                  || (flags == NSControlKeyMask));
        [dsource openSelectionInNewViewer: closesndr];
        return;
      }
      
    default:    
      break;
  }

  if (([characters length] > 0) && (character < 0xF700)) {														
		SEL icnwpSel = @selector(selectRepWithPrefix:);
		IMP icnwp = [dsource methodForSelector: icnwpSel];
  
    if (charBuffer == nil) {
      charBuffer = [characters substringToIndex: 1];
      RETAIN (charBuffer);
      lastKeyPressed = 0.0;
    } else {
      if ([theEvent timestamp] - lastKeyPressed < 500.0) {
        ASSIGN (charBuffer, ([charBuffer stringByAppendingString:
				    															[characters substringToIndex: 1]]));
      } else {
        ASSIGN (charBuffer, ([characters substringToIndex: 1]));
        lastKeyPressed = 0.0;
      }														
    }	
    
    lastKeyPressed = [theEvent timestamp];

    if ((*icnwp)(dsource, icnwpSel, charBuffer)) {
      return;
    }
	}  
  
  [super keyDown: theEvent];
}

- (void)setFrame:(NSRect)frameRect
{
  [super setFrame: frameRect];
  [self checkSize];
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldFrameSize
{
  [super resizeWithOldSuperviewSize: oldFrameSize];
  [self checkSize];
}

- (NSImage *)dragImageForRows:(NSArray *)dragRows
			                  event:(NSEvent *)dragEvent 
	            dragImageOffset:(NSPointPointer)dragImageOffset
{
  id deleg = [self delegate];
  
  if ([deleg respondsToSelector: @selector(tableView:dragImageForRows:)]) {
    NSImage *image = [deleg tableView: self dragImageForRows: dragRows];
    if (image) {
      return image;
    }
  }
      
  return [super dragImageForRows: dragRows
  		                     event: dragEvent 
		             dragImageOffset: dragImageOffset];
}

@end


@implementation FSNListView (NodeRepContainer)

- (void)showContentsOfNode:(FSNode *)anode
{
  [dsource showContentsOfNode: anode];
}

- (NSDictionary *)readNodeInfo
{
  return [dsource readNodeInfo];
}

- (void)updateNodeInfo
{
  [dsource updateNodeInfo];
}

- (void)reloadContents
{
  [dsource reloadContents];
}

- (void)reloadFromNode:(FSNode *)anode
{
  [dsource reloadFromNode: anode];
}

- (FSNode *)baseNode
{
  return [dsource baseNode];
}

- (FSNode *)shownNode
{
  return [dsource shownNode];
}

- (BOOL)isSingleNode
{
  return YES;
}

- (BOOL)isShowingNode:(FSNode *)anode
{
  return [dsource isShowingNode: anode];
}

- (BOOL)isShowingPath:(NSString *)path
{
  return [dsource isShowingPath: path];
}

- (void)sortTypeChangedAtPath:(NSString *)path
{
  [dsource sortTypeChangedAtPath: path];
}

- (void)nodeContentsWillChange:(NSDictionary *)info
{
  [dsource nodeContentsWillChange: info];
}

- (void)nodeContentsDidChange:(NSDictionary *)info
{
  [dsource nodeContentsDidChange: info];
}

- (void)watchedPathChanged:(NSDictionary *)info
{
  [dsource watchedPathChanged: info];
}

- (void)setShowType:(FSNInfoType)type
{
  [dsource setShowType: type];
}

- (void)setExtendedShowType:(NSString *)type
{
  [(FSNListViewDataSource *)dsource setExtendedShowType: type];
}

- (FSNInfoType)showType
{
  return [dsource showType];
}

- (id)repOfSubnode:(FSNode *)anode
{
  return [dsource repOfSubnode: anode];
}

- (id)repOfSubnodePath:(NSString *)apath
{
  return [dsource repOfSubnodePath: apath];
}

- (id)addRepForSubnode:(FSNode *)anode
{
  return [dsource addRepForSubnode: anode];
}

- (void)removeRepOfSubnode:(FSNode *)anode
{
  [dsource removeRepOfSubnode: anode];
}

- (void)removeRepOfSubnodePath:(NSString *)apath
{
  [dsource removeRepOfSubnodePath: apath];
}

- (void)unloadFromNode:(FSNode *)anode
{
  [dsource unloadFromNode: anode];
}

- (void)unselectOtherReps:(id)arep
{
  [dsource unselectOtherReps: arep];
}

- (void)selectReps:(NSArray *)reps
{
  [dsource selectReps: reps];
}

- (void)selectRepsOfSubnodes:(NSArray *)nodes
{
  [dsource selectRepsOfSubnodes: nodes];
}

- (void)selectRepsOfPaths:(NSArray *)paths
{
  [dsource selectRepsOfPaths: paths];
}

- (void)selectAll
{
  [dsource selectAll];
}

- (void)scrollSelectionToVisible
{
  [dsource scrollSelectionToVisible];
}

- (NSArray *)reps
{
  return [dsource reps];
}

- (NSArray *)selectedReps
{
  return [dsource selectedReps];
}

- (NSArray *)selectedNodes
{
  return [dsource selectedNodes];
}

- (NSArray *)selectedPaths
{
  return [dsource selectedPaths];
}

- (void)selectionDidChange
{
  [dsource selectionDidChange];
}

- (void)checkLockedReps
{
  [dsource checkLockedReps];
}

- (void)openSelectionInNewViewer:(BOOL)newv
{
  [dsource openSelectionInNewViewer: newv];
}

- (void)setLastShownNode:(FSNode *)anode
{
  [dsource setLastShownNode: anode];
}

- (BOOL)needsDndProxy
{
  return [dsource needsDndProxy];
}

- (BOOL)involvedByFileOperation:(NSDictionary *)opinfo
{
  return [dsource involvedByFileOperation: opinfo];
}

- (BOOL)validatePasteOfFilenames:(NSArray *)names
                       wasCutted:(BOOL)cutted
{
  return [dsource validatePasteOfFilenames: names wasCutted: cutted];
}

- (void)stopRepNameEditing
{
  [dsource stopRepNameEditing];
}

@end


@implementation FSNListView (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
  return [dsource listViewDraggingEntered: sender];
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
  return [dsource listViewDraggingUpdated: sender];
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  [dsource listViewDraggingExited: sender];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
  return [dsource listViewPrepareForDragOperation: sender];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
  return [dsource listViewPerformDragOperation: sender];
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
  [dsource listViewConcludeDragOperation: sender];
}

@end


@implementation NSDictionary (TableColumnSort)

- (int)compareTableColumnInfo:(NSDictionary *)info
{
  NSNumber *p1 = [self objectForKey: @"position"];
  NSNumber *p2 = [info objectForKey: @"position"];
  return [p1 compare: p2];
}

@end
