/* IconsViewerIcon.h
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


#ifndef ICONVIEWSICON_H
#define ICONVIEWSICON_H

#include <AppKit/NSView.h>

@class NSString;
@class NSArray;
@class NSMutableArray;
@class NSNotification;
@class NSEvent;
@class NSPasteboard;
@class NSTextField;
@class NSImage;
@class NSFileManager;

@interface IconsViewerIcon : NSView
{
  NSString *path;
  NSString *name;
  NSString *type;
	BOOL isPakage;
  BOOL isSelect;
  BOOL locked;
  
	NSImage *icon, *highlight;
	NSTextField *namelabel;
  int labelWidth;

  id delegate;
  int dragdelay;
  BOOL isDragTarget;
  BOOL onSelf;
  
  NSFileManager *fm;
}

- (id)initForPath:(NSString *)apath delegate:(id)adelegate;

- (void)setPath:(NSString *)apath;

- (void)select;

- (void)unselect;

- (void)renewIcon;

- (void)setLabelWidth;

- (NSTextField *)myLabel;

- (NSString *)type;

- (NSString *)path;

- (NSString *)myName;

- (NSSize)iconShift;

- (BOOL)isSelect;

- (void)setLocked:(BOOL)value;

- (BOOL)isLocked;

- (id)delegate;

- (void)setDelegate:(id)aDelegate;

@end

@interface IconsViewerIcon (DraggingSource)

- (void)startExternalDragOnEvent:(NSEvent *)event
                 withMouseOffset:(NSSize)offset;

- (void)declareAndSetShapeOnPasteboard:(NSPasteboard *)pb;

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag;

@end

@interface IconsViewerIcon (DraggingDestination)

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

@interface NSObject (IconsViewerIconDelegateMethods)

- (int)getCellsWidth;

- (void)setLabelFrameOfIcon:(id)aicon;

- (void)unselectIconsDifferentFrom:(id)aicon;

- (void)setShiftClickValue:(BOOL)value;

- (void)setTheCurrentSelection:(id)paths;

- (NSArray *)getTheCurrentSelection;

- (void)openTheCurrentSelection:(id)paths newViewer:(BOOL)newv;

- (id)menuForRightMouseEvent:(NSEvent *)theEvent;

@end

#endif // ICONVIEWSICON_H

