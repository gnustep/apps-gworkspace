/* Browser.h
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */


#ifndef BROWSER_H
#define BROWSER_H

#include <AppKit/NSView.h>

@class NSString;
@class NSArray;
@class NSFileManager;
@class NSDictionary;
@class NSNotification;
@class NSScroller;
@class NSFont;
@class NSCursor;
@class Column;
@class Icon;
@class Cell;
@class NameEditor;

typedef int (*intIMP)(id, SEL, id);

@interface Browser : NSView 
{
  NSString *remoteHostName;    
  NSCursor *waitCursor;
  
	NSString *basePath;
  NSString *pathSeparator;
	BOOL isLoaded;
  
  NSMutableArray *columns;
  NSRect *colRects;
  Cell *cellPrototype;
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
  
  NameEditor *nameEditor;
  NSFont *editorFont;
  Column *edCol;
  BOOL isEditingIconName;
  
  NSString *charBuffer;	
	NSTimeInterval lastKeyPressed;
  int alphaNumericalLastColumn;
	
  id delegate;
  id gwremote;

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
					  	delegate:(id)anobject
            remoteHost:(NSString *)rhost;

- (void)setPathAndSelection:(NSArray *)selection;

- (void)loadColumnZero;
- (Column *)createEmptyColumn;
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
- (Column *)selectedColumn;
- (NSArray *)selectionInColumn:(int)column;
- (NSArray *)selectionInColumnBeforeColumn:(Column *)col;
- (void)selectCellsWithNames:(NSArray *)names 
            inColumnWithPath:(NSString *)cpath
                  sendAction:(BOOL)act;
- (void)extendSelectionWithDimmedFiles:(NSArray *)dimmFiles 
                    fromColumnWithPath:(NSString *)cpath;
- (void)selectAllInLastColumn;
- (void)selectForEditingInLastColumn;
- (void)unselectNameEditor;
- (void)restoreSelectionAfterDndOfIcon:(Icon *)dndicon;
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
- (Column *)lastLoadedColumn;
- (Column *)lastNotEmptyColumn;
- (Column *)columnWithPath:(NSString *)cpath;
- (Column *)columnBeforeColumn:(Column *)col;
- (Column *)columnAfterColumn:(Column *)col;
- (NSArray *)columnsDifferentFromColumn:(Column *)col;

- (NSPoint)positionOfLastIcon;
- (NSPoint)positionForSlidedImage;

- (BOOL)viewsapps;

- (void)doubleClikTimeOut:(id)sender;
- (void)clickInMatrixOfColumn:(Column *)col;
- (void)doubleClickInMatrixOfColumn:(Column *)col;
- (void)clickOnIcon:(Icon *)icon ofColumn:(Column *)col;
- (void)doubleClickOnIcon:(Icon *)icon 
                 ofColumn:(Column *)col 
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
@interface NSObject (BrowserDelegateMethods)

- (void)currentSelectedPaths:(NSArray *)paths;

- (void)openSelectedPaths:(NSArray *)paths newViewer:(BOOL)isnew;

@end

#endif // BROWSER_H

