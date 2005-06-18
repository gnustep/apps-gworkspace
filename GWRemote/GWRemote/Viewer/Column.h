/* Column.h
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

#ifndef COLUMN_H
#define COLUMN_H

#include <AppKit/NSView.h>

@class NSMatrix;
@class NSScrollView;
@class NSTextField;
@class Matrix;
@class Icon;
@class Cell;
@class Browser;

@interface Column : NSView
{
  NSScrollView *scroll;
  Matrix *matrix;
  Cell *cellPrototype;
  NSView *iconView;
	Icon *icon;

  int cellsHeight;
  
  NSString *remoteHostName;    
  
  NSString *path;
  NSString *oldpath;
  int index;
  BOOL isLoaded;
  BOOL isLeaf;
  
  Browser *browser;

  id gwremote;
  id fm;
  id ws;
}

- (id)initInBrowser:(Browser *)aBrowser
            atIndex:(int)ind
      cellPrototype:(Cell *)cell
         remoteHost:(NSString *)rhost;

- (void)setCurrentPaths:(NSArray *)cpaths;

- (void)createRowsInMatrix;

- (void)addMatrixCellsWithNames:(NSArray *)names;

- (void)addDimmedMatrixCellsWithNames:(NSArray *)names;

- (void)removeMatrixCellsWithNames:(NSArray *)names;

- (BOOL)selectMatrixCellsWithNames:(NSArray *)names sendAction:(BOOL)act;

- (void)selectMatrixCells:(NSArray *)cells sendAction:(BOOL)act;

- (BOOL)selectFirstCell;

- (BOOL)selectCellWithPrefix:(NSString *)prefix;

- (void)selectIcon;

- (void)selectAll;

- (NSArray *)selection;

- (void)lockCellsWithNames:(NSArray *)names;

- (void)unLockCellsWithNames:(NSArray *)names;

- (void)lock;

- (void)unLock;

- (void)adjustMatrix;

- (void)updateIcon;

- (id)cellWithName:(NSString *)name;

- (void)setLeaf:(BOOL)value;

- (Browser *)browser;

- (NSMatrix *)cmatrix;

- (NSView *)iconView;

- (Icon *)myIcon;

- (NSTextField *)iconLabel;

- (NSString *)currentPath;

- (int)index;

- (BOOL)isLoaded;

- (BOOL)isSelected;

- (BOOL)isLeaf;

- (void)doClick:(id)sender;

- (void)doDoubleClick:(id)sender;

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
                   inMatrixCell:(id)aCell;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
                 inMatrixCell:(id)aCell;
                 
@end

@interface Column (IconDelegateMethods)

- (void)icon:(Icon *)sender setFrameOfLabel:(NSTextField *)label;

- (void)unselectOtherIcons:(Icon *)selicon;

- (void)unselectNameEditor;

- (void)restoreSelectionAfterDndOfIcon:(Icon *)dndicon;

- (void)clickOnIcon:(Icon *)clicked;

- (void)doubleClickOnIcon:(Icon *)clicked newViewer:(BOOL)isnew;

@end

#endif // COLUMN_H
