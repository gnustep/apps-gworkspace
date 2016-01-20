/* FSNBrowser.m
 *  
 * Copyright (C) 2004-2016 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 *         Riccardo Mottola <rm@gnu.org>
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
#include <unistd.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <GNUstepBase/GNUstep.h>
#import "FSNBrowser.h"
#import "FSNBrowserColumn.h"
#import "FSNBrowserMatrix.h"
#import "FSNBrowserCell.h"
#import "FSNIcon.h"
#import "FSNFunctions.h"


#define DEFAULT_ISIZE 24

#ifndef max
#define max(a,b) ((a) >= (b) ? (a):(b))
#define min(a,b) ((a) <= (b) ? (a):(b))
#endif

@implementation FSNBrowser

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  RELEASE (baseNode);
  RELEASE (extInfoType);  
  RELEASE (lastSelection);
  RELEASE (columns);
  RELEASE (nameEditor);
  RELEASE (cellPrototype);
  RELEASE (charBuffer);
  RELEASE (backColor);

  [super dealloc];
}

- (id)initWithBaseNode:(FSNode *)bsnode
		    visibleColumns:(int)vcols 
              scroller:(NSScroller *)scrl
            cellsIcons:(BOOL)cicns
         editableCells:(BOOL)edcells
       selectionColumn:(BOOL)selcol
{
  self = [super init];
  
  if (self) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
    NSString *appName = [defaults stringForKey: @"DesktopApplicationName"];
    NSString *selName = [defaults stringForKey: @"DesktopApplicationSelName"];
    id defentry;
    int i;
    
    fsnodeRep = [FSNodeRep sharedInstance];
    
    if (appName && selName) {
      Class desktopAppClass = [[NSBundle mainBundle] classNamed: appName];
      SEL sel = NSSelectorFromString(selName);
      desktopApp = [desktopAppClass performSelector: sel];
    }
    
    ASSIGN (backColor, [NSColor windowBackgroundColor]);
  
    defentry = [defaults objectForKey: @"fsn_info_type"];
    infoType = defentry ? [defentry intValue] : FSNInfoNameType;
    extInfoType = nil;
    
    if (infoType == FSNInfoExtendedType) {
      defentry = [defaults objectForKey: @"extended_info_type"];

      if (defentry) {
        NSArray *availableTypes = [fsnodeRep availableExtendedInfoNames];
      
        if ([availableTypes containsObject: defentry]) {
          ASSIGN (extInfoType, defentry);
        }
      }
      
      if (extInfoType == nil) {
        infoType = FSNInfoNameType;
      }
    }
    
    ASSIGN (baseNode, [FSNode nodeWithPath: [bsnode path]]);	    
    [self readNodeInfo];
    
    lastSelection = nil;
    visibleColumns = vcols;
    
    scroller = scrl;
    [scroller setTarget: self];
    [scroller setAction: @selector(scrollViaScroller:)];    
    
    cellsIcon = cicns;
    selColumn = selcol;

    updateViewsLock = 0;
   
    if ([defaults objectForKey:@"NSFontSize"])
      fontSize = [defaults integerForKey:@"NSFontSize"];
    else
      fontSize = 12;
    cellPrototype = [FSNBrowserCell new];
    [cellPrototype setFont: [NSFont systemFontOfSize: fontSize]];

    columns = [NSMutableArray new];
  
    nameEditor = nil;
  
    if (edcells) {
      nameEditor = [FSNCellNameEditor new];
      [nameEditor setDelegate: self];  
      [nameEditor setEditable: YES];
      [nameEditor setSelectable: YES];	   
      [nameEditor setFont: [cellPrototype font]];
      [nameEditor setBezeled: NO];
      [nameEditor setAlignment: NSLeftTextAlignment];
    }  
  
    for (i = 0; i < visibleColumns; i++) {
      [self createEmptyColumn];
    }
		    
    firstVisibleColumn = 0;
    lastVisibleColumn = visibleColumns - 1;	
    currentshift = 0;	
    lastColumnLoaded = -1;
    alphaNumericalLastColumn = -1;
		
    skipUpdateScroller = NO;
    lastKeyPressed = 0.;
    charBuffer = nil;
    simulatingDoubleClick = NO;    
    isLoaded = NO;	

    viewer = nil;
    manager = nil;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(defaultsChanged:) name:NSUserDefaultsDidChangeNotification object:nil];
  }
  
  return self;
}

- (void)defaultsChanged:(NSNotification *)not
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
  NSInteger newSize;

  if ([defaults objectForKey:@"NSFontSize"]) {
    newSize = [defaults integerForKey:@"NSFontSize"];
    if (newSize != fontSize) {
      fontSize = newSize;
      [cellPrototype setFont: [NSFont systemFontOfSize: fontSize]];
      [nameEditor setFont: [cellPrototype font]];
      [self setVisibleColumns:[self visibleColumns]];
    }
  }
}

- (void)setBaseNode:(FSNode *)node
{
  ASSIGN (baseNode, [FSNode nodeWithPath: [node path]]);
  [self readNodeInfo];
  [self loadColumnZero];
  [self notifySelectionChange: [NSArray arrayWithObject: node]];
}

- (void)setUsesCellsIcons:(BOOL)cicns
{
  cellsIcon = cicns;
}

- (void)setUsesSelectionColumn:(BOOL)selcol
{
  selColumn = selcol;
}

- (void)setVisibleColumns:(int)vcols
{
  FSNBrowserColumn *bc = [self lastLoadedColumn];
  NSArray *selection = nil;
  int i;

  updateViewsLock++;
  
  if (bc) {
    selection = [bc selectedNodes];
  
    if ((selection == nil) && [bc shownNode]) {
      selection = [NSArray arrayWithObject: [bc shownNode]];
    }
  }  
  
  if (selection == nil) {
    selection = [NSArray arrayWithObject: baseNode];
  }
  
  selection = [selection copy];
  
  for (i = 0; i < [columns count]; i++) {
    [[columns objectAtIndex: i] removeFromSuperview];
  }

  [columns removeAllObjects];

  visibleColumns = vcols;
  
  for (i = 0; i < visibleColumns; i++) {
    [self createEmptyColumn];
  }
		    
  firstVisibleColumn = 0;
  lastVisibleColumn = visibleColumns - 1;	
  currentshift = 0;	
  lastColumnLoaded = -1;
  skipUpdateScroller = NO;
  isLoaded = NO;	

  [self showSelection: selection];
  RELEASE (selection);
    
  updateViewsLock--;
  [self tile];

  bc = [self lastLoadedColumn];
  if (bc) {
    [[self window] makeFirstResponder: [bc cmatrix]];
  }  
}

- (int)visibleColumns
{
  return visibleColumns;
}


- (void)showSubnode:(FSNode *)node
{
  NSArray *components;
	int column;
  int i;
  
  updateViewsLock++;
  
  if ([node isEqual: baseNode] || ([node isSubnodeOfNode: baseNode] == NO)) {
    updateViewsLock--;
    [self setBaseNode: node];
    [self tile];
		[self setNeedsDisplay: YES];
		return;
	}

  [self loadColumnZero];
  
  if ([[baseNode path] isEqual: path_separator()]) {
    components = [FSNode nodeComponentsToNode: node];
  } else {
    components = [FSNode nodeComponentsFromNode: baseNode toNode: node];
  }

  if ([components count] == 1) {
    updateViewsLock--;
    [self tile];
		[self setNeedsDisplay: YES];
		return;
  }

  components = [components subarrayWithRange: NSMakeRange(1, [components count] -1)];

  column = lastColumnLoaded;
  
  for (i = 0; i < [components count]; i++) {
    FSNBrowserColumn *bc = [columns objectAtIndex: column + i];
    FSNode *nd = [components objectAtIndex: i];
    FSNBrowserCell *cell = [bc selectCellOfNode: nd sendAction: NO];
    
    if (cell) {
      if ([cell isLeaf]) {
        break;
      }
    } else {
      NSLog(@"Browser: unable to find cell '%@' in column %d\n", [nd name], column + i);
      break;
    }
    
    nd = [FSNode nodeWithRelativePath: [nd name] parent: [bc shownNode]];
    [self addAndLoadColumnForNode: nd];
  }
  
  updateViewsLock--;
  [self tile];
  [self setNeedsDisplay: YES];
}

- (void)showSelection:(NSArray *)selection
{
  if (selection && [selection count]) {
    FSNode *node = [selection objectAtIndex: 0];
    FSNBrowserColumn *bc;
    NSArray *selNodes;
    
    updateViewsLock++;
    
    if ([selection count] > 1) {
      BOOL alldirs = YES;
      int i;
      
      for (i = 0; i < [selection count]; i++) {
        FSNode *nd = [selection objectAtIndex: i];  
        
        if ([nd isDirectory] == NO) {
          node = nd;
          alldirs = NO;
          break;
        }
      }
    
      if (alldirs) {
        node = [FSNode nodeWithPath: [node parentPath]];
      }
    }
    
    [self showSubnode: node];

    bc = [self lastLoadedColumn];
    [bc selectCellsOfNodes: selection sendAction: NO];

    if (selColumn) {
      if ([selection count] == 1) {
        FSNode *node = [selection objectAtIndex: 0];

        if (([node isDirectory] == NO) || [node isPackage]) {
          [self addFillingColumn];
        }

      } else {
        [self addFillingColumn];
      }
    }

    updateViewsLock--;
    [self tile];

    selNodes = [bc selectedNodes];
    if (selNodes == nil) {
      selNodes = [NSArray arrayWithObject: [bc shownNode]];
    }
    [self notifySelectionChange: selNodes];
  }
}

- (void)showPathsSelection:(NSArray *)selpaths
{
  if (selpaths && [selpaths count]) {
    FSNode *node = [FSNode nodeWithPath: [selpaths objectAtIndex: 0]];      
    FSNBrowserColumn *bc;
    NSArray *selNodes;

    updateViewsLock++;

    if ([selpaths count] > 1) {
      BOOL alldirs = YES;
      int i;
      
      for (i = 0; i < [selpaths count]; i++) {
        FSNode *nd = [FSNode nodeWithPath: [selpaths objectAtIndex: i]];
        
        if ([nd isDirectory] == NO) {
          node = nd;
          alldirs = NO;
          break;
        }
      }
    
      if (alldirs) {
        node = [FSNode nodeWithPath: [node parentPath]];
      }
    }

    [self showSubnode: node];

    bc = [self lastLoadedColumn];
    [bc selectCellsWithPaths: selpaths sendAction: NO];

    if (selColumn) {
      if ([selpaths count] == 1) {
        if (([node isDirectory] == NO) || [node isPackage]) {
          [self addFillingColumn];
        }

      } else {
        [self addFillingColumn];
      }
    }

    updateViewsLock--;
    [self tile];

    selNodes = [bc selectedNodes];
    if (selNodes == nil) {
      selNodes = [NSArray arrayWithObject: [bc shownNode]];
    }
    [self notifySelectionChange: selNodes];
  }
}


- (void)loadColumnZero
{
  updateViewsLock++;
  [self setLastColumn: -1];
  [self addAndLoadColumnForNode: baseNode];
  isLoaded = YES;
  updateViewsLock--;
  [self tile];
}

- (FSNBrowserColumn *)createEmptyColumn
{
  CREATE_AUTORELEASE_POOL(arp);
  int count = [columns count];
  FSNBrowserColumn *bc = [[FSNBrowserColumn alloc] initInBrowser: self
                                       atIndex: count
                                 cellPrototype: cellPrototype
                                     cellsIcon: cellsIcon
                                  nodeInfoType: infoType
                                  extendedType: extInfoType
                               backgroundColor: backColor];
                                     
  [columns insertObject: bc atIndex: count];
  [self addSubview: bc]; 
  RELEASE(bc);
  RELEASE (arp);
  	
  return bc;
}

- (void)addAndLoadColumnForNode:(FSNode *)node
{
  FSNBrowserColumn *bc;
  int i;
			
  if (lastColumnLoaded + 1 >= [columns count]) {
    i = [columns indexOfObject: [self createEmptyColumn]];
	} else {
    i = lastColumnLoaded + 1;
	}
  
  bc = [columns objectAtIndex: i];
  [bc showContentsOfNode: node];
  
  updateViewsLock++;
  [self setLastColumn: i];
  isLoaded = YES;

  if ((i > 0) && ((i - 1) == lastVisibleColumn)) { 
    [self scrollColumnsRightBy: 1];
	} 
  
  updateViewsLock--;
  [self tile];
}

- (void)addFillingColumn 
{
  int i;
			
  if (lastColumnLoaded + 1 >= [columns count]) {
    i = [columns indexOfObject: [self createEmptyColumn]];
	} else {
    i = lastColumnLoaded + 1;
	}
        
  updateViewsLock++;
  [self setLastColumn: i];

  if ((i > 0) && ((i - 1) == lastVisibleColumn)) { 
    [self scrollColumnsRightBy: 1];
	} 
  
  updateViewsLock--;
  [self tile];
}

- (void)unloadFromColumn:(int)column
{
  FSNBrowserColumn *bc = nil; 
	int count = [columns count];
	int i;			
  
  updateViewsLock++;
	
  for (i = column; i < count; ++i) {
		bc = [columns objectAtIndex: i];

		if ([bc isLoaded]) {			
	  	[bc showContentsOfNode: nil];
		}
		
		if (i >= visibleColumns) {
	  	[bc removeFromSuperview];
      [columns removeObject: bc];			
	  	count--;
	  	i--;
		}
  }
  
  if (column == 0) {
		isLoaded = NO;
	}
  
  if (column <= lastVisibleColumn) {
		[self scrollColumnsLeftBy: lastVisibleColumn - column + 1];
	}
	
  updateViewsLock--;
  [self tile];
}

- (void)reloadColumnWithNode:(FSNode *)anode
{
  FSNBrowserColumn *col = [self columnWithNode: anode];
  
  if (col) {
    [col showContentsOfNode: anode];    
  }
}

- (void)reloadColumnWithPath:(NSString *)path
{
  FSNBrowserColumn *col = [self columnWithPath: path];
  
  if (col) {
    FSNBrowserColumn *parentCol = [self columnBeforeColumn: col];
    FSNode *node;  
    
    if (parentCol) {
      node = [FSNode nodeWithRelativePath: path parent: [parentCol shownNode]];      
    } else {
      node = [FSNode nodeWithPath: path];      
    }
    
    [col showContentsOfNode: node];    
  }
}

- (void)reloadFromColumn:(FSNBrowserColumn *)col
{
  CREATE_AUTORELEASE_POOL(arp);
	int index = [col index];
  int i = 0;

  updateViewsLock++;
  
	for (i = index; i < [columns count]; i++) {
    FSNBrowserColumn *nextcol = [columns objectAtIndex: i];
    NSArray *selection = [self selectionInColumnBeforeColumn: nextcol];
    BOOL done = NO;
    
    if (selection && ([selection count] == 1)) {
      FSNode *node = [selection objectAtIndex: 0];
    
      if ([node isDirectory] && (([node isPackage] == NO) || (i == 0))) {
        [nextcol showContentsOfNode: node]; 
      } else {
        done = YES;
      }
    } else {
      done = YES;
    }
    
    if (done) {
      int last = (i > 0) ? i - 1 : 0;
      int shift = 0;
      int leftscr = 0;
    
      if (last >= visibleColumns) {
        if (last < firstVisibleColumn) {
          shift = visibleColumns - 1;
        } else if (last > lastVisibleColumn) {
          leftscr = last - lastVisibleColumn;
        } else {
          shift = lastVisibleColumn - last;
        }
      }

      [self setLastColumn: last];

      if (shift) {
        currentshift = 0;
        [self setShift: shift];
      } else if (leftscr) {
        [self scrollColumnsLeftBy: leftscr];
      }

      break;
    }
	}

  col = [self lastLoadedColumn];

  if (col) {
    NSArray *selection = [col selectedNodes];
    int index = [col index];

    if (index < firstVisibleColumn) {
      [self scrollColumnToVisible: index];      
    }
    
    [[self window] makeFirstResponder: [col cmatrix]];

    if (selection) {
      if (selColumn && (index == lastColumnLoaded)) {
        if ([selection count] == 1) {
          FSNode *node = [selection objectAtIndex: 0];
        
          if (([node isDirectory] == NO) || [node isPackage]) {
            [self addFillingColumn];
          }
        
        } else {
          [self addFillingColumn];
        }
      }
    
      [self notifySelectionChange: selection];	
    
    } else {
      FSNode *node = [col shownNode];
      [self notifySelectionChange: [NSArray arrayWithObject: node]];
    }
  }

  updateViewsLock--;
  [self tile];
  RELEASE (arp);
}

- (void)reloadFromColumnWithNode:(FSNode *)anode
{
  FSNBrowserColumn *col = [self columnWithNode: anode];
  
  if (col) {
    [self reloadFromColumn: col];
  }
}

- (void)reloadFromColumnWithPath:(NSString *)path
{
  FSNBrowserColumn *col = [self columnWithPath: path];
  
  if (col) {
    [self reloadFromColumn: col];
  }
}

- (void)setLastColumn:(int)column
{
  lastColumnLoaded = column;
  [self unloadFromColumn: column + 1];
}


- (void)tile
{
  updateViewsLock = (updateViewsLock < 0) ? 0 : updateViewsLock;

  if (updateViewsLock == 0) {
    NSWindow *window = [self window];
    NSRect r = [self bounds];
    float frameWidth = r.size.width - visibleColumns;
    int count = [columns count];
    NSRect colrect;
    int i;

    columnSize.height = r.size.height;
    columnSize.width = myrintf(frameWidth / visibleColumns);
    
    [window disableFlushWindow];
    
    for (i = 0; i < count; i++) {
      int n = i - firstVisibleColumn;
    
      colrect = NSZeroRect;
      colrect.size = columnSize;
      colrect.origin.y = 0;

      if (i < firstVisibleColumn) {
        colrect.origin.x = (n * columnSize.width) - 8;
      } else {
        if (i == firstVisibleColumn) {
          colrect.origin.x = (n * columnSize.width);
        } else if (i <= lastVisibleColumn) {
          colrect.origin.x = (n * columnSize.width) + n;
        } else {
          colrect.origin.x = (n * columnSize.width) + n + 8;
        }
	    }

      if (i == lastVisibleColumn) {
        colrect.size.width = [self bounds].size.width - colrect.origin.x;
	    }
      
      [[columns objectAtIndex: i] setFrame: colrect];
    }
    
    [self synchronizeViewer];
    [self updateScroller];
    [self stopCellEditing];
        
    [window enableFlushWindow];
    [window flushWindowIfNeeded];
  }
}

- (void)scrollViaScroller:(NSScroller *)sender
{
  NSScrollerPart hit = [sender hitPart];
  BOOL needsDisplay = NO;
  
  updateViewsLock++;
  skipUpdateScroller = YES;
  
  switch (hit) {
		// Scroll to the left
		case NSScrollerDecrementLine:
		case NSScrollerDecrementPage:        
			[self scrollColumnsLeftBy: 1];
			if (currentshift > 0) {
        [self setLastColumn: (lastColumnLoaded - currentshift)];
        [self setShift: currentshift - 1];
      }
			break;
      
		// Scroll to the right
		case NSScrollerIncrementLine:
		case NSScrollerIncrementPage:
      [self scrollColumnsRightBy: 1];
      needsDisplay = YES;
			break;
      
		// The knob or knob slot
		case NSScrollerKnob:
		case NSScrollerKnobSlot: 
      {
	  		float f = [sender floatValue];
	  		float n = lastColumnLoaded + 1 - visibleColumns;
				
	  		[self scrollColumnToVisible: myrintf(f * n) + visibleColumns - 1];
				
        if (currentshift > 0) {
          [self setLastColumn: (lastColumnLoaded - currentshift)];			
		      currentshift = 0;
        }
        
        needsDisplay = YES;
			}
      break;
      
		default:
			break;
	}
  
  skipUpdateScroller = NO;
  
  updateViewsLock--;
  [self tile];
  [self setNeedsDisplay: needsDisplay];
} 

- (void)updateScroller
{
  if ((lastColumnLoaded == 0) || (lastColumnLoaded <= (visibleColumns - 1))) {
		[scroller setEnabled: NO];

	} else {
		if (skipUpdateScroller == NO) {
			float prop = (float)visibleColumns / (float)(lastColumnLoaded + 1);
			float i = lastColumnLoaded - visibleColumns + 1;
			float f = 1 + ((lastVisibleColumn - lastColumnLoaded) / i);
      
	    if (lastVisibleColumn > lastColumnLoaded) {   
        prop = (float)visibleColumns / (float)(lastVisibleColumn + 1);
      }
      
			[scroller setFloatValue: f knobProportion: prop];
		}

		[scroller setEnabled: YES];
	}
  
  [scroller setNeedsDisplay: YES];
}

- (void)scrollColumnsLeftBy:(int)shiftAmount
{	
  if ((firstVisibleColumn - shiftAmount) < 0) {
    shiftAmount = firstVisibleColumn;
	}
	
  if (shiftAmount <= 0) {
    return;
	}
		
  firstVisibleColumn = firstVisibleColumn - shiftAmount;
  lastVisibleColumn = lastVisibleColumn - shiftAmount;

  [self tile];
  
  [self setNeedsDisplay: YES];
}

- (void)scrollColumnsRightBy:(int)shiftAmount
{	
  if ((shiftAmount + lastVisibleColumn) > lastColumnLoaded) {
    shiftAmount = lastColumnLoaded - lastVisibleColumn;
	}
	
  if (shiftAmount <= 0) {
    return;
	}
		
  firstVisibleColumn = firstVisibleColumn + shiftAmount;
  lastVisibleColumn = lastVisibleColumn + shiftAmount;

  [self tile];
}

- (void)scrollColumnToVisible:(int)column
{
  int i;
	
  if (lastVisibleColumn == column) {
    return;
	}
	
  if ((lastColumnLoaded + 1) <= visibleColumns) {
    return;
	}
		
  i = lastVisibleColumn - column;
  if (i > 0) {
    [self scrollColumnsLeftBy: i];
  } else {
    [self scrollColumnsRightBy: -i];
	}
}

- (void)moveLeft
{
	FSNBrowserColumn *selCol = [self selectedColumn];
	int index;
  			
	if (selCol == nil) {
		return;
	}

  index = [selCol index];
  
  if (index > 0) {
    updateViewsLock++;
    
    index--;
    if (index < firstVisibleColumn) {
      [self scrollColumnToVisible: index];      
    }
    
    selCol = [columns objectAtIndex: index];
    [[self window] makeFirstResponder: [selCol cmatrix]];
    [self clickInMatrixOfColumn: selCol];
    
    updateViewsLock--;
    [self tile];
  }
}

- (void)moveRight
{
	FSNBrowserColumn *selCol = [self selectedColumn];
  			
	if (selCol == nil) {
		selCol = [columns objectAtIndex: 0];
    
    if ([selCol selectFirstCell]) {
      [[self window] makeFirstResponder: [selCol cmatrix]];
    }
	} else {
    NSMatrix *matrix = [selCol cmatrix];
    
    if ([[matrix cells] count]) {
      int index = [selCol index];
      
      [matrix sendAction];
      
      if (index < ([columns count] - 1)) {
        selCol = [columns objectAtIndex: index + 1];
        matrix = [selCol cmatrix];
        
        if ([[matrix cells] count]) {
          if ([selCol selectFirstCell]) {
            [matrix sendAction];  
            [[self window] makeFirstResponder: matrix];
          }
        }
      }
    }
  }
}

- (void)setShift:(int)s
{
  int i;
    			
  for (i = 0; i < s; i++) {  
    [self createEmptyColumn];
  }
	
	currentshift = s;  
  updateViewsLock++;
  [self setLastColumn: (lastColumnLoaded + s)];
  [self scrollColumnsRightBy: s];
  updateViewsLock--;
  [self tile];
}

- (FSNode *)nodeOfLastColumn
{
  FSNBrowserColumn *col = [self lastLoadedColumn];

  if (col) {
    return [col shownNode];
  }
  
  return nil;
}

- (NSString *)pathToLastColumn
{
  FSNode *node = [self nodeOfLastColumn];

  if (node) {
    return [node path];
  }
  
  return nil;
}

- (NSArray *)selectionInColumnBeforeColumn:(FSNBrowserColumn *)col
{
  int index = [col index];
  
  if (index == 0) {
    return [NSArray arrayWithObject: baseNode];
  } 
  
  return [[columns objectAtIndex: index - 1] selectedNodes];
}

- (void)selectCellsWithNames:(NSArray *)names 
            inColumnWithPath:(NSString *)cpath
                  sendAction:(BOOL)act
{
  FSNBrowserColumn *col = [self columnWithPath: cpath];
  
  if (col) {
    [col selectCellsWithNames: names sendAction: act];
  }
}

- (void)selectAllInLastColumn
{
  FSNBrowserColumn *col = [self lastLoadedColumn];

  if (col) {
    [col selectAll];
  }
}

- (void)notifySelectionChange:(NSArray *)newsel
{
  if (newsel) {
    if ((lastSelection == nil) || ([newsel isEqual: lastSelection] == NO)) {
      ASSIGN (lastSelection, newsel);
      [self synchronizeViewer];
      [desktopApp selectionChanged: newsel];
    }
  }      
}

- (void)synchronizeViewer
{
  if (viewer) {
    NSRange range = NSMakeRange(firstVisibleColumn, visibleColumns);
    [viewer setSelectableNodesRange: range];
  }
}

- (void)addCellsWithNames:(NSArray *)names 
         inColumnWithPath:(NSString *)cpath
{
  FSNBrowserColumn *col = [self columnWithPath: cpath];
  
  if (col) {
    [col addCellsWithNames: names];
  }
}

- (void)removeCellsWithNames:(NSArray *)names 
            inColumnWithPath:(NSString *)cpath
{
  FSNBrowserColumn *col = [self columnWithPath: cpath];
  
  if (col) {
    [col removeCellsWithNames: names];
  }
}            

- (int)firstVisibleColumn
{
  return firstVisibleColumn;
}

- (int)lastColumnLoaded
{
  return lastColumnLoaded;
}

- (int)lastVisibleColumn
{
  return lastVisibleColumn;
}

- (FSNBrowserColumn *)selectedColumn
{
  int i;
  
  for (i = lastColumnLoaded; i >= 0; i--) {
    FSNBrowserColumn *col = [columns objectAtIndex: i];
    
    if ([col isSelected]) {
      return col;
		}
  }
  
  return nil;
}

- (FSNBrowserColumn *)lastLoadedColumn
{
  int i;
  
  for (i = [columns count] - 1; i >= 0; i--) {
    FSNBrowserColumn *col = [columns objectAtIndex: i];
  
    if ([col isLoaded]) {
      return col;        
    }
  }
  
  return nil;
}

- (FSNBrowserColumn *)columnWithNode:(FSNode *)anode
{
  int i;
  
  for (i = 0; i < [columns count]; i++) {
    FSNBrowserColumn *col = [columns objectAtIndex: i];
  
    if ([[col shownNode] isEqual: anode]) {
      return col;
    }
  }
  
  return nil;   
}

- (FSNBrowserColumn *)columnWithPath:(NSString *)cpath
{
  int i;
  
  for (i = 0; i < [columns count]; i++) {
    FSNBrowserColumn *col = [columns objectAtIndex: i];
  
    if ([[[col shownNode] path] isEqual: cpath]) {
      return col;
    }
  }
  
  return nil;   
}

- (FSNBrowserColumn *)columnBeforeColumn:(FSNBrowserColumn *)col
{
  int index = [col index];

  if (index > 0) {
    return [columns objectAtIndex: index - 1];  
  }
  
  return nil;
}

- (FSNBrowserColumn *)columnAfterColumn:(FSNBrowserColumn *)col
{
  int index = [col index];

  if (index < ([columns count] - 1)) {
    return [columns objectAtIndex: index + 1];  
  }
  
  return nil;
}

- (void)clickInColumn:(FSNBrowserColumn *)col
{
  if (viewer) {
    NSArray *selection = [col selectedNodes];

    if (selection && [selection count]) {
      [viewer multipleNodeViewDidSelectSubNode: [col shownNode]];
    }
  }
}

- (void)clickInMatrixOfColumn:(FSNBrowserColumn *)col
{
  int index = [col index];
  int pos = index - firstVisibleColumn + 1;  
  BOOL mustshift = (firstVisibleColumn > 0);
  int added = 0;
  NSArray *selection = [col selectedNodes];
  
  if ((selection == nil) || ([selection count] == 0))
    {
      [self notifySelectionChange: [NSArray arrayWithObject: [col shownNode]]];
      return;
    }

  if (selColumn)
    {
      if ((pos == visibleColumns) && (index == ([columns count] -1)))
        {
          NSPoint p = [[self window] mouseLocationOutsideOfEventStream];
          
          mousePointX = p.x;
          mousePointY = p.y;
          simulatingDoubleClick = YES;
          
          [NSTimer scheduledTimerWithTimeInterval: 0.3
                                           target: self 
                                         selector: @selector(doubleClikTimeOut:)
                                         userInfo: nil 
                                          repeats: NO];
        }
    }
  
  currentshift = 0;
  updateViewsLock++;
  
  [self setLastColumn: index];
  
  if ([selection count] == 1)
    {
      FSNode *node = [selection objectAtIndex: 0];
      
      if ([node isDirectory] && ([node isPackage] == NO))
        {
          [self addAndLoadColumnForNode: node];
          added = 1;
          
        }
      else if (selColumn)
        {
          [self addFillingColumn];
        }  
      
    }
  else if (selColumn)
    {
      [self addFillingColumn];
    } 
  
  if (selColumn == NO)
    {
      if (mustshift && (pos < visibleColumns))
        { 
          [self setShift: visibleColumns - pos - added];
        }
    }
  else
    {
      if (mustshift && (pos < (visibleColumns - 1)))
        { 
          [self setShift: visibleColumns - pos - 1];
        }
    }
  
  updateViewsLock--;
  [self tile];
  
  [self notifySelectionChange: [col selectedNodes]];		  
}

- (void)doubleClickInMatrixOfColumn:(FSNBrowserColumn *)col
{
  if (manager) {
    unsigned int mouseFlags = [(FSNBrowserMatrix *)[col cmatrix] mouseFlags];
    BOOL closesndr = ((mouseFlags == NSAlternateKeyMask) 
                              || (mouseFlags == NSControlKeyMask));
    
    [viewer openSelectionInNewViewer: closesndr];
//    [manager openSelectionInViewer: viewer closeSender: closesndr];
  } else {
    [desktopApp openSelectionInNewViewer: NO];
  }
}

- (void)doubleClikTimeOut:(id)sender
{
  simulatingDoubleClick = NO;
}

- (void)mouseDown:(NSEvent*)theEvent
{
  if (simulatingDoubleClick) {
    NSPoint p = [[self window] mouseLocationOutsideOfEventStream];
      
    if ((max(p.x, mousePointX) - min(p.x, mousePointX)) <= 3
            && (max(p.y, mousePointY) - min(p.y, mousePointY)) <= 3) {
      if (manager) {
        [manager openSelectionInViewer: viewer closeSender: NO];
      } else {
        [desktopApp openSelectionInNewViewer: NO];
      }
    }
  }
  
  [super mouseDown: theEvent];
}

- (void)keyDown:(NSEvent *)theEvent
{
	NSString *characters = [theEvent characters];
	unichar character = 0;
	FSNBrowserColumn *column = [self selectedColumn];
	NSMatrix *matrix;
	
	if (column == nil) {
    [super keyDown: theEvent];
		return;
	}
  
  matrix = [column cmatrix];
  
	if (matrix == nil) {
    [super keyDown: theEvent];
		return;
	}
		
  if ([characters length] > 0) {
		character = [characters characterAtIndex: 0];
	}
  
	switch (character) {
		case NSUpArrowFunctionKey:
		case NSDownArrowFunctionKey:
      [super keyDown: theEvent];
	  	return;
	
		case NSLeftArrowFunctionKey:
			{
				if ([theEvent modifierFlags] & NSControlKeyMask) {
	      	[super keyDown: theEvent];
	    	} else {
	    		[self moveLeft];
				}
			}
      return;
      
		case NSRightArrowFunctionKey:
			{
				if ([theEvent modifierFlags] & NSControlKeyMask) {
	      	[super keyDown: theEvent];
	    	} else {
	    		[self moveRight];
				}
			}
	  	return;
      
		case NSCarriageReturnCharacter:
      [(FSNBrowserMatrix *)matrix setMouseFlags: [theEvent modifierFlags]];
      [matrix sendDoubleAction];
      return;
  }  
  
  if (([characters length] > 0) && (character < 0xF700)) {														
    column = [self lastLoadedColumn];
    
		if (column) {
			int index = [column index];

	  	matrix = [column cmatrix];

      if (matrix == nil) {
        return;
      }
      
	  	if (charBuffer == nil) {
	      charBuffer = [characters substringToIndex: 1];
	      RETAIN (charBuffer);
	    } else {
	      if (([theEvent timestamp] - lastKeyPressed < 500.0)
		  											      && (alphaNumericalLastColumn == index)) {
          NSString *transition = [charBuffer stringByAppendingString:
				                                      [characters substringToIndex: 1]];
		      RELEASE (charBuffer);
		      charBuffer = transition;
		      RETAIN (charBuffer);
				} else {
		      RELEASE (charBuffer);
		      charBuffer = [characters substringToIndex: 1];
		      RETAIN (charBuffer);
				}														
			}
			
			alphaNumericalLastColumn = index;
			lastKeyPressed = [theEvent timestamp];
			
      if ([column selectCellWithPrefix: charBuffer]) {
        [[self window] makeFirstResponder: matrix];
        return;
      }
		}
		
		lastKeyPressed = 0.0;			
	}  
  
  [super keyDown: theEvent];
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (BOOL)becomeFirstResponder
{
	FSNBrowserColumn *selCol;
  NSMatrix *matrix;

  selCol = [self selectedColumn];
  
  if (selCol == nil) {
    matrix = [[columns objectAtIndex: 0] cmatrix];
  } else {
    matrix = [selCol cmatrix];
	}
	
  if ([[matrix cells] count]) {
    [[self window] makeFirstResponder: matrix];
	}
	
  return YES;
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldBoundsSize
{
  NSRect r = [[self superview] bounds];
  int ncols = myrintf(r.size.width / columnSize.width);

  [self setFrame: r];
  
  if (ncols != visibleColumns) {
    updateViewsLock++;
    [self setVisibleColumns: ncols];
    updateViewsLock--;
  }
    
  [self tile];
}

- (void)viewDidMoveToSuperview
{
  [super viewDidMoveToSuperview];

  if ([self superview]) {
    [self setFrame: [[self superview] bounds]];
    [self tile];
  }
}

/*
- (void)drawRect:(NSRect)rect
{
  int i;
  
	[[NSColor blackColor] set];
  
  for (i = 0; i < visibleColumns; i++) { 
    NSPoint p1 = NSMakePoint((columnSize.width * i) + 1 + (i-1), columnSize.height);
    NSPoint p2 = NSMakePoint((columnSize.width * i) + 1 + (i-1), 0);	
    [NSBezierPath strokeLineFromPoint: p1 toPoint: p2];
  }  
}
*/

