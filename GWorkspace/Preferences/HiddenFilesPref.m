/* HiddenFilesPref.m
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
  #ifdef GNUSTEP 
#include "GWLib.h"
#include "GWFunctions.h"
#include "GWNotifications.h"
  #else
#include <GWorkspace/GWLib.h>
#include <GWorkspace/GWFunctions.h>
#include <GWorkspace/GWNotifications.h>
  #endif
#include "HiddenFilesPref.h"
#include "GWorkspace.h"
#include "GNUstep.h"

static NSString *nibName = @"HiddenFilesPref";

#define CHECKSIZE(sz) \
if (sz.width < 0) sz.width = 0; \
if (sz.height < 0) sz.height = 0

@implementation HiddenFilesPref

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
  TEST_RELEASE (prefbox);
  RELEASE (currentPath);
  TEST_RELEASE (leftMatrix);
  TEST_RELEASE (rightMatrix); 
  RELEASE (cellPrototipe); 
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
    } else {
      NSArray *selection;
      NSString *path;  
      NSString *defApp;
      NSString *type;
      BOOL isdir;

      RETAIN (prefbox);
      RELEASE (win); 

      gw = [GWorkspace gworkspace];    
		  fm = [NSFileManager defaultManager];
      ws = [NSWorkspace sharedWorkspace];

      selection = [gw selectedPaths];
      path = [selection objectAtIndex: 0];

      if ([selection count] > 1) {
        path = [path stringByDeletingLastPathComponent];     
      } else {
        [fm fileExistsAtPath: path isDirectory: &isdir];    
        if (isdir == NO) {
          path = [path stringByDeletingLastPathComponent];     
        } else if ([GWLib isPakageAtPath: path]) {
          path = [path stringByDeletingLastPathComponent];         
        }
      }

      ASSIGN (currentPath, path);

      [ws getInfoForFile: currentPath application: &defApp type: &type];      
      [iconView setImage: [GWLib iconForFile: currentPath ofType: type]]; 		
      
      cellPrototipe = [NSBrowserCell new];

      [leftScroll setBorderType: NSBezelBorder];
		  [leftScroll setHasHorizontalScroller: NO];
  	  [leftScroll setHasVerticalScroller: YES]; 

		  [rightScroll setBorderType: NSBezelBorder];
      [rightScroll setHasHorizontalScroller: NO];
  	  [rightScroll setHasVerticalScroller: YES]; 

      leftMatrix = nil;
      rightMatrix = nil;	

		  [addButt setImage: [NSImage imageNamed: @"common_ArrowLeftH.tiff"]];
		  [removeButt setImage: [NSImage imageNamed: @"common_ArrowRightH.tiff"]];

		  [setButt setEnabled: NO];

      [[NSNotificationCenter defaultCenter] addObserver: self 
                					  selector: @selector(selectionChanged:) 
                						    name: GWCurrentSelectionChangedNotification
                					    object: nil];
      /* Internationalization */
      [setButt setTitle: NSLocalizedString(@"Activate changes", @"")];
      [loadButt setTitle: NSLocalizedString(@"Load", @"")];
      [hiddenlabel setStringValue: NSLocalizedString(@"Hidden files", @"")];
      [shownlabel setStringValue: NSLocalizedString(@"Shown files", @"")];
      [labelinfo setStringValue: NSLocalizedString(@"Select and move the files to hide or to show", @"")];
    }
  }
  
  return self;
}

- (NSView *)prefView
{
  return prefbox;
}

- (NSString *)prefName
{
  return NSLocalizedString(@"Hidden Files", @"");
}

- (void)selectionChanged:(NSNotification *)n
{
  NSArray *selection;
  NSString *path;  
  NSString *defApp;
  NSString *type;
  BOOL isdir;

  selection = [gw selectedPaths];
  path = [selection objectAtIndex: 0];

  if ([selection count] > 1) {
    path = [path stringByDeletingLastPathComponent];     
  } else {
    [fm fileExistsAtPath: path isDirectory: &isdir];    
    if (isdir == NO) {
      path = [path stringByDeletingLastPathComponent];     
    } else if ([GWLib isPakageAtPath: path]) {
      path = [path stringByDeletingLastPathComponent];         
    }
  }

  ASSIGN (currentPath, path);

  [ws getInfoForFile: currentPath application: &defApp type: &type];      
  [iconView setImage: [GWLib iconForFile: currentPath ofType: type]]; 		

  [pathField setStringValue: [currentPath lastPathComponent]]; 

  [self clearAll];

  [prefbox setNeedsDisplay: YES];
}

