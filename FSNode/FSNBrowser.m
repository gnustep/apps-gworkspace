/* FSNBrowser.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <math.h>
#include "FSNBrowser.h"
#include "FSNBrowserColumn.h"
#include "FSNBrowserCell.h"
#include "FSNIcon.h"
#include "FSNFunctions.h"
#include "GNUstep.h"

#define DEFAULT_ISIZE 24


@implementation FSNBrowser

- (void)dealloc
{
  RELEASE (baseNode);
  TEST_RELEASE (infoPath);
  TEST_RELEASE (nodeInfo);
  TEST_RELEASE (extInfoType);  
  TEST_RELEASE (lastSelection);
  RELEASE (columns);
  RELEASE (cellPrototype);
  TEST_RELEASE (charBuffer);
  RELEASE (backColor);

  [super dealloc];
}

- (id)initWithBaseNode:(FSNode *)bsnode
		    visibleColumns:(int)vcols 
              scroller:(NSScroller *)scrl
            cellsIcons:(BOOL)cicns
       selectionColumn:(BOOL)selcol
{
  self = [super init];
  
  if (self) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
    NSString *appName = [defaults stringForKey: @"DesktopApplicationName"];
    NSString *selName = [defaults stringForKey: @"DesktopApplicationSelName"];
    id defentry;
		int i;

    if (appName && selName) {
		  Class desktopAppClass = [[NSBundle mainBundle] classNamed: appName];
      SEL sel = NSSelectorFromString(selName);
      desktopApp = [desktopAppClass performSelector: sel];
    }
    
    defentry = [defaults dictionaryForKey: @"backcolor"];
    if (defentry) {
      float red = [[defentry objectForKey: @"red"] floatValue];
      float green = [[defentry objectForKey: @"green"] floatValue];
      float blue = [[defentry objectForKey: @"blue"] floatValue];
      float alpha = [[defentry objectForKey: @"alpha"] floatValue];
    
      ASSIGN (backColor, [NSColor colorWithCalibratedRed: red 
                                                   green: green 
                                                    blue: blue 
                                                   alpha: alpha]);
    } else {
      ASSIGN (backColor, [[NSColor windowBackgroundColor] colorUsingColorSpaceName: NSDeviceRGBColorSpace]);
    }
  
    defentry = [defaults objectForKey: @"fsn_info_type"];
    infoType = defentry ? [defentry intValue] : FSNInfoNameType;
    extInfoType = nil;
    
    if (infoType == FSNInfoExtendedType) {
      defentry = [defaults objectForKey: @"extended_info_type"];

      if (defentry) {
        NSArray *availableTypes = [FSNodeRep availableExtendedInfoNames];
      
        if ([availableTypes containsObject: defentry]) {
          ASSIGN (extInfoType, defentry);
        }
      }
      
      if (extInfoType == nil) {
        infoType = FSNInfoNameType;
      }
    }

    [FSNodeRep setUseThumbnails: [defaults boolForKey: @"use_thumbnails"]];
    
    ASSIGN (baseNode, [FSNode nodeWithRelativePath: [bsnode path] parent: nil]);	    
    [self readNodeInfo];
    
    lastSelection = nil;
		visibleColumns = vcols;
    
    scroller = scrl;
	  [scroller setTarget: self];
	  [scroller setAction: @selector(scrollViaScroller:)];    
    
    cellsIcon = cicns;
    selColumn = selcol;

    updateViewsLock = 0;
   
    cellPrototype = [FSNBrowserCell new];
  
  	columns = [NSMutableArray new];
  
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
  	isLoaded = NO;	

    viewer = nil;
    manager = nil;
  }
  
  return self;
}

- (void)setBaseNode:(FSNode *)node
{
  ASSIGN (baseNode, [FSNode nodeWithRelativePath: [node path] parent: nil]);
  [self readNodeInfo];
  [self loadColumnZero];
  [self notifySelectionChange: [NSArray arrayWithObject: [node path]]];
}

- (NSDictionary *)readNodeInfo
{
  NSDictionary *nodeDict = nil;
  
  ASSIGN (infoPath, [[baseNode path] stringByAppendingPathComponent: @".dirinfo"]);
  
  if ([[NSFileManager defaultManager] fileExistsAtPath: infoPath]) {
    nodeDict = [NSDictionary dictionaryWithContentsOfFile: infoPath];

    if (nodeDict) {
      id entry = [nodeDict objectForKey: @"backcolor"];
      
      if (entry) {
        float red = [[entry objectForKey: @"red"] floatValue];
        float green = [[entry objectForKey: @"green"] floatValue];
        float blue = [[entry objectForKey: @"blue"] floatValue];
        float alpha = [[entry objectForKey: @"alpha"] floatValue];

        ASSIGN (backColor, [NSColor colorWithCalibratedRed: red 
                                                     green: green 
                                                      blue: blue 
                                                     alpha: alpha]);
      }

      entry = [nodeDict objectForKey: @"fsn_info_type"];
      infoType = entry ? [entry intValue] : infoType;

      if (infoType == FSNInfoExtendedType) {
        DESTROY (extInfoType);
        entry = [nodeDict objectForKey: @"ext_info_type"];

        if (entry) {
          NSArray *availableTypes = [FSNodeRep availableExtendedInfoNames];

          if ([availableTypes containsObject: entry]) {
            ASSIGN (extInfoType, entry);
          }
        }

        if (extInfoType == nil) {
          infoType = FSNInfoNameType;
        }
      }
    }
  }
    
  if (nodeDict) {
    nodeInfo = [nodeDict mutableCopy];
  } else {
    nodeInfo = [NSMutableDictionary new];
  }
    
  return nodeDict;
}

- (void)updateNodeInfo
{
  if ([baseNode isWritable]) {
    NSMutableDictionary *backColorDict = [NSMutableDictionary dictionary];
    float red, green, blue, alpha;
	
    [backColor getRed: &red green: &green blue: &blue alpha: &alpha];
    [backColorDict setObject: [NSNumber numberWithFloat: red] forKey: @"red"];
    [backColorDict setObject: [NSNumber numberWithFloat: green] forKey: @"green"];
    [backColorDict setObject: [NSNumber numberWithFloat: blue] forKey: @"blue"];
    [backColorDict setObject: [NSNumber numberWithFloat: alpha] forKey: @"alpha"];

    [nodeInfo setObject: backColorDict forKey: @"backcolor"];
    
    [nodeInfo setObject: [NSNumber numberWithInt: infoType] 
                 forKey: @"fsn_info_type"];

    if (infoType == FSNInfoExtendedType) {
      [nodeInfo setObject: extInfoType forKey: @"ext_info_type"];
    }
    
    [nodeInfo writeToFile: infoPath atomically: YES];
  }
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
    FSNBrowserColumn *bc;

    updateViewsLock++;

    [self showSubnode: [selection objectAtIndex: 0]];

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

    [self notifySelectionChange: [bc selectedPaths]];
  }
}

- (void)showPathsSelection:(NSArray *)selpaths
{
  if (selpaths && [selpaths count]) {
    FSNode *node = [FSNode nodeWithRelativePath: [selpaths objectAtIndex: 0] parent: nil];      
    FSNBrowserColumn *bc;

    updateViewsLock++;

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

    [self notifySelectionChange: [bc selectedPaths]];
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
  FSNBrowserColumn *bc;
  int i;
			
  if (lastColumnLoaded + 1 >= [columns count]) {
    i = [columns indexOfObject: [self createEmptyColumn]];
	} else {
    i = lastColumnLoaded + 1;
	}

  bc = [columns objectAtIndex: i];
  bc = [self columnBeforeColumn: bc];
  if (bc && [bc isLoaded]) {
    [bc setLeaf: YES];
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
    FSNode *node = [FSNode nodeWithRelativePath: path 
                                         parent: (parentCol ? [parentCol shownNode] : nil)];  
    [col showContentsOfNode: node];    
  }
}

- (void)reloadFromColumn:(FSNBrowserColumn *)col
{
	int index = [col index];
  int i = 0;

  updateViewsLock++;
  
	for (i = index; i < [columns count]; i++) {
    FSNBrowserColumn *nextcol = [columns objectAtIndex: i];
    NSArray *selection = [self selectionInColumnBeforeColumn: nextcol];
    BOOL done = NO;
    
    if (selection && ([selection count] == 1)) {
      FSNode *node = [selection objectAtIndex: 0];
    
      if ([node isDirectory]) {
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
  
  updateViewsLock--;
  [self tile];
  
  col = [self lastLoadedColumn];

  if (col) {
    NSArray *selection = [col selectedPaths];
    int index = [col index];

    if (index < firstVisibleColumn) {
      [self scrollColumnToVisible: index];      
    }

    if (selection) {
      [self notifySelectionChange: selection];	

    } else {
      FSNode *node = [col shownNode];

      if (node) {
        [self notifySelectionChange: [NSArray arrayWithObject: [node path]]];
      }
    }
  }
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
  if (updateViewsLock == 0) {
    NSRect r = [self frame];
    float frameWidth = r.size.width - (4 + visibleColumns);
    int count = [columns count];
    NSRect colrect;
    int i;

    columnSize.height = r.size.height;
    columnSize.width = floor(frameWidth / visibleColumns);

    for (i = 0; i < count; i++) {
      int n = i - firstVisibleColumn;

      colrect = NSZeroRect;
      colrect.size = columnSize;
      colrect.origin.y = 0;

      if (i <= firstVisibleColumn) {
        colrect.origin.x = (n * columnSize.width);
      } else if (i <= lastVisibleColumn) {
        colrect.origin.x = (n * columnSize.width) + n;
      } else {
        colrect.origin.x = (n * columnSize.width) + 8;
      }

      if (i == lastVisibleColumn) {
        colrect.size.width = [self bounds].size.width - (colrect.origin.x);
	    }
    
      [[columns objectAtIndex: i] setFrame: colrect];
    }
    
    [self synchronizeViewer];
    [self updateScroller];
  }
}

- (void)scrollViaScroller:(NSScroller *)sender
{
  NSScrollerPart hit = [sender hitPart];
  
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
			break;
      
		// The knob or knob slot
		case NSScrollerKnob:
		case NSScrollerKnobSlot: 
      {
	  		float f = [sender floatValue];
	  		float n = lastColumnLoaded + 1 - visibleColumns;
				
	  		[self scrollColumnToVisible: rintf(f * n) + visibleColumns - 1];
				
        if (currentshift > 0) {
          [self setLastColumn: (lastColumnLoaded - currentshift)];			
		      currentshift = 0;
        }
			}
      break;
      
		default:
			break;
	}
  
  skipUpdateScroller = NO;
  
  updateViewsLock--;
  [self tile];
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
    
    if (matrix) {
      int index = [selCol index];
      
      [matrix sendAction];
      
      if (index < ([columns count] - 1)) {
        selCol = [columns objectAtIndex: index + 1];
        matrix = [selCol cmatrix];
        if (matrix) {
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
  int i;
  
  for (i = 0; i < [columns count]; i++) {
    FSNBrowserColumn *col = [columns objectAtIndex: i];
  
    if ([col isLeaf]) {
      FSNode *node = [col shownNode];
    
      if ([node isDirectory]) {	
        if ([node isPackage] == NO) {
          return node;                  
        } else if (i > 0) {
          return [[columns objectAtIndex: i-1] shownNode];      
        }        
      } else if (i > 0) {
        return [[columns objectAtIndex: i-1] shownNode];   
      }
    }
  }
  
  return nil;
}

- (NSString *)pathToLastColumn
{
  FSNode *node = [self nodeOfLastColumn];
  return node ? [node path] : nil;
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
  
    if ([col isLoaded] && [col isLeaf]) {
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


- (void)clickInMatrixOfColumn:(FSNBrowserColumn *)col
{
  int index = [col index];
  int pos = index - firstVisibleColumn + 1;  
  BOOL last = (index == lastVisibleColumn) || (index == ([columns count] -1));
  BOOL mustshift = (firstVisibleColumn > 0);
  NSArray *selection = [col selectedNodes];
  
  if ((selection == nil) || ([selection count] == 0)) {
    [self notifySelectionChange: [NSArray arrayWithObject: [[col shownNode] path]]];
    return;
  }

  currentshift = 0;
  updateViewsLock++;
  
  [self setLastColumn: index];
  
  if ([selection count] == 1) {
    FSNode *node = [selection objectAtIndex: 0];
  
    if ([node isDirectory] && ([node isPackage] == NO)) {
      [self addAndLoadColumnForNode: node];
    
    } else {
      if ((last == NO) || selColumn) {
        [self addFillingColumn];
      } 
    }
    
  } else {
    if ((last == NO) || selColumn) {
      [self addFillingColumn];
    }
  } 
    
  if (mustshift && (pos < (visibleColumns - 1))) { 
		[self setShift: visibleColumns - pos - 1];
	}
  
  updateViewsLock--;
  [self tile];
  
  [self notifySelectionChange: [col selectedPaths]];		  
}

- (void)doubleClickInMatrixOfColumn:(FSNBrowserColumn *)col
{
  [desktopApp openSelectionInNewViewer: NO];
}

- (void)keyDown:(NSEvent *)theEvent
{
	NSString *characters = [theEvent characters];
	unichar character = 0;
	FSNBrowserColumn *column = [self selectedColumn];
	NSMatrix *matrix;
	
	if (column == nil) {
		return;
	}
  
  matrix = [column cmatrix];
  
	if (matrix == nil) {
		return;
	}
		
  if ([characters length] > 0) {
		character = [characters characterAtIndex: 0];
	}
  
	switch (character) {
		case NSUpArrowFunctionKey:
		case NSDownArrowFunctionKey:
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
      
		case 13:
      [matrix sendDoubleAction];
      return;
  }  
  
  if ((character < 0xF700) && ([characters length] > 0)) {														
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
	      if (([theEvent timestamp] - lastKeyPressed < 2000.0)
		  											      && (alphaNumericalLastColumn == index)) {
		  		ASSIGN (charBuffer, ([charBuffer stringByAppendingString:
				    																[characters substringToIndex: 1]]));
				} else {
		  		ASSIGN (charBuffer, ([characters substringToIndex: 1]));
				}														
			}
			
			alphaNumericalLastColumn = index;
			lastKeyPressed = [theEvent timestamp];
			
      if ([column selectCellWithPrefix: charBuffer]) {
        [[self window] makeFirstResponder: matrix];
        return;
      }
		}
		
		lastKeyPressed = 0.;			
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
	
  if (matrix) {
    [[self window] makeFirstResponder: matrix];
	}
	
  return YES;
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldBoundsSize
{
  NSRect r = [[self superview] bounds];
  int ncols = rintf(r.size.width / columnSize.width);

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

- (BOOL)fileManager:(NSFileManager *)manager 
              shouldProceedAfterError:(NSDictionary *)errorDict
{
	NSString *title = NSLocalizedString(@"Error", @"");
	NSString *msg1 = NSLocalizedString(@"Cannot rename ", @"");

//  NSString *name = [nameEditor name];
  NSString *name = @"sdkljgzasdgfro;zdfhozdfzhdhz"; // ATTENZIONE !!!!!!!!!!!!!!

	NSString *msg2 = NSLocalizedString(@"Continue", @"");

  NSRunAlertPanel(title, [NSString stringWithFormat: @"%@'%@'!", msg1, name], msg2, nil, nil);   

	return NO;
}

- (void)fileManager:(NSFileManager *)manager willProcessPath:(NSString *)path
{
}

@end


@implementation FSNBrowser (NodeRepContainer)

- (void)showContentsOfNode:(FSNode *)anode
{
  [self setBaseNode: anode];
}

- (void)reloadContents
{
  [self reloadFromColumnWithNode: baseNode];
}

- (FSNode *)shownNode
{
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
  [self checkLockedReps];
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

  if ([operation isEqual: @"NSWorkspaceMoveOperation"] 
        || [operation isEqual: @"NSWorkspaceCopyOperation"]
        || [operation isEqual: @"NSWorkspaceLinkOperation"]
        || [operation isEqual: @"NSWorkspaceDuplicateOperation"]
        || [operation isEqual: @"GWorkspaceCreateDirOperation"]
        || [operation isEqual: @"GWorkspaceCreateFileOperation"]
        || [operation isEqual: @"GWorkspaceRenameOperation"]
			  || [operation isEqual: @"GWorkspaceRecycleOutOperation"]) { 
    if ([self isShowingPath: destination]) {
      [self reloadFromColumnWithPath: destination];     
      
      if ([operation isEqual: @"GWorkspaceCreateFileOperation"]
                    || [operation isEqual: @"GWorkspaceCreateDirOperation"]
                    || [operation isEqual: @"GWorkspaceRenameOperation"]) {  
        if ([[self window] isKeyWindow]) {
          [self selectCellsWithNames: files
                    inColumnWithPath: destination
                          sendAction: YES];
        }
      }
    }
  }

  if ([operation isEqual: @"NSWorkspaceMoveOperation"]
        || [operation isEqual: @"NSWorkspaceDestroyOperation"]
				|| [operation isEqual: @"NSWorkspaceRecycleOperation"]
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

  if ([event isEqual: @"GWWatchedDirectoryDeleted"]) {
    NSString *s = [path stringByDeletingLastPathComponent];

    if ([self isShowingPath: s]) {
      [self reloadFromColumnWithPath: s]; 
    }
    
  } else if ([event isEqual: @"GWFileDeletedInWatchedDirectory"]) {
    [self removeCellsWithNames: [info objectForKey: @"files"]
              inColumnWithPath: path];
                 
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
  }
}

- (FSNInfoType)showType
{
  return infoType;
}

- (void)setIconSize:(int)size
{
}

- (int)iconSize
{
  return DEFAULT_ISIZE;
}

- (void)setLabelTextSize:(int)size
{
}

- (int)labelTextSize
{
  return 12;
}

- (void)setIconPosition:(int)pos
{
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
  FSNBrowserColumn *bc = [self columnWithNode: anode];
  
  if (bc) {
    int index = [bc index];
    
    if (index > 0) {
      return [[self columnBeforeColumn: bc] cellOfNode: anode];
    }
  }

  return nil;
}

- (id)repOfSubnodePath:(NSString *)apath
{
  FSNBrowserColumn *bc = [self columnWithPath: apath];
  
  if (bc) {
    int index = [bc index];
    
    if (index > 0) {
      return [[self columnBeforeColumn: bc] cellWithPath: apath];
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

- (void)unloadFromPath:(NSString *)path
{
  FSNBrowserColumn *bc = [self columnWithPath: path];

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

- (void)unselectOtherReps:(id)arep
{
  FSNBrowserColumn *bc = [self lastLoadedColumn];
  
  if (bc) {
    [bc setLeaf: YES];
  }
}

- (void)selectReps:(NSArray *)reps
{
  if (reps && [reps count]) {
    FSNode *node = [[reps objectAtIndex: 0] node];
    FSNBrowserColumn *bc = [self columnWithPath: [node parentPath]];
    
    if (bc) {
      [bc selectCells: reps sendAction: NO];
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
        [bc selectCellsOfNodes: nodes sendAction: NO];
      } else {
        [self showSelection: nodes];
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
        [bc selectCellsWithPaths: paths sendAction: NO];
      } else {
        [self showPathsSelection: paths];
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
    [self selectRepsOfPaths: lastSelection];
  }
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
                       wasCutted:(BOOL)cutted
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

- (void)setBackgroundColor:(NSColor *)acolor
{
  int i;
  
  ASSIGN (backColor, acolor);
  for (i = 0; i < [columns count]; i++) {
    [[columns objectAtIndex: i] setBackgroundColor: backColor];
  }
  
  [self setNeedsDisplay: YES];
}

- (NSColor *)backgroundColor
{
  return backColor;
}

- (void)setTextColor:(NSColor *)acolor
{
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
