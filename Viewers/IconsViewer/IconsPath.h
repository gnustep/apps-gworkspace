/* IconsPath.h
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


#ifndef ICONSPATH_H
#define ICONSPATH_H

#include <AppKit/NSView.h>

@class NSString;
@class NSArray;
@class NSMutableArray;
@class NSFileManager;
@class PathIcon;
@class BNameEditor;

@interface IconsPath : NSView
{
  NSString *root;
  NSString *currentPath;  
  NSMutableArray *icons;  
  BNameEditor *nameEditor;
  PathIcon *edIcon;
  NSFont *editorFont;
  float columnsWidth;
	id delegate;
}

- (id)initWithRootAtPath:(NSString *)rpath 
        		columnsWidth:(float)cwidth
						    delegate:(id)adelegate;

- (void)setIconsForSelection:(NSArray *)selection;

- (void)setColumnWidth:(float)width;

- (void)renewIcons:(int)n;

- (void)addIcon;

- (void)removeIcon:(PathIcon *)icon;

- (void)removeIconAtIndex:(int)index;

- (void)lockIconsFromPath:(NSString *)path;

- (void)unlockIconsFromPath:(NSString *)path;

- (void)setIconsPositions;

- (void)setLabelRectOfIcon:(PathIcon *)icon;

- (void)unselectOtherIcons:(PathIcon *)icon;

- (void)selectIconAtIndex:(int)index;

- (void)startEditing;

- (NSArray *)icons;

- (PathIcon *)iconAtIndex:(int)index;

- (int)indexOfIcon:(PathIcon *)icon;

- (int)indexOfIconWithPath:(NSString *)path;

- (PathIcon *)iconWithPath:(NSString *)path;

- (PathIcon *)lastIcon;

- (NSPoint)positionOfLastIcon;

- (NSPoint)positionForSlidedImage;

- (int)numberOfIcons;

- (void)updateNameEditor;

- (void)editorAction:(id)sender;

- (id)delegate;

- (void)setDelegate:(id)anObject;

@end

//
// Methods Implemented by the Delegate 
//

@interface NSObject (IconsPathDelegateMethods)

- (void)clickedIcon:(id)anicon;

- (void)doubleClickedIcon:(id)anicon newViewer:(BOOL)isnew;

@end

//
// PathIcon Delegate Methods
//

@interface IconsPath (PathIconDelegateMethods)

- (void)setLabelFrameOfIcon:(id)anicon;

- (void)unselectIconsDifferentFrom:(id)anicon;

- (void)clickedIcon:(id)anicon;

- (void)doubleClickedIcon:(id)anicon newViewer:(BOOL)isnew;

- (void)unselectNameEditor;

- (void)restoreSelectionAfterDndOfIcon:(id)dndicon;

@end

#endif // ICONSPATH_H

