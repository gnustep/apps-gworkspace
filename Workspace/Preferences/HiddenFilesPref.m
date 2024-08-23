/* HiddenFilesPref.m
 *  
 * Copyright (C) 2003-2016 Free Software Foundation, Inc.
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */


#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <GNUstepBase/GNUstep.h>

#import "FSNodeRep.h"
#import "FSNFunctions.h"
#import "HiddenFilesPref.h"
#import "GWorkspace.h"


static NSString *nibName = @"HiddenFilesPref";

#define ICON_SIZE 48
#define LINEH 20

#define CHECKSIZE(sz) \
if (sz.width < 0) sz.width = 0; \
if (sz.height < 0) sz.height = 0

@implementation HiddenFilesPref

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  RELEASE (prefbox);
  RELEASE (currentNode);
  RELEASE (hiddenPaths);
  RELEASE (leftMatrix);
  RELEASE (rightMatrix); 
  RELEASE (dirsMatrix); 
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
      NSArray *hpaths;
      NSArray *selection;
      FSNode *node;
      NSImage *icon;
      
      RETAIN (prefbox);
      RELEASE (win); 

      gw = [GWorkspace gworkspace];    
		  fm = [NSFileManager defaultManager];
      ws = [NSWorkspace sharedWorkspace];

      selection = [gw selectedPaths];
      node = [FSNode nodeWithPath: [selection objectAtIndex: 0]];

      if ([selection count] > 1) {
        node = [FSNode nodeWithPath: [node parentPath]];
      } else {
        if ([node isDirectory] == NO) {
          node = [FSNode nodeWithPath: [node parentPath]];
        } else if ([node isPackage]) {
          node = [FSNode nodeWithPath: [node parentPath]];
        }
      }

      ASSIGN (currentNode, node);

      icon = [[FSNodeRep sharedInstance] iconOfSize: ICON_SIZE 
                                            forNode: currentNode];
      [iconView setImage: icon]; 		
      
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
                						    name: @"GWCurrentSelectionChangedNotification"
                					    object: nil];
                              
      [hiddenDirsScroll setBorderType: NSBezelBorder];
		  [hiddenDirsScroll setHasHorizontalScroller: NO];
  	  [hiddenDirsScroll setHasVerticalScroller: YES]; 
                    
      hiddenPaths = [NSMutableArray new];
      hpaths = [[FSNodeRep sharedInstance] hiddenPaths];
      
      if ([hpaths count]) { 
        NSSize cs, ms;
        NSUInteger i;
       
        [hiddenPaths addObjectsFromArray: hpaths];
        
        dirsMatrix = [[NSMatrix alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)
				            			        mode: NSListModeMatrix prototype: cellPrototipe
			       											              numberOfRows: 0 numberOfColumns: 0];
        [dirsMatrix setIntercellSpacing: NSZeroSize];
        [dirsMatrix setCellSize: NSMakeSize(130, LINEH)];
        [dirsMatrix setAutoscroll: YES];
	      [dirsMatrix setAllowsEmptySelection: YES];
        cs = [hiddenDirsScroll contentSize];
        ms = [dirsMatrix cellSize];
        ms.width = cs.width;
        CHECKSIZE (ms);
        [dirsMatrix setCellSize: ms];
	      [hiddenDirsScroll setDocumentView: dirsMatrix];	
        
        [dirsMatrix addColumn];   
        for (i = 0; i < [hiddenPaths count]; ++i) {
          id cell;

          if (i != 0) {
		        [dirsMatrix insertRow: i];
          }     
          cell = [dirsMatrix cellAtRow: i column: 0];   
          [cell setStringValue: [hiddenPaths objectAtIndex: i]];
          [cell setLeaf: YES];
        }  
        [dirsMatrix sizeToCells]; 
      } else {
        dirsMatrix = nil;
      }     
      
      [setDirButt setEnabled: NO];
                                                            
      /* Internationalization */
      {
        NSInteger tabindex;
        NSTabViewItem *item;
        
        tabindex = [tabView indexOfTabViewItemWithIdentifier: @"Files"];
        item = [tabView tabViewItemAtIndex: tabindex];
        [item setLabel: NSLocalizedString(@"Files", @"")];

        tabindex = [tabView indexOfTabViewItemWithIdentifier: @"Folders"];
        item = [tabView tabViewItemAtIndex: tabindex];
        [item setLabel: NSLocalizedString(@"Folders", @"")];

        [setButt setTitle: NSLocalizedString(@"Activate changes", @"")];
        [loadButt setTitle: NSLocalizedString(@"Load", @"")];
        [hiddenlabel setStringValue: NSLocalizedString(@"Hidden files", @"")];
        [shownlabel setStringValue: NSLocalizedString(@"Shown files", @"")];
        [labelinfo setStringValue: NSLocalizedString(@"Select and move the files to hide or to show", @"")];
        [hiddenDirslabel setStringValue: NSLocalizedString(@"Hidden directories", @"")];
        [addDirButt setTitle: NSLocalizedString(@"Add", @"")];
        [removeDirButt setTitle: NSLocalizedString(@"Remove", @"")];
        [setDirButt setTitle: NSLocalizedString(@"Activate changes", @"")];
      }
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
  FSNode *node;
  NSImage *icon;

  selection = [gw selectedPaths];
  node = [FSNode nodeWithPath: [selection objectAtIndex: 0]];

  if ([selection count] > 1) {
    node = [FSNode nodeWithPath: [node parentPath]];
  } else {
    if ([node isDirectory] == NO) {
      node = [FSNode nodeWithPath: [node parentPath]];
    } else if ([node isPackage]) {
      node = [FSNode nodeWithPath: [node parentPath]];
    }
  }

  ASSIGN (currentNode, node);

  icon = [[FSNodeRep sharedInstance] iconOfSize: ICON_SIZE 
                                            forNode: currentNode];
  [iconView setImage: icon]; 		

  [pathField setStringValue: [currentNode name]]; 

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
  [leftMatrix setCellSize: NSMakeSize(130, LINEH)];
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
  [rightMatrix setCellSize: NSMakeSize(130, LINEH)];
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
  NSArray *subNodes;
  NSMutableArray *hiddenFiles;
  BOOL hideSysFiles;
  NSString *h; 
  NSUInteger i, count;

  [self clearAll];
	
  subNodes = [currentNode subNodes];

  h = [[currentNode path] stringByAppendingPathComponent: @".hidden"];
  
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
	hideSysFiles = [[FSNodeRep sharedInstance] hideSysFiles];
	
	if (hiddenFiles != nil  ||  hideSysFiles) {	
		NSMutableArray *mutableNodes = AUTORELEASE ([subNodes mutableCopy]);
    
    if (hiddenFiles) {
      NSUInteger count = [mutableNodes count];
      
      for (i = 0; i < count; i++) {
        FSNode *node = [mutableNodes objectAtIndex: i];
        
        if ([hiddenFiles containsObject: [node name]]) {
          [mutableNodes removeObject: node];
          count--;
          i--;
        }
      }
    }
    
    if (hideSysFiles) {
	    int j = [mutableNodes count] - 1;
	    
	    while (j >= 0) {
				NSString *file = [(FSNode *)[mutableNodes objectAtIndex: j] name];

				if ([file hasPrefix: @"."]) {
		    	[mutableNodes removeObjectAtIndex: j];
		  	}
				j--;
			}
	  }
		
		subNodes = mutableNodes;
	}

  count = [subNodes count];
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
    [cell setStringValue: [(FSNode *)[subNodes objectAtIndex: i] name]];
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
    NSUInteger i;
    
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
    NSUInteger i;
    
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
  if ([currentNode isWritable] == NO)
    {
      NSString *message = NSLocalizedString(@"You have not write permission\nfor","");
      message = [message stringByAppendingString: [currentNode name]]; 
      
      NSRunAlertPanel(NSLocalizedString(@"Error", @""), 
                      message, 
                      NSLocalizedString(@"Continue", @""), 
                      nil, nil);
      return;
    }
  else {
    NSString *base = [currentNode path];
    NSMutableArray *paths = [NSMutableArray array];
    NSArray *cells = [leftMatrix cells];
    
    if (cells) {	
      NSMutableArray *names;
      NSString *hconts;
      NSString *h;		
      NSUInteger i;
     
      names = [NSMutableArray arrayWithCapacity: 1];    
      for (i = 0; i < [cells count]; i++) {
        id cell = [cells objectAtIndex: i]; 
        NSString *name = [cell stringValue];
        
        [names addObject: name];
        [paths addObject: [base stringByAppendingPathComponent: name]];
      }
      
      hconts = [names componentsJoinedByString: @"\n"];      
      h = [[currentNode path] stringByAppendingPathComponent: @".hidden"];
      [hconts writeToFile: h atomically: YES];
      [gw hiddenFilesDidChange: paths];
      [setButt setEnabled: NO];
    }
  }
}

