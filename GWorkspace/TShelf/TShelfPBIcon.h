/* TShelfPBIcon.h
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


#ifndef TSHELF_PB_ICON_H
#define TSHELF_ICON_H

#include <AppKit/NSView.h>

@class NSImage;
@class TShelfIconsView;

@interface TShelfPBIcon : NSView
{
  NSString *dataPath;
  NSString *dataType;

	NSImage *icon;
  NSImage *highlight;
	NSPoint position;
	int gridindex;

  TShelfIconsView *tview;

  BOOL isSelect;
}

- (id)initForPBDataAtPath:(NSString *)dpath
                   ofType:(NSString *)type
				        gridIndex:(int)index
              inIconsView:(TShelfIconsView *)aview;

- (NSString *)dataPath;

- (NSString *)dataType;

- (NSImage *)icon;

- (void)select;

- (void)unselect;

- (BOOL)isSelect;

- (void)setPosition:(NSPoint)pos;

- (NSPoint)position;

- (void)setGridIndex:(int)index;

- (int)gridindex;

@end

#endif // TSHELF_PB_ICON_H