@end


@implementation FSNBrowser (NodeRepContainer)

- (void)showContentsOfNode:(FSNode *)anode
{
  [self showSubnode: anode];
}

- (NSDictionary *)readNodeInfo
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	      
  NSString *prefsname = [NSString stringWithFormat: @"viewer_at_%@", [baseNode path]];
  NSDictionary *nodeDict = nil;

  if ([baseNode isWritable]
        && ([[fsnodeRep volumes] containsObject: [baseNode path]] == NO)) {
    NSString *infoPath = [[baseNode path] stringByAppendingPathComponent: @".gwdir"];
  
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
    id entry = [nodeDict objectForKey: @"fsn_info_type"];
    infoType = entry ? [entry intValue] : infoType;

    if (infoType == FSNInfoExtendedType) {
      DESTROY (extInfoType);
      entry = [nodeDict objectForKey: @"ext_info_type"];

      if (entry) {
        NSArray *availableTypes = [fsnodeRep availableExtendedInfoNames];

        if ([availableTypes containsObject: entry]) {
          ASSIGN (extInfoType, entry);
        }
      }

      if (extInfoType == nil) {
        infoType = FSNInfoNameType;
      }
    }
  }
        
  return nodeDict;
}

- (NSMutableDictionary *)updateNodeInfo:(BOOL)ondisk
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableDictionary *updatedInfo = nil;

  if ([baseNode isValid]) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	      
    NSString *prefsname = [NSString stringWithFormat: @"viewer_at_%@", [baseNode path]];
    NSString *infoPath = [[baseNode path] stringByAppendingPathComponent: @".gwdir"];
    BOOL writable = ([baseNode isWritable] && ([[fsnodeRep volumes] containsObject: [baseNode path]] == NO));
    
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
	
    [updatedInfo setObject: [NSNumber numberWithInt: infoType] 
                    forKey: @"fsn_info_type"];

    if (infoType == FSNInfoExtendedType) {
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
  [self reloadFromColumnWithNode: baseNode];
}

