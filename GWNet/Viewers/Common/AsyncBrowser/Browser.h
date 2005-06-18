/* Browser.h
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

#ifndef BROWSER_H
#define BROWSER_H

#include <Foundation/Foundation.h>
#include <AppKit/NSView.h>

@class NSScroller;
@class NSFont;
@class NSCursor;
@class Column;
@class Icon;
@class Cell;
@class NameEditor;

@interface Browser : NSView 
{
  NSString *hostName;    
  
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
  
  NameEditor *nameEditor;
  NSFont *editorFont;
  Column *edCol;
  BOOL isEditingIconName;
  
  NSString *charBuffer;	
	NSTimeInterval lastKeyPressed;
  int alphaNumericalLastColumn;
	
  id delegate;
}

- (id)initWithDelegate:(id)adelegate
         pathSeparator:(NSString *)psep
              hostName:(NSString *)hname
        visibleColumns:(int)vcols;

- (id)delegate;

- (void)setPathAndSelection:(NSArray *)selection;

- (void)loadColumnZero;
- (Column *)createEmptyColumn;
- (void)addAndLoadColumnForPaths:(NSArray *)cpaths;
- (void)directoryContents:(NSDictionary *)contents
             readyForPath:(NSString *)path;
- (void)unloadFromColumn:(int)column;
- (void)reloadFromColumnWithPath:(NSString *)cpath;
- (void)reloadLastColumn;
- (void)lockFromColumnWithPath:(NSString *)cpath;
- (void)unlockFromColumnWithPath:(NSString *)cpath;
- (void)lockCellsWithNames:(NSArray *)names 
          inColumnWithPath:(NSString *)cpath;
- (void)extendSelectionWithDimmedFiles:(NSArray *)dimmFiles 
                    fromColumnWithPath:(NSString *)cpath;
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
- (void)selectAllInLastColumn;
- (void)unselectNameEditor;
- (void)restoreSelectionAfterDndOfIcon:(Icon *)dndicon;
- (void)renewLastIcon;

- (int)firstVisibleColumn;
- (Column *)lastLoadedColumn;
- (Column *)lastNotEmptyColumn;
- (Column *)columnWithPath:(NSString *)cpath;
- (Column *)columnBeforeColumn:(Column *)col;
- (Column *)columnAfterColumn:(Column *)col;
- (NSArray *)columnsDifferentFromColumn:(Column *)col;

- (NSPoint)positionOfLastIcon;
- (NSPoint)positionForSlidedImage;

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

@end

//
// Methods Implemented by the Delegate 
//
@interface NSObject (BrowserDelegateMethods)

- (BOOL)fileExistsAtPath:(NSString *)path;

- (BOOL)existsAndIsDirectoryFileAtPath:(NSString *)path;

- (BOOL)isWritableFileAtPath:(NSString *)path;

- (NSString *)typeOfFileAt:(NSString *)path;

- (BOOL)isPakageAtPath:(NSString *)path;

- (BOOL)isLockedPath:(NSString *)path;

- (void)prepareContentsForPath:(NSString *)path;

- (NSDictionary *)contentsForPath:(NSString *)path;

- (NSDictionary *)preContentsForPath:(NSString *)path;

- (void)invalidateContentsRequestForPath:(NSString *)path;

- (BOOL)isLoadingSelection;

- (void)stopLoadSelection;

- (void)setSelectedPaths:(NSArray *)paths;

- (void)openSelectedPaths:(NSArray *)paths 
                newViewer:(BOOL)isnew;

- (void)renamePath:(NSString *)oldPath 
            toPath:(NSString *)newPath;

- (void)uploadFiles:(NSDictionary *)info;

- (NSImage *)iconForFile:(NSString *)fullPath 
                  ofType:(NSString *)type;

- (NSString *)dndConnName;

@end

#endif // BROWSER_H

