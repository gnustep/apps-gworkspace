/* RecyclerView.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#ifndef RECYCLER_VIEW_H
#define RECYCLER_VIEW_H

#include <AppKit/NSView.h>
#include "Recycler.h"
#include "FSNodeRep.h"

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

- (void)nodeContentsWillChange:(NSDictionary *)info;

- (void)nodeContentsDidChange:(NSDictionary *)info;

- (void)watchedPathChanged:(NSDictionary *)info;

- (void)repSelected:(id)arep;

- (void)unselectOtherReps:(id)arep;

- (NSArray *)selectedPaths;

- (void)selectionDidChange;

- (void)setSelectionMask:(FSNSelectionMask)mask;

- (FSNSelectionMask)selectionMask;

- (void)openSelectionInNewViewer:(BOOL)newv;

- (void)restoreLastSelection;

- (BOOL)validatePasteOfFilenames:(NSArray *)names
                       wasCutted:(BOOL)cutted;

- (NSColor *)backgroundColor;

- (NSColor *)textColor;

- (NSColor *)disabledTextColor;

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender;

@end

#endif // RECYCLER_VIEW_H