- (void)reloadFromNode:(FSNode *)anode
{
  [self reloadFromColumnWithNode: anode];
}

- (FSNode *)baseNode
{
  return baseNode;
}

- (FSNode *)shownNode
{
  FSNBrowserColumn *bc = [self lastLoadedColumn];
  
  if (bc) {
    return [bc shownNode];
  }
  
  return baseNode;
}

- (BOOL)isSingleNode
{
  return NO;
}

- (BOOL)isShowingNode:(FSNode *)anode
{
  return ([self columnWithNode: anode] ? YES : NO);
}

- (BOOL)isShowingPath:(NSString *)path
{
  return ([self columnWithPath: path] ? YES : NO);
}

- (void)sortTypeChangedAtPath:(NSString *)path
{
  if (path) {
    [self reloadColumnWithPath: path];
  } else {
    [self reloadContents];
  }
}

- (void)nodeContentsWillChange:(NSDictionary *)info
{
  NSString *operation = [info objectForKey: @"operation"];
  
  if ([operation isEqual: @"GWorkspaceRenameOperation"] == NO) {
    [self checkLockedReps];
  }
}

- (void)nodeContentsDidChange:(NSDictionary *)info
{
  NSString *operation = [info objectForKey: @"operation"];
  NSString *source = [info objectForKey: @"source"];
  NSString *destination = [info objectForKey: @"destination"];
  NSArray *files = [info objectForKey: @"files"];
  
  if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
    files = [NSArray arrayWithObject: [destination lastPathComponent]];
    destination = [destination stringByDeletingLastPathComponent]; 
  }

  if ([operation isEqual: NSWorkspaceRecycleOperation]) {
		files = [info objectForKey: @"origfiles"];
  }	

  if ([operation isEqual: NSWorkspaceMoveOperation] 
        || [operation isEqual: NSWorkspaceCopyOperation]
        || [operation isEqual: NSWorkspaceLinkOperation]
        || [operation isEqual: NSWorkspaceDuplicateOperation]
        || [operation isEqual: @"GWorkspaceCreateDirOperation"]
        || [operation isEqual: @"GWorkspaceCreateFileOperation"]
        || [operation isEqual: NSWorkspaceRecycleOperation]
        || [operation isEqual: @"GWorkspaceRenameOperation"]
			  || [operation isEqual: @"GWorkspaceRecycleOutOperation"]) { 
    FSNBrowserColumn *bc = [self columnWithPath: destination];        
   
    if (bc) {
      [self reloadFromColumn: bc];     
      
      if ([[self window] isKeyWindow]) {
        BOOL selectCell = NO;
      
        if ([operation isEqual: @"GWorkspaceCreateFileOperation"]
                || [operation isEqual: @"GWorkspaceCreateDirOperation"]) {  
          selectCell = YES;
          
        } else if ([operation isEqual: @"GWorkspaceRenameOperation"]) { 
          NSString *newname = [files objectAtIndex: 0];
          NSString *newpath = [destination stringByAppendingPathComponent: newname];
          
          selectCell = ([bc cellWithPath: newpath] != nil);
        }
        
        if (selectCell) {
          [self selectCellsWithNames: files
                    inColumnWithPath: destination
                          sendAction: YES];
        }
      }
    }
  }

  if ([operation isEqual: NSWorkspaceMoveOperation]
        || [operation isEqual: NSWorkspaceDestroyOperation]
				|| [operation isEqual: NSWorkspaceRecycleOperation]
				|| [operation isEqual: @"GWorkspaceRecycleOutOperation"]
				|| [operation isEqual: @"GWorkspaceEmptyRecyclerOperation"]) {
    if ([self isShowingPath: source]) {
      [self reloadFromColumnWithPath: source]; 
    }
  }
}

