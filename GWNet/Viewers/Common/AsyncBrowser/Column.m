/* Column.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
 *
 * This file is part of the GNUstep GWNet application
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
#include "Functions.h"
#include "Column.h"
#include "Matrix.h"
#include "Cell.h"
#include "Icon.h"
#include "Browser.h"
#include "Notifications.h"
#include "GNUstep.h"

#define ICON_FRAME_HEIGHT 52
#define ICON_VOFFSET 14

#define CELLS_HEIGHT 15

#define CHECKRECT(rct) \
if (rct.size.width < 0) rct.size.width = 0; \
if (rct.size.height < 0) rct.size.height = 0

#define CHECKSIZE(sz) \
if (sz.width < 0) sz.width = 0; \
if (sz.height < 0) sz.height = 0

@implementation Column

- (void)dealloc
{
	TEST_RELEASE (icon);
  TEST_RELEASE (iconView);
  TEST_RELEASE (matrix);
  TEST_RELEASE (scroll);
  RELEASE (cellPrototype);
  TEST_RELEASE (hostName);
  TEST_RELEASE (path);
  RELEASE (selection);
  TEST_RELEASE (nextPath);
  TEST_RELEASE (lastPath);
  TEST_RELEASE (visibleCellsNames);  
  
  [super dealloc];
}

- (id)initInBrowser:(Browser *)aBrowser
            atIndex:(int)ind
      cellPrototype:(Cell *)cell
           hostName:(NSString *)hname
{
  self = [super init];
  
  if (self) {
	  NSRect rect = NSMakeRect(0, 0, 150, 100);
        
    ASSIGN (hostName, hname);
        
    browser = aBrowser;
    browserDelegate = [browser delegate];
    index = ind;
    ASSIGN (cellPrototype, cell);

    selection = [NSMutableArray new];
    path = nil;
    nextPath = nil;
    lastPath = nil;
    visibleCellsNames = nil;    
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
    
    iconView = [NSView new];
    cellsHeight = CELLS_HEIGHT;
  }
  
  return self;
}

- (void)setCurrentPaths:(NSArray *)cpaths
{
  Column *col;
  int i;

  DESTROY (path);  
  DESTROY (nextPath);
  DESTROY (visibleCellsNames);
  scrollTune = 0;
  
  if (cpaths == nil) {
    if (icon) {
      [icon removeFromSuperview];
      [[icon label] removeFromSuperview];
      DESTROY (icon);
    }
    
    if (lastPath) {
      // NSLog(@"try to invalidate %@", lastPath);
      [browserDelegate invalidateContentsRequestForPath: lastPath];
    }
    
    DESTROY (lastPath);
    DESTROY (selection);
    isLoaded = NO;
    
  } else {
    [browserDelegate setSelectedPaths: cpaths];		

    if ([cpaths count] == 1) {
      ASSIGN (nextPath, [cpaths objectAtIndex: 0]);
      
      if (matrix && lastPath && [lastPath isEqual: nextPath]) {
        NSArray *vnames = [matrix getNamesOfVisibleCellsAndTuneSpace: &scrollTune];

        if (vnames && [vnames count]) {
          visibleCellsNames = [vnames mutableCopy];
        }
      }
    }
    
    if (icon == nil) {
	    icon = [[Icon alloc] initWithHostName: hostName inBrowser: browser];
	    [icon setDelegate: self];
	    [iconView addSubview: icon];
	    [iconView addSubview: [icon label]];     
    } 
    
    [icon setPaths: cpaths];	
    [icon setLocked: NO];
    [icon select];   
            
		for (i = 0; i < [cpaths count]; i++) {
      NSString *cpath = [cpaths objectAtIndex: i];

			if ([browserDelegate isLockedPath: cpath]) {
				[icon setLocked: YES];
				break;
			}
		}
    
    [self setLeaf: YES];
    
    col = [browser columnBeforeColumn: self];
    if (col) {
      [col setLeaf: NO];
    }
  } 
  
  [self clearMatrix];
  
  if (nextPath) {
    NSDictionary *pathContents = [browserDelegate contentsForPath: nextPath];
  
    if (pathContents) {
      [self createContents: pathContents];
       
    } else {
      NSString *type = [browserDelegate typeOfFileAt: nextPath];
                
      if ((type == nil) || [type isEqual: NSFileTypeDirectory]) {
        NSDictionary *preContents = [browserDelegate preContentsForPath: nextPath];
    
        if (preContents) {
          [self createPreContents: preContents];
        }
      
        [self lock];
        [browserDelegate prepareContentsForPath: nextPath];

      } else if (type && ([type isEqual: NSFileTypeDirectory] == NO)) {
        [self setLeaf: YES];
        isLoaded = YES;

        col = [browser columnBeforeColumn: self]; 

        if (col) {
          NSString *selname = [nextPath lastPathComponent];

          [col selectMatrixCellsWithNames: [NSArray arrayWithObject: selname] 
                               sendAction: NO];
          [col setLeaf: NO]; 
        }
      }
    }
     
  } else if (cpaths && [cpaths count]) {
    col = [browser columnBeforeColumn: self]; 

    if (col) {
      if ([col isLoaded]) {
        NSMutableArray *selNames = [NSMutableArray array];

		    for (i = 0; i < [cpaths count]; i++) {
          [selNames addObject: [[cpaths objectAtIndex: i] lastPathComponent]];
        }

        [col selectMatrixCellsWithNames: selNames sendAction: NO];
      }

      [col setLeaf: NO]; 
    }
  
    if ([cpaths count] > 1) {
      DESTROY (lastPath);
      [self setLeaf: YES];
      isLoaded = YES;
    }
  }
}

- (BOOL)isWaitingContentsForPath:(NSString *)apath
{
  return (nextPath && [nextPath isEqual: apath]);
}

- (void)createContents:(NSDictionary *)pathContents
{
  Column *col = [browser columnBeforeColumn: self]; 
  BOOL checkSelection = (lastPath && [nextPath isEqual: lastPath] && selection);
    
  ASSIGN (lastPath, nextPath);
  ASSIGN (path, nextPath);
  [self fillMatrix: pathContents];
  [matrix setCellSize: NSMakeSize([scroll contentSize].width, cellsHeight)];  
  [self adjustMatrix];  
  isLoaded = YES;
//  [self unLock];  
  [self setLeaf: YES];
  
  [icon setPaths: [NSArray arrayWithObject: path]];	
  [icon select];   
  
  if (col) {
    NSArray *selnames = [NSArray arrayWithObject: [path lastPathComponent]];
    [col selectMatrixCellsWithNames: selnames sendAction: NO];
    [col setLeaf: NO];
    [browserDelegate setSelectedPaths: [NSArray arrayWithObject: path]];		
  }
    
  if (checkSelection) {
    NSArray *fnames = [pathContents allKeys];
    int count = [selection count];
    BOOL removed = NO;
    BOOL lastLoaded = NO;
    int i;
    
    for (i = 0; i < count; i++) {
      NSString *selName = [[selection objectAtIndex: i] lastPathComponent];
  
      if ([fnames containsObject: selName] == NO) {
        [selection removeObjectAtIndex: i];
        removed = YES;
        count--;
        i--;
      }
    }
    
    if (removed) {
      [browser clickOnIcon: icon ofColumn: self];
    }
    
    count = [selection count];
    
    if (count) {
      NSMutableArray *selnames = [NSMutableArray array];

      for (i = 0; i < [selection count]; i++) {
        NSString *sname = [selection objectAtIndex: i];
        [selnames addObject: [sname lastPathComponent]];
      }
      
      [self selectMatrixCellsWithNames: selnames sendAction: NO];

      if (count > 1) {
        lastLoaded = YES;
      } else {
        NSString *selpath = [selection objectAtIndex: 0];
        NSString *type = [browserDelegate typeOfFileAt: selpath];
        
        if ([type isEqual: NSFileTypeDirectory] == NO) {
          lastLoaded = YES; 
        }
      }
      
      if (lastLoaded) {
        NSMutableArray *selnames = [NSMutableArray array];
    
        for (i = 0; i < [selection count]; i++) {
          NSString *sname = [selection objectAtIndex: i];
          [selnames addObject: [sname lastPathComponent]];
        }    
        
        [self selectMatrixCellsWithNames: selnames sendAction: YES];
      }
    }
  }
}

- (void)createPreContents:(NSDictionary *)preContents
{
  [self fillMatrix: preContents];
  [matrix setCellSize: NSMakeSize([scroll contentSize].width, cellsHeight)];  
  [self adjustMatrix];  
  isLoaded = YES;
  [self setLeaf: YES];
}

- (void)fillMatrix:(NSDictionary *)contsDict
{
  NSArray *fnames = [contsDict allKeys];
  int count = [fnames count];
  int i;
    
  if (count == 0) {
		return;
	}

  [self createMatrix];
  
  for (i = 0; i < count; i++) {
    NSString *name = [fnames objectAtIndex: i];
    NSString *fullpath = [path stringByAppendingPathComponent: name];
    NSDictionary *dict = [contsDict objectForKey: name];
    NSString *type = [dict objectForKey: @"NSFileType"];
//    NSString *linkto = [dict objectForKey: @"linkto"];
//    unsigned long size = [[dict objectForKey: @"NSFileSize"] unsignedLongValue];
//    int index = [[dict objectForKey: @"index"] intValue];
    id cell;
    
    if (i != 0) {
		  [matrix insertRow: i];
    } 
    
    cell = [matrix cellAtRow: i column: 0];   
    [cell setLoaded: YES];
    [cell setStringValue: name];
    [cell setLeaf: !([type isEqual: NSFileTypeDirectory])];   
    [cell setEnabled: !([browserDelegate isLockedPath: fullpath])];	
  }
  
  [matrix sortUsingFunction: (int (*)(id, id, void*))compareCellsRemote 
                    context: (void *)nil];	
}

- (void)createMatrix
{
  [self clearMatrix];
  
	matrix = [[Matrix alloc] initInColumn: self withFrame: [self frame]
		                      mode: NSListModeMatrix prototype: cellPrototype
		      					                      numberOfRows: 0 numberOfColumns: 0];
  
	[matrix setIntercellSpacing: NSMakeSize(0, 0)];
  [matrix setCellSize: NSMakeSize([scroll contentSize].width, cellsHeight)];  
	[matrix setAutoscroll: YES];
	[matrix setAllowsEmptySelection: YES];
	[matrix setTarget: self];
	[matrix setAction: @selector(doClick:)];
	[matrix setDoubleAction: @selector(doDoubleClick:)];
	[scroll setDocumentView: matrix];
  
  [matrix addColumn]; 
}

- (void)clearMatrix
{
  if (matrix) {
    [matrix removeFromSuperviewWithoutNeedingDisplay];  
    [scroll setDocumentView: nil];	  
    DESTROY (matrix);
  }
}

- (BOOL)selectMatrixCellsWithNames:(NSArray *)names 
                        sendAction:(BOOL)act
{
  NSArray *cells = [matrix cells];
  NSMutableArray *selarr = [NSMutableArray array];
  int i = 0;
  BOOL found = NO;
  
  [matrix deselectAllCells];
  
	for (i = 0; i < [cells count]; i++) {
	  NSCell *cell = [cells objectAtIndex: i];
    NSString *cellname = [cell stringValue];
    
    if ([names containsObject: cellname]) {
      NSString *cellpath = [path stringByAppendingPathComponent: cellname]; 
        
      [selarr addObject: cellpath];
      [matrix selectCell: cell];
      found = YES;
    } 
	}
  
  DESTROY (selection);
  if (found) {
    selection = [selarr mutableCopy];
  }

  if (visibleCellsNames) {
    if (cells && [cells count]) {
      NSMutableArray *cellsNames = [NSMutableArray arrayWithCapacity: 1];
      int count = [visibleCellsNames count];
      int i;
      
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
        id cell = [self cellWithName: [visibleCellsNames objectAtIndex: 0]];
        [matrix scrollToFirstPositionCell: cell withScrollTune: scrollTune];
      }
    }
    
    DESTROY (visibleCellsNames);
  }      
  
  if (act) {
    [self doClick: nil];
  }
  
  return found;
}

- (BOOL)selectFirstCell
{
  if (matrix && [[matrix cells] count]) {
    [matrix selectCellAtRow: 0 column: 0];
    [self doClick: nil];
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
        [self doClick: nil];
		  	return YES;
			}
	  }
    
		for (i = 0; i < s; i++) {
      cellstr = [[matrix cellAtRow: i column: 0] stringValue];
    
			if (([cellstr length] > 0) && ([cellstr hasPrefix: prefix])) {
        [matrix deselectAllCells];
        [matrix selectCellAtRow: i column: 0];
		  	[matrix scrollCellToVisibleAtRow: i column: 0];
        [self doClick: nil];
		  	return YES;
			}
		}
  }  
  return NO;
}

- (void)selectIcon
{
  [icon select];
}

- (void)selectAll
{
  if (matrix && [[matrix cells] count]) {
    [matrix selectAll: nil];
    [self doClick: nil];
  } else {
    Column *col = [browser columnBeforeColumn: self];
  
    if (col) {
      [col selectAll];
    }
  }
}

- (NSArray *)selection
{
	return selection;
}

- (void)lock
{
	NSArray *cells;
  int i, count;

	if (icon && ([icon isLocked] == NO)) {
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

	if (icon && [icon isLocked]) {
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

- (void)lockCellsWithNames:(NSArray *)names
{
  int i;
  BOOL found = NO;
  
  for (i = 0; i < [names count]; i++) {
    Cell *cell = [self cellWithName: [names objectAtIndex: i]];
    if (cell && [cell isEnabled]) { 
      [cell setEnabled: NO];
      found = YES;
    }
  }
		
  [matrix setNeedsDisplay: found];   
}

- (void)unLockCellsWithNames:(NSArray *)names
{
  int i;
  BOOL found = NO;

  for (i = 0; i < [names count]; i++) {
    Cell *cell = [self cellWithName: [names objectAtIndex: i]];
    if (cell != nil) { 
			if ([cell isEnabled] == NO) {   
				[cell setEnabled: YES];
        found = YES;
			}
    }
  }
		
  [matrix setNeedsDisplay: found];   
}

- (void)adjustMatrix
{
  [matrix setCellSize: NSMakeSize([scroll contentSize].width, cellsHeight)];  
  [matrix sizeToCells];
}

- (void)updateIcon
{
  if (icon) {
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

- (Browser *)browser
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

- (Icon *)myIcon
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
  NSArray *selected = [matrix selectedCells];
  int count = [selected count];
  int i;

  DESTROY (selection);
  selection = [NSMutableArray new];

  for (i = 0; i < count; i++) {    
    NSString *cellname = [[selected objectAtIndex: i] stringValue];  
    NSString *cellpath = [path stringByAppendingPathComponent: cellname]; 

    [selection addObject: cellpath];
  }
  
  [browser clickInMatrixOfColumn: self];
}

- (void)doDoubleClick:(id)sender
{
  [browser doubleClickInMatrixOfColumn: self];
}

- (void)setFrame:(NSRect)frameRect
{
  NSRect r = NSMakeRect(0, 0, frameRect.size.width, frameRect.size.height);

  CHECKRECT (frameRect);
  [super setFrame: frameRect]; 
   
  CHECKRECT (r);
  [scroll setFrame: r];  

  if (icon) {
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
// Icon Delegate Methods
//
@implementation Column (IconDelegateMethods)

- (void)icon:(Icon *)sender setFrameOfLabel:(NSTextField *)label
{
	float icnwidth, labwidth, labxpos, labypos;
  NSRect labRect;
  
	icnwidth = [sender frame].size.width;
 	labwidth = [label frame].size.width;
	labypos = [sender frame].origin.y - 14;

	if(icnwidth > labwidth) {
		labxpos = [sender frame].origin.x + ((icnwidth - labwidth) / 2);
	} else {
		labxpos = [sender frame].origin.x - ((labwidth - icnwidth) / 2);
  }
  
  labRect = NSMakeRect(labxpos, labypos, labwidth, 14);
  CHECKRECT (labRect);
	[label setFrame: labRect];
  [label setNeedsDisplay: YES];
}

- (void)unselectOtherIcons:(Icon *)selicon
{
  NSArray *otherCols = [browser columnsDifferentFromColumn: self];
  int i;
  
  for (i = 0; i < [otherCols count]; i++) {
    Icon *icn = [[otherCols objectAtIndex: i] myIcon];
  
		if ([icn isSelect]) {
			[icn unselect];
		}
  }
}

- (void)unselectNameEditor
{
  [browser unselectNameEditor];
}

- (void)restoreSelectionAfterDndOfIcon:(Icon *)dndicon
{
  [browser restoreSelectionAfterDndOfIcon: dndicon];
}

- (void)clickOnIcon:(Icon *)clicked
{
  [self setLeaf: YES];
  [browser clickOnIcon: icon ofColumn: self];
}

- (void)doubleClickOnIcon:(Icon *)clicked newViewer:(BOOL)isnew
{
  [browser doubleClickOnIcon: clicked ofColumn: self newViewer: isnew];
}

@end