- (IBAction)addDir:(id)sender
{
  NSOpenPanel *openPanel;
  NSString *hidePath;
  NSInteger result;
  
  openPanel = [NSOpenPanel openPanel];
  [openPanel setTitle: _(@"Hide")];	
  [openPanel setAllowsMultipleSelection: NO];
  [openPanel setCanChooseFiles: NO];
  [openPanel setCanChooseDirectories: YES];

  result = [openPanel runModalForDirectory: path_separator() 
                                      file: nil 
                                     types: nil];
  if(result != NSOKButton)
    return;
  
  hidePath = [NSString stringWithString: [openPanel filename]];

  if ([hiddenPaths containsObject: hidePath] == NO) {
    NSSize cs, ms;
    NSUInteger i;
        
    [hiddenPaths addObject: hidePath];

    if (dirsMatrix) {
      [dirsMatrix removeFromSuperview];  
      [hiddenDirsScroll setDocumentView: nil];	  
      DESTROY (dirsMatrix);
    }

    dirsMatrix = [[NSMatrix alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)
				            			    mode: NSListModeMatrix prototype: cellPrototipe
			       											          numberOfRows: 0 numberOfColumns: 0];
    [dirsMatrix setIntercellSpacing: NSZeroSize];
    [dirsMatrix setCellSize: NSMakeSize(130, LINEH)];
    [dirsMatrix setAutoscroll: YES];
    [dirsMatrix setAllowsEmptySelection: YES];
    cs = [hiddenDirsScroll contentSize];
    ms = [dirsMatrix cellSize];
    ms.width = cs.width;
    CHECKSIZE (ms);
    [dirsMatrix setCellSize: ms];
	  [hiddenDirsScroll setDocumentView: dirsMatrix];	

    [dirsMatrix addColumn];   
    for (i = 0; i < [hiddenPaths count]; ++i) {
      id cell;

      if (i != 0) {
		    [dirsMatrix insertRow: i];
      }     
      cell = [dirsMatrix cellAtRow: i column: 0];   
      [cell setStringValue: [hiddenPaths objectAtIndex: i]];
      [cell setLeaf: YES];
    }  
    [dirsMatrix sizeToCells]; 
    
    [setDirButt setEnabled: YES];
  }
}

