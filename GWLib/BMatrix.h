/* BMatrix.h
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


#ifndef BMATRIX_H_
#define BMATRIX_H_

#include <AppKit/NSMatrix.h>

@class BColumn;
@class Browser2;

@interface BMatrix : NSMatrix
{
  BColumn *column;
  Browser2 *browser;
  id gworkspace;
  BOOL acceptDnd;
  NSCell *dndTarget;
  unsigned int dragOperation;
}

- (id)initInColumn:(BColumn *)col
         withFrame:(NSRect)frameRect 
              mode:(int)aMode 
         prototype:(NSCell *)aCell 
      numberOfRows:(int)numRows
   numberOfColumns:(int)numColumns
         acceptDnd:(BOOL)dnd;

- (NSArray *)getVisibleCellsAndTuneSpace:(float *)tspace;

- (NSArray *)getNamesOfVisibleCellsAndTuneSpace:(float *)tspace;

- (void)scrollToFirstPositionCell:(id)aCell withScrollTune:(float)vtune;

- (void)selectIconOfCell:(id)aCell;

- (void)unSelectIconsOfCellsDifferentFrom:(id)aCell;

@end

@interface BMatrix (DraggingSource)

- (void)startExternalDragOnEvent:(NSEvent *)event;

- (void)declareAndSetShapeOnPasteboard:(NSPasteboard *)pb;

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag;

@end

@interface BMatrix (DraggingDestination)

- (unsigned int)checkReturnValueForCell:(NSCell *)acell
                       withDraggingInfo:(id <NSDraggingInfo>)sender;

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender;

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender;

- (void)draggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

@end

#endif // BMATRIX_H_
