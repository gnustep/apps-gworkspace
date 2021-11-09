/* TShelfIcon.h
 *  
 * Copyright (C) 2003-2021 Free Software Foundation, Inc.
 *
 * Authors: Enrico Sersale <enrico@imago.ro>
 *          Riccardo Mottola <rm@gnu.org>
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

#ifndef TSHELF_ICON_H
#define TSHELF_ICON_H

#import <Foundation/Foundation.h>
#import <AppKit/NSView.h>
#import <AppKit/NSDragging.h>

#define ONICON(p, s1, s2) ([self mouse: (p) \
inRect: NSMakeRect(((int)(s1).width - (int)(s2).width) >> 1,\
((int)(s1).height - (int)(s2).height) >> 1, 48, 48)])

@class NSEvent;
@class NSPasteboard;
@class NSTextField;
@class NSImage;
@class NSBezierPath;
@class NSWorkspace;
@class TShelfIconsView;
@class FSNode;
@class FSNodeRep;
@class GWorkspace;

@interface TShelfIcon : NSView
{
  NSMutableArray *paths;
  NSString *name;
  NSString *hostname;
  FSNode *node;
  BOOL singlepath;
  BOOL isRootIcon;
  BOOL isSelected;
  BOOL locked;
  
  NSImage *icon;
  NSTextField *namelabel;  
  NSBezierPath *highlightPath;
  NSPoint position;
  NSUInteger gridIndex;
  int labelWidth;
  NSTrackingRectTag trectTag;
  
  TShelfIconsView *tview;
  
  FSNodeRep *fsnodeRep;
  NSFileManager *fm;
  GWorkspace *gw;
  
  int dragDelay;
  BOOL isDragTarget;
  BOOL forceCopy;
  BOOL onSelf;
  int minimumLaunchClicks;
}

- (id)initForPaths:(NSArray *)fpaths 
       inIconsView:(TShelfIconsView *)aview;

- (id)initForPaths:(NSArray *)fpaths 
        atPosition:(NSPoint)pos
       inIconsView:(TShelfIconsView *)aview;

- (id)initForPaths:(NSArray *)fpaths 
	 gridIndex:(NSUInteger)index
       inIconsView:(TShelfIconsView *)aview;

- (void)setPaths:(NSArray *)fpaths;

- (void)select;

- (void)unselect;

- (void)renewIcon;

- (void)setLabelWidth;

- (void)setPosition:(NSPoint)pos;

- (void)setPosition:(NSPoint)pos gridIndex:(NSUInteger)index;

- (NSPoint)position;

- (void)setGridIndex:(NSUInteger)index;

- (NSUInteger)gridIndex;

- (NSTextField *)myLabel;

- (NSString *)shownName;

- (NSArray *)paths;

- (BOOL)isSinglePath;

- (BOOL)isSelected;

- (void)setLocked:(BOOL)value;

- (BOOL)isLocked;

- (void)setSingleClickLaunch:(BOOL)value;

@end

@interface TShelfIcon (DraggingSource)

- (void)startExternalDragOnEvent:(NSEvent *)event
                 withMouseOffset:(NSSize)offset;

- (void)declareAndSetShapeOnPasteboard:(NSPasteboard *)pb;

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)flag;

- (void)draggedImage:(NSImage *)anImage 
             endedAt:(NSPoint)aPoint 
           deposited:(BOOL)flag;

@end

@interface TShelfIcon (DraggingDestination)

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender;

- (void)draggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

@end

#endif // TSHELF_ICON_H

