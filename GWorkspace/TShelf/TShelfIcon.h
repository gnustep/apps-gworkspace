/* TShelfIcon.h
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

#ifndef TSHELF_ICON_H
#define TSHELF_ICON_H

#include <AppKit/NSView.h>

#define ONICON(p, s1, s2) ([self mouse: (p) \
inRect: NSMakeRect(((int)(s1).width - (int)(s2).width) >> 1,\
((int)(s1).height - (int)(s2).height) >> 1, 48, 48)])

@class NSString;
@class NSArray;
@class NSMutableArray;
@class NSNotification;
@class NSEvent;
@class NSPasteboard;
@class NSTextField;
@class NSImage;
@class NSFileManager;
@class NSWorkspace;
@class TShelfIconsView;
@class GWorkspace;

@interface TShelfIcon : NSView
{
  NSMutableArray *paths;
  NSString *fullPath;
  NSString *name;
	NSString *hostname;
  BOOL singlepath;
	BOOL isRootIcon;	
	BOOL isPakage;	
  NSString *type;
  BOOL isSelect;
  BOOL locked;
  
	NSImage *icon, *highlight;
	NSTextField *namelabel;
	NSPoint position;
	int gridindex;
  int labelWidth;

  TShelfIconsView *tview;
  
  NSFileManager *fm;
	NSWorkspace *ws;
  GWorkspace *gw;
  
  int dragdelay;
  BOOL isDragTarget;
  BOOL onSelf;
}

- (id)initForPaths:(NSArray *)fpaths 
       inIconsView:(TShelfIconsView *)aview;

- (id)initForPaths:(NSArray *)fpaths 
        atPosition:(NSPoint)pos
       inIconsView:(TShelfIconsView *)aview;

- (id)initForPaths:(NSArray *)fpaths 
				 gridIndex:(int)index
       inIconsView:(TShelfIconsView *)aview;

- (void)setPaths:(NSArray *)fpaths;

- (void)select;

- (void)unselect;

- (void)renewIcon;

- (void)setLabelWidth;

- (void)setPosition:(NSPoint)pos;

- (void)setPosition:(NSPoint)pos gridIndex:(int)index;

- (NSPoint)position;

- (void)setGridIndex:(int)index;

- (int)gridindex;

- (NSTextField *)myLabel;

- (NSString *)type;

- (NSArray *)paths;

- (NSString *)name;

- (NSString *)hostname;

- (BOOL)isSinglePath;

- (BOOL)isSelect;

- (void)setLocked:(BOOL)value;

- (BOOL)isLocked;

- (BOOL)isRootIcon;

- (BOOL)isPakage;

@end

@interface TShelfIcon (DraggingSource)

- (void)startExternalDragOnEvent:(NSEvent *)event
                 withMouseOffset:(NSSize)offset;

- (void)declareAndSetShapeOnPasteboard:(NSPasteboard *)pb;

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag;

- (void)draggedImage:(NSImage *)anImage 
						 endedAt:(NSPoint)aPoint 
					 deposited:(BOOL)flag;

@end

@interface TShelfIcon (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender;

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender;

- (void)draggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

@end

#endif // TSHELF_ICON_H