- (void)watchedPathChanged:(NSDictionary *)info
{
  NSString *event = [info objectForKey: @"event"];
  NSString *path = [info objectForKey: @"path"];

  if ([event isEqual: @"GWWatchedPathDeleted"]) {
    NSString *s = [path stringByDeletingLastPathComponent];

    if ([self isShowingPath: s]) {
      [self reloadFromColumnWithPath: s]; 
    }
    
  } else if ([event isEqual: @"GWFileDeletedInWatchedDirectory"]) {    
    if ([self isShowingPath: path]) {
      FSNBrowserColumn *col;
    
      [self reloadFromColumnWithPath: path]; 
       
      col = [self lastLoadedColumn];

      if (col) {
        NSArray *selection = [col selectedNodes];
        
        if (selection == nil) {
          selection = [NSArray arrayWithObject: [col shownNode]];
        }
        
        [viewer selectionChanged: selection];
        [self synchronizeViewer];
      }  
    }      
                 
  } else if ([event isEqual: @"GWFileCreatedInWatchedDirectory"]) {   
    [self addCellsWithNames: [info objectForKey: @"files"]
           inColumnWithPath: path];
  }
}

- (void)setShowType:(FSNInfoType)type
{
  if (infoType != type) {
    int i;
    
    infoType = type;
    DESTROY (extInfoType);
    
    for (i = 0; i < [columns count]; i++) {
      [[columns objectAtIndex: i] setShowType: infoType];
    }
    
    [self tile];
  }
}

