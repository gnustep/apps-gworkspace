/* Browser.m
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
#include <math.h>
#include "Browser.h"
#include "Column.h"
#include "Cell.h"
#include "Icon.h"
#include "NameEditor.h"
#include "Functions.h"
#include "Notifications.h"
#include "GNUstep.h"

#define NSBR_VOFFSET 4
#define BEZEL_BORDER_SIZE NSMakeSize(2, 2)
#define ICON_FRAME_HEIGHT 52
#define ICON_SIZE_WIDTH 48
#define ICON_VOFFSET 14
#define LINE_SCROLL 10
#define LABEL_HEIGHT 14
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

@implementation Browser

- (void)dealloc
{
  RELEASE (columns);
	if (colRects != NULL) {
		NSZoneFree (NSDefaultMallocZone(), colRects);
	}
  RELEASE (cellPrototype);
  RELEASE (scroller);
  RELEASE (pathSeparator);
  RELEASE (hostName);
	RELEASE (nameEditor);
  RELEASE (editorFont);
  TEST_RELEASE (charBuffer);
  
  [super dealloc];
}

- (id)initWithDelegate:(id)adelegate
         pathSeparator:(NSString *)psep
              hostName:(NSString *)hname
        visibleColumns:(int)vcols 
{
  self = [super init];
	
	if (self) {
		NSRect rect = NSMakeRect(0, 0, 600, 200);
  	NSSize bs = BEZEL_BORDER_SIZE;
		int i;

		delegate = adelegate;
    ASSIGN (hostName, hname);
		ASSIGN (pathSeparator, fixpath(psep, 0));	
    
		[self setFrame: rect];
		visibleColumns = vcols;
    canUpdateViews = YES;
    
    colRects = NULL;
  	columnWidth = (rect.size.width / (float)visibleColumns);
		scrollerWidth = [NSScroller scrollerWidth];
		iconsPathWidth = 96 - scrollerWidth;
    columnOriginY = 0;
    
    cellPrototype = [[Cell alloc] init];
    
  	columns = [[NSMutableArray alloc] init];
        
  	scrollerRect.origin.x = bs.width;
    scrollerRect.origin.y = [self frame].size.height - iconsPathWidth - scrollerWidth;
  	scrollerRect.size.width = [self frame].size.width - (2 * bs.width);
  	scrollerRect.size.height = scrollerWidth;
  	scroller = [[NSScroller alloc] initWithFrame: scrollerRect];
	  [scroller setTarget: self];
	  [scroller setAction: @selector(scrollViaScroller:)];
  	[self addSubview: scroller];

    rect = [self frame];    
    
		for (i = 0; i < visibleColumns; i++) {
      [self createEmptyColumn];
		}
		
    nameEditor = [[NameEditor alloc] init];
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
  	isLoaded = NO;	
  }		
  
  return self;
}

- (id)delegate
{
  return delegate;
}

- (void)setPathAndSelection:(NSArray *)selection
{
  NSString *path;
  NSMutableArray *subStrings;
  NSString *progrPath;
  unsigned numberOfSubStrings;
  unsigned i;
  Column *col;
  
  canUpdateViews = NO;
  	
  [self loadColumnZero];
  	
  if ([selection count] > 1) {
    path = [[selection objectAtIndex: 0] stringByDeletingLastPathComponent];
  } else {
    path = [selection objectAtIndex: 0];
  }
  
  subStrings = [[path componentsSeparatedByString: pathSeparator] mutableCopy];
  [subStrings removeObject: @""];
  numberOfSubStrings = [subStrings count];
	
  progrPath = [NSString stringWithString: pathSeparator];
  
  for (i = 0; i < numberOfSubStrings; i++) {
		NSString *str = [subStrings objectAtIndex: i];
    progrPath = [progrPath stringByAppendingPathComponent: str];
    [self addAndLoadColumnForPaths: [NSArray arrayWithObject: progrPath]];
	}
  
  RELEASE (subStrings);
  
  if ([selection count] > 1) {
    [self addAndLoadColumnForPaths: selection];
	}

  canUpdateViews = YES;
  [self tile];
  [self setNeedsDisplay: YES];
  
  col = [self selectedColumn];
  if (col) {
    NSMatrix *matrix = [col cmatrix];

    if (matrix) {
      [[self window] makeFirstResponder: matrix];
	  }
  }  
}

- (void)loadColumnZero
{
  [self setLastColumn: -1];
  [self addAndLoadColumnForPaths: [NSArray arrayWithObject: pathSeparator]];
  isLoaded = YES;
  [self tile];
}

- (Column *)createEmptyColumn
{
  Column *bc = [[Column alloc] initInBrowser: self
                                     atIndex: [columns count]	
                               cellPrototype: cellPrototype
                                    hostName: hostName];
  [columns addObject: bc];
  [self addSubview: bc];
  [self addSubview: [bc iconView]];
  RELEASE (bc);
	
  return bc;
}

- (void)addAndLoadColumnForPaths:(NSArray *)cpaths
{
  Column *bc;
  int i;
			
  if (lastColumnLoaded + 1 >= [columns count]) {
    i = [columns indexOfObject: [self createEmptyColumn]];
	} else {
    i = lastColumnLoaded + 1;
	}

  bc = [columns objectAtIndex: i];
  
  [bc setCurrentPaths: cpaths];
  [self setLastColumn: i];
  
  isLoaded = YES;

  [self tile];
  
  if ((i > 0) && ((i - 1) == lastVisibleColumn)) { 
    [self scrollColumnsRightBy: 1];
	} 
}

- (void)directoryContents:(NSDictionary *)contents
             readyForPath:(NSString *)path
{
  int i;
  
  for (i = 0; i < [columns count]; i++) {
    Column *bc = [columns objectAtIndex: i];
  
    if ([bc isWaitingContentsForPath: path]) {
      [bc createContents: contents];
      break;
    }
  }
}

- (void)unloadFromColumn:(int)column
{
  Column *bc = nil; 
	int i, count;
				
  count = [columns count];
	
  for (i = column; i < count; ++i) {
		bc = [columns objectAtIndex: i];
    
    [bc setCurrentPaths: nil];
		
		if (i >= visibleColumns) {
	  	[bc removeFromSuperview];
      [[bc iconView] removeFromSuperview];
            
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

- (void)reloadFromColumnWithPath:(NSString *)cpath
{
  Column *col = [self columnWithPath: cpath];
    
  if (col) {
		int index = [col index];
    int i = 0;
 
    for (i = index; i < [columns count]; i++) {
      Column *nextcol = [columns objectAtIndex: i];
      NSString *path = [nextcol currentPath];
      
      if (path) {
        [nextcol setCurrentPaths: [NSArray arrayWithObject: path]];
      }
    }
  }    
}

- (void)reloadLastColumn
{
  NSString *lastpath = [self pathToLastColumn];
  
  if (lastpath) {
    Column *col = [self columnWithPath: lastpath];
    
    [self setLastColumn: [col index]];
    [col setCurrentPaths: [NSArray arrayWithObject: lastpath]];
  } 
}

- (void)lockFromColumnWithPath:(NSString *)cpath
{
  Column *col = [self columnWithPath: cpath];
  
  if (col) {
		int index = [col index];
    int i = 0;
    										        
		for (i = index; i < [columns count]; i++) {
      Column *nextcol = [columns objectAtIndex: i];
      NSArray *selection = [self selectionInColumnBeforeColumn: nextcol];

      if (selection) {
        [nextcol lock]; 
      }
    }
  }
}

- (void)unlockFromColumnWithPath:(NSString *)cpath
{
  Column *col = [self columnWithPath: cpath];
  
  if (col) {
		int index = [col index];
    int i = 0;
    										        
		for (i = index; i < [columns count]; i++) {
      [[columns objectAtIndex: i] lock]; 
    }
  }
}

- (void)lockCellsWithNames:(NSArray *)names 
          inColumnWithPath:(NSString *)cpath
{          
  Column *col = [self columnWithPath: cpath];
  
  if (col) {
    [col lockCellsWithNames: names];
  }
}         

- (void)extendSelectionWithDimmedFiles:(NSArray *)dimmFiles 
                    fromColumnWithPath:(NSString *)cpath
{
  Column *col = [self columnWithPath: cpath];
  
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
          [[columns objectAtIndex: i] lock];          
		    }
      }
    }
  }
}

- (void)setLastColumn:(int)column
{
  lastColumnLoaded = column;
  [self unloadFromColumn: (column + 1)];
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
  columnOriginY = 0;
  
  // Horizontal scroller
	scrollerRect.origin.x = bs.width;
  scrollerRect.origin.y = r.size.height - iconsPathWidth - scrollerWidth - 1;  
  scrollerRect.size.width = r.size.width - (2 * bs.width);
	scrollerRect.size.height = scrollerWidth;

  columnSize.height -= iconsPathWidth + scrollerWidth + (3 * bs.height) + NSBR_VOFFSET;
  
  if (NSEqualRects(scrollerRect, [scroller frame]) == NO) {
		CHECKRECT (scrollerRect);
		[scroller setFrame: scrollerRect];
	}  

  // Columns	
  frameWidth = r.size.width - (4.0 + (float)visibleColumns);
  columnSize.width = (int)(frameWidth / (float)visibleColumns);
	CHECKSIZE (columnSize);

  [self makeColumnsRects];
  
  for (i = 0; i < [columns count]; i++) {
		Column *bc = [columns objectAtIndex: i];
    
    [[bc iconView] setFrame: NSMakeRect(colRects[i].origin.x, 
                      r.size.height - iconsPathWidth + (2 * bs.width), 
									colRects[i].size.width, iconsPathWidth - (2 * bs.width))];

    [bc setFrame: colRects[i]];
	}
  
  [self updateNameEditor];
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
				
	  		skipUpdateScroller = YES;
	  		[self scrollColumnToVisible: myrintf(f * n) + visibleColumns - 1];
	  		skipUpdateScroller = NO;
				
        [self setLastColumn: (lastColumnLoaded - currentshift)];
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
		if (skipUpdateScroller == NO) {
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
	Column *selCol = [self selectedColumn];
	int index;
  			
	if (selCol == nil) {
		return;
	}

  index = [selCol index];
  
  if (index > 0) {
    if ([delegate isLoadingSelection]) {
      [delegate stopLoadSelection];
    }
    
    canUpdateViews = NO;
    [self setLastColumn: index];
    [selCol setLeaf: YES];
    [selCol selectIcon];
    canUpdateViews = YES;
    [self tile];
  
    selCol = [columns objectAtIndex: (index - 1)];
    [delegate setSelectedPaths: [selCol selection]];	
    [[self window] makeFirstResponder: [selCol cmatrix]];
  } 
}

- (void)moveRight:(id)sender
{
	Column *selCol = [self selectedColumn];
  
  if ([delegate isLoadingSelection]) {
    [delegate stopLoadSelection];
  }
			
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
        selCol = [columns objectAtIndex: (index + 1)];
        
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
    [self createEmptyColumn]; 
  }
	
	currentshift = s;  
  [self setLastColumn: (lastColumnLoaded + s)];
  [self scrollColumnsRightBy: s];
  [self tile];
}

- (NSString *)pathToLastColumn
{
  int i;
  
  for (i = 0; i < [columns count]; i++) {
    Column *col = [columns objectAtIndex: i];
    
    if ([col isLeaf]) {
      NSString *cpath = [col currentPath];
      BOOL is_dir = NO; 
    
      is_dir = [delegate existsAndIsDirectoryFileAtPath: cpath];
      if (is_dir) {	
        if (([delegate isPakageAtPath: cpath] == NO)) {
          return cpath;                  
        } else if (i > 0) {
          return [[columns objectAtIndex: (i - 1)] currentPath];
        }        
      } else if (i > 0) {
        return [[columns objectAtIndex: (i - 1)] currentPath];
      }
    }
  }
  
  return nil;
}

- (BOOL)isShowingPath:(NSString *)path
{
  return ([self columnWithPath: path] ? YES : NO);
}

- (Column *)selectedColumn
{
  int i;
  
  for (i = lastColumnLoaded; i >= 0; i--) {
    Column *col = [columns objectAtIndex: i];
    
    if ([col isSelected]) {
      return col;
		}
  }
  
  return nil;
}

- (NSArray *)selectionInColumn:(int)column
{
  return [[columns objectAtIndex: column] selection];
}

- (NSArray *)selectionInColumnBeforeColumn:(Column *)col
{
  int index = [col index];
  
  if (index == 0) {
    return [NSArray arrayWithObject: pathSeparator];
  } 
  
  return [[columns objectAtIndex: (index - 1)] selection];
}

- (void)selectAllInLastColumn
{
  Column *col = [self lastNotEmptyColumn];

  if (col) {
    [col selectAll];
  } 
}

- (void)unselectNameEditor
{
  [nameEditor setBackgroundColor: [NSColor windowBackgroundColor]];
  [self setNeedsDisplayInRect: [nameEditor frame]];
}

- (void)restoreSelectionAfterDndOfIcon:(Icon *)dndicon
{
  Column *col = [self lastLoadedColumn];

  [[col myIcon] select];
  [nameEditor setBackgroundColor: [NSColor whiteColor]];
  [self updateNameEditor];
}

- (void)renewLastIcon
{
  Column *col = [self lastLoadedColumn];
  Icon *icon = [col myIcon];

  if (icon) {
    [icon renewIcon];
  }
}

- (int)firstVisibleColumn
{
  return firstVisibleColumn;
}

- (Column *)lastLoadedColumn
{
  int i;
  
  for (i = [columns count] - 1; i >= 0; i--) {
    Column *col = [columns objectAtIndex: i];
    
    if ([col isLoaded] && [col isLeaf]) {
      return col;        
    }
  }
  
  return nil;
}

- (Column *)lastNotEmptyColumn
{
  int i;
  
  for (i = 0; i < [columns count]; i++) {
    Column *col = [columns objectAtIndex: i];
    
    if ([col isLeaf]) {
      id matrix = [col cmatrix];
    
      if (matrix && [[matrix cells] count]) {
        return col;        
      } else if (i > 0) {
        return [columns objectAtIndex: (i - 1)];     
      }
    }
  }
  
  return nil;
}

- (Column *)columnWithPath:(NSString *)cpath
{
  int i;
  
  for (i = 0; i < [columns count]; i++) {
    Column *col = [columns objectAtIndex: i];
    
    if ([[col currentPath] isEqual: cpath]) {
      return col;
    }
  }
  
  return nil;   
}

- (Column *)columnBeforeColumn:(Column *)col
{
  int index = [col index];

  if (index > 0) {
    return [columns objectAtIndex: (index - 1)];
  }
  
  return nil;
}

- (Column *)columnAfterColumn:(Column *)col
{
  int index = [col index];

  if (index < ([columns count] - 1)) {
    return [columns objectAtIndex: (index + 1)];
  }
  
  return nil;
}

- (NSArray *)columnsDifferentFromColumn:(Column *)col
{
  NSMutableArray *arr = [NSMutableArray arrayWithCapacity: 1];
	int i;
	
  for (i = 0; i < [columns count]; i++) {
	  Column *bc = [columns objectAtIndex: i];
    
    if (bc != col) {
      [arr addObject: bc];
    }
	}
  
  return arr;
}

- (NSPoint)positionOfLastIcon
{
  Column *col = [self lastLoadedColumn];
  NSRect r = [[col iconView] frame];
  NSSize s = [[col myIcon] iconShift];

	return NSMakePoint(r.origin.x + s.width, 
                          r.origin.y + s.height + ICON_VOFFSET);
}

- (NSPoint)positionForSlidedImage
{
  if ((lastVisibleColumn < [columns count])) {
    Column *col = [columns objectAtIndex: lastVisibleColumn];
    
    NSRect r = [[col iconView] frame];
    NSPoint p = [self positionOfLastIcon];  

    return NSMakePoint(r.origin.x + ((r.size.width - ICON_SIZE_WIDTH) / 2), p.y);    
  }

  return NSZeroPoint;
}

- (void)clickInMatrixOfColumn:(Column *)col
{
  int index = [col index];
  int pos = index - firstVisibleColumn + 1;  
  BOOL mustshift = (firstVisibleColumn > 0) ? YES : NO;
  NSArray *selection = [col selection];

  if ([delegate isLoadingSelection]) {
    [delegate stopLoadSelection];
  }
  
  if ((selection == nil) || ([selection count] == 0)) {
    [self clickOnIcon: [col myIcon] ofColumn: col];
    return;
  }
	[delegate setSelectedPaths: selection];		

  currentshift = 0;
  canUpdateViews = NO;
  
  [self setLastColumn: index];
  [self addAndLoadColumnForPaths: selection];
  		      
  if ((mustshift == YES) && (pos < (visibleColumns - 1))) {
		[self setShift: visibleColumns - pos - 1];
	}
  
  canUpdateViews = YES;
  [self tile];
}

- (void)doubleClickInMatrixOfColumn:(Column *)col
{
  NSArray *selection = [col selection];
  
  if (selection) {
    [delegate openSelectedPaths: selection newViewer: NO];
  }
}

- (void)clickOnIcon:(Icon *)icon ofColumn:(Column *)col
{ 
  Column *column;
      
  if ([icon isSinglePath] == NO) {
    return;
  }
    
  column = [self columnBeforeColumn: col];

  if (column) {
    NSString *name = [icon name];

    if ([column selectMatrixCellsWithNames: [NSArray arrayWithObject: name]
                                sendAction: YES] == NO) {
      if ([delegate isLoadingSelection]) {
        [delegate stopLoadSelection];
      }                                
      [self setLastColumn: [column index]];
      [delegate setSelectedPaths: [NSArray arrayWithObject: [column currentPath]]];
    }
        
  } else {
    if ([delegate isLoadingSelection]) {
      [delegate stopLoadSelection];
    }
    [self setLastColumn: 0];
    [delegate setSelectedPaths: [NSArray arrayWithObject: pathSeparator]];	
    [self tile];
  }
  
  [nameEditor setBackgroundColor: [NSColor whiteColor]];
  [[self window] makeFirstResponder: self];
}

- (void)doubleClickOnIcon:(Icon *)icon 
                 ofColumn:(Column *)col 
                newViewer:(BOOL)isnew
{
  [delegate openSelectedPaths: [icon paths] newViewer: isnew];
}

- (void)updateNameEditor
{
  Column *col = [self lastLoadedColumn];
    
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
    Icon *icon = [col myIcon];
    NSArray *paths = [icon paths];
    NSString *name = [icon isRootIcon] ? [icon hostname] : [icon name];
    BOOL locked = [icon isLocked];
    BOOL canedit = ((locked == NO) && (paths && [paths count] == 1) && ([icon isRootIcon] == NO));
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
  NSString *newname = [nameEditor stringValue];
  NSString *newpath = [basepath stringByAppendingPathComponent: newname];

  [self updateNameEditor];

  [delegate renamePath: oldpath toPath: newpath];
}

- (void)editorAction:(id)sender
{
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (BOOL)becomeFirstResponder
{
	Column *selCol;
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

- (void)keyDown:(NSEvent *)theEvent
{
	Column *column;
	NSMatrix *matrix;
	NSString *characters;
	unichar character;
	
  column = [self selectedColumn];
	if (column == nil) {
		return;
	}
  
  matrix = [column cmatrix];
	if (matrix == nil) {
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

  if (isLoaded == NO) {
		[self loadColumnZero];
	}

  scrollerBorderRect = NSMakeRect(scrollerRect.origin.x, 
			        scrollerRect.origin.y, scrollerRect.size.width, 
			            scrollerRect.size.height + iconsPathWidth - 2);

	scrollerBorderRect.origin.x = 0;
	scrollerBorderRect.origin.y = scrollerRect.origin.y - 1;
	scrollerBorderRect.size.width += 2 * bs.width;
	scrollerBorderRect.size.height += (2 * bs.height);   
                     
	if (NSIntersectsRect(scrollerBorderRect, r)) {
		p1 = NSMakePoint(scrollerBorderRect.origin.x + 2,
					 scrollerBorderRect.origin.y + scrollerRect.size.height + 2);
		p2 = NSMakePoint(scrollerBorderRect.origin.x + scrollerBorderRect.size.width - 2, 
					 scrollerBorderRect.origin.y + scrollerRect.size.height + 2);
               
		NSDrawGrayBezel(scrollerBorderRect, r);
    
    [[NSColor blackColor] set];
    [NSBezierPath strokeLineFromPoint: p1 toPoint: p2];
  }

  browserRect = NSMakeRect(0, -2, r.size.width, columnSize.height + 4);
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


















