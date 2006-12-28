/* CategoryView.h
 *  
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: December 2006
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

#ifndef CATEGORIES_VIEW_H
#define CATEGORIES_VIEW_H

#include <Foundation/Foundation.h>
#include <AppKit/NSView.h>
#include <AppKit/NSTextField.h>

@class NSButton;
@class NSImage;
@class NSColor;
@class CViewTitleField;
@class CategoriesEditor;

@interface CategoryView : NSView 
{
  NSMutableDictionary *catinfo;
  CategoriesEditor *editor;
  
  NSButton *stateButton;
  NSImage *icon;
  CViewTitleField *titleField;
  NSColor *backcolor;
  NSImage *dragImage;
  BOOL isDragTarget;
  NSRect targetRects[2];
  int insertpos;
}

- (id)initWithCategoryInfo:(NSDictionary *)info 
                  inEditor:(CategoriesEditor *)aneditor;

- (NSDictionary *)categoryInfo;

- (int)index;

- (void)setIndex:(int)index;

- (void)createDragImage;

- (void)stateButtonAction:(id)sender;

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag;

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender;
- (void)draggingExited:(id <NSDraggingInfo>)sender;
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

@end


@interface CViewTitleField : NSTextField 
{
  CategoryView *cview;
}

- (id)initWithFrame:(NSRect)rect
     inCategoryView:(CategoryView *)view;

@end

#endif // CATEGORIES_VIEW_H

