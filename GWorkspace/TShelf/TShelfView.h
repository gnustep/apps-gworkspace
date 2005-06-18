/* TShelfView.h
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#ifndef TABBED_SHELF_VIEW_H
#define TABBED_SHELF_VIEW_H
 
#include <AppKit/NSView.h>

@class NSFont;
@class NSImage;
@class TShelfViewItem;
@class NSButton;

@interface TShelfView : NSView 
{
  NSMutableArray *items;
  TShelfViewItem *lastItem;
  NSFont *font;
  NSFont *italicFont;
  TShelfViewItem *selected;
  int selectedItem;
  NSButton *ffButt, *rewButt;
}

- (void)addTabItem:(TShelfViewItem *)item;

- (BOOL)insertTabItem:(TShelfViewItem *)item
		          atIndex:(int)index;

- (void)setLastTabItem:(TShelfViewItem *)item;
                  
- (BOOL)removeTabItem:(TShelfViewItem *)item;

- (int)indexOfItem:(TShelfViewItem *)item;

- (void)selectTabItem:(TShelfViewItem *)item;

- (void)selectTabItemAtIndex:(int)index;

- (void)selectLastItem;

- (TShelfViewItem *)selectedTabItem;

- (TShelfViewItem *)tabItemAtPoint:(NSPoint)point;

- (TShelfViewItem *)lastTabItem;

- (NSArray *)items;

- (void)buttonsAction:(id)sender;

- (void)setButtonsEnabled:(BOOL)enabled;

- (NSFont *)font;

- (NSFont *)italicFont;

- (NSRect)contentRect;

@end

#endif // TABBED_SHELF_VIEW_H

