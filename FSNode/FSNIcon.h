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
  NSImage *openicon;
  NSImage *drawicon;
  int iconSize;
  NSRect icnBounds;
  NSPoint icnPoint;
  unsigned int icnPosition;

  NSRect brImgBounds;
    
  NSBezierPath *highlightPath;
  NSRect hlightRect;
  
  FSNTextCell *label;
  NSRect labelRect;
  FSNTextCell *infolabel;
  NSRect infoRect;
  FSNInfoType showType;

  unsigned int gridIndex;
  
  BOOL isSelected;
  BOOL selectable;
  
  BOOL isOpened;
  
  BOOL nameEdited;
  BOOL isLeaf;
  BOOL isLocked;
  
  NSTimeInterval editstamp;  

  BOOL dndSource;
  BOOL acceptDnd;
  BOOL slideBack;
  int dragdelay;
  BOOL isDragTarget;
  BOOL forceCopy;
  BOOL onSelf;
  
  NSView <FSNodeRepContainer> *container;
  
  FSNodeRep *fsnodeRep;
}

+ (NSImage *)branchImage;

- (id)initForNode:(FSNode *)anode
     nodeInfoType:(FSNInfoType)type
     extendedType:(NSString *)exttype
         iconSize:(int)isize
     iconPosition:(unsigned int)ipos
        labelFont:(NSFont *)lfont
        textColor:(NSColor *)tcolor
        gridIndex:(int)gindex
        dndSource:(BOOL)dndsrc
        acceptDnd:(BOOL)dndaccept
        slideBack:(BOOL)slback;

- (void)setSelectable:(BOOL)value;

- (NSRect)iconBounds;

- (void)tile;

@end


@interface FSNIcon (DraggingSource)

- (void)startExternalDragOnEvent:(NSEvent *)event
                 withMouseOffset:(NSSize)offset;

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
  NSView <FSNodeRepContainer> *container;
}  

- (void)setNode:(FSNode *)anode 
    stringValue:(NSString *)str
          index:(int)idx;

- (FSNode *)node;

- (int)index;

@end

#endif // FSN_ICON_H
