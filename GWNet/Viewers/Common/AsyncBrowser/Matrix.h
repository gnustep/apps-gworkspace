/* Matrix.h
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

#ifndef MATRIX_H
#define MATRIX_H

#include <AppKit/NSMatrix.h>

@class Column;
@class Browser;

@interface Matrix : NSMatrix
{
  Column *column;
  Browser *browser;
}

- (id)initInColumn:(Column *)col
         withFrame:(NSRect)frameRect 
              mode:(int)aMode 
         prototype:(NSCell *)aCell 
      numberOfRows:(int)numRows
   numberOfColumns:(int)numColumns;

- (NSArray *)getNamesOfVisibleCellsAndTuneSpace:(float *)tspace;

- (void)scrollToFirstPositionCell:(id)aCell withScrollTune:(float)vtune;

@end

#endif // MATRIX_H
