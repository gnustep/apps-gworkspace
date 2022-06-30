/* FSNBrowserColumn.h
 *  
 * Copyright (C) 2004-2022 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
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

#ifndef FSN_BROWSER_COLUMN_H
#define FSN_BROWSER_COLUMN_H

#include <Foundation/Foundation.h>
#include <AppKit/NSView.h>
#include "FSNodeRep.h"

@class FSNBrowser;
@class FSNBrowserCell;
@class FSNBrowserMatrix;
@class FSNBrowserScroll;

@interface FSNBrowserColumn : NSView 
{
  FSNBrowserScroll *scroll;
  FSNBrowserMatrix *matrix;
  FSNBrowserCell *cellPrototype;

  int cellsHeight;
  BOOL cellsIcon;
    
  FSNode *shownNode;
  FSNode *oldNode;
  FSNInfoType infoType;
  NSString *extInfoType;  
  NSInteger index;
  BOOL isLoaded;
  BOOL isLeaf;

  BOOL isDragTarget;
  BOOL forceCopy;
  
  FSNBrowser *browser;
  NSColor *backColor;
  
  FSNodeRep *fsnodeRep;
}

- (id)initInBrowser:(FSNBrowser *)abrowser
            atIndex:(NSInteger)ind
      cellPrototype:(FSNBrowserCell *)acell
          cellsIcon:(BOOL)cicon
       nodeInfoType:(FSNInfoType)type
       extendedType:(NSString *)exttype          
    backgroundColor:(NSColor *)acolor;

- (void)setShowType:(FSNInfoType)type;

- (void)setExtendedShowType:(NSString *)type;

- (void)showContentsOfNode:(FSNode *)anode;

- (FSNode *)shownNode;

- (void)createRowsInMatrix;

- (void)addCellsWithNames:(NSArray *)names;

- (void)removeCellsWithNames:(NSArray *)names;

- (NSArray *)selectedCells;

- (NSArray *)selectedNodes;

- (NSArray *)selectedPaths;

- (void)selectCell:(FSNBrowserCell *)cell
        sendAction:(BOOL)act;

- (FSNBrowserCell *)selectCellOfNode:(FSNode *)node
                          sendAction:(BOOL)act;
                
- (FSNBrowserCell *)selectCellWithPath:(NSString *)path
                            sendAction:(BOOL)act;
                
- (FSNBrowserCell *)selectCellWithName:(NSString *)name 
                            sendAction:(BOOL)act;

- (void)selectCells:(NSArray *)cells 
         sendAction:(BOOL)act;

- (void)selectCellsOfNodes:(NSArray *)nodes 
                sendAction:(BOOL)act;
                
- (void)selectCellsWithPaths:(NSArray *)paths 
                  sendAction:(BOOL)act;

- (void)selectCellsWithNames:(NSArray *)names 
                  sendAction:(BOOL)act;

- (BOOL)selectFirstCell;

- (BOOL)selectCellWithPrefix:(NSString *)prefix;

- (void)selectAll;

- (void)unselectAllCells;

- (void)setEditorForCell:(FSNBrowserCell *)cell;

- (void)stopCellEditing;

- (void)checkLockedReps;
           
- (void)lockCellsOfNodes:(NSArray *)nodes;

- (void)lockCellsWithPaths:(NSArray *)paths;

- (void)lockCellsWithNames:(NSArray *)names;
           
- (void)unLockCellsOfNodes:(NSArray *)nodes;

- (void)unLockCellsWithPaths:(NSArray *)paths;

- (void)unLockCellsWithNames:(NSArray *)names;

- (void)lock;

- (void)unlock;
     
- (FSNBrowserCell *)cellOfNode:(FSNode *)node;                

- (FSNBrowserCell *)cellWithPath:(NSString *)path;                

- (FSNBrowserCell *)cellWithName:(NSString *)name;                
                
- (void)adjustMatrix;

- (void)doClick:(id)sender;

- (void)doDoubleClick:(id)sender;
                                
- (NSMatrix *)cmatrix;
                
- (NSInteger)index;                

- (BOOL)isLoaded;                

- (BOOL)isSelected;

- (void)setBackgroundColor:(NSColor *)acolor;

@end


@interface FSNBrowserColumn (DraggingDestination)

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender;

- (void)draggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
                      inMatrixCell:(id)cell;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
                 inMatrixCell:(id)cell;

@end

#endif // FSN_BROWSER_COLUMN_H