- (IBAction)removeDir:(id)sender
{
  NSArray *cells = [dirsMatrix selectedCells];

  if (cells) {
    NSMutableArray *paths = [NSMutableArray arrayWithCapacity: 1];
    NSUInteger i;
    
    for (i = 0; i < [cells count]; i++) {
      NSString *path = [[cells objectAtIndex: i] stringValue];  
      [hiddenPaths removeObject: path];
      [paths addObject: path];
    }
    
    [self removeCellsWithNames: paths inMatrix: dirsMatrix];
    [setDirButt setEnabled: YES];
  }
}

- (IBAction)activateDirChanges:(id)sender
{
  [[FSNodeRep sharedInstance] setHiddenPaths: hiddenPaths];
  [gw hiddenFilesDidChange: hiddenPaths];
  [setDirButt setEnabled: NO];
}

- (void)addCellsWithNames:(NSArray *)names inMatrix:(NSMatrix *)matrix
{
  id cell;
  NSSize cs, ms;  
  NSUInteger i;
		
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
  NSUInteger i;
	
  for (i = 0; i < [names count]; i++) {
    cell = [self cellWithTitle: [names objectAtIndex: i] inMatrix: matrix];

    if (cell != nil) {    
      NSInteger row, col;
			
      [matrix getRow: &row column: &col ofCell: cell];  
      [matrix removeRow: row];    			
    }
  }

  [matrix sizeToCells];
  [matrix setNeedsDisplay: YES];   
}

- (void)selectCellsWithNames:(NSArray *)names inMatrix:(NSMatrix *)matrix
{
  NSUInteger i, count;
  NSInteger max;
  NSInteger *selectedIndexes = NULL;
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
  selectedIndexes = NSZoneMalloc(NSDefaultMallocZone(), sizeof(NSInteger) * count);

  for (i = 0; i < count; i++) {
    NSCell *cell;
    NSInteger sRow, sColumn;
		
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
  NSUInteger i;
  
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
