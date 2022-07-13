/* FSNBrowserMatrix.m
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

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <GNUstepBase/GNUstep.h>
#import "FSNBrowserMatrix.h"
#import "FSNBrowserCell.h"
#import "FSNBrowserColumn.h"
#import "FSNIcon.h"
#import "FSNFunctions.h"

#define DOUBLE_CLICK_LIMIT  300
#define EDIT_CLICK_LIMIT   1000

@implementation FSNBrowserMatrix

- (void)dealloc
{
  [super dealloc];
}

- (id)initInColumn:(FSNBrowserColumn *)col
         withFrame:(NSRect)frameRect 
              mode:(NSMatrixMode)aMode
         prototype:(FSNBrowserCell *)aCell 
      numberOfRows:(NSInteger)numRows
   numberOfColumns:(NSInteger)numColumns
         acceptDnd:(BOOL)dnd
{
  self = [super initWithFrame: frameRect mode: aMode prototype: aCell
		 numberOfRows: numRows numberOfColumns: numColumns];

  if (self)
    {
      column = col;
      mouseFlags = 0;
      dndTarget = nil;
      acceptDnd = dnd;
      if (acceptDnd)
	{
	  [self registerForDraggedTypes: [NSArray arrayWithObjects:
						    NSFilenamesPboardType,
						  @"GWLSFolderPboardType",
						  @"GWRemoteFilenamesPboardType",
						  nil]];
	}
      editstamp = 0.0;
      editIndex = -1;
    }
  
  return self;
}

- (void)visibleCellsNodes:(NSArray **)nodes
          scrollTuneSpace:(float *)tspace
{
  NSArray *cells = [self cells];

  if (cells && [cells count]) {
    NSRect vr = [self visibleRect];
    float ylim = vr.origin.y + vr.size.height - [self cellSize].height;
    NSMutableArray *vnodes = [NSMutableArray array];
    BOOL found = NO;
    NSUInteger i;
 
    for (i = 0; i < [cells count]; i++) {
      NSRect cr = [self cellFrameAtRow: i column: 0];

      if ((cr.origin.y >= vr.origin.y) && (cr.origin.y <= ylim)) {
        if (found == NO) {
          *tspace = cr.origin.y - vr.origin.y;
          found = YES;
        }        
        [vnodes addObject: [[cells objectAtIndex: i] node]];
      }
    }
    
    if ([vnodes count]) {
      *nodes = vnodes;
    }
  }
}

- (void)scrollToFirstPositionCell:(id)aCell withScrollTune:(float)vtune
{
  NSRect vr, cr;
  NSInteger row, col;
  
  vr = [self visibleRect];
  
  [self getRow: &row column: &col ofCell: aCell];
  cr = [self cellFrameAtRow: row column: col];
  cr.size.height = vr.size.height - vtune;
    
  [self scrollRectToVisible: cr];
} 

- (void)selectIconOfCell:(id)aCell
{
  FSNBrowserCell *cell = (FSNBrowserCell *)aCell;
  
  if ([cell selectIcon]) {
    NSRect cellFrame;
    NSInteger row, col;
  
    [self getRow: &row column: &col ofCell: aCell];
    cellFrame = [self cellFrameAtRow: row column: col];
    [self setNeedsDisplayInRect: cellFrame];
  }
  
  [self unSelectIconsOfCellsDifferentFrom: cell];
}

- (void)unSelectIconsOfCellsDifferentFrom:(id)aCell
{
  NSArray *cells = [self cells];
  NSUInteger i = 0;

  for (i = 0; i < [cells count]; i++) {
    FSNBrowserCell *c = [cells objectAtIndex: i];  
  
    if (c != aCell) {
      if ([c unselectIcon]) {
        NSRect cellFrame;
        NSInteger row, col;
  
        [self getRow: &row column: &col ofCell: c];
        cellFrame = [self cellFrameAtRow: row column: col];
        [self setNeedsDisplayInRect: cellFrame];
      }
    }
  }
}

- (NSUInteger)mouseFlags
{
  return mouseFlags;
}

- (void)setMouseFlags:(NSUInteger)flags
{
  mouseFlags = flags;
}

- (void)mouseDown:(NSEvent*)theEvent
{
  int clickCount;
  NSPoint lastLocation;
  NSInteger row, col;

  mouseFlags = [theEvent modifierFlags];
  
  if (acceptDnd == NO)
    {
      [super mouseDown: theEvent];
      return;
    }

  if (([self numberOfRows] == 0) || ([self numberOfColumns] == 0))
    {
      [super mouseDown: theEvent];
      return;
    }

  [column stopCellEditing];
    
  clickCount = [theEvent clickCount];

  if (clickCount >= 2)
    {
      editIndex = -1;
      [self sendDoubleAction];
      return;
    }

  lastLocation = [theEvent locationInWindow];
  lastLocation = [self convertPoint: lastLocation
			   fromView: nil];

  if ([self getRow: &row column: &col forPoint: lastLocation])
    {
      FSNBrowserCell *cell = [[self cells] objectAtIndex: row];
      NSRect rect = [self cellFrameAtRow: row column: col];
      
      if ([cell isEnabled])
	{
	  int sz = [cell iconSize];
	  NSSize size = NSMakeSize(sz, sz);

	  rect.size.width = size.width;
	  rect.size.height = size.height;

	  if (NSPointInRect(lastLocation, rect))
	    {
	      NSEvent *nextEvent;
	      BOOL startdnd = NO;
	      int dragdelay = 0;

	      editIndex = -1;
	      if (!([theEvent modifierFlags] & NSShiftKeyMask))
		{
		  [self deselectAllCells];
		  if (editIndex != row)
		    {
		      editIndex = row;
		    }
		}
                    
	      [self selectCellAtRow: row column: col];
	      [self sendAction];
          
	      while (1)
		{
		  nextEvent = [[self window] nextEventMatchingMask:
					       NSLeftMouseUpMask | NSLeftMouseDraggedMask];

		  if ([nextEvent type] == NSLeftMouseUp)
		    {
		      [[self window] postEvent: nextEvent atStart: NO];
		      break;

		    }
		  else if ([nextEvent type] == NSLeftMouseDragged)
		    {
		      if (dragdelay < 5)
			{
			  dragdelay++;
			}
		      else
			{
			  editIndex = -1;
			  startdnd = YES;
			  break;
			}
		    }
		}

	      if (startdnd)
		[self startExternalDragOnEvent: theEvent];
                        
	    }
	  else
	    {
	      [super mouseDown: theEvent];
          
	      if (editIndex != row) {
		editIndex = row;
            
	      } else {
		NSTimeInterval interval = ([theEvent timestamp] - editstamp);
          
		if ((interval > DOUBLE_CLICK_LIMIT)
		    && (interval < EDIT_CLICK_LIMIT)) {
		  [column setEditorForCell: cell];
		}
	      }
	    }
        
	  editstamp = [theEvent timestamp];
	}
    }
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

@end


@implementation FSNBrowserMatrix (DraggingSource)

- (void)startExternalDragOnEvent:(NSEvent *)event
{
  NSArray *selectedCells = [self selectedCells];
  unsigned count = [selectedCells count];

  if (count) {
    NSPoint dragPoint = [event locationInWindow];
    NSPasteboard *pb = [NSPasteboard pasteboardWithName: NSDragPboard];	
    int iconSize = [[self prototype] iconSize];
    NSImage *dragIcon;

    [self declareAndSetShapeOnPasteboard: pb];

    if (count > 1) {
      dragIcon = [[FSNodeRep sharedInstance] multipleSelectionIconOfSize: iconSize];
    } else {
      FSNBrowserCell *cell = [selectedCells objectAtIndex: 0];
      FSNode *node = [cell node];

      if (node && [node isValid]) {
        dragIcon = [[FSNodeRep sharedInstance] iconOfSize: iconSize forNode: node];
      } else {
        return;
      }
    } 

    dragPoint = [self convertPoint: dragPoint fromView: nil];
    dragPoint.x -= (iconSize / 2);
    dragPoint.y += (iconSize / 2);

    [self dragImage: dragIcon
                 at: dragPoint 
             offset: NSZeroSize
              event: event
         pasteboard: pb
             source: self
          slideBack: YES];
  }
}

- (void)draggedImage:(NSImage *)anImage 
						 endedAt:(NSPoint)aPoint 
					 deposited:(BOOL)flag
{
}

- (void)declareAndSetShapeOnPasteboard:(NSPasteboard *)pb
{
  NSArray *selectedCells = [self selectedCells];
  NSMutableArray *selection = [NSMutableArray array];
  NSArray *dndtypes;
  int i; 

  for (i = 0; i < [selectedCells count]; i++) {
    FSNBrowserCell *cell = [selectedCells objectAtIndex: i];
    FSNode *node = [cell node];
  
    if (node && [node isValid]) {
      [selection addObject: [node path]];
    }
  }
  
  if ([selection count]) { 	
    dndtypes = [NSArray arrayWithObject: NSFilenamesPboardType];
    [pb declareTypes: dndtypes owner: nil];

    if ([pb setPropertyList: selection forType: NSFilenamesPboardType] == NO) {
      return;
    }
  }
}

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag
{
  return NSDragOperationAll;
}

@end


@implementation FSNBrowserMatrix (DraggingDestination)

- (NSDragOperation)checkReturnValueForCell:(FSNBrowserCell *)acell
                          withDraggingInfo:(id <NSDraggingInfo>)sender
{
  if (dndTarget != acell) {
    dndTarget = acell;
    dragOperation = [column draggingEntered: sender inMatrixCell: dndTarget];
    
    if (dragOperation != NSDragOperationNone) {
      [self selectIconOfCell: dndTarget];
    } else {
      [self unSelectIconsOfCellsDifferentFrom: nil];
    }
  }

  return dragOperation;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  NSPoint location;
  NSInteger row, col;
  
  location = [[self window] mouseLocationOutsideOfEventStream];
  location = [self convertPoint: location fromView: nil];
  
  dndTarget = nil;
  
  if ([self getRow: &row column: &col forPoint: location]) {
    dndTarget = [[self cells] objectAtIndex: row];  
    dragOperation = [column draggingEntered: sender inMatrixCell: dndTarget];
    
    if (dragOperation != NSDragOperationNone) {
      [self selectIconOfCell: dndTarget];
    } else {
      [self unSelectIconsOfCellsDifferentFrom: nil];
    }
    
    if (dragOperation == NSDragOperationNone) {
      dndTarget = nil;
      return [column draggingEntered: sender];
    }
    
    return dragOperation;
  }
  
  return NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSPoint location;
  NSInteger row, col;

  location = [[self window] mouseLocationOutsideOfEventStream];
  location = [self convertPoint: location fromView: nil];

  if ([self getRow: &row column: &col forPoint: location]) {
    FSNBrowserCell *cell = [[self cells] objectAtIndex: row];  
    
    [self checkReturnValueForCell: cell withDraggingInfo: sender];

    if (dragOperation == NSDragOperationNone) {
      dndTarget = nil;
      return [column draggingUpdated: sender];
    }
    
    return dragOperation;
  }

  return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  [self unSelectIconsOfCellsDifferentFrom: nil];
  dndTarget = nil;
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
  return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
  if (dndTarget) {
    [column concludeDragOperation: sender inMatrixCell: dndTarget];
    [self unSelectIconsOfCellsDifferentFrom: nil];
  } else {
    [column concludeDragOperation: sender];
  }
}

@end
