- (void)clearAll
{
  NSSize cs, ms;
  
  if (leftMatrix) {
    [leftMatrix removeFromSuperview];  
    [leftScroll setDocumentView: nil];	  
    DESTROY (leftMatrix);
  }
  
  leftMatrix = [[NSMatrix alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)
				            			    mode: NSListModeMatrix prototype: cellPrototipe
			       											          numberOfRows: 0 numberOfColumns: 0];
  [leftMatrix setIntercellSpacing: NSZeroSize];
  [leftMatrix setCellSize: NSMakeSize(130, 14)];
  [leftMatrix setAutoscroll: YES];
	[leftMatrix setAllowsEmptySelection: YES];
  cs = [leftScroll contentSize];
  ms = [leftMatrix cellSize];
  ms.width = cs.width;
  CHECKSIZE (ms);
  [leftMatrix setCellSize: ms];
	[leftScroll setDocumentView: leftMatrix];	

  if (rightMatrix) {
    [rightMatrix removeFromSuperview]; 
    [rightScroll setDocumentView: nil];	  
    DESTROY (rightMatrix);
  }

  rightMatrix = [[NSMatrix alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)
				            			    mode: NSListModeMatrix prototype: cellPrototipe
			       											          numberOfRows: 0 numberOfColumns: 0];
  [rightMatrix setIntercellSpacing: NSZeroSize];
  [rightMatrix setCellSize: NSMakeSize(130, 14)];
  [rightMatrix setAutoscroll: YES];
	[rightMatrix setAllowsEmptySelection: YES];
  cs = [rightScroll contentSize];
  ms = [rightMatrix cellSize];
  ms.width = cs.width;
  CHECKSIZE (ms);
  [rightMatrix setCellSize: ms];
	[rightScroll setDocumentView: rightMatrix];	
  
  [setButt setEnabled: NO];
}

- (IBAction)loadContents:(id)sender
{
  NSArray *files;
  NSMutableArray *hiddenFiles;
	BOOL hideSysFiles;
  NSString *h; 
  int i, count;

  [self clearAll];
	
  files = [fm directoryContentsAtPath: currentPath];

	h = [currentPath stringByAppendingPathComponent: @".hidden"];
  if ([fm fileExistsAtPath: h]) {
	  h = [NSString stringWithContentsOfFile: h];
	  hiddenFiles = [[h componentsSeparatedByString: @"\n"] mutableCopy];
	
    count = [hiddenFiles count];    
    for (i = 0; i < count; i++) {
      NSString *s = [hiddenFiles objectAtIndex: i]; 
    
      if ([s length] == 0) {
        [hiddenFiles removeObject: s];        
        count--;
        i--;
      }
    }
  
  } else {
    hiddenFiles = nil;
  }
	hideSysFiles = [GWLib hideSysFiles];
	
	if (hiddenFiles != nil  ||  hideSysFiles) {	
		NSMutableArray *mutableFiles = AUTORELEASE ([files mutableCopy]);
	
		if (hiddenFiles != nil) {
	    [mutableFiles removeObjectsInArray: hiddenFiles];
	  }
	
		if (hideSysFiles) {
	    int j = [mutableFiles count] - 1;
	    
	    while (j >= 0) {
				NSString *file = (NSString *)[mutableFiles objectAtIndex: j];

				if ([file hasPrefix: @"."]) {
		    	[mutableFiles removeObjectAtIndex: j];
		  	}
				j--;
			}
	  }
		
		files = mutableFiles;
	}

  count = [files count];
  if (count == 0) {
    TEST_RELEASE (hiddenFiles);
		return;
	}  
  
  [rightMatrix addColumn];   
  for (i = 0; i < count; ++i) {
    id cell;
		
    if (i != 0) {
		  [rightMatrix insertRow: i];
    }     
    cell = [rightMatrix cellAtRow: i column: 0];   
    [cell setStringValue: [files objectAtIndex: i]];
    [cell setLeaf: YES];
  }  
  [rightMatrix sizeToCells]; 

  if (hiddenFiles != nil) {
    count = [hiddenFiles count];
    if (count == 0) {
      TEST_RELEASE (hiddenFiles);
		  return;
	  }  

    [leftMatrix addColumn];   
    for (i = 0; i < count; ++i) {
      id cell;

      if (i != 0) {
		    [leftMatrix insertRow: i];
      }     
      cell = [leftMatrix cellAtRow: i column: 0];   
      [cell setStringValue: [hiddenFiles objectAtIndex: i]];
      [cell setLeaf: YES];
    }  
    [leftMatrix sizeToCells]; 
  }
  
  TEST_RELEASE (hiddenFiles);
}

- (IBAction)moveToHidden:(id)sender
{
  NSArray *cells = [rightMatrix selectedCells];

  if (cells) {
    NSMutableArray *names = [NSMutableArray arrayWithCapacity: 1];
    int i;
    
    for (i = 0; i < [cells count]; i++) {
      NSString *name = [[cells objectAtIndex: i] stringValue];  
      [names addObject: name];
    }
    
    [self removeCellsWithNames: names inMatrix: rightMatrix];
    [self addCellsWithNames: names inMatrix: leftMatrix];    
    
    [setButt setEnabled: YES];
  }
}

