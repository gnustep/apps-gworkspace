/* PathIcon.h
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


#ifndef PATHICON_H
#define PATHICON_H

#include <AppKit/NSView.h>

@class NSString;
@class NSArray;
@class NSPasteboard;
@class NSEvent;
@class NSImage;
@class NSFileManager;
@class NSWorkspace;
@class PathIconLabel;
@class NSTextField;

@interface PathIcon : NSView
{
  NSArray *paths;
  NSString *fullpath;
  NSString *name;
  NSString *hostname;
  
	BOOL isRootIcon;	
	BOOL isPakage;
  BOOL singlepath;
  NSString *type;
  BOOL isbranch;
  BOOL locked;
  
	NSImage *icon, *highlight, *arrow;  
	PathIconLabel *namelabel;	
      
  id delegate;
  id gworkspace;
  
  BOOL isSelect;

  int dragdelay;
  BOOL isDragTarget;

  BOOL contestualMenu;

  NSFileManager *fm;
	NSWorkspace *ws;
}  

- (id)initWithDelegate:(id)aDelegate;

- (void)setPaths:(NSArray *)p;

- (void)select;

- (void)unselect;

- (void)renewIcon;

- (void)openWithApp:(id)sender;

- (void)openWith:(id)sender;

- (NSTextField *)label;

- (void)clickOnLabel;

- (NSString *)type;

- (BOOL)isSinglePath;

- (BOOL)isSelect;

- (void)setPaths:(NSArray *)paths;

- (void)setBranch:(BOOL)value;

- (BOOL)isBranch;

- (void)setLocked:(BOOL)value;

- (BOOL)isLocked;

- (BOOL)isRootIcon;

- (BOOL)isPakage;

- (NSArray *)paths;

- (NSString *)name;

- (NSString *)hostname;

- (NSImage *)icon;

- (NSSize)iconShift;

- (BOOL)isSinglePath;

- (id)delegate;

- (void)setDelegate:(id)aDelegate;

@end


@interface PathIcon (DraggingSource)

- (void)startExternalDragOnEvent:(NSEvent *)event;

- (void)declareAndSetShapeOnPasteboard:(NSPasteboard *)pb;

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag;

@end

@interface PathIcon (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender;

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender;

- (void)draggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

@end

//
// Methods Implemented by the Delegate 
//

@interface NSObject (PathIconDelegateMethods)

- (void)setLabelFrameOfIcon:(id)anicon;

- (void)unselectIconsDifferentFrom:(id)anicon;

- (void)clickedIcon:(id)anicon;

- (void)doubleClickedIcon:(id)anicon newViewer:(BOOL)isnew;

- (void)unselectNameEditor;

- (void)restoreSelectionAfterDndOfIcon:(id)dndicon;

@end

#endif // PATHICON_H
