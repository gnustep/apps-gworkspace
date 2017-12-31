/* FSNListView.m
 *  
 * Copyright (C) 2004-2016 Free Software Foundation, Inc.
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <math.h>
#include <unistd.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "FSNListView.h"
#import "FSNTextCell.h"
#import "FSNFunctions.h"

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
  RELEASE (node);
  RELEASE (extInfoType);
  RELEASE (nodeReps);
  RELEASE (nameEditor);
  RELEASE (lastSelection);

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
    [nameEditor setEditable: NO];
    [nameEditor setSelectable: NO];	   
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
      [[column headerCell] setStringValue: NSLocalizedStringFromTableInBundle(@"Name", nil, [NSBundle bundleForClass:[FSNode class]], @"")];
      break;
    case FSNInfoKindType:
      [[column headerCell] setStringValue: NSLocalizedStringFromTableInBundle(@"Type", nil, [NSBundle bundleForClass:[FSNode class]], @"")];
      break;
    case FSNInfoDateType:
      [[column headerCell] setStringValue: NSLocalizedStringFromTableInBundle(@"Date Modified", nil, [NSBundle bundleForClass:[FSNode class]], @"")];
      break;
    case FSNInfoSizeType:
      [[column headerCell] setStringValue: NSLocalizedStringFromTableInBundle(@"Size", nil, [NSBundle bundleForClass:[FSNode class]], @"")];
      break;
    case FSNInfoOwnerType:
      [[column headerCell] setStringValue: NSLocalizedStringFromTableInBundle(@"Owner", nil, [NSBundle bundleForClass:[FSNode class]], @"")];
      break;
    case FSNInfoParentType:
      [[column headerCell] setStringValue: NSLocalizedStringFromTableInBundle(@"Parent", nil, [NSBundle bundleForClass:[FSNode class]], @"")];
      break;
    case FSNInfoExtendedType:
      [[column headerCell] setStringValue: extInfoType]; /* should come Localized from the ExtInfo bundle */
      break;
    default:
      [[column headerCell] setStringValue: NSLocalizedStringFromTableInBundle(@"Name", nil, [NSBundle bundleForClass:[FSNode class]], @"")];
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
  
  if (columns)
    { 
      int i;

      for (i = 0; i < [columns count]; i++)
	{
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

	  [colsinfo setObject: dict forKey: [identifier stringValue]];
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
    [nodeReps sortUsingFunction: compareWithExtType
                        context: (void *)NULL];
  }

  column = [listView tableColumnWithIdentifier: [NSNumber numberWithInt: hlighColId]];
  if (column) {
    [listView setHighlightedTableColumn: column];
  }
}