- (IBAction)moveToShown:(id)sender
{
  NSArray *cells = [leftMatrix selectedCells];

  if (cells) {
    NSMutableArray *names = [NSMutableArray arrayWithCapacity: 1];
    int i;
    
    for (i = 0; i < [cells count]; i++) {
      NSString *name = [[cells objectAtIndex: i] stringValue];  
      [names addObject: name];
    }
    
    [self removeCellsWithNames: names inMatrix: leftMatrix];
    [self addCellsWithNames: names inMatrix: rightMatrix];  
    
    [setButt setEnabled: YES];  
  }
}

- (IBAction)activateChanges:(id)sender
{
  if ([fm isWritableFileAtPath: currentPath] == NO) {
    NSString *message = @"You have not write access to ";
    message = [message stringByAppendingString: [currentPath lastPathComponent]]; 
    
    NSRunAlertPanel(NSLocalizedString(@"error", @""), 
                        NSLocalizedString(message, @""), 
												NSLocalizedString(@"Continue", @""), 
                        nil, nil);
    return;
  } else {
    NSArray *cells = [leftMatrix cells];
    
    if (cells) {	
      NSMutableArray *names;
      NSString *hconts;
      NSString *h;		
      int i;
     
      names = [NSMutableArray arrayWithCapacity: 1];    
      for (i = 0; i < [cells count]; i++) {
        id cell = [cells objectAtIndex: i];      
        [names addObject: [cell stringValue]];
      }
      
      hconts = [names componentsJoinedByString: @"\n"];      
      h = [currentPath stringByAppendingPathComponent: @".hidden"];
      [hconts writeToFile: h atomically: YES];
      
      [setButt setEnabled: NO];
    }
  }
}

- (void)addCellsWithNames:(NSArray *)names inMatrix:(NSMatrix *)matrix
{
	id cell;
  NSSize cs, ms;  
  int i;
		
  [matrix setIntercellSpacing: NSMakeSize(0, 0)];
	  
  for (i = 0; i < [names count]; i++) {
    [matrix addRow];
    cell = [matrix cellAtRow: [[matrix cells] count] -1 column: 0];
    [cell setStringValue: [names objectAtIndex: i]];
		[cell setLeaf: YES];
  }
  	
  if (matrix == leftMatrix) {
    cs = [leftScroll contentSize];
  } else {
    cs = [rightScroll contentSize];
  }
  ms = [matrix cellSize];
  ms.width = cs.width;
  CHECKSIZE (ms);
  [matrix setCellSize: ms];
  [matrix sizeToCells];  

  [self selectCellsWithNames: names inMatrix: matrix];

  [matrix setNeedsDisplay: YES]; 
}

- (void)removeCellsWithNames:(NSArray *)names inMatrix:(NSMatrix *)matrix
{
	id cell;
  int i;
	
  for (i = 0; i < [names count]; i++) {
    cell = [self cellWithTitle: [names objectAtIndex: i] inMatrix: matrix];

    if (cell != nil) {    
			int row, col;
			
      [matrix getRow: &row column: &col ofCell: cell];  
      [matrix removeRow: row];    			
    }
  }

  [matrix sizeToCells];
  [matrix setNeedsDisplay: YES];   
}

- (void)selectCellsWithNames:(NSArray *)names inMatrix:(NSMatrix *)matrix
{
  int i, count, max;
  int *selectedIndexes = NULL;		
	NSMutableArray *cells;		

  cells = [NSMutableArray arrayWithCapacity: 1];
  for (i = 0; i < [names count]; i++) {
    NSString *name = [names objectAtIndex: i];
    id cell = [self cellWithTitle: name inMatrix: matrix];
    
    if (cell) {
      [cells addObject: cell];
    }
  }
  
  count = [cells count];
	max = [matrix numberOfRows];
	selectedIndexes = NSZoneMalloc(NSDefaultMallocZone(), sizeof(int) * count);

	for (i = 0; i < count; i++) {
	  NSCell *cell;
	  int sRow, sColumn;
		
		cell = [cells objectAtIndex: i];
	  [matrix getRow: &sRow column: &sColumn ofCell: cell];
	  selectedIndexes[i] = sRow;
	}
  
	for (i = 0; i < count; i++) {
	  if (selectedIndexes[i] > max) {
	    break;
	  }
	  [matrix selectCellAtRow: selectedIndexes[i] column: 0];
	}

	NSZoneFree(NSDefaultMallocZone(), selectedIndexes);
}

- (id)cellWithTitle:(NSString *)title inMatrix:(NSMatrix *)matrix
{
  NSArray *cells;
  id cell;
  int i;
  
  cells = [matrix cells]; 
  if (cells) {
	  for (i = 0; i < [cells count]; i++) {
      cell = [cells objectAtIndex: i];                  
		  if ([[cell stringValue] isEqualToString: title]) {    
        return cell;
      }
    }
  }
  
  return nil;
}

@end
