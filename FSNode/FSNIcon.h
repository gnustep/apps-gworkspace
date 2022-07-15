/* FSNIcon.h
 *  
 * Copyright (C) 2004-2022 Free Software Foundation, Inc.
 *
 * Authors: Enrico Sersale <enrico@imago.ro>
 *          Riccardo Mottola <rm@gnu.org>
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#ifndef FSN_ICON_H
#define FSN_ICON_H

#import <Foundation/Foundation.h>
#import <AppKit/NSView.h>
#import "FSNodeRep.h"

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
  NSImage *selectedicon;
  NSImage *drawicon;
  int iconSize;
  NSRect icnBounds;
  NSPoint icnPoint;
  NSUInteger icnPosition;

  NSRect brImgBounds;
    
  NSBezierPath *highlightPath;
  NSRect hlightRect;
  
  NSTrackingRectTag trectTag;
  
  FSNTextCell *label;
  NSRect labelRect;
  BOOL drawLabelBackground;
  NSColor *labelFrameColor;
  FSNTextCell *infolabel;
  NSRect infoRect;
  FSNInfoType showType;

  NSUInteger gridIndex;
  
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
  BOOL onApplication;
  BOOL onSelf;
  
  NSView <FSNodeRepContainer> *container;
  
  FSNodeRep *fsnodeRep;
}

+ (NSImage *)branchImage;

- (id)initForNode:(FSNode *)anode
     nodeInfoType:(FSNInfoType)type
     extendedType:(NSString *)exttype
         iconSize:(int)isize
     iconPosition:(NSUInteger)ipos
        labelFont:(NSFont *)lfont
        textColor:(NSColor *)tcolor
        gridIndex:(NSUInteger)gindex
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

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)flag;

- (void)draggedImage:(NSImage *)anImage 
	     endedAt:(NSPoint)aPoint 
	   deposited:(BOOL)flag;

@end


@interface FSNIcon (DraggingDestination)

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender;

- (void)draggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

@end


@interface FSNIconNameEditor : NSTextField
{
  FSNode *node;
  NSView <FSNodeRepContainer> *container;
}  

- (void)setNode:(FSNode *)anode 
    stringValue:(NSString *)str;

- (FSNode *)node;


@end

#endif // FSN_ICON_H