- (void)setExtendedShowType:(NSString *)type
{
  if ((extInfoType == nil) || ([extInfoType isEqual: type] == NO)) {
    int i;
    
    infoType = FSNInfoExtendedType;
    ASSIGN (extInfoType, type);

    for (i = 0; i < [columns count]; i++) {
      FSNBrowserColumn *col = [columns objectAtIndex: i];
      [col setExtendedShowType: extInfoType];
    }
    
    [self tile];
  }
}

- (FSNInfoType)showType
{
  return infoType;
}

- (int)iconSize
{
  return DEFAULT_ISIZE;
}

- (int)labelTextSize
{
  return fontSize;
}

- (int)iconPosition
{
  return NSImageLeft;
}

- (void)updateIcons
{
}

- (id)repOfSubnode:(FSNode *)anode
{
  if ([[anode path] isEqual: path_separator()] == NO) {
    FSNBrowserColumn *bc = [self columnWithPath: [anode parentPath]];
    
    if (bc) {
      return [bc cellOfNode: anode];
    }
  }
  
  return nil;
}

- (id)repOfSubnodePath:(NSString *)apath
{
  if ([apath isEqual: path_separator()] == NO) {
    NSString *parentPath = [apath stringByDeletingLastPathComponent];
    FSNBrowserColumn *bc = [self columnWithPath: parentPath];
    
    if (bc) {
      return [bc cellWithPath: apath];
    }
  }

  return nil;
}

