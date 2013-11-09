/* RecyclerView.h
 *  
 * Copyright (C) 2004-2013 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: June 2004
 *
 * This file is part of the GNUstep Recycler application
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

#import <AppKit/NSView.h>
#import "Recycler.h"
#import "FSNodeRep.h"

@class NSImage;
@class RecyclerIcon;

@interface RecyclerWindow : NSWindow 
{
  id icon;
}

- (void)setRecyclerIcon:(id)icn;

@end

@interface RecyclerView : NSView
{
  RecyclerWindow *win;
  RecyclerIcon *icon;
  NSImage *tile;
  Recycler *recycler;  
}

- (id)initWithWindow;

- (void)activate;

- (RecyclerIcon *)trashIcon;

- (void)updateDefaults;

@end


@interface RecyclerView (NodeRepContainer)

- (void)nodeContentsDidChange:(NSDictionary *)info;

- (void)watchedPathChanged:(NSDictionary *)info;

- (FSNSelectionMask)selectionMask;

- (BOOL)validatePasteOfFilenames:(NSArray *)names
                       wasCut:(BOOL)cut;

- (NSColor *)backgroundColor;

- (NSColor *)textColor;

- (NSColor *)disabledTextColor;

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender;

@end

