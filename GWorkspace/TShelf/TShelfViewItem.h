 /* TShelfViewItem.h
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

#ifndef TSHELF_VIEW_ITEM_H
#define TSHELF_VIEW_ITEM_H

#ifndef FILES_TAB
  #define FILES_TAB 0
  #define DATA_TAB 1
#endif

#include <Foundation/Foundation.h>

@class NSString;
@class NSView;
@class NSColor;
@class NSFont;
@class NSImage;
@class TShelfView;

@interface TShelfViewItem : NSObject
{
  id ident;
  int tabtype;
  NSString *label;
  NSFont *labfont;
  NSView *view;
  NSColor *color;
  NSTabState state;
  NSView *firstResponder;
  TShelfView *tview;
  NSRect rect; 
}

- (id)initWithTabType:(int)type;

- (void)setLabel:(NSString *)labstr;
- (NSString *)label;
- (NSSize)sizeOfLabel:(NSString *)str;

- (void)setView:(NSView *)v;
- (NSView *)view;

- (void)setColor:(NSColor *)clr;
- (NSColor *)color;

- (NSTabState)tabState;
- (TShelfView *)tView;

- (void)setTabState:(NSTabState)tabState;
- (void)setTShelfView:(TShelfView *)tView;
- (NSRect)tabRect;
- (NSString *)truncatedLabelAtLenght:(float)lenght;

- (void)setInitialFirstResponder:(NSView *)v;
- (id)initialFirstResponder;

- (void)drawLabelInRect:(NSRect)tabRect;
- (void)drawImage:(NSImage *)image inRect:(NSRect)tabRect;

@end

#endif // TSHELF_VIEW_ITEM_H

