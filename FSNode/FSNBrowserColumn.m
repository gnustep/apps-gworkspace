/* FSNBrowserColumn.m
 *  
 * Copyright (C) 2004-2022 Free Software Foundation, Inc.
 *
 * Authors: Enrico Sersale <enrico@imago.ro>
 *          Riccardo Mottola <rm@gnu.org>
 * Date: July 2004
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

#import <AppKit/AppKit.h>
#import "FSNBrowserColumn.h"
#import "FSNBrowserCell.h"
#import "FSNBrowserMatrix.h"
#import "FSNBrowserScroll.h"
#import "FSNBrowser.h"
#import "FSNFunctions.h"

#define ICON_CELL_HEIGHT 28

#define CHECKRECT(rct) \
if (rct.size.width < 0) rct.size.width = 0; \
if (rct.size.height < 0) rct.size.height = 0

#define CHECKSIZE(sz) \
if (sz.width < 0) sz.width = 0; \
if (sz.height < 0) sz.height = 0

static id <DesktopApplication> desktopApp = nil;

@implementation FSNBrowserColumn

- (void)dealloc
{
  RELEASE (cellPrototype);
  RELEASE (shownNode);
  RELEASE (oldNode);
  RELEASE (extInfoType);  
  RELEASE (backColor);
    
  [super dealloc];
}

+ (void)initialize
{
  static BOOL initialized = NO;

  if (initialized == NO)
    {
      if (desktopApp == nil)
	{
	  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	  NSString *appName = [defaults stringForKey: @"DesktopApplicationName"];
	  NSString *selName = [defaults stringForKey: @"DesktopApplicationSelName"];

	  if (appName && selName)
	    {
	      Class desktopAppClass = [[NSBundle mainBundle] classNamed: appName];
	      SEL sel = NSSelectorFromString(selName);
	      desktopApp = [desktopAppClass performSelector: sel];
	    }
	}
  
      initialized = YES;
    }
}

- (id)initInBrowser:(FSNBrowser *)abrowser
            atIndex:(NSInteger)ind
      cellPrototype:(FSNBrowserCell *)acell
          cellsIcon:(BOOL)cicon
       nodeInfoType:(FSNInfoType)type
       extendedType:(NSString *)exttype
    backgroundColor:(NSColor *)acolor
{
  self = [super init];
  
  if (self)
    {
      NSRect rect = NSMakeRect(0, 0, 150, 100);
      int lineh;
               
      browser = abrowser;
      index = ind;
      ASSIGN (cellPrototype, acell);
      cellsIcon = cicon;
      ASSIGN (backColor, acolor);

      infoType = type;
      extInfoType = nil;
      if (exttype)
	ASSIGN (extInfoType, exttype);

      shownNode = nil;
      oldNode = nil;
      scroll = nil;
      matrix = nil;
      isLoaded = NO;
    
      [self setFrame: rect];
    
      fsnodeRep = [FSNodeRep sharedInstance];
      lineh = floor([fsnodeRep heightOfFont: [acell font]]);
    
      scroll = [[FSNBrowserScroll alloc] initWithFrame: rect 
					      inColumn: self acceptDnd: cellsIcon];
      [self addSubview: scroll];
      RELEASE (scroll);
    
      if (cellsIcon)
	cellsHeight = ICON_CELL_HEIGHT;
      else
	cellsHeight = lineh;
    
      if (infoType != FSNInfoNameType)
	cellsHeight += (lineh +1);
    
      isDragTarget = NO;

      matrix = [[FSNBrowserMatrix alloc] initInColumn: self 
					    withFrame: [self bounds]
						 mode: NSListModeMatrix 
					    prototype: cellPrototype
					 numberOfRows: 0 
				      numberOfColumns: 0 
					    acceptDnd: cellsIcon];

      [matrix setIntercellSpacing: NSMakeSize(0, 0)];
      [matrix setCellSize: NSMakeSize([scroll contentSize].width, cellsHeight)];  
      [matrix setAutoscroll: YES];
      [matrix setAllowsEmptySelection: YES];
      [matrix setBackgroundColor: backColor];
      [matrix setCellBackgroundColor: backColor];
      [matrix setTarget: self];
      [matrix setAction: @selector(doClick:)];
      [matrix setDoubleAction: @selector(doDoubleClick:)];
      [scroll setDocumentView: matrix];
      RELEASE (matrix);
    }
  
  return self;
}

- (void)setShowType:(FSNInfoType)type
{
  if (infoType != type)
    {
      NSArray *cells = [matrix cells];
      int lineh = floor([fsnodeRep heightOfFont: [cellPrototype font]]);
      NSUInteger i;
    
      infoType = type;
      DESTROY (extInfoType);

      if (cellsIcon)
	cellsHeight = ICON_CELL_HEIGHT;
      else
	cellsHeight = lineh;

      if (infoType != FSNInfoNameType)
	cellsHeight += (lineh +1);
    
      [self adjustMatrix];

      for (i = 0; i < [cells count]; i++)
	{
	  [[cells objectAtIndex: i] setNodeInfoShowType: infoType];
	}
    }
}

- (void)setExtendedShowType:(NSString *)type
{
  if ((extInfoType == nil) || ([extInfoType isEqual: type] == NO))
    {
      NSArray *cells = [matrix cells];    
      int lineh = floor([fsnodeRep heightOfFont: [cellPrototype font]]);  
      NSUInteger i;
    
      infoType = FSNInfoExtendedType;
      ASSIGN (extInfoType, type);

      if (cellsIcon)
	cellsHeight = ICON_CELL_HEIGHT;
      else
	cellsHeight = lineh;

      cellsHeight += (lineh +1);

      [self adjustMatrix];

      for (i = 0; i < [cells count]; i++)
	{
	  FSNBrowserCell *cell = [cells objectAtIndex: i];
	  [cell setExtendedShowType: extInfoType];
	}       
    }
}						\

- (void)showContentsOfNode:(FSNode *)anode
{
  NSArray *savedSelection = nil;
  NSMutableArray *visibleNodes = nil;
  float scrollTune = 0;

  if (oldNode && anode && [oldNode isEqualToNode: anode] && [anode isValid])
    {
      NSArray *vnodes = nil;  
    
      savedSelection = [self selectedNodes];
    
      if (savedSelection) {
	RETAIN (savedSelection);
      }
    
      [matrix visibleCellsNodes: &vnodes scrollTuneSpace: &scrollTune];

      if (vnodes) {
	visibleNodes = [NSMutableArray new];
	[visibleNodes addObjectsFromArray: vnodes];
      }    
    }
      
  if ([matrix numberOfColumns] > 0)
    {
      [matrix removeColumn: 0];
    }
  
  DESTROY (shownNode); 
  DESTROY (oldNode);
  isLoaded = NO;

  if (anode && [anode isValid])
    {
      id cell = nil;
    
      ASSIGN (oldNode, anode);    
      ASSIGN (shownNode, anode);    
        
      [self createRowsInMatrix];
      [self adjustMatrix];

      if (savedSelection)
	[self selectCellsOfNodes: savedSelection sendAction: NO];

      if (visibleNodes)
	{
	  NSUInteger i;
	  NSInteger count = [visibleNodes count];
      
	  for (i = 0; i < count; i++)
	    {
	      FSNode *node = [visibleNodes objectAtIndex: i];

	      if ([self cellOfNode: node] == nil)
		{
		  [visibleNodes removeObjectAtIndex: i];
		  count--;
		  i--;
		}
	    }

	  if ([visibleNodes count])
	    {
	      cell = [self cellOfNode: [visibleNodes objectAtIndex: 0]];
	      [matrix scrollToFirstPositionCell: cell withScrollTune: scrollTune];
      
	    }
	  else if ([[matrix cells] count])
	    {
	      [matrix scrollCellToVisibleAtRow: 0 column: 0];
	    }
	}
      else if ([[matrix cells] count])
	{
	  [matrix scrollCellToVisibleAtRow: 0 column: 0];
	}
               
      isLoaded = YES;
    }
  
  RELEASE (savedSelection);
  RELEASE (visibleNodes);  
}

- (FSNode *)shownNode
{
  return shownNode;
}

- (void)createRowsInMatrix
{
  NSAutoreleasePool *pool;
  NSArray *subNodes = [shownNode subNodes];
  NSUInteger count = [subNodes count];
  SEL compSel = [fsnodeRep compareSelectorForDirectory: [shownNode path]];
  NSInteger i;

  if ([matrix numberOfColumns] > 0)
    [matrix removeColumn: 0];


  if (count == 0)
    {
      [matrix setNeedsDisplay: YES];
      return;
    }
  
  pool = [[NSAutoreleasePool alloc] init];

  [matrix addColumn]; 

  for (i = 0; i < count; ++i)
    {
      FSNode *subnode = [subNodes objectAtIndex: i];
      id cell;
    
      if (i != 0)
	[matrix insertRow: i];

      cell = [matrix cellAtRow: i column: 0];   
      [cell setLoaded: YES];
      [cell setEnabled: YES]; 
      [cell setNode: subnode nodeInfoType: infoType extendedType: extInfoType];
   
      if ([subnode isDirectory])
	{
	  if ([subnode isPackage])
	    [cell setLeaf: YES]; 
	  else
	    [cell setLeaf: NO]; 
	}
      else
	{
	  [cell setLeaf: YES];
	}
    
      if (cellsIcon)
	[cell setIcon];
    
      [cell checkLocked];	
    }

  [matrix sortUsingSelector: compSel];
  RELEASE (pool);
}

- (void)addCellsWithNames:(NSArray *)names
{
  NSArray *subNodes = [shownNode subNodes];

  if ([subNodes count])
    {
      CREATE_AUTORELEASE_POOL(arp);
      NSArray *selectedNodes = [self selectedNodes];
      SEL compSel = [fsnodeRep compareSelectorForDirectory: [shownNode path]];
      NSUInteger i;

      [matrix setIntercellSpacing: NSMakeSize(0, 0)];
    	  
      for (i = 0; i < [names count]; i++)
	{
	  NSString *name = [names objectAtIndex: i];
	  FSNode *node = [FSNode subnodeWithName: name inSubnodes: subNodes];
      
	  if ([node isValid])
	    {   
	      FSNBrowserCell *cell = [self cellOfNode: node]; 
         
	      if (cell == nil)
		{
		  [matrix addRow];
		  cell = [matrix cellAtRow: [[matrix cells] count] -1 column: 0];

		  [cell setLoaded: YES];
		  [cell setEnabled: YES]; 
		  [cell setNode: node nodeInfoType: infoType extendedType: extInfoType];

		  if ([node isDirectory])
		    {
		      if ([node isPackage])
			[cell setLeaf: YES]; 
		      else
			[cell setLeaf: NO]; 
		    }
		  else
		    {
		      [cell setLeaf: YES];
		    }

		  if (cellsIcon)
		    [cell setIcon];

		  [cell checkLocked];	
		}
	      else
		{
		  [cell setEnabled: YES];
		}
	    }
	}

      [matrix sortUsingSelector: compSel];
      [self adjustMatrix];

      if (selectedNodes)
	[self selectCellsOfNodes: selectedNodes sendAction: NO];

      [matrix setNeedsDisplay: YES]; 
      RELEASE (arp);
    }
}

- (void)removeCellsWithNames:(NSArray *)names
{
  CREATE_AUTORELEASE_POOL(arp);
  NSArray *selcells = nil;
  NSMutableArray *selectedCells = nil;
  NSArray *vnodes = nil;
  NSMutableArray *visibleNodes = nil;
  FSNBrowserColumn *col = nil;
  id cell = nil;
  float scrollTune = 0;
  BOOL updated = NO;
  NSUInteger i;
  
  selcells = [matrix selectedCells];
  
  if (selcells && [selcells count]) {
    selectedCells = [selcells mutableCopy];
  }

  [matrix visibleCellsNodes: &vnodes scrollTuneSpace: &scrollTune];
  
  if (vnodes && [vnodes count])
    visibleNodes = [vnodes mutableCopy];
  
  for (i = 0; i < [names count]; i++)
    {
      NSString *cname = [names objectAtIndex: i];
    
      cell = [self cellWithName: cname];

      if (cell)
	{
	  FSNode *node = [cell node];
	  NSInteger row, col;
      
	  if (visibleNodes && [visibleNodes containsObject: node])
	    [visibleNodes removeObject: node];

	  if (selectedCells && [selectedCells containsObject: cell])
	    [selectedCells removeObject: cell];

	  [matrix getRow: &row column: &col ofCell: cell];  
	  [matrix removeRow: row];  
	  updated = YES;  			
	}
    }

  [matrix sizeToCells];
  [matrix setNeedsDisplay: YES];
  
  if (updated)
    {
      if ([selectedCells count] > 0)
	{    
    
	  [self selectCells: selectedCells sendAction: NO];    
	  [matrix setNeedsDisplay: YES];
      
	  if (visibleNodes && [visibleNodes count])
	    {
	      cell = [self cellOfNode: [visibleNodes objectAtIndex: 0]];
	      [matrix scrollToFirstPositionCell: cell withScrollTune: scrollTune];
	    }
	}
      else
	{
	  if (index != 0)
	    {		
	      if ((index - 1) >= [browser firstVisibleColumn])
		{
		  col = [browser columnBeforeColumn: self];
		  cell = [col cellWithPath: [shownNode parentPath]];
		    
		  [col selectCell: cell sendAction: YES];
		}
	    }
	  else
	    {
	      [browser setLastColumn: index];
	    }
	}
    }
  else if ([visibleNodes count])
    {
      cell = [self cellOfNode: [visibleNodes objectAtIndex: 0]];
      [matrix scrollToFirstPositionCell: cell withScrollTune: scrollTune];
    }

  RELEASE (selectedCells); 
  RELEASE (visibleNodes);
  RELEASE (arp);
}

- (NSArray *)selectedCells
{
  NSArray *selected = [matrix selectedCells];

  if (selected)
    {
      NSMutableArray *cells = [NSMutableArray array];
      BOOL missing = NO;
      NSUInteger i;
  
      for (i = 0; i < [selected count]; i++)
	{  
	  FSNBrowserCell *cell = [selected objectAtIndex: i];
      
	  if ([[cell node] isValid])
	    [cells addObject: cell];
	  else
	    missing = YES;
	}

      if (missing)
	{
	  [matrix deselectAllCells];
	  if ([cells count])
	    {
	      [self selectCells: cells sendAction: YES];
	    }
	}

      if ([cells count] > 0)
	return [cells makeImmutableCopyOnFail: NO];
    }
	
  return nil;
 }

- (NSArray *)selectedNodes
{
  NSArray *selected = [matrix selectedCells];

  if (selected)
    {
      NSMutableArray *nodes = [NSMutableArray array];
      BOOL missing = NO;
      NSUInteger i;
  
      for (i = 0; i < [selected count]; i++)
	{  
	  FSNode *node = [[selected objectAtIndex: i] node];
      
	  if ([node isValid]) 
	    [nodes addObject: node];
	  else
	    missing = YES;
	}

      if (missing)
	{
	  [matrix deselectAllCells];
	  if ([nodes count])
	    {
	      [self selectCellsOfNodes: nodes sendAction: YES];
	    }
	}

      if ([nodes count] > 0)
	{
  	  return [nodes makeImmutableCopyOnFail: NO];
	}
    }
	
  return nil;
 }

- (NSArray *)selectedPaths
{
  NSArray *selected = [matrix selectedCells];

  if (selected)
    {
      NSMutableArray *paths = [NSMutableArray array];
      BOOL missing = NO;
      NSUInteger i;
  
      for (i = 0; i < [selected count]; i++)
	{  
	  FSNode *node = [[selected objectAtIndex: i] node];
      
	  if ([node isValid])
       
	    [paths addObject: [node path]];
	  else
	    missing = YES;
	}

      if (missing)
	{
	  [matrix deselectAllCells];
	  if ([paths count])
	    {
	      [self selectCellsWithPaths: paths sendAction: YES];
	    }
	}

      if ([paths count] > 0)
	return [paths makeImmutableCopyOnFail: NO];

    }
	
  return nil;
 }

- (void)selectCell:(FSNBrowserCell *)cell
        sendAction:(BOOL)act
{
  [matrix selectCell: cell];
  if (act) {
    [matrix sendAction];
  }
}

- (FSNBrowserCell *)selectCellOfNode:(FSNode *)node
                          sendAction:(BOOL)act
{
  FSNBrowserCell *cell = [self cellOfNode: node];  

  if (cell) {
    [matrix selectCell: cell];
    if (act) {
      [matrix sendAction];
    }
    return cell;
  }
  
  return nil;
}
                
- (FSNBrowserCell *)selectCellWithPath:(NSString *)path
                            sendAction:(BOOL)act
{
  FSNBrowserCell *cell = [self cellWithPath: path];  

  if (cell) {
    [matrix selectCell: cell];
    if (act) {
      [matrix sendAction];
    }
    return cell;
  }
  
  return nil;
}
                
                
- (FSNBrowserCell *)selectCellWithName:(NSString *)name 
                            sendAction:(BOOL)act
{
  FSNBrowserCell *cell = [self cellWithName: name];  

  if (cell) {
    [matrix selectCell: cell];
    if (act) {
      [matrix sendAction];
    }
    return cell;
  }
  
  return nil;
}

- (void)selectCells:(NSArray *)cells 
         sendAction:(BOOL)act
{
  if (cells && [cells count])
    {
      NSUInteger i;

      [matrix deselectAllCells];

      for (i = 0; i < [cells count]; i++)
	{
	  [matrix selectCell: [cells objectAtIndex: i]];
	}

      if (act)
	[matrix sendAction];
    }
}

- (void)selectCellsOfNodes:(NSArray *)nodes 
                sendAction:(BOOL)act
{
  if (nodes && [nodes count])
    {
      NSArray *cells = [matrix cells];
      NSUInteger i;

      [matrix deselectAllCells];

      for (i = 0; i < [cells count]; i++)
	{
	  FSNBrowserCell *cell = [cells objectAtIndex: i];

	  if ([nodes containsObject: [cell node]])
	    [matrix selectCell: cell];
	}

      if ([cells count] && act)
	[matrix sendAction];
    }
}

- (void)selectCellsWithPaths:(NSArray *)paths 
                  sendAction:(BOOL)act
{
  if (paths && [paths count])
    {
      NSArray *cells = [matrix cells];
      NSUInteger i;

      [matrix deselectAllCells];

      for (i = 0; i < [cells count]; i++)
	{
	  FSNBrowserCell *cell = [cells objectAtIndex: i];

	  if ([paths containsObject: [[cell node] path]])
	    {
	      [matrix selectCell: cell];
	    } 
	}

      if (act)
	[matrix sendAction];
    }
}

- (void)selectCellsWithNames:(NSArray *)names  
                  sendAction:(BOOL)act
{
  if (names && [names count])
    {
      NSArray *cells = [matrix cells];
      NSUInteger i;

      [matrix deselectAllCells];

      for (i = 0; i < [cells count]; i++)
	{
	  FSNBrowserCell *cell = [cells objectAtIndex: i];

	  if ([names containsObject: [[cell node] name]])
	    [matrix selectCell: cell];
	}

      if (act)
	[matrix sendAction];
    }  
}

- (BOOL)selectFirstCell
{
  if ([[matrix cells] count])
    {
      [matrix selectCellAtRow: 0 column: 0];
      [matrix sendAction];
      return YES;
    }  
  
  return NO;
}

- (BOOL)selectCellWithPrefix:(NSString *)prefix
{
  if ([[matrix cells] count])
    {
      NSInteger n = [matrix numberOfRows];
      NSInteger s = [matrix selectedRow];
      NSString *cellStr = nil;
      NSInteger i = 0;

      // Nothing eselected
      if (s != -1)
	cellStr = [[matrix cellAtRow: s column: 0] stringValue];

      if (cellStr && ([cellStr length] > 0) && [cellStr hasPrefix: prefix])
	return YES;

      for (i = s + 1; i < n; i++)
	{
	  cellStr = [[matrix cellAtRow: i column: 0] stringValue];

	  if (([cellStr length] > 0) && ([cellStr hasPrefix: prefix]))
	    {
	      [matrix deselectAllCells];
	      [matrix selectCellAtRow: i column: 0];
	      [matrix scrollCellToVisibleAtRow: i column: 0];
	      [matrix sendAction];
	      return YES;
	    }
	}

      for (i = 0; i < s; i++)
	{
	  cellStr = [[matrix cellAtRow: i column: 0] stringValue];

	  if (([cellStr length] > 0) && ([cellStr hasPrefix: prefix]))
	    {
	      [matrix deselectAllCells];
	      [matrix selectCellAtRow: i column: 0];
	      [matrix scrollCellToVisibleAtRow: i column: 0];
	      [matrix sendAction];
	      return YES;
	    }
	}
    }

  return NO;
}

- (void)selectAll
{
  NSArray *cells = [matrix cells];

  if ([cells count])
    {
      NSUInteger count = [cells count];
      FSNBrowserCell *cell;
      NSInteger selStart = 0;
      NSInteger selEnd = 0;
      NSInteger i;

      [matrix deselectAllCells];
      while (selStart < count)
	{
	  cell = [cells objectAtIndex: selStart];

	  if ([[cell node] isReserved] == NO)
	    break;

	  selStart++;
	}

      i = selStart;
      while (i < count)
	{
	  cell = [cells objectAtIndex: i];

	  if ([[cell node] isReserved] == NO)
	    {
	      selEnd = i;
	    }
	  else
	    {
	      [matrix setSelectionFrom: selStart
				    to: selEnd
				anchor: selStart
			     highlight: YES];
	      selStart = i + 1;

	      while (selStart < count)
		{
		  cell = [cells objectAtIndex: selStart];

		  if ([[cell node] isReserved] == NO)
		    break;
           
		  selStart++;
		  i++;
		}
	    }
	  i++;
	}
    
      if (selStart < count)
	{
	  [matrix setSelectionFrom: selStart
				to: selEnd
			    anchor: selStart
			 highlight: YES];
	}

      [matrix sendAction];
    }
  else
    {
      FSNBrowserColumn *col = [browser columnBeforeColumn: self];

      if (col)
	[col selectAll];
    }
}

- (void)unselectAllCells
{
  [matrix deselectAllCells];
}

- (void)setEditorForCell:(FSNBrowserCell *)cell
{
  [browser setEditorForCell: cell inColumn: self];
}

- (void)stopCellEditing
{
  [browser stopCellEditing];
}

- (void)checkLockedReps
{
  NSArray *cells = [matrix cells];
  NSUInteger i;  

  for (i = 0; i < [cells count]; i++) {
    [[cells objectAtIndex: i] checkLocked];
  }

  [matrix setNeedsDisplay: YES];   
}

- (void)lockCellsOfNodes:(NSArray *)nodes
{
  NSUInteger i;
  BOOL found = NO;
  
  for (i = 0; i < [nodes count]; i++) {
    FSNBrowserCell *cell = [self cellOfNode: [nodes objectAtIndex: i]];
    
    if (cell && [cell isEnabled]) {   
      [cell setEnabled: NO];
      found = YES;
    }
  }
		
  [matrix setNeedsDisplay: found];   
}

- (void)lockCellsWithPaths:(NSArray *)paths
{
  NSUInteger i;
  BOOL found = NO;
  
  for (i = 0; i < [paths count]; i++) {
    FSNBrowserCell *cell = [self cellWithPath: [paths objectAtIndex: i]];
    
    if (cell && [cell isEnabled]) {   
      [cell setEnabled: NO];
      found = YES;
    }
  }
		
  [matrix setNeedsDisplay: found];   
}

- (void)lockCellsWithNames:(NSArray *)names
{
  NSUInteger i;
  BOOL found = NO;
  
  for (i = 0; i < [names count]; i++) {
    FSNBrowserCell *cell = [self cellWithName: [names objectAtIndex: i]];
    
    if (cell && [cell isEnabled]) {   
      [cell setEnabled: NO];
      found = YES;
    }
  }
		
  [matrix setNeedsDisplay: found];   
}

- (void)unLockCellsOfNodes:(NSArray *)nodes
{
  NSUInteger i;
  BOOL found = NO;

  for (i = 0; i < [nodes count]; i++) {
    FSNBrowserCell *cell = [self cellOfNode: [nodes objectAtIndex: i]];
    
    if (cell && ([cell isEnabled] == NO)) { 
      [cell setEnabled: YES];
      found = YES;
    }
  }
		
  [matrix setNeedsDisplay: found];   
}

- (void)unLockCellsWithPaths:(NSArray *)paths
{
  NSUInteger i;
  BOOL found = NO;

  for (i = 0; i < [paths count]; i++) {
    FSNBrowserCell *cell = [self cellWithPath: [paths objectAtIndex: i]];
    
    if (cell && ([cell isEnabled] == NO)) { 
      [cell setEnabled: YES];
      found = YES;
    }
  }
		
  [matrix setNeedsDisplay: found];   
}

- (void)unLockCellsWithNames:(NSArray *)names
{
  NSUInteger i;
  BOOL found = NO;

  for (i = 0; i < [names count]; i++) {
    FSNBrowserCell *cell = [self cellWithName: [names objectAtIndex: i]];
    
    if (cell && ([cell isEnabled] == NO)) { 
      [cell setEnabled: YES];
      found = YES;
    }
  }
		
  [matrix setNeedsDisplay: found];   
}

- (void)lock
{
  NSArray *cells = [matrix cells];
  NSUInteger i;  

  for (i = 0; i < [cells count]; i++)
    {
      id cell = [cells objectAtIndex: i];
      
      if ([cell isEnabled])
    	[cell setEnabled: NO];
    }

  [matrix setNeedsDisplay: YES];   
}

- (void)unlock
{
  NSArray *cells = [matrix cells];
  NSUInteger i;  

  for (i = 0; i < [cells count]; i++)
    {
      id cell = [cells objectAtIndex: i];

      if ([cell isEnabled] == NO)
    	[cell setEnabled: YES];
    }

  [matrix setNeedsDisplay: YES];   
}

- (FSNBrowserCell *)cellOfNode:(FSNode *)node
{
  NSArray *cells = [matrix cells];
  NSUInteger i;

  for (i = 0; i < [cells count]; i++)
    {
      FSNBrowserCell *cell = [cells objectAtIndex: i];
      
      if ([[cell node] isEqualToNode: node])
        return cell;
    }

  return nil;
}            

- (FSNBrowserCell *)cellWithPath:(NSString *)path
{
  NSArray *cells = [matrix cells];
  NSUInteger i;

  for (i = 0; i < [cells count]; i++)
    {
      FSNBrowserCell *cell = [cells objectAtIndex: i];
    
      if ([[[cell node] path] isEqual: path])
	return cell;
    }

  return nil;
}            

- (FSNBrowserCell *)cellWithName:(NSString *)name
{
  NSArray *cells = [matrix cells];
  NSUInteger i;

  for (i = 0; i < [cells count]; i++)
    {
      FSNBrowserCell *cell = [cells objectAtIndex: i];
    
      if ([[[cell node] name] isEqual: name])
	return cell;
    
    }

  return nil;
}             

- (void)adjustMatrix
{
  if (scroll == nil)
    {
      NSLog(@"FSNBrowserColumn adjustMatrix: scroll is nil");
      return;
    }
  
  [matrix setCellSize: NSMakeSize([scroll contentSize].width, cellsHeight)];  
  [matrix sizeToCells];
}

- (void)doClick:(id)sender
{
  [browser clickInMatrixOfColumn: self];
}

- (void)doDoubleClick:(id)sender
{
  [browser doubleClickInMatrixOfColumn: self];
}

- (NSMatrix *)cmatrix
{
  return matrix;
}

- (NSInteger)index
{
  return index;
}

- (BOOL)isLoaded
{
  return isLoaded;
}

- (BOOL)isSelected
{
  if (isLoaded && matrix) {
    return ([matrix selectedCell] ? YES : NO);
  }
  
  return NO;
}

- (void)setBackgroundColor:(NSColor *)acolor
{
  ASSIGN (backColor, acolor);
  [matrix setBackgroundColor: backColor];
  [matrix setCellBackgroundColor: backColor];
}

- (void)mouseUp:(NSEvent *)theEvent
{
  NSPoint p = [theEvent locationInWindow];
  NSInteger row, col;

  p = [matrix convertPoint: p fromView: nil];

  if ([matrix getRow: &row column: &col forPoint: p] == NO) {
    [browser clickInColumn: self];
  }
}

- (void)setFrame:(NSRect)frameRect
{
  NSRect r = NSMakeRect(1, 0, frameRect.size.width -1, frameRect.size.height);
  
  if (index == [browser firstVisibleColumn])
    {
      r.origin.x = 0;
      r.size.width += 1;
    }
  
  CHECKRECT (frameRect);
  [super setFrame: frameRect]; 
   
  CHECKRECT (r);

  if (scroll != nil)
    {
      [scroll setFrame: r];  
      [self adjustMatrix];
    }
}

- (void)drawRect:(NSRect)rect
{
  [super drawRect: rect];
  
  if (index != [browser firstVisibleColumn])
    {
      [[NSColor blackColor] set];  
      [NSBezierPath strokeLineFromPoint: NSMakePoint(0, 0) 
				toPoint: NSMakePoint(0, rect.size.height)];
    }
}

@end


@implementation FSNBrowserColumn (DraggingDestination)

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pb;
  NSDragOperation sourceDragMask;
  NSArray *sourcePaths;
  NSString *basePath;
  NSString *nodePath;
  NSString *prePath;
  NSUInteger count;
  
  isDragTarget = NO;	
  
  if ((shownNode == nil) || ([shownNode isValid] == NO)) {
    return NSDragOperationNone;
  }

  if ([shownNode isDirectory]) {
    if ([shownNode isSubnodeOfPath: [desktopApp trashPath]]) { 
      return NSDragOperationNone;
    }
  }	
  
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
  if (count == 0)
    return NSDragOperationNone;
    
  if ([shownNode isWritable] == NO) {
    return NSDragOperationNone;
  }
    
  nodePath = [shownNode path];

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

  if ([shownNode isDirectory] && [shownNode isParentOfPath: basePath]) {
    NSArray *subNodes = [shownNode subNodes];
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

  isDragTarget = NO;	
  return NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
  
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

  return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  isDragTarget = NO;
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
  return isDragTarget;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
  return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pb;
  NSDragOperation sourceDragMask;
  NSArray *sourcePaths;
  NSString *operation, *source;
  NSMutableArray *files;
  NSMutableDictionary *opDict;
  NSString *trashPath;
  NSUInteger i;

  isDragTarget = NO;  

  sourceDragMask = [sender draggingSourceOperationMask];
  pb = [sender draggingPasteboard];
    
  if ([[pb types] containsObject: @"GWRemoteFilenamesPboardType"]) {  
    NSData *pbData = [pb dataForType: @"GWRemoteFilenamesPboardType"]; 

    [desktopApp concludeRemoteFilesDragOperation: pbData
                                     atLocalPath: [shownNode path]];
    return;
    
  } else if ([[pb types] containsObject: @"GWLSFolderPboardType"]) {  
    NSData *pbData = [pb dataForType: @"GWLSFolderPboardType"]; 

    [desktopApp lsfolderDragOperation: pbData
                      concludedAtPath: [shownNode path]];
    return;
  }
    
  sourcePaths = [pb propertyListForType: NSFilenamesPboardType];
  
  if ([sourcePaths count] == 0)
    return;
  
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
  for (i = 0; i < [sourcePaths count]; i++)
    [files addObject: [[sourcePaths objectAtIndex: i] lastPathComponent]];
  
  opDict = [NSMutableDictionary dictionary];
  [opDict setObject: operation forKey: @"operation"];
  [opDict setObject: source forKey: @"source"];
  [opDict setObject: [shownNode path] forKey: @"destination"];
  [opDict setObject: files forKey: @"files"];

  [desktopApp performFileOperation: opDict];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
                      inMatrixCell:(id)cell
{
  NSPasteboard *pb = [sender draggingPasteboard];
  NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
  FSNode *node = [cell node];
  NSString *nodePath = [node path];
  NSArray *sourcePaths;
  NSString *fromPath;
  NSString *prePath;
  NSUInteger i, count;

  if (([cell isEnabled] == NO) || ([node isDirectory] == NO) 
            || ([node isPackage] && ([node isApplication] == NO))
            || (([node isWritable] == NO) && ([node isApplication] == NO))) {
    return NSDragOperationNone;
  }

  if ([node isDirectory]) {
    if ([node isSubnodeOfPath: [desktopApp trashPath]]) { 
      return NSDragOperationNone;
    }
  }	
 
  sourcePaths = nil;

  if ([[pb types] containsObject: NSFilenamesPboardType]) {
    sourcePaths = [pb propertyListForType: NSFilenamesPboardType]; 
       
  } else if ([[pb types] containsObject: @"GWRemoteFilenamesPboardType"]) {
    if ([node isApplication] == NO) {
      NSData *pbData = [pb dataForType: @"GWRemoteFilenamesPboardType"]; 
      NSDictionary *pbDict = [NSUnarchiver unarchiveObjectWithData: pbData];
    
      sourcePaths = [pbDict objectForKey: @"paths"];
    }
  } else if ([[pb types] containsObject: @"GWLSFolderPboardType"]) {
    if ([node isApplication] == NO) {
      NSData *pbData = [pb dataForType: @"GWLSFolderPboardType"]; 
      NSDictionary *pbDict = [NSUnarchiver unarchiveObjectWithData: pbData];
    
      sourcePaths = [pbDict objectForKey: @"paths"];
    }
  }

  if (sourcePaths == nil) {
    return NSDragOperationNone;
  }
  
  count = [sourcePaths count];
  if (count == 0) {
    return NSDragOperationNone;
  } 

  fromPath = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];

  if ([nodePath isEqual: fromPath]) {
    return NSDragOperationNone;
  }  

  if ([sourcePaths containsObject: nodePath]) {
    return NSDragOperationNone;
  }

  prePath = [NSString stringWithString: nodePath];

  while (1) {
    CREATE_AUTORELEASE_POOL(arp);

    if ([sourcePaths containsObject: prePath]) {
      RELEASE (arp);
      return NSDragOperationNone;
    }
    if ([prePath isEqual: path_separator()]) {
      RELEASE (arp);
      break;
    }            
    prePath = [prePath stringByDeletingLastPathComponent];
    RELEASE (arp);
  }

  if ([node isApplication]) {
    for (i = 0; i < count; i++) {
      CREATE_AUTORELEASE_POOL(arp);
      FSNode *nd = [FSNode nodeWithPath: [sourcePaths objectAtIndex: i]];
      
      if (([nd isPlain] == NO) && ([nd isPackage] == NO)) {
        RELEASE (arp);
        return NSDragOperationNone;
      }
      RELEASE (arp);
    }
  }

  if ([node isDirectory] && [node isParentOfPath: fromPath]) {
    NSArray *subNodes = [node subNodes];
    
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

  if (sourceDragMask == NSDragOperationCopy) {
    return ([node isApplication] ? NSDragOperationMove : NSDragOperationCopy);
  } else if (sourceDragMask == NSDragOperationLink) {
    return ([node isApplication] ? NSDragOperationMove : NSDragOperationLink);
  } else {
    if ([[NSFileManager defaultManager] isWritableFileAtPath: fromPath]
	|| [node isApplication]) {
      return NSDragOperationAll;			
    } else {
      return NSDragOperationCopy;			
    }
  }
    
  return NSDragOperationNone;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
                 inMatrixCell:(id)cell
{
  FSNode *node = [cell node];
  NSPasteboard *pb = [sender draggingPasteboard];
  NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
  NSArray *sourcePaths;
  NSString *operation, *source;
  NSMutableArray *files;
  NSMutableDictionary *opDict;
  NSString *trashPath;
  NSUInteger i;

  if (([cell isEnabled] == NO) 
      || ([cell isLeaf] && ([node isApplication] == NO)))
    {
    return;
  }

  if ([node isApplication] == NO)
    {    
      if ([[pb types] containsObject: @"GWRemoteFilenamesPboardType"])
	{  
	  NSData *pbData = [pb dataForType: @"GWRemoteFilenamesPboardType"]; 

	  [desktopApp concludeRemoteFilesDragOperation: pbData
					   atLocalPath: [[cell node] path]];
	  return;

	}
      else if ([[pb types] containsObject: @"GWLSFolderPboardType"])
	{  
	  NSData *pbData = [pb dataForType: @"GWLSFolderPboardType"]; 

	  [desktopApp lsfolderDragOperation: pbData
			    concludedAtPath: [[cell node] path]];
	  return;
	}
    }
  
  sourcePaths = [pb propertyListForType: NSFilenamesPboardType];

  if ([node isApplication] == NO)
    {  
      source = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];
      trashPath = [desktopApp trashPath];

      if ([source isEqual: trashPath])
	{
	  operation = @"GWorkspaceRecycleOutOperation";
	}
      else
	{	
	  if (sourceDragMask == NSDragOperationCopy)
	    {
	      operation = NSWorkspaceCopyOperation;
	    }
	  else if (sourceDragMask == NSDragOperationLink)
	    {
	      operation = NSWorkspaceLinkOperation;
	    }
	  else
	    {
	      if ([[NSFileManager defaultManager] isWritableFileAtPath: source])
		{
		  operation = NSWorkspaceMoveOperation;
		}
	      else
		{
		  operation = NSWorkspaceCopyOperation;
		}
	    }
	}

    files = [NSMutableArray arrayWithCapacity: 1];    
    for(i = 0; i < [sourcePaths count]; i++)
      {    
	[files addObject: [[sourcePaths objectAtIndex: i] lastPathComponent]];
      }  

    opDict = [NSMutableDictionary dictionaryWithCapacity: 4];
    [opDict setObject: operation forKey: @"operation"];
    [opDict setObject: source forKey: @"source"];
    [opDict setObject: [[cell node] path] forKey: @"destination"];
    [opDict setObject: files forKey: @"files"];

    [desktopApp performFileOperation: opDict];
    }
  else
    {
      for (i = 0; i < [sourcePaths count]; i++)
	{    
	  NSString *path = [sourcePaths objectAtIndex: i];
    
	  NS_DURING
	    {
	      [[NSWorkspace sharedWorkspace] openFile: path 
				      withApplication: [node name]];
	    }
	  NS_HANDLER
	    {
	      NSRunAlertPanel(NSLocalizedString(@"error", @""), 
			      [NSString stringWithFormat: @"%@ %@!", 
					NSLocalizedString(@"Can't open ", @""), [node name]],
			      NSLocalizedString(@"OK", @""), 
			      nil, 
			      nil);                                     
	    }
	  NS_ENDHANDLER  
        }
    }
}

@end
