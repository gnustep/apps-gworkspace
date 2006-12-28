/* CategoriesEditor.h
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

#ifndef CATEGORIES_EDITOR_H
#define CATEGORIES_EDITOR_H

#include <Foundation/Foundation.h>
#include <AppKit/NSView.h>

@class CategoryView;

@interface CategoriesEditor : NSView 
{
  NSMutableDictionary *categories;
  NSMutableArray *catviews;
  id mdindexing;
}

- (void)setMdindexing:(id)anobject;

- (void)categoryViewDidChangeState:(CategoryView *)view;

- (void)moveCategoryViewAtIndex:(int)srcind
                        toIndex:(int)dstind;

- (void)applyChanges;

- (void)revertChanges;

- (void)tile;

@end


@interface NSDictionary (CategorySort)

- (NSComparisonResult)compareAccordingToIndex:(NSDictionary *)dict;

@end

#endif // CATEGORIES_EDITOR_H

