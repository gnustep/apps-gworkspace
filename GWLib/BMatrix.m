/* BMatrix.m
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
#include "GWLib.h"
#include "GWNotifications.h"
#include "BMatrix.h"
#include "BColumn.h"
#include "BCell.h"
#include "Browser2.h"
#include "GNUstep.h"

@implementation BMatrix

- (void)dealloc
{
  [super dealloc];
}

- (id)initInColumn:(BColumn *)col
         withFrame:(NSRect)frameRect 
              mode:(int)aMode 
         prototype:(NSCell *)aCell 
      numberOfRows:(int)numRows
   numberOfColumns:(int)numColumns
         acceptDnd:(BOOL)dnd
{
  NSArray *pbTypes = [NSArray arrayWithObjects: NSFilenamesPboardType, 
                                          GWRemoteFilenamesPboardType, nil];

  self = [super initWithFrame: frameRect mode: aMode prototype: aCell 
                        numberOfRows: numRows numberOfColumns: numColumns];

  if (self) {
    column = col;
    browser = [column browser];
    dndTarget = nil;
    acceptDnd = dnd;
    
    if (acceptDnd) {
      [self registerForDraggedTypes: pbTypes];    
    }
  }
  
  return self;
}

- (NSArray *)getVisibleCellsAndTuneSpace:(float *)tspace
{
  NSArray *cells = [self cells];

  if (cells && [cells count]) {
    NSRect vr = [self visibleRect];
    float ylim = vr.origin.y + vr.size.height - [self cellSize].height;
    NSMutableArray *vCells = [NSMutableArray arrayWithCapacity: 1];
    BOOL found = NO;
    int i;
 
    for (i = 0; i < [cells count]; i++) {
      NSRect cr = [self cellFrameAtRow: i column: 0];

      if ((cr.origin.y >= vr.origin.y) && (cr.origin.y <= ylim)) {
        if (found == NO) {
          *tspace = cr.origin.y - vr.origin.y;
          found = YES;
        }        
        [vCells addObject: [cells objectAtIndex: i]];
      }
    }
    
    if ([vCells count]) {
      return vCells;
    }
  }

  return nil;
}

- (NSArray *)getNamesOfVisibleCellsAndTuneSpace:(float *)tspace
{
  NSArray *cells = [self cells];

  if (cells && [cells count]) {
    NSRect vr = [self visibleRect];
    float ylim = vr.origin.y + vr.size.height - [self cellSize].height;
    NSMutableArray *vCells = [NSMutableArray arrayWithCapacity: 1];
    BOOL found = NO;
    int i;
 
    for (i = 0; i < [cells count]; i++) {
      NSRect cr = [self cellFrameAtRow: i column: 0];

      if ((cr.origin.y >= vr.origin.y) && (cr.origin.y <= ylim)) {
        if (found == NO) {
          *tspace = cr.origin.y - vr.origin.y;
          found = YES;
        }        
        [vCells addObject: [[cells objectAtIndex: i] stringValue]];
      }
    }
    
    if ([vCells count]) {
      return vCells;
    }
  }

  return nil;
}

- (void)scrollToFirstPositionCell:(id)aCell withScrollTune:(float)vtune
{
  NSRect vr, cr;
  int row, col;
  
  vr = [self visibleRect];
  
  [self getRow: &row column: &col ofCell: aCell];
  cr = [self cellFrameAtRow: row column: col];
  cr.size.height = vr.size.height - vtune;
    
  [self scrollRectToVisible: cr];
} 

- (void)selectIconOfCell:(id)aCell
{
  BCell *cell = (BCell *)aCell;
  
  if ([cell selectIcon]) {
    NSRect cellFrame;
    int row, col;
  
    [self getRow: &row column: &col ofCell: aCell];
    cellFrame = [self cellFrameAtRow: row column: col];
    [self setNeedsDisplayInRect: cellFrame];
  }
  
  [self unSelectIconsOfCellsDifferentFrom: cell];
}

- (void)unSelectIconsOfCellsDifferentFrom:(id)aCell
{
  NSArray *cells = [self cells];
  int i = 0;

  for (i = 0; i < [cells count]; i++) {
    BCell *c = [cells objectAtIndex: i];  
  
    if (c != aCell) {
      if ([c unSelectIcon]) {
        NSRect cellFrame;
        int row, col;
  
        [self getRow: &row column: &col ofCell: c];
        cellFrame = [self cellFrameAtRow: row column: col];
        [self setNeedsDisplayInRect: cellFrame];
      }
    }
  }
}

- (void)mouseDown:(NSEvent*)theEvent
{
  if (acceptDnd == NO) {
    [super mouseDown: theEvent];
    return;
    
  } else {
    int clickCount;
    NSPoint lastLocation;
    int row, col;
    
    if (([self numberOfRows] == 0) || ([self numberOfColumns] == 0)) {
      [super mouseDown: theEvent];
      return; 
    }

    clickCount = [theEvent clickCount];

    if (clickCount > 2) {
      return;
    }
    
    if (clickCount == 2) {
      [self sendDoubleAction];
      return;
    }

    lastLocation = [theEvent locationInWindow];
    lastLocation = [self convertPoint: lastLocation
		                         fromView: nil];

    if ([self getRow: &row column: &col forPoint: lastLocation]) {
      BCell *cell = [[self cells] objectAtIndex: row];
      NSRect rect = [self cellFrameAtRow: row column: col];
      
      if ([cell isEnabled]) {
        NSSize size = [cell iconSize];

        rect.size.width = size.width;
        rect.size.height = size.height;

        if (NSPointInRect(lastLocation, rect)) {
	        NSEvent *nextEvent;
          BOOL startdnd = NO;
          int dragdelay = 0;
          
          if ([theEvent modifierFlags] & NSShiftKeyMask) {
            [super mouseDown: theEvent];
            return;            
          } 
          
          [self deselectAllCells];             
          [self selectCellAtRow: row column: col]; 
          [self sendAction];
          
          while (1) {
	          nextEvent = [[self window] nextEventMatchingMask:
    							                    NSLeftMouseUpMask | NSLeftMouseDraggedMask];

            if ([nextEvent type] == NSLeftMouseUp) {              
              break;

            } else if ([nextEvent type] == NSLeftMouseDragged) {
	            if(dragdelay < 5) {
                dragdelay++;
              } else {        
                startdnd = YES;        
                break;
              }
            }
          }

          if (startdnd == YES) {  
            [self startExternalDragOnEvent: nextEvent];    
          }               
        } else {
          [super mouseDown: theEvent];
        }
      }
    }
  }
}

- (BOOL)acceptsFirstResponder
{
  return (![browser isEditingIconName]);
}

@end

@implementation BMatrix (DraggingSource)

- (void)startExternalDragOnEvent:(NSEvent *)event
{
  NSPoint dragPoint;
  NSPasteboard *pb;
  NSArray *selectedCells;
  NSImage *dragIcon;
  
  dragPoint = [event locationInWindow];
  dragPoint = [self convertPoint: dragPoint fromView: nil];

	pb = [NSPasteboard pasteboardWithName: NSDragPboard];	
  [self declareAndSetShapeOnPasteboard: pb];
	
	selectedCells = [self selectedCells];
		
  if ([selectedCells count] > 1) {
    dragIcon = [NSImage imageNamed: @"MultipleSelection.tiff"];
  } else {
    NSArray *paths = [[selectedCells objectAtIndex: 0] paths];
    
    if ([paths count] > 1) {
      dragIcon = [NSImage imageNamed: @"MultipleSelection.tiff"];
    } else {
      NSString *path = [paths objectAtIndex: 0];
      NSString *type = [GWLib typeOfFileAt: path];

      dragIcon = [GWLib iconForFile: path ofType: type]; 
    }
  }   

  [self dragImage: dragIcon
               at: dragPoint 
           offset: NSZeroSize
            event: event
       pasteboard: pb
           source: self
        slideBack: [[GWLib workspaceApp] animateSlideBack]];
}

- (void)draggedImage:(NSImage *)anImage 
						 endedAt:(NSPoint)aPoint 
					 deposited:(BOOL)flag
{
}

- (void)declareAndSetShapeOnPasteboard:(NSPasteboard *)pb
{
  NSArray *selectedCells = [self selectedCells];
  NSMutableArray *selection = [NSMutableArray arrayWithCapacity: 1];
  NSArray *dndtypes;
  int i; 

  for (i = 0; i < [selectedCells count]; i++) {
    NSArray *paths = [[selectedCells objectAtIndex: i] paths];
    [selection addObjectsFromArray: paths];
  }
  	
  dndtypes = [NSArray arrayWithObject: NSFilenamesPboardType];
  [pb declareTypes: dndtypes owner: nil];

  if ([pb setPropertyList: selection forType: NSFilenamesPboardType] == NO) {
    return;
  }
}

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag
{
  return NSDragOperationAll;
}

@end

@implementation BMatrix (DraggingDestination)

- (unsigned int)checkReturnValueForCell:(NSCell *)acell
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

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
  NSPoint location;
  int row, col;
  
  location = [[self window] mouseLocationOutsideOfEventStream];
  location = [self convertPoint: location fromView: nil];

  if ([self getRow: &row column: &col forPoint: location]) {
    dndTarget = [[self cells] objectAtIndex: row];  
    dragOperation = [column draggingEntered: sender inMatrixCell: dndTarget];
    
    if (dragOperation != NSDragOperationNone) {
      [self selectIconOfCell: dndTarget];
    } else {
      [self unSelectIconsOfCellsDifferentFrom: nil];
    }
    
    return dragOperation;
  }
  
  return NSDragOperationNone;
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSPoint location;
  int row, col;
  
  location = [[self window] mouseLocationOutsideOfEventStream];
  location = [self convertPoint: location fromView: nil];

  if ([self getRow: &row column: &col forPoint: location]) {
    NSCell *cell = [[self cells] objectAtIndex: row];  
    return [self checkReturnValueForCell: cell withDraggingInfo: sender];
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
  return (dndTarget ? YES : NO);
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	return (dndTarget ? YES : NO);
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
  [column concludeDragOperation: sender inMatrixCell: dndTarget];
  [self unSelectIconsOfCellsDifferentFrom: nil];
}

@end
