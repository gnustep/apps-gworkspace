/* SmallIconsPanel.h
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


#ifndef SMALLICONSPANEL_H
#define SMALLICONSPANEL_H

#include <AppKit/NSView.h>

@class NSString;
@class NSMutableString;
@class NSArray;
@class NSMutableArray;
@class NSNotification;
@class NSFileManager;
@class SmallIcon;

@interface SmallIconsPanel : NSView 
{
  id delegate;
  NSString *currentPath;

	NSMutableArray *icons; 
  NSImage *verticalImage;
  NSImage *horizontalImage;
	
	BOOL isDragTarget;	
  BOOL isShiftClick;
	BOOL selectInProgress;
  int cellsWidth;

  BOOL contestualMenu;
  
	NSString *charBuffer; 
	NSTimeInterval lastKeyPressed;

	SEL currSelectionSel;
	IMP currSelection;			

  NSFileManager *fm;
}

- (id)initAtPath:(NSString *)path
        delegate:(id)adelegate;

- (void)setPath:(NSString *)path;
- (void)setCurrentSelection;
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
- (SmallIcon *)iconWithPath:(NSString *)path;
- (NSArray *)iconsWithPaths:(NSArray *)paths;
- (SmallIcon *)iconWithNamePrefix:(NSString *)prefix inRange:(NSRange)range;
- (NSPoint)locationOfIconWithName:(NSString *)name;

- (void)selectIconWithPath:(NSString *)path;
- (void)selectIconsWithPaths:(NSArray *)paths;
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
- (void)addIconsWithPaths:(NSArray *)iconpaths;
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

- (id)delegate;

- (void)setDelegate:(id)anObject;

@end

@interface SmallIconsPanel (DraggingDestination)

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

@interface NSObject (SmallIconsPanelDelegateMethods)

- (void)setTheSelectedPaths:(id)paths;

- (void)setSelectedPathsFromIcons:(id)paths;

- (void)openTheCurrentSelection:(id)paths newViewer:(BOOL)newv;

- (int)iconCellsWidth;

@end

//
// SmallIcon Delegate Methods
//

@interface SmallIconsPanel (SmallIconDelegateMethods)

- (void)unselectIconsDifferentFrom:(id)aicon;

- (void)setShiftClickValue:(BOOL)value;

- (void)setTheCurrentSelection;

- (NSArray *)getTheCurrentSelection;

- (void)openTheCurrentSelection:(id)paths newViewer:(BOOL)newv;

- (id)menuForRightMouseEvent:(NSEvent *)theEvent;

@end

#endif // SMALLICONSPANEL_H

