/*
 *  RecyclerWindow.h: Interface and declarations for the RecyclerWindow Class 
 *  of the GNUstep GWorkspace application
 *
 *  Copyright (c) 2001 Enrico Sersale <enrico@imago.ro>
 *  
 *  Author: Enrico Sersale
 *  Date: August 2001
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

#ifndef RECYCLER_WINDOW_H
#define RECYCLER_WINDOW_H

#include <AppKit/NSView.h>

@class NSImage;
@class NSFileManager;
@class GWorkspace;
@class Recycler;
@class RecyclerIcon;

@interface RecyclerView : NSView 
{
}
@end

@interface LogoView : NSView 
{
	NSImage *fullImg, *emptyImg;
	BOOL isFull;
}

- (void)setIsFull:(BOOL)value;

@end

@interface IconsView : NSView 
{
	NSMutableArray *icons; 
	int cellsWidth;
	Recycler *recicler;
  NSFileManager *fm;
  GWorkspace *gw;
}

- (id)initForRecycler:(Recycler *)rec;

- (void)addIcon:(RecyclerIcon *)icon;

- (void)removeIcon:(RecyclerIcon *)icon;

- (void)setLabelRectOfIcon:(RecyclerIcon *)icon;

- (void)unselectOtherIcons:(id)icon;

- (void)setCurrentSelection:(NSString *)path;

- (NSArray *)icons;

- (int)cellsWidth;

- (void)cellsWidthChanged:(NSNotification *)notification;

@end

#endif // RECYCLER_WINDOW_H