- (id)addRepForSubnode:(FSNode *)anode
{
  return [self addRepForSubnodePath: [anode path]];
}

- (id)addRepForSubnodePath:(NSString *)apath
{
  if ([apath isEqual: path_separator()] == NO) {
    NSString *bcpath = [apath stringByDeletingLastPathComponent];
    FSNBrowserColumn *bc = [self columnWithPath: bcpath];
  
    if (bc) {
      [bc addCellsWithNames: [NSArray arrayWithObject: [apath lastPathComponent]]];
      return [bc cellWithPath: apath];
    }
  }
  
  return nil;
}

- (void)removeRepOfSubnode:(FSNode *)anode
{
  [self removeRepOfSubnodePath: [anode path]];
}

- (void)removeRepOfSubnodePath:(NSString *)apath
{
  if ([apath isEqual: path_separator()] == NO) {
    NSString *bcpath = [apath stringByDeletingLastPathComponent];
    FSNBrowserColumn *bc = [self columnWithPath: bcpath];
  
    if (bc) {
      [bc removeCellsWithNames: [NSArray arrayWithObject: [apath lastPathComponent]]];
    }
  }
}

- (void)removeRep:(id)arep
{
  [self removeRepOfSubnode: [arep node]];
}

- (void)unloadFromNode:(FSNode *)anode
{
  FSNBrowserColumn *bc = [self columnWithNode: anode];

	if (bc) {
    FSNBrowserColumn *col = [self columnBeforeColumn: bc];
    int index;  
    int pos;  
    BOOL mustshift;
    
    if (col == nil) {
      col = [columns objectAtIndex: 0];
    }
    
    index = [col index];
    pos = index - firstVisibleColumn + 1; 
    mustshift = (firstVisibleColumn > 0);
        
    updateViewsLock++; 
    
    [[col cmatrix] deselectAllCells];
    [self setLastColumn: index];
    [self reloadFromColumn: col];
    
    if (mustshift && (pos < visibleColumns)) { 
      currentshift = 0;
		  [self setShift: visibleColumns - pos];
	  }
    
    updateViewsLock--;
    [self tile];
  }  
}