- (void)setMouseFlags:(NSUInteger)flags
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
  NSUInteger i;

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
  NSUInteger i;

  for (i = 0; i < [nodeReps count]; i++)
    {
      FSNListViewNodeRep *rep = [nodeReps objectAtIndex: i];  
      NSString *name = [[rep node] name];
    
      if ([name hasPrefix: prefix])
        {
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
  NSUInteger row = [nodeReps indexOfObjectIdenticalTo: aRep];
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
                                row:(NSInteger)rowIndex
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
                       row:(NSInteger)rowIndex
{
}

- (BOOL)tableView:(NSTableView *)aTableView
	      writeRows:(NSArray *)rows
     toPasteboard:(NSPasteboard *)pboard
{
  NSMutableArray *paths = [NSMutableArray array];
  NSUInteger i;

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
                 proposedRow:(NSInteger)row 
       proposedDropOperation:(NSTableViewDropOperation)operation
{
  return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)tableView 
       acceptDrop:(id <NSDraggingInfo>)info 
              row:(NSInteger)row 
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
  shouldSelectRow:(NSInteger)rowIndex
{
  return ((rowIndex != -1) 
                && ([[nodeReps objectAtIndex: rowIndex] isLocked] == NO));
}

- (void)tableView:(NSTableView *)aTableView 
  willDisplayCell:(id)aCell 
   forTableColumn:(NSTableColumn *)aTableColumn 
              row:(NSInteger)rowIndex
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
      NSUInteger index = [nodeReps indexOfObjectIdenticalTo: rep];
      
      [self selectReps: selected];
      
      if (index != NSNotFound) {
        [listView scrollRowToVisible: index];
      }
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
                              row:(NSInteger)rowIndex
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
  NSUInteger i;
  
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

  if ([infoNode isWritable]
          && ([[fsnodeRep volumes] containsObject: [node path]] == NO)) {
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

- (NSMutableDictionary *)updateNodeInfo:(BOOL)ondisk
{
  CREATE_AUTORELEASE_POOL(arp);
  FSNode *infoNode = [self infoNode];
  NSMutableDictionary *updatedInfo = nil;

  if ([infoNode isValid]) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	      
    NSString *prefsname = [NSString stringWithFormat: @"viewer_at_%@", [infoNode path]];
    NSString *infoPath = [[infoNode path] stringByAppendingPathComponent: @".gwdir"];
    BOOL writable = ([infoNode isWritable] && ([[fsnodeRep volumes] containsObject: [node path]] == NO));
    
    if (writable) {
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
    
    if (ondisk) {
      if (writable) {
        [updatedInfo writeToFile: infoPath atomically: YES];
      } else {
        [defaults setObject: updatedInfo forKey: prefsname];
      }
    }
  }
  
  RELEASE (arp);
  
  return (AUTORELEASE (updatedInfo));
}

- (void)reloadContents
{
  CREATE_AUTORELEASE_POOL (pool);
  NSMutableArray *selection = [[self selectedNodes] mutableCopy];
  NSMutableArray *opennodes = [NSMutableArray array];
  NSUInteger i, count;

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
    NSUInteger i;
  
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
  NSUInteger i; 

  [self stopRepNameEditing];

  if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
    files = [NSArray arrayWithObject: [source lastPathComponent]];
    source = [source stringByDeletingLastPathComponent]; 
  }

  if (([ndpath isEqual: source] == NO) && ([ndpath isEqual: destination] == NO)) {    
    [self reloadContents];
    return;
  }
  
  if ([ndpath isEqual: source]) {
    if ([operation isEqual: NSWorkspaceMoveOperation]
              || [operation isEqual: NSWorkspaceDestroyOperation]
              || [operation isEqual: NSWorkspaceRecycleOperation]
              || [operation isEqual: @"GWorkspaceRenameOperation"]
	|| [operation isEqual: @"GWorkspaceRecycleOutOperation"]) {

      if ([operation isEqual: NSWorkspaceRecycleOperation]) {
		    files = [info objectForKey: @"origfiles"];
      }	

      for (i = 0; i < [files count]; i++) {
        NSString *fname = [files objectAtIndex: i];
        FSNode *subnode = [FSNode nodeWithRelativePath: fname parent: node];
        [self removeRepOfSubnode: subnode];
      }
      needsreload = YES;
    } 
  }

  if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
    files = [NSArray arrayWithObject: [destination lastPathComponent]];
    destination = [destination stringByDeletingLastPathComponent]; 
  }

  if ([ndpath isEqual: destination]
          && ([operation isEqual: NSWorkspaceMoveOperation]   
              || [operation isEqual: NSWorkspaceCopyOperation]
              || [operation isEqual: NSWorkspaceLinkOperation]
              || [operation isEqual: NSWorkspaceDuplicateOperation]
              || [operation isEqual: @"GWorkspaceCreateDirOperation"]
              || [operation isEqual: @"GWorkspaceCreateFileOperation"]
              || [operation isEqual: NSWorkspaceRecycleOperation]
              || [operation isEqual: @"GWorkspaceRenameOperation"]
	      || [operation isEqual: @"GWorkspaceRecycleOutOperation"])) { 

    if ([operation isEqual: NSWorkspaceRecycleOperation]) {
		  files = [info objectForKey: @"files"];
    }	

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
          NSUInteger index = [nodeReps indexOfObjectIdenticalTo: rep];
        
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
      
      if (subnode && [subnode isValid]) {
        FSNListViewNodeRep *rep = [self repOfSubnode: subnode];
      
        if (rep) {
          [rep setNode: subnode];
        } else {
          [self addRepForSubnode: subnode];
        }
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
    NSUInteger index = [nodeReps indexOfObjectIdenticalTo: rep];
  
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
  NSMutableIndexSet *set = [NSMutableIndexSet indexSet];
  NSUInteger i;

  for (i = 0; i < [nodeReps count]; i++) {
    FSNListViewNodeRep *rep = [nodeReps objectAtIndex: i];
  
    if ([[rep node] isReserved] == NO) {
      [set addIndex: i];
    }
  }

  if ([set count]) {
    [listView deselectAll: self];
    [listView selectRowIndexes: set byExtendingSelection: NO];
    [listView setNeedsDisplay: YES];
  }
}

- (void)scrollSelectionToVisible
{
  NSArray *selected = [self selectedReps];
    
  if ([selected count]) {
    id rep = [selected objectAtIndex: 0];
    NSUInteger index = [nodeReps indexOfObjectIdenticalTo: rep];
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
  NSIndexSet *set = [listView selectedRowIndexes];
  NSMutableArray *selreps = [NSMutableArray array];

  NSUInteger i;
  for (i = [set firstIndex]; i != NSNotFound; i = [set indexGreaterThanIndex: i])
    {
      [selreps addObject: [nodeReps objectAtIndex: i]];
    }
  return [NSArray arrayWithArray: selreps];
}

- (NSArray *)selectedNodes
{
  NSMutableArray *selnodes = [NSMutableArray array];

  NSEnumerator *e = [[self selectedReps] objectEnumerator];
  id rep;
  while ((rep = [e nextObject]) != nil)
    {
      [selnodes addObject: [rep node]];
    }

  return [NSArray arrayWithArray: selnodes];
}

- (NSArray *)selectedPaths
{
  NSMutableArray *selpaths = [NSMutableArray array];

  NSEnumerator *e = [[self selectedNodes] objectEnumerator];
  id n;
  while ((n = [e nextObject]) != nil)
    {
      [selpaths addObject: [n path]];
    }

  return [NSArray arrayWithArray: selpaths];
}

- (void)selectionDidChange
{
  NSArray *selection = [self selectedNodes];

  if ([selection count] == 0) {
    selection = [NSArray arrayWithObject: node];
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
                       wasCut:(BOOL)cut
{
  NSString *nodePath = [node path];
  NSString *prePath = [NSString stringWithString: nodePath];
  NSString *basePath;
  
  if ([names count] == 0)
    {
      return NO;
    } 

  if ([node isWritable] == NO)
    {
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
  if ([[listView subviews] containsObject: nameEditor]) {
    [nameEditor abortEditing];
    [nameEditor setEditable: NO];
    [nameEditor setSelectable: NO];
    [nameEditor setNode: nil stringValue: @"" index: -1];
    [nameEditor removeFromSuperview];
    [listView setNeedsDisplayInRect: [nameEditor frame]];
  }
}

@end


@implementation FSNListViewDataSource (RepNameEditing)

- (void)setEditorAtRow:(int)row withMouseDownEvent: (NSEvent *)anEvent
{
  [self stopRepNameEditing];

  if ([[listView selectedRowIndexes] count] == 1) {
    FSNListViewNodeRep *rep = [nodeReps objectAtIndex: row];  
    FSNode *nd = [rep node];
    BOOL canedit = (([rep isLocked] == NO) && ([nd isMountPoint] == NO));
    
    if (canedit) {   
      NSNumber *num = [NSNumber numberWithInt: FSNInfoNameType];
      unsigned col = [listView columnWithIdentifier: num];
      NSRect r = [listView frameOfCellAtColumn: col row: row];
      NSFont *edfont = [nameEditor font];
      float fnheight = [fsnodeRep heightOfFont: edfont]; 
      
      float xshift = [[rep icon] size].width + 4;
  
      r.origin.y += ((r.size.height - fnheight) / 2);
      r.size.height = fnheight;
      r.origin.x += xshift;
      r.size.width -= xshift;
      r = NSIntegralRect(r);  
      [nameEditor setFrame: r];

      [nameEditor setNode: nd stringValue: [nd name] index: 0];

      [listView addSubview: nameEditor];

      if (anEvent != nil)
	{
	  [nameEditor mouseDown: anEvent];
	}
    }
  }
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
  FSNode *ednode = [nameEditor node];

#define CLEAREDITING \
  [self stopRepNameEditing]; \
  return 
    
   
    if ([ednode isParentWritable] == NO)
      {
        showAlertNoPermission([FSNode class], [ednode parentName]);
        CLEAREDITING;
      }
    else if ([ednode isSubnodeOfPath: [desktopApp trashPath]])
      {
        showAlertInRecycler([FSNode class]);
        CLEAREDITING;
      }
    else
      {
      NSString *newname = [nameEditor stringValue];
      NSString *newpath = [[ednode parentPath] stringByAppendingPathComponent: newname];
      NSString *extension = [newpath pathExtension];
      NSCharacterSet *notAllowSet = [NSCharacterSet characterSetWithCharactersInString: @"/\\*:?\33"];
      NSRange range = [newname rangeOfCharacterFromSet: notAllowSet];
      NSArray *dirContents = [ednode subNodeNamesOfParent];
      NSMutableDictionary *opinfo = [NSMutableDictionary dictionary];

      if (([newname length] == 0) || (range.length > 0)) {
        showAlertInvalidName([FSNode class]);
        CLEAREDITING;
      }	

      if (([extension length] 
              && ([ednode isDirectory] && ([ednode isPackage] == NO))))
        {
          if (showAlertExtensionChange([FSNode class], extension) == NSAlertDefaultReturn)
            {
              CLEAREDITING;
            }
        }

      if ([dirContents containsObject: newname]) {
        if ([newname isEqual: [ednode name]])
          {
            CLEAREDITING;
          }
        else
          {
            showAlertNameInUse([FSNode class], newname);
            CLEAREDITING;
          }
      }

      [opinfo setObject: @"GWorkspaceRenameOperation" forKey: @"operation"];	
      [opinfo setObject: [ednode path] forKey: @"source"];	
      [opinfo setObject: newpath forKey: @"destination"];	
      [opinfo setObject: [NSArray arrayWithObject: @""] forKey: @"files"];	

      [self stopRepNameEditing];
      [desktopApp performFileOperation: opinfo];         
    }

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

- (NSDragOperation)checkReturnValueForRep:(FSNListViewNodeRep *)arep
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

- (NSDragOperation)listViewDraggingEntered:(id <NSDraggingInfo>)sender
{
  NSPoint location;
  NSInteger row;
  
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
    NSUInteger count;

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

    if ([node isDirectory] && [node isParentOfPath: basePath]) {
      NSArray *subNodes = [node subNodes];
      NSUInteger i;

      for (i = 0; i < [subNodes count]; i++) {
        FSNode *nd = [subNodes objectAtIndex: i];

        if ([nd isDirectory]) {
          NSUInteger j;

          for (j = 0; j < count; j++) {
            NSString *fname = [[sourcePaths objectAtIndex: j] lastPathComponent];

            if ([[nd name] isEqual: fname]) {
              return NSDragOperationNone;
            }
          }
        }
      }
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

- (NSDragOperation)listViewDraggingUpdated:(id <NSDraggingInfo>)sender
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
  RELEASE (openicon); 
  RELEASE (lockedicon); 
  RELEASE (spopenicon); 
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

- (void)setGridIndex:(NSUInteger)index
{
}

- (NSUInteger)gridIndex
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

- (NSDragOperation)repDraggingEntered:(id <NSDraggingInfo>)sender
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

  if ([node isDirectory]) {
    id <DesktopApplication> desktopApp = [dataSource desktopApp];

    if ([node isSubnodeOfPath: [desktopApp trashPath]]) { 
      return NSDragOperationNone;
    }
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

  if ([node isDirectory] && [node isParentOfPath: fromPath]) {
    NSArray *subNodes = [node subNodes];
    int i;
    
    for (i = 0; i < [subNodes count]; i++) {
      FSNode *nd = [subNodes objectAtIndex: i];
      
      if ([nd isDirectory]) {
        int j;
        
        for (j = 0; j < count; j++) {
          NSString *fname = [[sourcePaths objectAtIndex: j] lastPathComponent];
          
          if ([[nd name] isEqual: fname]) {
            return NSDragOperationNone;
          }
        }
      }
    }
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

NSComparisonResult sortSubviews(id view1, id view2, void *context)
{
  if ([view1 isMemberOfClass: [FSNListViewNameEditor class]]) {
    return NSOrderedAscending;
  }  
  return NSOrderedDescending;
}

- (void)dealloc
{
  RELEASE (node);
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

- (void)mouseDown:(NSEvent *)theEvent
{
  NSView *view = [self superview];
  
  if ([self isEditable] == NO) {
    [self setSelectable: YES];  
    [self setEditable: YES];       
    [[self window] makeFirstResponder: self];
  } else {  
    [super mouseDown: theEvent];
  }

  [view sortSubviewsUsingFunction: (NSComparisonResult (*)(id, id, void *))sortSubviews context: nil];
  [view setNeedsDisplayInRect: [self frame]];
}

@end


@implementation FSNListView

- (void)dealloc
{
  RELEASE (charBuffer);  
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
  if (sview && ([self bounds].size.width < [sview bounds].size.width)) {
    [self sizeLastColumnToFit];  
  }
}

- (void)singleClick: (NSTimer *)aTimer
{
  NSEvent *theEvent = [aTimer userInfo];
  NSPoint location;
  int row;

  location = [theEvent locationInWindow];
  location = [self convertPoint: location fromView: nil];
  row = [self rowAtPoint: location];
  
  if (row != -1) {  
    [dsource setEditorAtRow: row withMouseDownEvent: theEvent];
  }
  
  [clickTimer release];
  clickTimer = nil;
}

- (void)mouseDown:(NSEvent *)theEvent
{
  if (clickTimer != nil)
    {
      [clickTimer invalidate];
      [clickTimer release];
      clickTimer = nil;
    }
  
  if ([theEvent clickCount] == 1
      && (!([theEvent modifierFlags] & NSShiftKeyMask)))
    {
       NSPoint location;
       int row;
       
       location = [theEvent locationInWindow];
       location = [self convertPoint: location fromView: nil];
       row = [self rowAtPoint: location];
       
       if (row == [self selectedRow])
	 {
	   // We clicked on an already-selected row.

	   ASSIGN(clickTimer, [NSTimer scheduledTimerWithTimeInterval: 0.5 // FIXME: use [NSEvent doubleClickInterval]
							       target: self
							     selector: @selector(singleClick:)
							     userInfo: theEvent
							      repeats: NO]);
	 }
    }

  [dsource setMouseFlags: [theEvent modifierFlags]];   
  [dsource stopRepNameEditing];
  
  [super mouseDown: theEvent];
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
      [dsource stopRepNameEditing];
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
      [dsource stopRepNameEditing];
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
      [dsource stopRepNameEditing];
	    [dsource selectRepInPrevRow];
      return;

    case NSDownArrowFunctionKey:
      [dsource stopRepNameEditing];
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

- (NSMutableDictionary *)updateNodeInfo:(BOOL)ondisk
{
  return [dsource updateNodeInfo: ondisk];
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
                       wasCut:(BOOL)cut
{
  return [dsource validatePasteOfFilenames: names wasCut: cut];
}

- (void)stopRepNameEditing
{
  [dsource stopRepNameEditing];
}

@end


@implementation FSNListView (DraggingDestination)

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  return [dsource listViewDraggingEntered: sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
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


