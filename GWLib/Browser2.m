/* Browser2.m
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
#include "GWLib.h"
#include "GWProtocol.h"
#include "GWFunctions.h"
#include "GWNotifications.h"
#include <math.h>
#include "Browser2.h"
#include "BColumn.h"
#include "BCell.h"
#include "BIcon.h"
#include "BNameEditor.h"

#define NSBR_VOFFSET 4
#define BEZEL_BORDER_SIZE NSMakeSize(2, 2)

#define ICONS_PATH_WIDTH 96
#define ICON_FRAME_HEIGHT 52
#define ICON_SIZE_WIDTH 48
#define ICON_VOFFSET 14
#define LABEL_HEIGHT 14

#define LINE_SCROLL 10
#define LABEL_MARGIN 8
#define EDIT_MARGIN 4

#define CHECKRECT(rct) \
if (rct.size.width < 0) rct.size.width = 0; \
if (rct.size.height < 0) rct.size.height = 0

#define CHECKSIZE(sz) \
if (sz.width < 0) sz.width = 0; \
if (sz.height < 0) sz.height = 0

#ifndef max
#define max(a,b) ((a) >= (b) ? (a):(b))
#endif

#ifndef min
#define min(a,b) ((a) <= (b) ? (a):(b))
#endif

double myrintf(double a)
{
	return (floor(a + 0.5));         
}

@implementation Browser2

- (void)dealloc
{
  RELEASE (columns);
	if (colRects != NULL) {
		NSZoneFree (NSDefaultMallocZone(), colRects);
	}
  RELEASE (cellPrototype);
  RELEASE (scroller);
  RELEASE (pathSeparator);
	RELEASE (basePath);
	RELEASE (nameEditor);
  RELEASE (editorFont);
  TEST_RELEASE (doubleClickSelection);
  TEST_RELEASE (charBuffer);
  [super dealloc];
}

- (id)initWithBasePath:(NSString *)bpath
		  	visibleColumns:(int)vcols 
             styleMask:(int)mask
					  	delegate:(id)anobject
{
  self = [super init];
	
	if (self) {
		NSRect rect = NSMakeRect(0, 0, 600, 200);
  	NSSize bs = BEZEL_BORDER_SIZE;
		int i;

		createEmptySel = @selector(createEmptyColumn);
		createEmpty = [self methodForSelector: createEmptySel];

		addAndLoadSel = @selector(addAndLoadColumnForPaths:);
		addAndLoad = [self methodForSelector: addAndLoadSel];

    unloadFromSel = @selector(unloadFromColumn:);
    unloadFrom = [self methodForSelector: unloadFromSel];
    
		lastColumnSel = @selector(setLastColumn:);
		lastColumn = [self methodForSelector: lastColumnSel];

    setPathsSel = @selector(setCurrentPaths:);
    setPaths = [[BColumn class] instanceMethodForSelector: setPathsSel];
		
		[self setFrame: rect];
		visibleColumns = vcols;
		ASSIGN (basePath, bpath);		    
		delegate = anobject;
    styleMask = mask;		
    canUpdateViews = YES;
    
    colRects = NULL;
  	columnWidth = (rect.size.width / (float)visibleColumns);
		scrollerWidth = [NSScroller scrollerWidth];
		iconsPathWidth = ICONS_PATH_WIDTH - scrollerWidth;
    if (styleMask & GWColumnIconMask) {
      columnOriginY = 0;
    } else {
      columnOriginY = scrollerWidth + (4 * bs.height);
    }

		ASSIGN (pathSeparator, fixPath(@"/", 0));	
    
    if (styleMask & GWIconCellsMask) {
      cellPrototype = [[BCell alloc] initIconCell];
    } else {
      cellPrototype = [[BCell alloc] init];
    }
    
  	columns = [[NSMutableArray alloc] init];
    getSel = @selector(objectAtIndex:);
    getImp = [columns methodForSelector: getSel];		
    indexSel = @selector(indexOfObject:);
    indexImp = (intIMP)[columns methodForSelector: indexSel];		
        
  	scrollerRect.origin.x = bs.width;
    if (styleMask & GWColumnIconMask) {
  	  scrollerRect.origin.y = [self frame].size.height - iconsPathWidth - scrollerWidth;
    } else {
      scrollerRect.origin.y = bs.height;
    }
  	scrollerRect.size.width = [self frame].size.width - (2 * bs.width);
  	scrollerRect.size.height = scrollerWidth;
  	scroller = [[NSScroller alloc] initWithFrame: scrollerRect];
	  [scroller setTarget: self];
	  [scroller setAction: @selector(scrollViaScroller:)];
  	[self addSubview: scroller];

    rect = [self frame];    
    
		for (i = 0; i < visibleColumns; i++) {
      (*createEmpty)(self, createEmptySel);
		}
		
    nameEditor = [[BNameEditor alloc] init];
    [nameEditor setDelegate: self];  
    [nameEditor setTarget: self]; 
    [nameEditor setAction: @selector(editorAction:)];  
    ASSIGN (editorFont, [NSFont systemFontOfSize: 12]); 
		[nameEditor setFont: editorFont];
		[nameEditor setBezeled: NO];
		[nameEditor setAlignment: NSCenterTextAlignment];
	  [nameEditor setBackgroundColor: [NSColor whiteColor]];
    edCol = nil;
    isEditingIconName = NO;
    
  	firstVisibleColumn = 0;
  	lastVisibleColumn = visibleColumns - 1;	
		currentshift = 0;	
  	lastColumnLoaded = -1;
  	alphaNumericalLastColumn = -1;
		
  	skipUpdateScroller = NO;
		lastKeyPressed = 0.;
  	charBuffer = nil;
    doubleClickSelection = nil;
    simulatingDoubleClick = NO;
  	isLoaded = NO;	
  }		
  
  return self;
}

- (void)setPathAndSelection:(NSArray *)selection
{
  NSString *path;
  NSArray	*subStrings;
  NSString *aStr;
  NSString *progrPath;
  unsigned numberOfSubStrings;
  unsigned i;
	int column;
  BColumn *selCol;

  canUpdateViews = NO;
  	
  [self loadColumnZero];

  if (selection == nil || [[selection objectAtIndex: 0] isEqual: basePath]) {
    canUpdateViews = YES;
    [self tile];
		[self setNeedsDisplay: YES];
		return;
	}
	
  if ([selection count] > 1) {
    path = [[selection objectAtIndex: 0] stringByDeletingLastPathComponent];
  } else {
    path = [selection objectAtIndex: 0];
  }
  
	if ([basePath isEqualToString: pathSeparator] == NO) { 
		NSRange range = [path rangeOfString: basePath]; 		 
																												 
		if (range.length == 0) {														 
			ASSIGN (basePath, pathSeparator); 								 
			[self loadColumnZero];		
			subStrings = [path componentsSeparatedByString: pathSeparator];
					
		} else {
			NSString *rpath = [path substringFromIndex: [basePath cStringLength]];
			subStrings = [rpath componentsSeparatedByString: pathSeparator];
		}
		
	} else {
  	subStrings = [path componentsSeparatedByString: pathSeparator];
	}
	
	numberOfSubStrings = [subStrings count];
	
  // Ignore a trailing void component. 
  if (numberOfSubStrings > 0
      			&& [[subStrings objectAtIndex: 0] isEqualToString: @""]) {
		numberOfSubStrings--;
      
		if (numberOfSubStrings) {
	  	NSRange theRange;
				        
	  	theRange.location = 1;
	  	theRange.length = numberOfSubStrings;
	  	subStrings = [subStrings subarrayWithRange: theRange];
		}

		[self loadColumnZero];
	}

  column = lastColumnLoaded;
  if (column < 0) {
    column = 0;
	}
	
  progrPath = [NSString stringWithString: basePath];
  
  for (i = 0; i < numberOfSubStrings; i++) {
		BColumn *bc = (*getImp)(columns, getSel, column + i);
          
		aStr = [subStrings objectAtIndex: i];

		if ([aStr isEqualToString: @""] == NO) {
	  	BOOL found = NO;	

      progrPath = [progrPath stringByAppendingPathComponent: aStr];

      found = [bc selectMatrixCellsWithNames: [NSArray arrayWithObject: aStr]
                                  sendAction: NO];

	  	if (found == NO) {
				NSLog(@"Browser: unable to find cell '%@' in column %d\n", aStr, column + i);
	    	break;
			}

      (*addAndLoad)(self, addAndLoadSel, [NSArray arrayWithObject: progrPath]);
		}
	}

  if ([selection count] > 1) {
		BColumn *bc = (*getImp)(columns, getSel, lastColumnLoaded);
    
  	NSMutableArray *names = [NSMutableArray arrayWithCapacity: 1];
		int i = 0;
    
  	for (i = 0; i < [selection count]; i++) {
    	[names addObject: [[selection objectAtIndex: i] lastPathComponent]];
    }

    [bc selectMatrixCellsWithNames: names sendAction: NO];
    
    (*addAndLoad)(self, addAndLoadSel, selection);
	}

  canUpdateViews = YES;
  [self tile];
  [self setNeedsDisplay: YES];
  
  selCol = [self selectedColumn];
  if (selCol) {
    NSMatrix *matrix = [selCol cmatrix];

    if (matrix) {
      [[self window] makeFirstResponder: matrix];
	  }
  }
}

- (void)loadColumnZero
{
  (*lastColumn)(self, lastColumnSel, -1);
  (*addAndLoad)(self, addAndLoadSel, [NSArray arrayWithObject: basePath]);
  isLoaded = YES;
  [self tile];
}

- (BColumn *)createEmptyColumn
{
  unsigned int style = (styleMask & GWColumnIconMask) 
                            | (styleMask & GWIconCellsMask) 
                                | (styleMask & GWViewsPaksgesMask);

  BColumn *bc = [[BColumn alloc] initInBrowser: self
                                       atIndex: [columns count]	
                                 cellPrototype: cellPrototype
                                     styleMask: style];
  [columns addObject: bc];
  [self addSubview: bc];
  if (styleMask & GWColumnIconMask) {
    [self addSubview: [bc iconView]];
  }  
  RELEASE(bc);
	
  return bc;
}

- (void)addAndLoadColumnForPaths:(NSArray *)cpaths
{
  BColumn *bc;
  int i;
			
  if (lastColumnLoaded + 1 >= [columns count]) {
    i = (*indexImp)(columns, indexSel, (*createEmpty)(self, createEmptySel));
	} else {
    i = lastColumnLoaded + 1;
	}
  
  bc = (*getImp)(columns, getSel, i);
  (*setPaths)(bc, setPathsSel, cpaths);
  (*lastColumn)(self, lastColumnSel, i);
  
  isLoaded = YES;

  [self tile];

  if ((i > 0) && ((i - 1) == lastVisibleColumn)) { 
    [self scrollColumnsRightBy: 1];
	} 
}

- (void)unloadFromColumn:(int)column
{
  BColumn *bc = nil; 
	int i, count;
				
  count = [columns count];
	
  for (i = column; i < count; ++i) {
		bc = (*getImp)(columns, getSel, i);

		if ([bc isLoaded]) {			
	  	[bc setCurrentPaths: nil];
		}
		
		if (i >= visibleColumns) {
	  	[bc removeFromSuperview];
      if (styleMask & GWColumnIconMask) {
        [[bc iconView] removeFromSuperview];
	  	}
            
      [columns removeObject: bc];
			
	  	count--;
	  	i--;
		}
  }
  
  if (column == 0) {
		isLoaded = NO;
	}
  
  // Scrolls if needed.
  if (column <= lastVisibleColumn) {
		[self scrollColumnsLeftBy: lastVisibleColumn - column + 1];
	}
	
  [self updateScroller];
}

- (void)reloadColumnWithPath:(NSString *)cpath
{
  BColumn *col = [self columnWithPath: cpath];
  
  if (col) {
    [col setCurrentPaths: [NSArray arrayWithObject: cpath]];    
  }
}

- (void)reloadFromColumnWithPath:(NSString *)cpath
{
  BColumn *col = [self columnWithPath: cpath];
  
  if (col) {
		int index = [col index];
    int i = 0;
    										        
		for (i = index; i < [columns count]; i++) {
      BColumn *nextcol = (*getImp)(columns, getSel, i);
      NSArray *selection = [self selectionInColumnBeforeColumn: nextcol];

      if (selection) {
        [nextcol setCurrentPaths: selection]; 
                     
      } else {
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
        
        (*lastColumn)(self, lastColumnSel, last);
  
        if (shift) {
          currentshift = 0;
          [self setShift: shift];
        } else if (leftscr) {
          [self scrollColumnsLeftBy: leftscr];
        }
        
        break;
      }
		}
  
    [self tile];
   
    col = [self lastNotEmptyColumn];
    
    if (col) {
      NSArray *selection = [col selection];
      int index = [col index];
      
      if (index < firstVisibleColumn) {
        [self scrollColumnToVisible: index];      
      }
      
      if (selection) {
        BColumn *nextcol = (*getImp)(columns, getSel, ([col index] + 1));
        
        if (styleMask & GWColumnIconMask) {     
          [nextcol updateIcon]; 
          [nextcol selectIcon];
        }
        
        [delegate currentSelectedPaths: selection];	

      } else {
        NSString *currpath = [col currentPath];
      
        if (currpath) {
          [delegate currentSelectedPaths: [NSArray arrayWithObject: currpath]];
          
          if (styleMask & GWColumnIconMask) {	    
            [col selectIcon];
          }
        }
      }
    }
  }
}

- (void)setLastColumn:(int)column
{
  lastColumnLoaded = column;
  (*unloadFrom)(self, unloadFromSel, column + 1);
}

- (void)tile
{
  NSSize bs = BEZEL_BORDER_SIZE;  
  float frameWidth;
  NSRect r;
  int i;
  
  if (canUpdateViews == NO) {
    return;
  }
  		
  r = [self frame];
    
  columnSize.height = r.size.height;
  if (styleMask & GWColumnIconMask) {
    columnOriginY = 0;
  } else {
    columnOriginY = scrollerWidth + (4 * bs.height);
  }
  
  // Horizontal scroller
	scrollerRect.origin.x = bs.width;
  if (styleMask & GWColumnIconMask) {
    scrollerRect.origin.y = r.size.height - iconsPathWidth - scrollerWidth - 1;  
  } else {
    scrollerRect.origin.y = bs.height;
  }
  scrollerRect.size.width = r.size.width - (2 * bs.width);
	scrollerRect.size.height = scrollerWidth;

  if (styleMask & GWColumnIconMask) {
	  columnSize.height -= iconsPathWidth + scrollerWidth + (3 * bs.height) + NSBR_VOFFSET;
  } else {
	  columnSize.height -= scrollerWidth + (3 * bs.height) + NSBR_VOFFSET;
  }
  
  if (!NSEqualRects(scrollerRect, [scroller frame])) {
		CHECKRECT (scrollerRect);
		[scroller setFrame: scrollerRect];
	}  

  // Columns	
  frameWidth = r.size.width - (4.0 + (float)visibleColumns);
  columnSize.width = (int)(frameWidth / (float)visibleColumns);
	CHECKSIZE (columnSize);

  [self makeColumnsRects];
  
  for (i = 0; i < [columns count]; i++) {
		BColumn *bc = (*getImp)(columns, getSel, i);

    if (styleMask & GWColumnIconMask) {
      [[bc iconView] setFrame: NSMakeRect(colRects[i].origin.x, 
                        r.size.height - iconsPathWidth + (2 * bs.width), 
										colRects[i].size.width, iconsPathWidth - (2 * bs.width))];
    }

    [bc setFrame: colRects[i]];
	}
  
  if (styleMask & GWColumnIconMask) {
    [self updateNameEditor];
  }
}

- (void)makeColumnsRects
{
  int count = [columns count];
  int i = 0;
  
 	if (colRects != NULL) {    
		NSZoneFree (NSDefaultMallocZone(), colRects);
	} 
	colRects = NSZoneMalloc (NSDefaultMallocZone(), sizeof(NSRect) * count);		

  for (i = 0; i < count; i++) {
    int n = i - firstVisibleColumn;

    colRects[i] = NSZeroRect;

    colRects[i].size = columnSize;

    if (i < firstVisibleColumn) {
      colRects[i].origin.x = (n * columnSize.width);
    } else {
      if (i == firstVisibleColumn) {
        colRects[i].origin.x = (n * columnSize.width) + 2;
      } else if (i <= lastVisibleColumn) {
        colRects[i].origin.x = (n * columnSize.width) + (n + 2);
      } else {
        colRects[i].origin.x = (n * columnSize.width) + (n + 8);
      }
	  }

    if (i == lastVisibleColumn) {
      colRects[i].size.width = [self bounds].size.width - (colRects[i].origin.x + 2);
	  }

    colRects[i].origin.y = columnOriginY;

    CHECKRECT (colRects[i]);
  }
}

- (void)scrollViaScroller:(NSScroller *)sender
{
  NSScrollerPart hit;
	
  if ([sender class] != [NSScroller class]) {
    return;
  }
	  	
  hit = [sender hitPart];
  
  switch (hit) {
		// Scroll to the left
		case NSScrollerDecrementLine:
		case NSScrollerDecrementPage:        
			[self scrollColumnsLeftBy: 1];
			if (currentshift > 0) {
        (*lastColumn)(self, lastColumnSel, (lastColumnLoaded - currentshift));
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
				
	  		skipUpdateScroller = YES;
	  		[self scrollColumnToVisible: myrintf(f * n) + visibleColumns - 1];
	  		skipUpdateScroller = NO;
				
        (*lastColumn)(self, lastColumnSel, (lastColumnLoaded - currentshift));			
				currentshift = 0;
			}
      break;
      
		// NSScrollerNoPart ???
		default:
			break;
	}
}

- (void)updateScroller
{
  if ((lastColumnLoaded == 0) || (lastColumnLoaded <= (visibleColumns - 1))) {
		[scroller setEnabled: NO];

	} else {
		if (!skipUpdateScroller) {
			float prop = (float)visibleColumns / (float)(lastColumnLoaded + 1);
			float i = lastColumnLoaded - visibleColumns + 1;
			float f = 1 + ((lastVisibleColumn - lastColumnLoaded) / i);
			[scroller setFloatValue: f knobProportion: prop];
		}

		[scroller setEnabled: YES];
	}
  
  [scroller setNeedsDisplay: YES];
}

- (void)scrollColumnsLeftBy:(int)shiftAmount
{	
  // Cannot shift past the zero column
  if ((firstVisibleColumn - shiftAmount) < 0) {
    shiftAmount = firstVisibleColumn;
	}
	
  // No amount to shift then nothing to do
  if (shiftAmount <= 0) {
    return;
	}
		
  // Shift
  firstVisibleColumn = firstVisibleColumn - shiftAmount;
  lastVisibleColumn = lastVisibleColumn - shiftAmount;

  // Update the scroller
  [self updateScroller];

  // Update the scrollviews
  [self tile];
  
  [self setNeedsDisplay: YES];
}

- (void)scrollColumnsRightBy:(int)shiftAmount
{	
  // Cannot shift past the last loaded column
  if ((shiftAmount + lastVisibleColumn) > lastColumnLoaded) {
    shiftAmount = lastColumnLoaded - lastVisibleColumn;
	}
	
  // No amount to shift then nothing to do
  if (shiftAmount <= 0) {
    return;
	}
		
  // Shift
  firstVisibleColumn = firstVisibleColumn + shiftAmount;
  lastVisibleColumn = lastVisibleColumn + shiftAmount;

  // Update the scroller
  [self updateScroller];

  // Update the scrollviews
  [self tile];
}

- (void)scrollColumnToVisible:(int)column
{
  int i;
	
  // If its the last visible column then we are there already
  if (lastVisibleColumn == column) {
    return;
	}
	
  // If there are not enough columns to scroll with
  // then the column must be visible
  if (lastColumnLoaded + 1 <= visibleColumns) {
    return;
	}
		
  i = lastVisibleColumn - column;
  if (i > 0) {
    [self scrollColumnsLeftBy: i];
  } else {
    [self scrollColumnsRightBy: (-i)];
	}
}

- (void)moveLeft:(id)sender
{
	BColumn *selCol;
	int index;
  			
	if (!(selCol = [self selectedColumn])) {
		return;
	}

  index = [selCol index];
  
  if (index > 0) {
    (*lastColumn)(self, lastColumnSel, index);  
    
    [selCol setLeaf: YES];
    if (styleMask & GWColumnIconMask) {
      [selCol selectIcon];
    }
      
    selCol = (*getImp)(columns, getSel, index - 1);
    [delegate currentSelectedPaths: [selCol selection]];	
    [[self window] makeFirstResponder: [selCol cmatrix]];
    
    [nameEditor setBackgroundColor: [NSColor whiteColor]];
    if (styleMask & GWColumnIconMask) {
      [self updateNameEditor];
    }

  }
}

- (void)moveRight:(id)sender
{
	BColumn *selCol = [self selectedColumn];
  			
	if (selCol == nil) {
		selCol = (*getImp)(columns, getSel, 0);
    
    if ([selCol selectFirstCell]) {
      [[self window] makeFirstResponder: [selCol cmatrix]];
    }
	} else {
    NSMatrix *matrix = [selCol cmatrix];
    
    if (matrix) {
      int index = [selCol index];
      
      [matrix sendAction];
      
      if (index < ([columns count] - 1)) {
        selCol = (*getImp)(columns, getSel, index + 1);
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
    			
  for (i = 0; i <= s; i++) {  
    (*createEmpty)(self, createEmptySel);
  }
	
	currentshift = s;  
  (*lastColumn)(self, lastColumnSel, (lastColumnLoaded + s));
  [self scrollColumnsRightBy: s];
  [self tile];
}

- (NSString *)pathToLastColumn
{
  int i;
  
  for (i = 0; i < [columns count]; i++) {
    BColumn *col = (*getImp)(columns, getSel, i);
  
    if ([col isLeaf]) {
      NSString *cpath = [col currentPath];
      BOOL is_dir = NO; 
    
      is_dir = [GWLib existsAndIsDirectoryFileAtPath: cpath];
      
      if (is_dir) {	
        if (([GWLib isPakageAtPath: cpath] == NO) 
                                        || (styleMask & GWViewsPaksgesMask)) {
          return cpath;                  
        } else if (i > 0) {
          return [(*getImp)(columns, getSel, i - 1) currentPath];      
        }        
      } else if (i > 0) {
        return [(*getImp)(columns, getSel, i - 1) currentPath];   
      }
    }
  }
  
  return nil;
}

- (BOOL)isShowingPath:(NSString *)path
{
  return ([self columnWithPath: path] ? YES : NO);
}

- (BColumn *)selectedColumn
{
  int i;
  
  for (i = lastColumnLoaded; i >= 0; i--) {
    BColumn *col = (*getImp)(columns, getSel, i);
    
    if ([col isSelected]) {
      return col;
		}
  }
  
  return nil;
}

- (NSArray *)selectionInColumn:(int)column
{
  return [(*getImp)(columns, getSel, column) selection];
}

- (NSArray *)selectionInColumnBeforeColumn:(BColumn *)col
{
  int index = [col index];
  
  if (index == 0) {
    return [NSArray arrayWithObject: basePath];
  } 
  
  return [(*getImp)(columns, getSel, (index - 1)) selection];
}

- (void)selectCellsWithNames:(NSArray *)names 
            inColumnWithPath:(NSString *)cpath
                  sendAction:(BOOL)act
{
  BColumn *col = [self columnWithPath: cpath];
  
  if (col) {
    [col selectMatrixCellsWithNames: names sendAction: act];
  }
}

- (void)extendSelectionWithDimmedFiles:(NSArray *)dimmFiles 
                    fromColumnWithPath:(NSString *)cpath
{
  BColumn *col = [self columnWithPath: cpath];
  
  if (col) {
    NSArray *selection = [col selection];
    int i = 0;
    
    if (selection) {
      BOOL contained = NO;
      
			for (i = 0; i < [selection count]; i++) {
				NSString *selFile = [[selection objectAtIndex: i] lastPathComponent];

				if ([dimmFiles containsObject: selFile]) {
					contained = YES;
					break;
				}
			}					
      
      if (contained) {            
        for (i = [col index] + 1; i < [columns count]; i++) {
          [(*getImp)(columns, getSel, i) lock];          
		    }
      }
    }
  }
}

- (void)selectAllInLastColumn
{
  BColumn *col = [self lastNotEmptyColumn];

  if (col) {
    [col selectAll];
  }
}

- (void)selectForEditingInLastColumn
{
//  [nameEditor selectText: nil];
}

- (void)unselectNameEditor
{
  [nameEditor setBackgroundColor: [NSColor windowBackgroundColor]];
  
  if ([[self subviews] containsObject: nameEditor]) {
    NSRect r = NSIntersectionRect([self visibleRect], [nameEditor frame]);

    if (NSEqualRects(r, NSZeroRect) == NO) {
      [self setNeedsDisplayInRect: r];
    }
  }
}

- (void)restoreSelectionAfterDndOfIcon:(BIcon *)dndicon
{
  BColumn *col = [self lastLoadedColumn];

  if (col && (styleMask & GWColumnIconMask)) {
    [[col myIcon] select];
  }
  
  [nameEditor setBackgroundColor: [NSColor whiteColor]];
  [self updateNameEditor];
}

- (void)renewLastIcon
{
  BColumn *col = [self lastLoadedColumn];

  if (col && (styleMask & GWColumnIconMask)) {
    BIcon *icon = [col myIcon];
    
    if (icon) {
      [icon renewIcon];
    }
  }
}

- (void)addCellsWithNames:(NSArray *)names 
         inColumnWithPath:(NSString *)cpath
{
  BColumn *col = [self columnWithPath: cpath];
  
  if (col) {
    [col addMatrixCellsWithNames: names];
  }
}

- (void)addDimmedCellsWithNames:(NSArray *)names 
               inColumnWithPath:(NSString *)cpath
{
  BColumn *col = [self columnWithPath: cpath];
  
  if (col) {
    [col addDimmedMatrixCellsWithNames: names];
  }
}

- (void)removeCellsWithNames:(NSArray *)names 
            inColumnWithPath:(NSString *)cpath
{
  BColumn *col = [self columnWithPath: cpath];
  
  if (col) {
    [col removeMatrixCellsWithNames: names];
  }
}            


- (void)lockCellsWithNames:(NSArray *)names 
          inColumnWithPath:(NSString *)cpath
{          
  BColumn *col = [self columnWithPath: cpath];
  
  if (col) {
    [col lockCellsWithNames: names];
  }
}         

- (void)unLockCellsWithNames:(NSArray *)names 
            inColumnWithPath:(NSString *)cpath
                  mustExtend:(BOOL)extend
{
  BColumn *col = [self columnWithPath: cpath];
  int i = 0;
  
  if (col) {
    [col unLockCellsWithNames: names];
    
    if (extend) {
      for (i = [col index] + 1; i < [columns count]; i++) {
        [(*getImp)(columns, getSel, i) unLock];
      }
    }
  }
}

- (int)firstVisibleColumn
{
  return firstVisibleColumn;
}

- (BColumn *)lastLoadedColumn
{
  int i;
  
  for (i = [columns count] - 1; i >= 0; i--) {
    BColumn *col = (*getImp)(columns, getSel, i);
  
    if ([col isLoaded] && [col isLeaf]) {
      return col;        
    }
  }
  
  return nil;
}

- (BColumn *)lastNotEmptyColumn
{
  int i;
  
  for (i = 0; i < [columns count]; i++) {
    BColumn *col = (*getImp)(columns, getSel, i);
  
    if ([col isLeaf]) {
      id matrix = [col cmatrix];
    
      if (matrix && [[matrix cells] count]) {
        return col;        
      } else if (i > 0) {
        return (*getImp)(columns, getSel, i - 1);      
      }
    }
  }
  
  return nil;
}

- (BColumn *)columnWithPath:(NSString *)cpath
{
  int i;
  
  for (i = 0; i < [columns count]; i++) {
    BColumn *col = (*getImp)(columns, getSel, i);
  
    if ([[col currentPath] isEqual: cpath]) {
      return col;
    }
  }
  
  return nil;   
}

- (BColumn *)columnBeforeColumn:(BColumn *)col
{
  int index = [col index];

  if (index > 0) {
    return (*getImp)(columns, getSel, index - 1);  
  }
  
  return nil;
}

- (BColumn *)columnAfterColumn:(BColumn *)col
{
  int index = [col index];

  if (index < ([columns count] - 1)) {
    return (*getImp)(columns, getSel, index + 1);  
  }
  
  return nil;
}

- (NSArray *)columnsDifferentFromColumn:(BColumn *)col
{
  NSMutableArray *arr = [NSMutableArray arrayWithCapacity: 1];
	int i;
	
  for (i = 0; i < [columns count]; i++) {
	  BColumn *bc = (*getImp)(columns, getSel, i);
    
    if (bc != col) {
      [arr addObject: bc];
    }
	}
  
  return arr;
}

- (NSPoint)positionOfLastIcon
{
  BColumn *col = [self lastLoadedColumn];

  if (col && (styleMask & GWColumnIconMask)) {
    NSRect r = [[col iconView] frame];
    NSSize s = [[col myIcon] iconShift];
    
		return NSMakePoint(r.origin.x + s.width, 
                            r.origin.y + s.height + ICON_VOFFSET);
  }
  
  return NSZeroPoint;
}

- (NSPoint)positionForSlidedImage
{
  if ((lastVisibleColumn < [columns count]) && (styleMask & GWColumnIconMask)) {
    BColumn *col = (*getImp)(columns, getSel, lastVisibleColumn);
    NSRect r = [[col iconView] frame];
    NSPoint p = [self positionOfLastIcon];  

    return NSMakePoint(r.origin.x + ((r.size.width - ICON_SIZE_WIDTH) / 2), p.y);    
  }

  return NSZeroPoint;
}

- (BOOL)viewsapps
{
  return (styleMask & GWViewsPaksgesMask);
}

- (void)mouseDown:(NSEvent*)theEvent
{  
  if (simulatingDoubleClick) {
    NSPoint p = [[self window] mouseLocationOutsideOfEventStream];
      
    if ((max(p.x, mousePointX) - min(p.x, mousePointX)) <= 3
            && (max(p.y, mousePointY) - min(p.y, mousePointY)) <= 3) {
      [delegate openSelectedPaths: doubleClickSelection newViewer: NO];
    }
  }
  
  [super mouseDown: theEvent];
}

- (void)doubleClikTimeOut:(id)sender
{
  simulatingDoubleClick = NO;
}

- (void)clickInMatrixOfColumn:(BColumn *)col
{
  int index = [col index];
  int pos = index - firstVisibleColumn + 1;  
  BOOL mustshift = (firstVisibleColumn > 0) ? YES : NO;
  NSArray *selection = [col selection];

  if ((selection == nil) || ([selection count] == 0)) {
    [self clickOnIcon: [col myIcon] ofColumn: col];
    return;
  }
				
  if ((pos == visibleColumns) && (index == ([columns count] -1))) {
    NSTimer *timer;
    NSPoint p;

    p = [[self window] mouseLocationOutsideOfEventStream];
    mousePointX = p.x;
    mousePointY = p.y;
    ASSIGN (doubleClickSelection, selection);
    simulatingDoubleClick = YES;

    timer = [NSTimer scheduledTimerWithTimeInterval: 0.3
												target: self selector: @selector(doubleClikTimeOut:) 
																					          userInfo: nil repeats: NO];
  }

	[delegate currentSelectedPaths: selection];		

  currentshift = 0;
  canUpdateViews = NO;
    
  (*lastColumn)(self, lastColumnSel, index);
  (*addAndLoad)(self, addAndLoadSel, selection);	
  		
  if ((mustshift == YES) && (pos < (visibleColumns - 1))) {
		[self setShift: visibleColumns - pos - 1];
	}
  
  canUpdateViews = YES;
  [self tile];
}

- (void)doubleClickInMatrixOfColumn:(BColumn *)col
{
  NSArray *selection = [col selection];
  
  if (selection) {
    [delegate openSelectedPaths: selection newViewer: NO];
  }
}

- (void)clickOnIcon:(BIcon *)icon ofColumn:(BColumn *)col
{ 
  BColumn *column;
      
  if ([icon isSinglePath] == NO) {
    return;
  }
  
  column = [self columnBeforeColumn: col];

  if (column) {
    NSString *name = [icon name];

    if ([column selectMatrixCellsWithNames: [NSArray arrayWithObject: name]
                                sendAction: YES] == NO) {
      (*lastColumn)(self, lastColumnSel, [column index]);   
      [delegate currentSelectedPaths: [NSArray arrayWithObject: [column currentPath]]];
    }
        
  } else {
    (*lastColumn)(self, lastColumnSel, 0);
    [delegate currentSelectedPaths: [NSArray arrayWithObject: basePath]];	
    [self tile];
  }
  
  [nameEditor setBackgroundColor: [NSColor whiteColor]];
  
  [[self window] makeFirstResponder: self];
}

- (void)doubleClickOnIcon:(BIcon *)icon 
                 ofColumn:(BColumn *)col 
                newViewer:(BOOL)isnew
{
  [delegate openSelectedPaths: [icon paths] newViewer: isnew];
}

- (void)updateNameEditor
{
  BColumn *col = [self lastLoadedColumn];
    
  if ([[self subviews] containsObject: nameEditor]) {
    NSRect edr = [nameEditor frame];
    
    [nameEditor abortEditing];
    [nameEditor setName: nil paths: nil index: -1];
    [nameEditor removeFromSuperview];
    [self setNeedsDisplayInRect: edr];
    edCol = nil;
  } 
  
  isEditingIconName = NO;

  if (col && ([col index] <= lastVisibleColumn)) {
    BIcon *icon = [col myIcon];
    NSArray *paths = [icon paths];
    NSString *name = [icon isRootIcon] ? [icon hostname] : [icon name];
    BOOL locked = [icon isLocked];
    BOOL canedit = ((!locked) && (paths && [paths count] == 1) && (![icon isRootIcon]));
    NSRect r = [[col iconView] frame];
    float bw = [self bounds].size.width - EDIT_MARGIN;
    float centerx = r.origin.x + (r.size.width / 2);
    float labwidth = [editorFont widthOfString: name] + LABEL_MARGIN;

    if ((centerx + (labwidth / 2)) >= bw) {
      centerx -= (centerx + (labwidth / 2) - bw);
    } else if ((centerx - (labwidth / 2)) < LABEL_MARGIN) {
      centerx += fabs(centerx - (labwidth / 2)) + LABEL_MARGIN;
    }    

    [[icon label] setFrame: NSMakeRect(centerx, r.origin.y, 1, 1)];
       
    r = NSMakeRect(centerx - (labwidth / 2), r.origin.y, labwidth, LABEL_HEIGHT);
    [nameEditor setFrame: r];
    [nameEditor setName: name paths: paths index: [col index]];
    [nameEditor setBackgroundColor: [NSColor whiteColor]];
    [nameEditor setTextColor: (locked ? [NSColor disabledControlTextColor] 
																			          : [NSColor controlTextColor])];
    [nameEditor setEditable: canedit];
    [nameEditor setSelectable: canedit];	
    [self addSubview: nameEditor];
  } 
}

- (BOOL)isEditingIconName
{
  return isEditingIconName;
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
  static NSRect edr = {{0, 0}, {0, 0}};
  static float crx = 0;
  static float ory = 0;
  static float bw = 0;
  NSString *s;
  float labwidth;
  float labcenter;
  
  if (edCol == nil) {
    edCol = [self lastLoadedColumn]; 
    edr = [[edCol iconView] frame];
    crx = edr.origin.x + (edr.size.width / 2);
    ory = edr.origin.y;
    bw = [self bounds].size.width - EDIT_MARGIN;
  }

  s = [nameEditor stringValue];
  labwidth = [editorFont widthOfString: s] + LABEL_MARGIN;
  
  labcenter = crx;
  
  while ((labcenter + (labwidth / 2)) > bw) {
    labcenter -= EDIT_MARGIN;  
    if (labcenter < EDIT_MARGIN) {
      break;
    }
  }
  
  while ((labcenter - (labwidth / 2)) < EDIT_MARGIN) {
    labcenter += EDIT_MARGIN;  
    if (labcenter >= bw) {
      break;
    }
  }
  
  [self setNeedsDisplayInRect: [nameEditor frame]];
  [nameEditor setFrame: NSMakeRect((labcenter - (labwidth / 2)), ory, labwidth, LABEL_HEIGHT)];
}

- (void)controlTextDidBeginEditing:(NSNotification *)aNotification
{  
  isEditingIconName = YES;
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
  NSString *oldpath = [[nameEditor paths] objectAtIndex: 0];
  NSString *basepath = [oldpath stringByDeletingLastPathComponent];
  NSString *oldname = [nameEditor name];
  NSString *newname = [nameEditor stringValue];
  NSString *newpath = [basepath stringByAppendingPathComponent: newname];
  NSFileManager *fm = [NSFileManager defaultManager];

#define CLEAREDITING \
	[self updateNameEditor]; \
  return
  
  isEditingIconName = NO;
  [nameEditor setAlignment: NSCenterTextAlignment];
  
  if ([fm isWritableFileAtPath: oldpath] == NO) {
    NSRunAlertPanel(NSLocalizedString(@"Error", @""), 
          [NSString stringWithFormat: @"%@\"%@\"!\n", 
              NSLocalizedString(@"You have not write permission\nfor ", @""), 
                      oldpath], NSLocalizedString(@"Continue", @""), nil, nil);   
    CLEAREDITING;
    
  } else if ([fm isWritableFileAtPath: basepath] == NO) {	
    NSRunAlertPanel(NSLocalizedString(@"Error", @""), 
          [NSString stringWithFormat: @"%@\"%@\"!\n", 
              NSLocalizedString(@"You have not write permission\nfor ", @""), 
                      basepath], NSLocalizedString(@"Continue", @""), nil, nil);   
    CLEAREDITING;
    
  } else {  
    NSCharacterSet *notAllowSet = [NSCharacterSet characterSetWithCharactersInString: @"/\\*$|~\'\"`^!?"];
    NSRange range = [newname rangeOfCharacterFromSet: notAllowSet];
    NSArray *dirContents = [fm directoryContentsAtPath: basepath];
    NSMutableDictionary *notifObj = [NSMutableDictionary dictionaryWithCapacity: 1];
    
    if (range.length > 0) {
      NSRunAlertPanel(NSLocalizedString(@"Error", @""), 
                NSLocalizedString(@"Invalid char in name", @""), 
                          NSLocalizedString(@"Continue", @""), nil, nil);   
      CLEAREDITING;
    }	
        
    if ([dirContents containsObject: newname]) {
      if ([newname isEqualToString: oldname]) {
        CLEAREDITING;
      } else {
        NSRunAlertPanel(NSLocalizedString(@"Error", @""), 
          [NSString stringWithFormat: @"%@\"%@\" %@\n", 
              NSLocalizedString(@"The name ", @""), 
              newname, NSLocalizedString(@" is already in use!", @"")], 
                            NSLocalizedString(@"Continue", @""), nil, nil);   
        CLEAREDITING;
      }
    }
    
	  [notifObj setObject: GWorkspaceRenameOperation forKey: @"operation"];	
    [notifObj setObject: oldpath forKey: @"source"];	
    [notifObj setObject: newpath forKey: @"destination"];	
    [notifObj setObject: [NSArray arrayWithObject: @""] forKey: @"files"];	

	  [[NSNotificationCenter defaultCenter]
 				   postNotificationName: GWFileSystemWillChangeNotification
	 								  object: notifObj];

    [fm movePath: oldpath toPath: newpath handler: self];

	  [[NSNotificationCenter defaultCenter]
 				   postNotificationName: GWFileSystemDidChangeNotification
	 								object: notifObj];
  
    [self updateNameEditor];
  }
}

- (void)editorAction:(id)sender
{
}

- (BOOL)fileManager:(NSFileManager *)manager 
              shouldProceedAfterError:(NSDictionary *)errorDict
{
	NSString *title = NSLocalizedString(@"Error", @"");
	NSString *msg1 = NSLocalizedString(@"Cannot rename ", @"");
  NSString *name = [nameEditor name];
	NSString *msg2 = NSLocalizedString(@"Continue", @"");

  NSRunAlertPanel(title, [NSString stringWithFormat: @"%@'%@'!", msg1, name], msg2, nil, nil);   

	return NO;
}

- (void)fileManager:(NSFileManager *)manager willProcessPath:(NSString *)path
{
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (BOOL)becomeFirstResponder
{
	BColumn *selCol;
  NSMatrix *matrix;

  selCol = [self selectedColumn];
  
  if (selCol == nil) {
    matrix = [(*getImp)(columns, getSel, 0) cmatrix];
  } else {
    matrix = [selCol cmatrix];
	}
	
  if (matrix) {
    [[self window] makeFirstResponder: matrix];
	}
	
  return YES;
}

- (void)keyDown:(NSEvent *)theEvent
{
	NSString *characters;
	unichar character;
	BColumn *column;
	NSMatrix *matrix;
	
	if (!(column = [self selectedColumn])) {
		return;
	}
	if (!(matrix = [column cmatrix])) {
		return;
	}
	
	characters = [theEvent characters];
	character = 0;
		
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
	    		[self moveLeft: self];
				}
			}
      return;
	
		case NSRightArrowFunctionKey:
			{
				if ([theEvent modifierFlags] & NSControlKeyMask) {
	      	[super keyDown: theEvent];
	    	} else {
	    		[self moveRight: self];
				}
			}
	  	return;

		case 13:
      [matrix sendDoubleAction];
      return;
	
		case NSTabCharacter:
	  	{
	    	if ([theEvent modifierFlags] & NSShiftKeyMask)
	      	[[self window] selectKeyViewPrecedingView: self];
	    	else
	      	[[self window] selectKeyViewFollowingView: self];
	  	}
			return;
	  	break;
	} 

  if ((character < 0xF700) && ([characters length] > 0)) {														
//		column = [self lastNotEmptyColumn];
		column = [self selectedColumn];

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
  //      [[self window] makeFirstResponder: matrix];
        return;
      }
		}
		
		lastKeyPressed = 0.;			
	}

  [super keyDown: theEvent];
}
                                
- (void)resizeSubviewsWithOldSize:(NSSize)oldSize
{
  [self tile];
}

- (void)drawRect:(NSRect)rect
{
  NSRect r;
	NSSize bs;
  NSPoint p1, p2;
  NSRect browserRect;
  NSRect scrollerBorderRect;
  int i;

  r = [self bounds];
  bs = BEZEL_BORDER_SIZE;
  
  NSRectClip(rect);	
  [[[self window] backgroundColor] set];
  NSRectFill(rect);

  if (!isLoaded) {
		[self loadColumnZero];
	}

  if (styleMask & GWColumnIconMask) {
    scrollerBorderRect = NSMakeRect(scrollerRect.origin.x, 
			          scrollerRect.origin.y, scrollerRect.size.width, 
			              scrollerRect.size.height + iconsPathWidth - 2);
                    
	  scrollerBorderRect.origin.x = 0;
	  scrollerBorderRect.origin.y = scrollerRect.origin.y - 1;
	  scrollerBorderRect.size.width += 2 * bs.width;
	  scrollerBorderRect.size.height += (2 * bs.height);   
                     
  } else {
    scrollerBorderRect = scrollerRect;
	  scrollerBorderRect.origin.x = 0;
	  scrollerBorderRect.origin.y = 1;
	  scrollerBorderRect.size.width += 2 * bs.width;
	  scrollerBorderRect.size.height += (2 * bs.height) - 1;                 
  }  

	if (NSIntersectsRect(scrollerBorderRect, r)) {
		p1 = NSMakePoint(scrollerBorderRect.origin.x + 2,
					 scrollerBorderRect.origin.y + scrollerRect.size.height + 2);
		p2 = NSMakePoint(scrollerBorderRect.origin.x + scrollerBorderRect.size.width - 2, 
					 scrollerBorderRect.origin.y + scrollerRect.size.height + 2);
    
    NSDrawGrayBezel(scrollerBorderRect, r);

    if (styleMask & GWColumnIconMask) {
      [[NSColor blackColor] set];
      [NSBezierPath strokeLineFromPoint: p1 toPoint: p2];
    }
  }

  if (styleMask & GWColumnIconMask) {
    browserRect = NSMakeRect(0, -2, r.size.width, columnSize.height + 4);
  } else {
    browserRect = NSMakeRect(0, columnOriginY - 2, r.size.width, 
                                      r.size.height - columnOriginY + 2);
  }
  NSDrawGrayBezel(browserRect, r);
  
	[[NSColor blackColor] set];
  
  for (i = 1; i < visibleColumns; i++) { 
    p1 = NSMakePoint((columnSize.width * i) + 2 + (i-1), 
                              columnSize.height + columnOriginY);
    p2 = NSMakePoint((columnSize.width * i) + 2 + (i-1), columnOriginY);	
    [NSBezierPath strokeLineFromPoint: p1 toPoint: p2];
  }  
}

@end


