- (void)repSelected:(id)arep
{
}

- (void)unselectOtherReps:(id)arep
{
  FSNBrowserColumn *bc = [self lastLoadedColumn];
  
  if (bc) {
    [[bc cmatrix] deselectAllCells];
    [self notifySelectionChange: [NSArray arrayWithObject: [bc shownNode]]];
  }
}

- (void)selectReps:(NSArray *)reps
{
  if (reps && [reps count]) {
    FSNode *node = [[reps objectAtIndex: 0] node];
    FSNBrowserColumn *bc = [self columnWithPath: [node parentPath]];
    
    if (bc) {
      [bc selectCells: reps sendAction: NO];
      [[self window] makeFirstResponder: [bc cmatrix]];
    }
  }
}

- (void)selectRepsOfSubnodes:(NSArray *)nodes
{
  if (nodes && [nodes count]) {
    FSNode *node = [nodes objectAtIndex: 0];
    
    if ([node isSubnodeOfNode: baseNode]) {
      FSNBrowserColumn *bc = [self columnWithPath: [node parentPath]];
    
      if (bc) {
        [bc selectCellsOfNodes: nodes sendAction: YES];
      } else {
        [self showSelection: nodes];
      }
      
      bc = [self lastLoadedColumn];
      if (bc) {
        [[self window] makeFirstResponder: [bc cmatrix]];
      }  
    }
  }
}

