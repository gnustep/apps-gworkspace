/* BColumn.m
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
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
#include "GWProtocol.h"
#include "GWFunctions.h"
#include "GWNotifications.h"
#include "GWLib.h"
#include "BColumn.h"
#include "BMatrix.h"
#include "BCell.h"
#include "BIcon.h"
#include "Browser2.h"
#include "GNUstep.h"

#ifdef GNUSTEP 
  #define ICON_FRAME_HEIGHT 52
  #define ICON_SIZE_WIDTH 48
  #define CELLS_HEIGHT 15
  #define ICON_VOFFSET 14
  #define LABEL_HEIGHT 14
  #define ICON_CELLS_HEIGHT 30
#else
  #define ICON_FRAME_HEIGHT 34
  #define ICON_SIZE_WIDTH 32
  #define CELLS_HEIGHT 16
  #define ICON_VOFFSET 15
  #define LABEL_HEIGHT 14
  #define ICON_CELLS_HEIGHT 30
#endif

#define CHECKRECT(rct) \
if (rct.size.width < 0) rct.size.width = 0; \
if (rct.size.height < 0) rct.size.height = 0

#define CHECKSIZE(sz) \
if (sz.width < 0) sz.width = 0; \
if (sz.height < 0) sz.height = 0

@implementation BColumn

- (void)dealloc
{
	TEST_RELEASE (icon);
  TEST_RELEASE (iconView);
  TEST_RELEASE (matrix);
  TEST_RELEASE (scroll);
  RELEASE (cellPrototype);
  TEST_RELEASE (path);
  TEST_RELEASE (oldpath);
  [super dealloc];
}

- (id)initInBrowser:(Browser2 *)aBrowser
            atIndex:(int)ind
      cellPrototype:(BCell *)cell
          styleMask:(int)mask
          
{
  self = [super init];
  
  if (self) {
	  NSRect rect = NSMakeRect(0, 0, 150, 100);
    styleMask = mask;
            
    fm = [NSFileManager defaultManager];
    ws = [NSWorkspace sharedWorkspace];
    
    browser = aBrowser;
    index = ind;
    ASSIGN (cellPrototype, cell);

    path = nil;
    oldpath = nil;
    matrix = nil;
    icon = nil;
    iconView = nil;
    isLoaded = NO;
    isLeaf = NO;
    
    [self setFrame: rect];
    
    scroll = [[NSScrollView alloc] initWithFrame: rect];
    [scroll setBorderType: NSBezelBorder];
    [scroll setHasHorizontalScroller: NO];
    [scroll setHasVerticalScroller: YES];
    [scroll setBorderType: NSNoBorder];
	
    [self addSubview: scroll];
    
    if (styleMask & GWColumnIconMask) {
      iconView = [NSView new];
    } 
    
    if (styleMask & GWIconCellsMask) {
      cellsHeight = ICON_CELLS_HEIGHT;
      
      [self registerForDraggedTypes: [NSArray arrayWithObject: NSFilenamesPboardType]];    
    } else {
      cellsHeight = CELLS_HEIGHT;
    }
  }
  
  return self;
}

- (void)setCurrentPaths:(NSArray *)cpaths
{
  NSMutableArray *iconPaths = nil;
  NSString *apath = nil;
  BOOL exists = YES;
  NSArray *savedSelection = nil;
  NSMutableArray *visibleCellsNames = nil;
  float scrollTune = 0;
  int i = 0;

  if (cpaths) {
    iconPaths = [NSMutableArray arrayWithCapacity: 1];
  
    for (i = 0; i < [cpaths count]; i++) {
      NSString *ipath = [cpaths objectAtIndex: i];

      if ([fm fileExistsAtPath: ipath]) { 
        [iconPaths addObject: ipath];
      }
    } 
    
    if ([iconPaths count]) {
      if ([iconPaths count] == 1) {
        apath = [cpaths objectAtIndex: 0];
        exists = [fm fileExistsAtPath: apath];
      }
    } else {
      iconPaths = nil;
    }
  }
  
  if (oldpath && apath && [oldpath isEqual: apath] && exists) {
    savedSelection = [self selection];
    if (savedSelection) {
      RETAIN (savedSelection);
    }
    
    if (matrix) {
      NSArray *vnames = [matrix getNamesOfVisibleCellsAndTuneSpace: &scrollTune];
    
      if (vnames) {
        visibleCellsNames = [NSMutableArray new];
        [visibleCellsNames addObjectsFromArray: vnames];
      }
    }
  }
    
  if (matrix) {
    [matrix removeFromSuperviewWithoutNeedingDisplay];  
    [scroll setDocumentView: nil];	  
    DESTROY (matrix);
  }

  DESTROY (path); 
  DESTROY (oldpath);

  if ((iconPaths == nil) || (exists == NO)) {
    TEST_RELEASE (savedSelection);   
    if ((styleMask & GWColumnIconMask) && icon) {
      [icon removeFromSuperview];
      [[icon label] removeFromSuperview];
      DESTROY (icon);
    }
    isLoaded = NO;
    return;
  
  } else {
    id cell = nil;
    BColumn *col = nil;
    
    if (apath) {
      ASSIGN (oldpath, apath);    
      ASSIGN (path, apath);    
    }
    
    if (styleMask & GWColumnIconMask) {
      if (icon == nil) {
	      icon = [[BIcon alloc] init];		
	      [icon setDelegate: self];
	      [iconView addSubview: icon];
	      [iconView addSubview: [icon label]];     
        [icon setPaths: iconPaths];	
		    [icon setLocked: NO];
        [icon select];   
      } else {
        [icon setPaths: iconPaths];	
		    [icon setLocked: NO];
      }

		  for (i = 0; i < [iconPaths count]; i++) {
        NSString *ipath = [iconPaths objectAtIndex: i];

			  if ([GWLib isLockedPath: ipath]) {
				  [icon setLocked: YES];
				  break;
			  }
		  }
    }
    
    [self setLeaf: YES];
    
    if (path) {
      [self createRowsInMatrix];
      [matrix setCellSize: NSMakeSize([scroll contentSize].width, cellsHeight)];  
      [self adjustMatrix];

      if (savedSelection) {
        NSMutableArray *savedNames = [NSMutableArray arrayWithCapacity: 1];

        for (i = 0; i < [savedSelection count]; i++) {
          NSString *savedSel = [savedSelection objectAtIndex: i];

          if ([fm fileExistsAtPath: savedSel]) {
            [savedNames addObject: [savedSel lastPathComponent]];
          }
        }

        if ([savedNames count]) {
          [self selectMatrixCellsWithNames: savedNames sendAction: NO];
        } 
      } 
      
      if (visibleCellsNames) {
        NSArray *cells = [matrix cells];

        if (cells && [cells count]) {
          NSMutableArray *cellsNames = [NSMutableArray arrayWithCapacity: 1];
          int count = [visibleCellsNames count];

          for (i = 0; i < [cells count]; i++) {
            [cellsNames addObject: [[cells objectAtIndex: i] stringValue]];
          }
          
          for (i = 0; i < count; i++) {
            NSString *vname = [visibleCellsNames objectAtIndex: i];
          
            if ([cellsNames containsObject: vname] == NO) {
              [visibleCellsNames removeObjectAtIndex: i];
              count--;
              i--;
            }
          }
          
          if ([visibleCellsNames count]) {
            cell = [self cellWithName: [visibleCellsNames objectAtIndex: 0]];
            [matrix scrollToFirstPositionCell: cell withScrollTune: scrollTune];
          }
        }
      }
    }
               
    isLoaded = YES;
    
    TEST_RELEASE (savedSelection);
    TEST_RELEASE (visibleCellsNames);
    
    col = [browser columnBeforeColumn: self];
    if (col) {
      [col setLeaf: NO];
    }
  }
}

- (void)createRowsInMatrix
{
  NSArray *files;
  int i, count;
  BOOL is_dir; 

  if ([GWLib existsAndIsDirectoryFileAtPath: path] == NO) {	
    return;
  } else {
		if ([GWLib isPakageAtPath: path] && (!(styleMask & GWViewsPaksgesMask))) {
    	return;
		}
  }

	matrix = [[BMatrix alloc] initInColumn: self withFrame: [self frame]
		                      mode: NSListModeMatrix prototype: cellPrototype
		      					                      numberOfRows: 0 numberOfColumns: 0 
                                    acceptDnd: (styleMask & GWIconCellsMask)];
  
	[matrix setIntercellSpacing: NSMakeSize(0, 0)];
  [matrix setCellSize: NSMakeSize([scroll contentSize].width, cellsHeight)];  
	[matrix setAutoscroll: YES];
	[matrix setAllowsEmptySelection: YES];
	[matrix setTarget: self];
	[matrix setAction: @selector(doClick:)];
	[matrix setDoubleAction: @selector(doDoubleClick:)];
	[scroll setDocumentView: matrix];

  files = [GWLib sortedDirectoryContentsAtPath: path];
  files = [GWLib checkHiddenFiles: files atPath: path];
  
  count = [files count];
  if (count == 0) {
		return;
	}
    
  [matrix addColumn]; 
  
  for (i = 0; i < count; ++i) {
    NSString *s = [path stringByAppendingPathComponent: [files objectAtIndex: i]];
    id cell;
    
    if (i != 0) {
		  [matrix insertRow: i];
    } 
    
    cell = [matrix cellAtRow: i column: 0];   
    [cell setLoaded: YES];
		[cell setEnabled: YES]; 
    
    if (styleMask & GWIconCellsMask) {
      [cell setPaths: [NSArray arrayWithObject: s]];
    } else {
      [cell setStringValue: [files objectAtIndex: i]];
    }
    
    is_dir = [GWLib existsAndIsDirectoryFileAtPath: s];
    if (is_dir == YES) {     
      [cell setLeaf: (([GWLib isPakageAtPath: s]) 
                              ? (!(styleMask & GWViewsPaksgesMask)) : NO)];
    } else {
		  [cell setLeaf: YES];
    }
		
    [cell setEnabled: !([GWLib isLockedPath: s])];	  
  }
}

- (void)addMatrixCellsWithNames:(NSArray *)names
{
  NSArray *files = [GWLib checkHiddenFiles: names atPath: path];

  if ([files count]) {
	  BCell *cell;
    NSArray *selectedCells;
	  NSMutableDictionary *sortDict;
	  int stype;
    BOOL isdir;
    int i;

    [matrix setIntercellSpacing: NSMakeSize(0, 0)];
    
	  selectedCells = [matrix selectedCells];

    for (i = 0; i < [names count]; i++) {
      NSString *name = [names objectAtIndex: i];
      NSString *cellpath = [path stringByAppendingPathComponent: name];

      isdir = [GWLib existsAndIsDirectoryFileAtPath: cellpath];
      
		  cell = [self cellWithName: name];    
      if (cell == nil) {
        [matrix addRow];
        cell = [matrix cellAtRow: [[matrix cells] count] -1 column: 0];
        
        if (styleMask & GWIconCellsMask) {
          [cell setPaths: [NSArray arrayWithObject: cellpath]];
        } else {
          [cell setStringValue: name];
        }
        
        if (isdir) {     
          [cell setLeaf: (([GWLib isPakageAtPath: cellpath]) 
                                ? (!(styleMask & GWViewsPaksgesMask)) : NO)];
        } else {
		      [cell setLeaf: YES];
        }
		
        [cell setLoaded: YES];
			  [cell setEnabled: YES];
        
      } else {
        [cell setEnabled: YES];
      }
    }

    [matrix setCellSize: NSMakeSize([scroll contentSize].width, cellsHeight)];  

	  stype = [GWLib sortTypeForDirectoryAtPath: path];			
	  sortDict = [NSMutableDictionary dictionaryWithCapacity: 1];
	  [sortDict setObject: path forKey: @"path"];
	  [sortDict setObject: [NSNumber numberWithInt: stype] forKey: @"type"];
    [matrix sortUsingFunction: (int (*)(id, id, void*))compareCells context: (void *)sortDict];	
	  [self adjustMatrix];
    [matrix sizeToCells];  

	  if (selectedCells != nil) {
      [self selectMatrixCells: selectedCells sendAction: NO];
    } 

    [matrix setNeedsDisplay: YES]; 
  }
}

- (void)addDimmedMatrixCellsWithNames:(NSArray *)names
{
  NSArray *files = [GWLib checkHiddenFiles: names atPath: path];

  if ([files count]) {
	  BCell *cell;
    NSArray *selectedCells;
    int i;

    [matrix setIntercellSpacing: NSMakeSize(0, 0)];
    
	  selectedCells = [matrix selectedCells];

    for (i = 0; i < [names count]; i++) {
      NSString *name = [names objectAtIndex: i];

		  cell = [self cellWithName: name];    
      if (cell == nil) {
        [matrix addRow];
        cell = [matrix cellAtRow: [[matrix cells] count] -1 column: 0];
        [cell setStringValue: name];
		    [cell setLeaf: YES];
        [cell setLoaded: YES];
			  [cell setEnabled: NO];

      } else {
        [cell setEnabled: NO];
      }
    }

    [matrix setCellSize: NSMakeSize([scroll contentSize].width, cellsHeight)];  

	  [self adjustMatrix];
    [matrix sizeToCells];  

	  if (selectedCells != nil) {
      [self selectMatrixCells: selectedCells sendAction: NO];
    } 

    [matrix setNeedsDisplay: YES]; 
  }
}

- (void)removeMatrixCellsWithNames:(NSArray *)names
{
  NSMutableArray *selectedCells = nil;
  NSMutableArray *visibleCellsNames = nil;
  BColumn *col = nil;
  id cell = nil;
  float scrollTune = 0;
  int i = 0;
  BOOL updatesel = NO;

  selectedCells = [[matrix selectedCells] mutableCopy];  
  AUTORELEASE (selectedCells);

  visibleCellsNames = [[matrix getNamesOfVisibleCellsAndTuneSpace: &scrollTune] mutableCopy];
  AUTORELEASE (visibleCellsNames);
  
  for (i = 0; i < [names count]; i++) {
    NSString *cname = [names objectAtIndex: i];
    
    cell = [self cellWithName: cname];

    if (cell) {    
			int row, col;
			
			if ([selectedCells containsObject: cell]) {
				[selectedCells removeObject: cell];
        updatesel = YES;
			}
      
			if ([visibleCellsNames containsObject: cname]) {
				[visibleCellsNames removeObject: cname];
			}
      
      [matrix getRow: &row column: &col ofCell: cell];  
      [matrix removeRow: row];    			
    }
  }

  [matrix sizeToCells];
  [matrix setNeedsDisplay: YES];
  
  if (updatesel) {
	  if ([selectedCells count] > 0) {      
      [self selectMatrixCells: selectedCells sendAction: NO];    
      [matrix setNeedsDisplay: YES];
      
      col = [browser columnAfterColumn: self];
      if (col) {
        [col updateIcon];
      }

      if ([visibleCellsNames count]) {
        cell = [self cellWithName: [visibleCellsNames objectAtIndex: 0]];
        [matrix scrollToFirstPositionCell: cell withScrollTune: scrollTune];
      }
      
	  } else {
      if (index != 0) {		
        if ((index - 1) >= [browser firstVisibleColumn]) {
          col = [browser columnBeforeColumn: self];
          cell = [col cellWithName: [path lastPathComponent]];

          [col selectMatrixCells: [NSArray arrayWithObject: cell]
                      sendAction: YES];
        }
      } else {
        [browser setLastColumn: index];
      }
	  }
    
  } else if ([visibleCellsNames count]) {
    cell = [self cellWithName: [visibleCellsNames objectAtIndex: 0]];
    [matrix scrollToFirstPositionCell: cell withScrollTune: scrollTune];
  }
}

- (BOOL)selectMatrixCellsWithNames:(NSArray *)names sendAction:(BOOL)act
{
  NSArray *cells = [matrix cells];
  int i = 0;
  BOOL found = NO;
  
  [matrix deselectAllCells];
  
	for (i = 0; i < [cells count]; i++) {
	  NSCell *cell = [cells objectAtIndex: i];
    
    if ([names containsObject: [cell stringValue]]) {
      [matrix selectCell: cell];
      found = YES;
    } 
	}
  
  if (act) {
    [matrix sendAction];
  }
  
  return found;
}

- (void)selectMatrixCells:(NSArray *)cells sendAction:(BOOL)act
{
  int i;		
	
  [matrix deselectAllCells];
  		
	for (i = 0; i < [cells count]; i++) {
    [matrix selectCell: [cells objectAtIndex: i]];
	}

  if (act) {
    [matrix sendAction];
  }
}

- (BOOL)selectFirstCell
{
  if (matrix && [[matrix cells] count]) {
    [matrix selectCellAtRow: 0 column: 0];
    [matrix sendAction];
    return YES;
  }  
  return NO;
}

- (BOOL)selectCellWithPrefix:(NSString *)prefix
{
  if (matrix && [[matrix cells] count]) {
    int n = [matrix numberOfRows];
    int s = [matrix selectedRow];
    NSString *cellstr = nil;
    int i = 0;

    cellstr = [[matrix cellAtRow: s column: 0] stringValue];
    
    if (([cellstr length] > 0) && ([cellstr hasPrefix: prefix])) {
      return YES;
    }
    
	  for (i = s + 1; i < n; i++) {
      cellstr = [[matrix cellAtRow: i column: 0] stringValue];
    
			if (([cellstr length] > 0) && ([cellstr hasPrefix: prefix])) {
        [matrix deselectAllCells];
        [matrix selectCellAtRow: i column: 0];
		  	[matrix scrollCellToVisibleAtRow: i column: 0];
		  	[matrix sendAction];
		  	return YES;
			}
	  }
    
		for (i = 0; i < s; i++) {
      cellstr = [[matrix cellAtRow: i column: 0] stringValue];
    
			if (([cellstr length] > 0) && ([cellstr hasPrefix: prefix])) {
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

- (void)selectIcon
{
  if (styleMask & GWColumnIconMask) {
    [icon select];
  }
}

- (void)selectAll
{
  if (matrix && [[matrix cells] count]) {
    [matrix selectAll: nil];
	  [matrix sendAction];
  } else {
    BColumn *col = [browser columnBeforeColumn: self];
  
    if (col) {
      [col selectAll];
    }
  }
}

- (NSArray *)selection
{
  NSArray *selected = [matrix selectedCells];

	if (selected == nil) {
		return nil;
    
	} else {  
    NSMutableArray *selection = [NSMutableArray array];
    NSMutableArray *cellsnames = [NSMutableArray array];
    int count = [selected count];
    BOOL fileMissing = NO;
    int i;
  
    for (i = 0; i < count; i++) {    
      NSString *cellname = [[selected objectAtIndex: i] stringValue];  
      NSString *cellpath = [path stringByAppendingPathComponent: cellname]; 
      
      if ([fm fileExistsAtPath: cellpath]) {   
        [selection addObject: cellpath];
        [cellsnames addObject: cellname];
      } else {
        fileMissing = YES;
      }
    }

    if (fileMissing) {
      [matrix deselectAllCells];
      if ([cellsnames count]) {
        [self selectMatrixCellsWithNames: cellsnames sendAction: YES];
      }
    }

	  if ([selection count] > 0) {
  	  return selection;
	  }
  }
	
	return nil;
}

- (void)lockCellsWithNames:(NSArray *)names
{
  int i;
  BOOL found = NO;
  
  for (i = 0; i < [names count]; i++) {
    BCell *cell = [self cellWithName: [names objectAtIndex: i]];
    if (cell != nil) {   
			if ([cell isEnabled]) { 
				[cell setEnabled: NO];
        found = YES;
			}
    }
  }
		
  [matrix setNeedsDisplay: found];   
}

- (void)unLockCellsWithNames:(NSArray *)names
{
  int i;
  BOOL found = NO;

  for (i = 0; i < [names count]; i++) {
    BCell *cell = [self cellWithName: [names objectAtIndex: i]];
    if (cell != nil) { 
			if ([cell isEnabled] == NO) {   
				[cell setEnabled: YES];
        found = YES;
			}
    }
  }
		
  [matrix setNeedsDisplay: found];   
}

- (void)lock
{
	NSArray *cells;
  int i, count;

	if ((styleMask & GWColumnIconMask) && icon && ([icon isLocked] == NO)) {
		[icon setLocked: YES];
		[icon setNeedsDisplay: YES];
    [[icon label] setNeedsDisplay: YES];
	}
	
  if (matrix == nil) {
		return;
	}
 
  cells = [matrix cells];	
  if (cells == nil) {
		return;
	}
	
	count = [cells count];
	
	if (count) {
  	for (i = 0; i < count; i++) {
			id cell = [cells objectAtIndex: i];

			if ([cell isEnabled]) {
    		[cell setEnabled: NO];
			}
  	}

  	[matrix setNeedsDisplay: YES];   
	}
}

- (void)unLock
{
	NSArray *cells;
  int i, count;

	if ((styleMask & GWColumnIconMask) && icon && [icon isLocked]) {
		[icon setLocked: NO];		   
		[icon setNeedsDisplay: YES];
    [[icon label] setNeedsDisplay: YES];    
	}
	
  if (matrix == nil) {
		return;
	}
 
  cells = [matrix cells];	
  if (cells == nil) {
		return;
	}

	count = [cells count];

	if (count) {
  	for (i = 0; i < count; i++) {
			id cell = [cells objectAtIndex: i];

			if ([cell isEnabled] == NO) {
    		[cell setEnabled: YES];
			}
  	}

  	[matrix setNeedsDisplay: count];   
	}
}

- (void)adjustMatrix
{
  [matrix setCellSize: NSMakeSize([scroll contentSize].width, cellsHeight)];  
  [matrix sizeToCells];
}

- (void)updateIcon
{
  if ((styleMask & GWColumnIconMask) && icon) {
    [icon setPaths: [browser selectionInColumnBeforeColumn: self]];	
        
    if ((matrix == nil) || ([[matrix selectedCells] count] == 0)) {
      [self setLeaf: YES];
    }
  }
}

- (id)cellWithName:(NSString *)name
{
  NSArray *cells = [matrix cells];
  int i = 0;

	for (i = 0; i < [cells count]; i++) {
    id cell = [cells objectAtIndex: i];                  
		if ([[cell stringValue] isEqualToString: name]) {    
      return cell;
    }
  }
  
  return nil;
}

- (void)setLeaf:(BOOL)value
{
  isLeaf = value;

  if (icon == nil) {
    return;
  } else {
    if ([icon isBranch] == value) {
      [icon setBranch: !value];
      
      if (isLeaf && matrix) {
        [matrix deselectAllCells];
      }
    }
  }
}

- (Browser2 *)browser
{
  return browser;
}

- (NSMatrix *)cmatrix
{
  return matrix;
}

- (NSView *)iconView
{
  return iconView;
}

- (BIcon *)myIcon
{
	return icon;
}

- (NSTextField *)iconLabel
{
  return (icon ? [icon label] : nil);
}

- (NSString *)currentPath
{
  return path;
}

- (int)index
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

- (BOOL)isLeaf
{
  return isLeaf;
}

- (void)doClick:(id)sender
{
  [browser clickInMatrixOfColumn: self];
}

- (void)doDoubleClick:(id)sender
{
  [browser doubleClickInMatrixOfColumn: self];
}

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
                   inMatrixCell:(id)aCell
{
  BCell *cell;
  NSPasteboard *pb;
  NSDragOperation sourceDragMask;
	NSArray *sourcePaths;
	NSString *fromPath;
  NSString *targetPath;
  NSString *buff;
	int count;

  cell = (BCell *)aCell;
  
  if ([cell isLeaf] || ([cell isEnabled] == NO)) {
    return NSDragOperationNone;
  } 
	  
  pb = [sender draggingPasteboard];

  if ([[pb types] indexOfObject: NSFilenamesPboardType] == NSNotFound) {
    return NSDragOperationNone;
  }

  sourcePaths = [pb propertyListForType: NSFilenamesPboardType];
  count = [sourcePaths count];

	if (count == 0) {
		return NSDragOperationNone;
  } 

  fromPath = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];  
  targetPath = [path stringByAppendingPathComponent: [cell stringValue]];

	if ([targetPath isEqualToString: fromPath]
                    || [sourcePaths containsObject: targetPath]) {
		return NSDragOperationNone;
  }  

	if ([fm isWritableFileAtPath: targetPath] == NO) {
		return NSDragOperationNone;
	}

	buff = [NSString stringWithString: targetPath];
	while (1) {
    if ([sourcePaths containsObject: buff]) {
      return NSDragOperationNone;
		}
    if ([buff isEqualToString: fixPath(@"/", 0)] == YES) {
      break;
    }            
		buff = [buff stringByDeletingLastPathComponent];
	}

	sourceDragMask = [sender draggingSourceOperationMask];

	if (sourceDragMask == NSDragOperationCopy) {
		return NSDragOperationCopy;
	} else if (sourceDragMask == NSDragOperationLink) {
		return NSDragOperationLink;
	} else {
		return NSDragOperationAll;
	}

  return NSDragOperationNone;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
                 inMatrixCell:(id)aCell
{
  NSPasteboard *pb;
  NSDragOperation sourceDragMask;
	NSArray *sourcePaths;
  NSString *targetPath;
  NSString *operation, *source;
  NSMutableArray *files;
	NSMutableDictionary *opDict;
	NSString *trashPath;
  BCell *cell;
  int i;

  cell = (BCell *)aCell;
  if ([cell isLeaf] || ([cell isEnabled] == NO)) {
    return;
  } 

  sourceDragMask = [sender draggingSourceOperationMask];  
  pb = [sender draggingPasteboard];

  if ([[pb types] indexOfObject: NSFilenamesPboardType] == NSNotFound) {
    return;
  }
    
  sourcePaths = [pb propertyListForType: NSFilenamesPboardType];
  source = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];
  targetPath = [path stringByAppendingPathComponent: [cell stringValue]];
  trashPath = [[GWLib workspaceApp] trashPath];

	if ([source isEqualToString: trashPath]) {
		operation = GWorkspaceRecycleOutOperation;
	} else {	
		if (sourceDragMask == NSDragOperationCopy) {
			operation = NSWorkspaceCopyOperation;
		} else if (sourceDragMask == NSDragOperationLink) {
			operation = NSWorkspaceLinkOperation;
		} else {
			operation = NSWorkspaceMoveOperation;
		}
  }
  
  files = [NSMutableArray arrayWithCapacity: 1];    
  for(i = 0; i < [sourcePaths count]; i++) {    
    [files addObject: [[sourcePaths objectAtIndex: i] lastPathComponent]];
  }  

	opDict = [NSMutableDictionary dictionaryWithCapacity: 4];
	[opDict setObject: operation forKey: @"operation"];
	[opDict setObject: source forKey: @"source"];
	[opDict setObject: targetPath forKey: @"destination"];
	[opDict setObject: files forKey: @"files"];

  [[GWLib workspaceApp] performFileOperationWithDictionary: opDict];
}

- (void)setFrame:(NSRect)frameRect
{
  NSRect r = NSMakeRect(0, 0, frameRect.size.width, frameRect.size.height);

  CHECKRECT (frameRect);
  [super setFrame: frameRect]; 
   
  CHECKRECT (r);
  [scroll setFrame: r];  

  if ((styleMask & GWColumnIconMask) && icon) {
    NSRect icnRect = NSMakeRect(0, ICON_VOFFSET, 
                [iconView frame].size.width, ICON_FRAME_HEIGHT);
    
    CHECKRECT (icnRect);
    [icon setFrame: icnRect];
    [iconView setNeedsDisplay: YES];
  }
  
  if (matrix) {
    [self adjustMatrix];
  }
}

@end

//
// BIcon Delegate Methods
//
@implementation BColumn (BIconDelegateMethods)

- (void)icon:(BIcon *)sender setFrameOfLabel:(NSTextField *)label
{
	float icnwidth, labwidth, labxpos, labypos;
  NSRect labRect;
  
	icnwidth = [sender frame].size.width;
 	labwidth = [label frame].size.width;
	labypos = [sender frame].origin.y - ICON_VOFFSET;

	if(icnwidth > labwidth) {
		labxpos = [sender frame].origin.x + ((icnwidth - labwidth) / 2);
	} else {
		labxpos = [sender frame].origin.x - ((labwidth - icnwidth) / 2);
  }
  
  labRect = NSMakeRect(labxpos, labypos, labwidth, LABEL_HEIGHT);
  CHECKRECT (labRect);
	[label setFrame: labRect];
  [label setNeedsDisplay: YES];
}

- (void)unselectOtherIcons:(BIcon *)selicon
{
  NSArray *otherCols = [browser columnsDifferentFromColumn: self];
  int i;
  
  for (i = 0; i < [otherCols count]; i++) {
    BIcon *icn = [[otherCols objectAtIndex: i] myIcon];
  
		if ([icn isSelect]) {
			[icn unselect];
		}
  }
}

- (void)unselectNameEditor
{
  [browser unselectNameEditor];
}

- (void)restoreSelectionAfterDndOfIcon:(BIcon *)dndicon
{
  [browser restoreSelectionAfterDndOfIcon: dndicon];
}

- (void)clickOnIcon:(BIcon *)clicked
{
  [self setLeaf: YES];
  [browser clickOnIcon: icon ofColumn: self];
}

- (void)doubleClickOnIcon:(BIcon *)clicked newViewer:(BOOL)isnew
{
  [browser doubleClickOnIcon: clicked ofColumn: self newViewer: isnew];
}

@end


