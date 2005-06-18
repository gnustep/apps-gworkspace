/* Column.h
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
  
  NSString *hostName;    
  
  NSString *path;
  NSString *lastPath;
  NSString *nextPath;
  NSMutableArray *selection;
  NSMutableArray *visibleCellsNames;
  float scrollTune;
  
  int index;
  BOOL isLoaded;
  BOOL isLeaf;
  
  Browser *browser;
  id browserDelegate;
}

- (id)initInBrowser:(Browser *)aBrowser
            atIndex:(int)ind
      cellPrototype:(Cell *)cell
           hostName:(NSString *)hname;

- (void)setCurrentPaths:(NSArray *)cpaths;

- (BOOL)isWaitingContentsForPath:(NSString *)apath;

- (void)createContents:(NSDictionary *)pathContents;

- (void)createPreContents:(NSDictionary *)preContents;

- (void)fillMatrix:(NSDictionary *)contsDict;

- (void)createMatrix;

- (void)clearMatrix;

- (BOOL)selectMatrixCellsWithNames:(NSArray *)names 
                        sendAction:(BOOL)act;

- (BOOL)selectFirstCell;

- (BOOL)selectCellWithPrefix:(NSString *)prefix;

- (void)selectIcon;

- (void)selectAll;

- (NSArray *)selection;

- (void)lock;

- (void)unLock;

- (void)lockCellsWithNames:(NSArray *)names;

- (void)unLockCellsWithNames:(NSArray *)names;

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
