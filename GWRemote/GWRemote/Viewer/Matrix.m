/* Matrix.m
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
 *
 * This file is part of the GNUstep GWRemote application
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


#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "Notifications.h"
#include "Matrix.h"
#include "Column.h"
#include "Cell.h"
#include "Browser.h"
#include "GNUstep.h"

@implementation Matrix

- (void)dealloc
{
  [super dealloc];
}

- (id)initInColumn:(Column *)col
         withFrame:(NSRect)frameRect 
              mode:(int)aMode 
         prototype:(NSCell *)aCell 
      numberOfRows:(int)numRows
   numberOfColumns:(int)numColumns
        
{
  self = [super initWithFrame: frameRect mode: aMode prototype: aCell 
                        numberOfRows: numRows numberOfColumns: numColumns];

  if (self) {
    column = col;
    browser = [column browser];
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
  [self unSelectIconsOfCellsDifferentFrom: aCell];
}

- (void)unSelectIconsOfCellsDifferentFrom:(id)aCell
{
}

- (BOOL)acceptsFirstResponder
{
  return (![browser isEditingIconName]);
}

@end