- (void)selectRepsOfPaths:(NSArray *)paths
{
  if (paths && [paths count]) {
    NSString *basepath = [paths objectAtIndex: 0];
    
    if ([baseNode isParentOfPath: basepath]) {
      FSNBrowserColumn *bc = [self columnWithPath: [basepath stringByDeletingLastPathComponent]];
    
      if (bc) {
        [bc selectCellsWithPaths: paths sendAction: YES];
      } else {
        [self showPathsSelection: paths];
      }
      
      bc = [self lastLoadedColumn];
      if (bc) {
        [[self window] makeFirstResponder: [bc cmatrix]];
      }  
    }
  }
}

- (void)selectAll
{
  [self selectAllInLastColumn];
}

- (NSArray *)reps
{
  FSNBrowserColumn *bc = [self lastLoadedColumn];
  
  if (bc) {
    return [[bc cmatrix] cells];
  }

  return nil;
}

- (NSArray *)selectedReps
{
  FSNBrowserColumn *bc = [self lastLoadedColumn];
  NSArray *selection = nil;

  if (bc) {
    selection = [bc selectedCells];  
  
    if ((selection == nil) && [bc shownNode]) {
      FSNBrowserColumn *col = [self columnBeforeColumn: bc];
    
      if (col) {
        return [col selectedCells];  
      }
    }
  }
  
  return selection;
}

- (NSArray *)selectedNodes
{
  FSNBrowserColumn *bc = [self lastLoadedColumn];
  NSArray *selection = nil;
  
  if (bc) {
    selection = [bc selectedNodes];
  
    if ((selection == nil) && [bc shownNode]) {
      selection = [NSArray arrayWithObject: [bc shownNode]];
    }
    
  } else {
    selection = [NSArray arrayWithObject: baseNode];
  }

  return selection;
}

- (NSArray *)selectedPaths
{
  FSNBrowserColumn *bc = [self lastLoadedColumn];
  NSArray *selection = nil;
  
  if (bc) {
    selection = [bc selectedPaths];
  
    if ((selection == nil) && [bc shownNode]) {
      selection = [NSArray arrayWithObject: [[bc shownNode] path]];
    } 
    
  } else {
    selection = [NSArray arrayWithObject: [baseNode path]];
  }

  return selection;
}

- (void)selectionDidChange
{
}

- (void)checkLockedReps
{
  int i;
  
  for (i = 0; i < [columns count]; i++) {
    [[columns objectAtIndex: i] checkLockedReps];
  }
}

- (void)setSelectionMask:(FSNSelectionMask)mask
{
}

- (FSNSelectionMask)selectionMask
{
  return NSSingleSelectionMask;
}

- (void)openSelectionInNewViewer:(BOOL)newv
{
  [desktopApp openSelectionInNewViewer: newv];
}

- (void)restoreLastSelection
{
  if (lastSelection) {
    [self selectRepsOfSubnodes: lastSelection];
  }
}

- (void)setLastShownNode:(FSNode *)anode
{
  FSNBrowserColumn *bc = [self columnWithNode: anode];

  if (bc) {
    FSNBrowserColumn *prev = [self columnBeforeColumn: bc];

    updateViewsLock++;
        
    if (prev) {
      if ([prev selectCellOfNode: anode sendAction: YES] == nil) {
        [self setLastColumn: [prev index]];
        [self notifySelectionChange: [NSArray arrayWithObject: [prev shownNode]]];
      }
    } else {
      [self setLastColumn: 0];
      [bc unselectAllCells];
      [self notifySelectionChange: [NSArray arrayWithObject: baseNode]];
    }
    
    updateViewsLock--;
    [self tile];    

    bc = [self lastLoadedColumn];
    if (bc) {
      [[self window] makeFirstResponder: [bc cmatrix]];
    }
  }
}

- (BOOL)needsDndProxy
{
  return NO;
}

- (BOOL)involvedByFileOperation:(NSDictionary *)opinfo
{
  int i;
  
  for (i = 0; i < [columns count]; i++) {
    FSNode *node = [[columns objectAtIndex: i] shownNode];
    
    if (node && [node involvedByFileOperation: opinfo]) {
      return YES;
    }
  }

  return NO;
}

- (BOOL)validatePasteOfFilenames:(NSArray *)names
                       wasCut:(BOOL)cut
{
  FSNode *node = [self nodeOfLastColumn];
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

- (NSColor *)backgroundColor
{
  return backColor;
}

- (NSColor *)textColor
{
  return [NSColor controlTextColor];
}

- (NSColor *)disabledTextColor
{
  return [NSColor disabledControlTextColor];
}

@end


@implementation FSNBrowser (IconNameEditing)

- (void)setEditorForCell:(FSNBrowserCell *)cell 
                inColumn:(FSNBrowserColumn *)col
{
  if (nameEditor) {
    FSNode *cellnode = [cell node];
    BOOL canedit = (([cell isLocked] == NO) 
                        && ([cellnode isMountPoint] == NO));
    
    [self stopCellEditing];

    if (canedit) {   
      NSMatrix *matrix = [col cmatrix];
      NSFont *edfont = [nameEditor font];
      float fnheight = [fsnodeRep heighOfFont: edfont];
      NSRect r = [cell labelRect];
      
      r = [matrix convertRect: r toView: self];
      r.origin.y += ((r.size.height - fnheight) / 2);
      r.size.height = fnheight;
      r = NSIntegralRect(r);  
      
      [nameEditor setFrame: r];

      [nameEditor setNode: cellnode 
              stringValue: [cell shownInfo]
                    index: 0];

      [nameEditor setEditable: YES];
      [nameEditor setSelectable: YES];	
      [self addSubview: nameEditor];
    }
  }
}

- (void)stopCellEditing
{
  if (nameEditor && [[self subviews] containsObject: nameEditor]) {
    [nameEditor abortEditing];
    [nameEditor setEditable: NO];
    [nameEditor setSelectable: NO];
    [nameEditor setNode: nil stringValue: @"" index: -1];
    [nameEditor removeFromSuperview];
    [self setNeedsDisplayInRect: [nameEditor frame]];
  }
}

- (void)stopRepNameEditing
{
  [self stopCellEditing];
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
  FSNode *ednode = [nameEditor node];

#define CLEAREDITING \
  [self stopCellEditing]; \
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

      if (([newname length] == 0) || (range.length > 0))
	{
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

      [self stopCellEditing];
      [desktopApp performFileOperation: opinfo];
    }
}

@end
