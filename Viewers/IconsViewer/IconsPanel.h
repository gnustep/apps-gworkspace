/* IconsPanel.h
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


#ifndef ICONSPANEL_H
#define ICONSPANEL_H

#include <AppKit/NSView.h>

@class NSString;
@class NSMutableString;
@class NSArray;
@class NSMutableArray;
@class NSNotification;
@class NSFileManager;
@class IconsViewerIcon;
@class BNameEditor;
@class NSImage;

@interface IconsPanel : NSView 
{
  id delegate;
  NSString *currentPath;

	NSMutableArray *icons; 
  NSImage *verticalImage;
  NSImage *horizontalImage;
  
	BOOL isDragTarget;
  BOOL isShiftClick;
  BOOL selectInProgress;
  int iconsperrow;
  int cellsWidth;
  
  BNameEditor *nameEditor;
  IconsViewerIcon *edIcon;
  NSFont *editorFont;
  BOOL editingIcnName;
  
  BOOL contestualMenu;
  
  NSString *charBuffer;	
	NSTimeInterval lastKeyPressed;
  
  NSFileManager *fm;
}

- (id)initAtPath:(NSString *)path
        delegate:(id)adelegate;

- (void)setPath:(NSString *)path;
- (void)setCurrentSelection:(NSArray *)paths;
- (void)reloadFromPath:(NSString *)path;
- (NSArray *)checkHiddenFiles:(NSArray *)files atPath:(NSString *)path;
- (void)makeFileIcons;
- (void)sortIcons;

- (void)tile;
- (void)scrollFirstIconToVisible;
- (void)scrollToVisibleIconsWithPaths:(NSArray *)paths;

- (NSString *)currentPath;
- (BOOL)isOnBasePath:(NSString *)bpath withFiles:(NSArray *)files;
- (NSArray *)currentSelection;
- (IconsViewerIcon *)iconWithPath:(NSString *)path;
- (NSArray *)iconsWithPaths:(NSArray *)paths;

- (void)selectIconWithPath:(NSString *)path;
- (void)selectIconsWithPaths:(NSArray *)paths;
- (NSString *)selectIconWithPrefix:(NSString *)prefix;
- (void)selectIconInPrevLine;
- (void)selectIconInNextLine;
- (void)selectPrevIcon;
- (void)selectNextIcon;
- (void)selectAllIcons;
- (void)unselectOtherIcons:(id)anIcon;
- (void)extendSelectionWithDimmedFiles:(NSArray *)files 
                        startingAtPath:(NSString *)bpath;
- (void)openSelectionWithApp:(id)sender;
- (void)openSelectionWith:(id)sender;

- (void)addIconWithPath:(NSString *)iconpath dimmed:(BOOL)isdimmed;
- (void)addIconsWithNames:(NSArray *)names dimmed:(BOOL)isdimmed;
- (void)removeIcon:(id)anIcon;
- (void)removeIconsWithNames:(NSArray *)names;

- (void)lockIconsWithNames:(NSArray *)names;
- (void)unLockIconsWithNames:(NSArray *)names;
- (void)lockAllIcons;
- (void)unLockAllIcons;

- (void)setLabelRectOfIcon:(id)anIcon;
- (int)cellsWidth;
- (void)cellsWidthChanged:(NSNotification *)notification;

- (void)setShiftClick:(BOOL)value;

- (void)openCurrentSelection:(NSArray *)paths newViewer:(BOOL)newv;

- (void)updateNameEditor;

- (void)editorAction:(id)sender;

- (void)setDelegate:(id)anObject;

- (id)delegate;

@end

@interface IconsPanel (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender;

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender;

- (void)draggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

@end

//
// Methods Implemented by the Delegate 
//

@interface NSObject (IconsPanelDelegateMethods)

- (void)setTheSelectedPaths:(id)paths;

- (void)openTheCurrentSelection:(id)paths newViewer:(BOOL)newv;

- (int)iconCellsWidth;

@end

//
// IconsViewerIcon Delegate Methods
//

@interface IconsPanel (IconsViewerIconDelegateMethods)

- (int)getCellsWidth;

- (void)setLabelFrameOfIcon:(id)aicon;

- (void)unselectIconsDifferentFrom:(id)aicon;

- (void)setShiftClickValue:(BOOL)value;

- (void)setTheCurrentSelection:(id)paths;

- (NSArray *)getTheCurrentSelection;

- (void)openTheCurrentSelection:(id)paths newViewer:(BOOL)newv;

- (id)menuForRightMouseEvent:(NSEvent *)theEvent;

@end

#endif // ICONSPANEL_H

