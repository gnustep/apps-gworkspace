/* BColumn.h
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

#ifndef BCOLUMN_H_
#define BCOLUMN_H_

#include <AppKit/NSView.h>

@class NSMatrix;
@class NSScrollView;
@class NSTextField;
@class BMatrix;
@class BIcon;
@class BCell;
@class Browser2;

@interface BColumn : NSView
{
  NSScrollView *scroll;
  BMatrix *matrix;
  BCell *cellPrototype;
  NSView *iconView;
	BIcon *icon;

  unsigned int styleMask;
  int cellsHeight;
    
  NSString *path;
  NSString *oldpath;
  int index;
  BOOL isLoaded;
  BOOL isLeaf;
  
  Browser2 *browser;

  id fm;
  id ws;
}

- (id)initInBrowser:(Browser2 *)aBrowser
            atIndex:(int)ind
      cellPrototype:(BCell *)cell
          styleMask:(int)mask;

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

- (Browser2 *)browser;

- (NSMatrix *)cmatrix;

- (NSView *)iconView;

- (BIcon *)myIcon;

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

@interface BColumn (BIconDelegateMethods)

- (void)icon:(BIcon *)sender setFrameOfLabel:(NSTextField *)label;

- (void)unselectOtherIcons:(BIcon *)selicon;

- (void)unselectNameEditor;

- (void)restoreSelectionAfterDndOfIcon:(BIcon *)dndicon;

- (void)clickOnIcon:(BIcon *)clicked;

- (void)doubleClickOnIcon:(BIcon *)clicked newViewer:(BOOL)isnew;

@end

#endif // BCOLUMN_H_
