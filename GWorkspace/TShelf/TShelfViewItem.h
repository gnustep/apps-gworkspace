 /*
 *  TShelfViewItem.h: Interface and declarations for 
 *  the TShelfViewItem Class of the GNUstep GWorkspace application
 *
 *  Copyright (c) 2003 Enrico Sersale <enrico@dtedu.net>
 *  
 *  Author: Enrico Sersale
 *  Date: July 2003
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#ifndef TSHELF_VIEW_ITEM_H
#define TSHELF_VIEW_ITEM_H

#include <Foundation/Foundation.h>

@class NSString;
@class NSView;
@class NSColor;
@class NSImage;
@class TShelfView;

@interface TShelfViewItem : NSObject
{
  id ident;
  NSString *label;
  NSView *view;
  NSColor *color;
  NSTabState state;
  NSView *firstResponder;
  TShelfView *tview;
  NSRect rect; 
}

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

