/* Browser2.h
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


#ifndef BROWSER2_H
#define BROWSER2_H

#include <AppKit/NSView.h>

enum {
  GWColumnIconMask = 1,
  GWIconCellsMask = 2,
  GWViewsPaksgesMask = 4	
};

@class NSString;
@class NSArray;
@class NSFileManager;
@class NSDictionary;
@class NSNotification;
@class NSScroller;
@class NSFont;
@class NSCursor;
@class BColumn;
@class BIcon;
@class BCell;
@class BNameEditor;

typedef int (*intIMP)(id, SEL, id);

@interface Browser2 : NSView 
{
	NSString *basePath;
  NSString *pathSeparator;
	BOOL isLoaded;
  unsigned int styleMask;
  
  NSMutableArray *columns;
  NSRect *colRects;
  BCell *cellPrototype;
  NSScroller *scroller;
  BOOL skipUpdateScroller;
  
  BOOL canUpdateViews;
    
	int visibleColumns;
  int lastColumnLoaded;
  int firstVisibleColumn;
  int lastVisibleColumn;	
	int currentshift;

  NSSize columnSize;
  float columnOriginY;
  float columnWidth;    
	float iconsPathWidth;
  NSRect scrollerRect;
  float scrollerWidth;	

  BOOL simulatingDoubleClick;
  NSArray *doubleClickSelection;
  float mousePointX;
  float mousePointY;
  
  BNameEditor *nameEditor;
  NSFont *editorFont;
  BColumn *edCol;
  BOOL isEditingIconName;
  
  NSString *charBuffer;	
	NSTimeInterval lastKeyPressed;
  int alphaNumericalLastColumn;
	
  id delegate;
  id gworkspace;

	SEL createEmptySel;
	IMP createEmpty;
	SEL addAndLoadSel;
	IMP addAndLoad;
  SEL unloadFromSel;
  IMP unloadFrom;
	SEL lastColumnSel;
	IMP lastColumn;    
  SEL setPathsSel;
  IMP setPaths;
  SEL getSel;
  IMP getImp;
  SEL indexSel;
  intIMP indexImp;
}

- (id)initWithBasePath:(NSString *)bpath
		  	visibleColumns:(int)vcols 
             styleMask:(int)mask
					  	delegate:(id)anobject;

- (void)setPathAndSelection:(NSArray *)selection;

- (void)loadColumnZero;
- (BColumn *)createEmptyColumn;
- (void)addAndLoadColumnForPaths:(NSArray *)cpaths;
- (void)unloadFromColumn:(int)column;
- (void)reloadColumnWithPath:(NSString *)cpath;
- (void)reloadFromColumnWithPath:(NSString *)cpath;
- (void)setLastColumn:(int)column;

- (void)tile;
- (void)makeColumnsRects;
- (void)scrollViaScroller:(NSScroller *)sender;
- (void)updateScroller;
- (void)scrollColumnsLeftBy:(int)shiftAmount;
- (void)scrollColumnsRightBy:(int)shiftAmount;
- (void)scrollColumnToVisible:(int)column;
- (void)moveLeft:(id)sender;
- (void)moveRight:(id)sender;
- (void)setShift:(int)s;

- (BOOL)isShowingPath:(NSString *)path;
- (NSString *)pathToLastColumn;
- (BColumn *)selectedColumn;
- (NSArray *)selectionInColumn:(int)column;
- (NSArray *)selectionInColumnBeforeColumn:(BColumn *)col;
- (void)selectCellsWithNames:(NSArray *)names 
            inColumnWithPath:(NSString *)cpath
                  sendAction:(BOOL)act;
- (void)extendSelectionWithDimmedFiles:(NSArray *)dimmFiles 
                    fromColumnWithPath:(NSString *)cpath;
- (void)selectAllInLastColumn;
- (void)selectForEditingInLastColumn;
- (void)unselectNameEditor;
- (void)restoreSelectionAfterDndOfIcon:(BIcon *)dndicon;
- (void)renewLastIcon;

- (void)addCellsWithNames:(NSArray *)names 
         inColumnWithPath:(NSString *)cpath;
- (void)addDimmedCellsWithNames:(NSArray *)names 
               inColumnWithPath:(NSString *)cpath;                   
- (void)removeCellsWithNames:(NSArray *)names 
            inColumnWithPath:(NSString *)cpath;
- (void)lockCellsWithNames:(NSArray *)names 
          inColumnWithPath:(NSString *)cpath;          
- (void)unLockCellsWithNames:(NSArray *)names 
            inColumnWithPath:(NSString *)cpath
                  mustExtend:(BOOL)extend;

- (int)firstVisibleColumn;
- (BColumn *)lastLoadedColumn;
- (BColumn *)lastNotEmptyColumn;
- (BColumn *)columnWithPath:(NSString *)cpath;
- (BColumn *)columnBeforeColumn:(BColumn *)col;
- (BColumn *)columnAfterColumn:(BColumn *)col;
- (NSArray *)columnsDifferentFromColumn:(BColumn *)col;

- (NSPoint)positionOfLastIcon;
- (NSPoint)positionForSlidedImage;

- (BOOL)viewsapps;

- (void)doubleClikTimeOut:(id)sender;
- (void)clickInMatrixOfColumn:(BColumn *)col;
- (void)doubleClickInMatrixOfColumn:(BColumn *)col;
- (void)clickOnIcon:(BIcon *)icon ofColumn:(BColumn *)col;
- (void)doubleClickOnIcon:(BIcon *)icon 
                 ofColumn:(BColumn *)col 
                newViewer:(BOOL)isnew;

- (void)updateNameEditor;
- (BOOL)isEditingIconName;
- (void)controlTextDidBeginEditing:(NSNotification *)aNotification;
- (void)controlTextDidChange:(NSNotification *)aNotification;
- (void)controlTextDidEndEditing:(NSNotification *)aNotification;
- (void)editorAction:(id)sender;
- (BOOL)fileManager:(NSFileManager *)manager 
              shouldProceedAfterError:(NSDictionary *)errorDict;
- (void)fileManager:(NSFileManager *)manager willProcessPath:(NSString *)path;

@end

//
// Methods Implemented by the Delegate 
//
@interface NSObject (Browser2DelegateMethods)

- (void)currentSelectedPaths:(NSArray *)paths;

- (void)openSelectedPaths:(NSArray *)paths newViewer:(BOOL)isnew;

@end

#endif // BROWSER2_H

