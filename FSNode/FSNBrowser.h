/* FSNBrowser.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#ifndef FSN_BROWSER_H
#define FSN_BROWSER_H

#include <Foundation/Foundation.h>
#include <AppKit/NSView.h>
#include "FSNodeRep.h"

@class FSNBrowserColumn;
@class FSNBrowserCell;
@class FSNCellNameEditor;
@class NSScroller;

@interface FSNBrowser : NSView 
{
  FSNode *baseNode;
  NSString *infoPath;
  NSMutableDictionary *nodeInfo;
  FSNInfoType infoType;
  NSString *extInfoType;
  
  NSArray *lastSelection;
  NSMutableArray *columns;
  FSNBrowserCell *cellPrototype;
  NSScroller *scroller;
  BOOL skipUpdateScroller;
  int updateViewsLock;

  FSNCellNameEditor *nameEditor;

  BOOL cellsIcon;
  BOOL selColumn;
  
	BOOL isLoaded;
    
	int visibleColumns;
  int lastColumnLoaded;
  int firstVisibleColumn;
  int lastVisibleColumn;	
	int currentshift;

  NSSize columnSize;
  
  NSString *charBuffer;	
	NSTimeInterval lastKeyPressed;
  int alphaNumericalLastColumn;

  NSColor *backColor;
	
  id viewer;  
  id manager;
  id <DesktopApplication> desktopApp;
}

- (id)initWithBaseNode:(FSNode *)bsnode
		    visibleColumns:(int)vcols 
              scroller:(NSScroller *)scrl
            cellsIcons:(BOOL)cicns
         editableCells:(BOOL)edcells
       selectionColumn:(BOOL)selcol;

- (void)setBaseNode:(FSNode *)node;
- (NSDictionary *)readNodeInfo;
- (void)updateNodeInfo;

- (void)setUsesCellsIcons:(BOOL)cicns;
- (void)setUsesSelectionColumn:(BOOL)selcol;
- (void)setVisibleColumns:(int)vcols;
- (int)visibleColumns;

- (void)showSubnode:(FSNode *)node;
- (void)showSelection:(NSArray *)selection;
- (void)showPathsSelection:(NSArray *)selpaths;

- (void)loadColumnZero;
- (FSNBrowserColumn *)createEmptyColumn;
- (void)addAndLoadColumnForNode:(FSNode *)node;
- (void)addFillingColumn;
- (void)unloadFromColumn:(int)column;
- (void)reloadColumnWithNode:(FSNode *)anode;
- (void)reloadColumnWithPath:(NSString *)cpath;
- (void)reloadFromColumn:(FSNBrowserColumn *)col;
- (void)reloadFromColumnWithNode:(FSNode *)anode;
- (void)reloadFromColumnWithPath:(NSString *)cpath;
- (void)setLastColumn:(int)column;

- (void)tile;
- (void)scrollViaScroller:(NSScroller *)sender;
- (void)updateScroller;
- (void)scrollColumnsLeftBy:(int)shiftAmount;
- (void)scrollColumnsRightBy:(int)shiftAmount;
- (void)scrollColumnToVisible:(int)column;
- (void)moveLeft;
- (void)moveRight;
- (void)setShift:(int)s;

- (FSNode *)nodeOfLastColumn;
- (NSString *)pathToLastColumn;
- (NSArray *)selectionInColumnBeforeColumn:(FSNBrowserColumn *)col;
- (void)selectCellsWithNames:(NSArray *)names 
            inColumnWithPath:(NSString *)cpath
                  sendAction:(BOOL)act;
- (void)selectAllInLastColumn;
- (void)notifySelectionChange:(NSArray *)newsel;
- (void)synchronizeViewer;

- (void)addCellsWithNames:(NSArray *)names 
         inColumnWithPath:(NSString *)cpath;
- (void)removeCellsWithNames:(NSArray *)names 
            inColumnWithPath:(NSString *)cpath;

- (int)firstVisibleColumn;
- (int)lastColumnLoaded;
- (int)lastVisibleColumn;
- (FSNBrowserColumn *)selectedColumn;
- (FSNBrowserColumn *)lastLoadedColumn;
- (FSNBrowserColumn *)columnWithNode:(FSNode *)anode;
- (FSNBrowserColumn *)columnWithPath:(NSString *)cpath;
- (FSNBrowserColumn *)columnBeforeColumn:(FSNBrowserColumn *)col;
- (FSNBrowserColumn *)columnAfterColumn:(FSNBrowserColumn *)col;

- (void)clickInMatrixOfColumn:(FSNBrowserColumn *)col;
- (void)doubleClickInMatrixOfColumn:(FSNBrowserColumn *)col;

@end


@interface FSNBrowser (NodeRepContainer)

- (void)showContentsOfNode:(FSNode *)anode;
- (void)reloadContents;
- (void)reloadFromNode:(FSNode *)anode;
- (FSNode *)baseNode;
- (FSNode *)shownNode;
- (BOOL)isSingleNode;
- (BOOL)isShowingNode:(FSNode *)anode;
- (BOOL)isShowingPath:(NSString *)path;
- (void)sortTypeChangedAtPath:(NSString *)path;
- (void)nodeContentsWillChange:(NSDictionary *)info;
- (void)nodeContentsDidChange:(NSDictionary *)info;
- (void)watchedPathChanged:(NSDictionary *)info;
- (void)setShowType:(FSNInfoType)type;
- (void)setExtendedShowType:(NSString *)type;
- (FSNInfoType)showType;
- (void)setIconSize:(int)size;
- (int)iconSize;
- (void)setLabelTextSize:(int)size;
- (int)labelTextSize;
- (void)setIconPosition:(int)pos;
- (int)iconPosition;
- (void)updateIcons;
- (id)repOfSubnode:(FSNode *)anode;
- (id)repOfSubnodePath:(NSString *)apath;
- (id)addRepForSubnode:(FSNode *)anode;
- (id)addRepForSubnodePath:(NSString *)apath;
- (void)removeRepOfSubnode:(FSNode *)anode;
- (void)removeRepOfSubnodePath:(NSString *)apath;
- (void)removeRep:(id)arep;
- (void)unloadFromNode:(FSNode *)anode;
- (void)repSelected:(id)arep;
- (void)unselectOtherReps:(id)arep;
- (void)selectReps:(NSArray *)reps;
- (void)selectRepsOfSubnodes:(NSArray *)nodes;
- (void)selectRepsOfPaths:(NSArray *)paths;
- (void)selectAll;
- (NSArray *)reps;
- (NSArray *)selectedReps;
- (NSArray *)selectedNodes;
- (NSArray *)selectedPaths;
- (void)selectionDidChange;
- (void)checkLockedReps;
- (void)setSelectionMask:(FSNSelectionMask)mask;
- (FSNSelectionMask)selectionMask;
- (void)openSelectionInNewViewer:(BOOL)newv;
- (void)restoreLastSelection;
- (void)setLastShownNode:(FSNode *)anode;
- (BOOL)involvedByFileOperation:(NSDictionary *)opinfo;
- (BOOL)validatePasteOfFilenames:(NSArray *)names
                       wasCutted:(BOOL)cutted;
- (void)setBackgroundColor:(NSColor *)acolor;
- (NSColor *)backgroundColor;
- (void)setTextColor:(NSColor *)acolor;
- (NSColor *)textColor;
- (NSColor *)disabledTextColor;

@end


@interface FSNBrowser (IconNameEditing)

- (void)setEditorForCell:(FSNBrowserCell *)cell 
                inColumn:(FSNBrowserColumn *)col;
                
- (void)stopCellEditing;                

- (void)stopRepNameEditing;                       

- (void)unselectNameEditor;
                
- (void)controlTextDidChange:(NSNotification *)aNotification;

- (void)controlTextDidEndEditing:(NSNotification *)aNotification;

- (BOOL)fileManager:(NSFileManager *)manager 
              shouldProceedAfterError:(NSDictionary *)errorDict;

- (void)fileManager:(NSFileManager *)manager willProcessPath:(NSString *)path;

@end

#endif // FSN_BROWSER_H
