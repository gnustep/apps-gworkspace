/*
 *  IconViewsIcon.h: Interface and declarations for the IconViewsIcon Class 
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

#ifndef ICONVIEWSICON_H
#define ICONVIEWSICON_H

#include <AppKit/NSView.h>
  #ifdef GNUSTEP 
#include "IconViewsProtocol.h"
  #else
#include <GWorkspace/IconViewsProtocol.h>
  #endif

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
@class GWorkspace;

@interface IconViewsIcon : NSView
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
  BOOL contestualMenu;
  
	NSImage *icon, *highlight;
	NSTextField *namelabel;
	NSPoint position;
	int gridindex;
  int labelWidth;

  id <IconViewsProtocol> container;
  
  NSFileManager *fm;
	NSWorkspace *ws;
  GWorkspace *gw;
  
  id delegate;
  int dragdelay;
  BOOL isDragTarget;
  BOOL onSelf;
}

- (id)initForPaths:(NSArray *)fpaths 
       inContainer:(id <IconViewsProtocol>)acontainer;

- (id)initForPaths:(NSArray *)fpaths 
        atPosition:(NSPoint)pos
       inContainer:(id <IconViewsProtocol>)acontainer;

- (id)initForPaths:(NSArray *)fpaths 
				 gridIndex:(int)index
       inContainer:(id <IconViewsProtocol>)acontainer;

- (void)setPaths:(NSArray *)fpaths;

- (void)select;

- (void)unselect;

- (void)renewIcon;

- (void)openWithApp:(id)sender;

- (void)openWith:(id)sender;

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

@interface IconViewsIcon (DraggingSource)

- (void)startExternalDragOnEvent:(NSEvent *)event;

- (void)declareAndSetShapeOnPasteboard:(NSPasteboard *)pb;

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag;

- (void)draggedImage:(NSImage *)anImage 
						 endedAt:(NSPoint)aPoint 
					 deposited:(BOOL)flag;

@end

@interface IconViewsIcon (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender;

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender;

- (void)draggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

@end

@interface ShelfIcon : IconViewsIcon
{
}

@end

@interface FinderShelfIcon : IconViewsIcon
{
}

@end

@interface DesktopViewIcon : ShelfIcon
{
}

- (void)unselectFromTimer:(id)sender;

@end

#endif // ICONVIEWSICON_H

