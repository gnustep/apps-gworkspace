/* FSNIcon.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
 *
 * This file is part of the GNUstep FSNode framework
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

#ifndef FSN_ICON_H
#define FSN_ICON_H

#include <Foundation/Foundation.h>
#include <AppKit/NSView.h>
#include "FSNodeRep.h"

@class NSImage;
@class NSFont;
@class NSBezierPath;
@class NSTextField;
@class FSNode;
@class FSNTextCell;

@interface FSNIcon : NSView <FSNodeRep>
{
  FSNode *node;
  NSString *hostname;
  NSArray *selection;
  NSString *selectionTitle;
  NSString *extInfoType;
  
  NSImage *icon;
  int iconSize;
  NSRect icnBounds;
  NSPoint icnPoint;
  unsigned int icnPosition;

  NSRect brImgBounds;
    
  NSBezierPath *highlightPath;
  NSRect hlightRect;
  
  FSNTextCell *label;
  NSRect labelRect;
  FSNInfoType showType;

  unsigned int gridIndex;
  
  BOOL isSelected;
  BOOL selectable;
  
  BOOL nameEdited;
  BOOL isLeaf;
  BOOL isLocked;
  
  BOOL dndSource;
  BOOL acceptDnd;
  int dragdelay;
  BOOL isDragTarget;
  BOOL onSelf;
  
  NSView <FSNodeRepContainer> *container;
}

+ (NSImage *)branchImage;

- (id)initForNode:(FSNode *)anode
     nodeInfoType:(FSNInfoType)type
     extendedType: (NSString *)exttype
         iconSize:(int)isize
     iconPosition:(unsigned int)ipos
        labelFont:(NSFont *)lfont
        gridIndex:(int)gindex
        dndSource:(BOOL)dndsrc
        acceptDnd:(BOOL)dndaccept;

- (void)setSelectable:(BOOL)value;

- (void)select;

- (void)unselect;

- (BOOL)isSelected;

- (NSRect)iconBounds;

- (void)tile;

@end


@interface FSNIcon (DraggingSource)

- (void)startExternalDragOnEvent:(NSEvent *)event;

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag;

- (void)draggedImage:(NSImage *)anImage 
						 endedAt:(NSPoint)aPoint 
					 deposited:(BOOL)flag;

@end


@interface FSNIcon (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender;

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender;

- (void)draggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

@end


@interface FSNIconNameEditor : NSTextField
{
  FSNode *node;
  int index;
}  

- (void)setNode:(FSNode *)anode 
    stringValue:(NSString *)str
          index:(int)idx;

- (FSNode *)node;

- (int)index;

@end

#endif // FSN_ICON_H
