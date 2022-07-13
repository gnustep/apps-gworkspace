/* FSNBrowserMatrix.h
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

#ifndef FSN_BROWSER_MATRIX_H
#define FSN_BROWSER_MATRIX_H

#include <Foundation/Foundation.h>
#include <AppKit/NSMatrix.h>
#include "FSNodeRep.h"

@class FSNBrowserColumn;
@class FSNBrowserCell;

@interface FSNBrowserMatrix : NSMatrix
{
  FSNBrowserColumn *column;
  NSUInteger mouseFlags;
  NSTimeInterval editstamp;  
  NSInteger editIndex;
  BOOL acceptDnd;
  FSNBrowserCell *dndTarget;
  unsigned int dragOperation;
}

- (id)initInColumn:(FSNBrowserColumn *)col
         withFrame:(NSRect)frameRect 
              mode:(NSMatrixMode)aMode
         prototype:(FSNBrowserCell *)aCell 
      numberOfRows:(NSInteger)numRows
   numberOfColumns:(NSInteger)numColumns
         acceptDnd:(BOOL)dnd;

- (void)visibleCellsNodes:(NSArray **)nodes
          scrollTuneSpace:(float *)tspace;

- (void)scrollToFirstPositionCell:(id)aCell withScrollTune:(float)vtune;

- (void)selectIconOfCell:(id)aCell;

- (void)unSelectIconsOfCellsDifferentFrom:(id)aCell;

- (NSUInteger)mouseFlags;

- (void)setMouseFlags:(NSUInteger)flags;

@end


@interface FSNBrowserMatrix (DraggingSource)

- (void)startExternalDragOnEvent:(NSEvent *)event;

- (void)declareAndSetShapeOnPasteboard:(NSPasteboard *)pb;

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag;

@end


@interface FSNBrowserMatrix (DraggingDestination)

- (NSDragOperation)checkReturnValueForCell:(FSNBrowserCell *)acell
                          withDraggingInfo:(id <NSDraggingInfo>)sender;

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender;

- (void)draggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

@end

#endif // FSN_BROWSER_MATRIX_H

