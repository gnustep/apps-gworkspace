/*
 *  SmallIcon.h: Interface and declarations for the SmallIcon Class 
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

#ifndef SMALLICON_H
#define SMALLICON_H

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
@class SmallIconLabel;

@interface SmallIcon : NSView
{
  NSString *path;
  NSString *name;
  NSString *type;
	BOOL isPakage;
  BOOL isSelect;
  BOOL locked;
  NSString *watched;
  
	NSImage *icon, *highlight;
	SmallIconLabel *namelabel;
  int labelWidth;
	NSPoint position;
	NSPoint center;
	int gridindex;

  id delegate;
  id gworkspace;
  int dragdelay;
  BOOL isDragTarget;
  BOOL onSelf;
  
  NSFileManager *fm;
}

- (id)initForPath:(NSString *)apath delegate:(id)adelegate;

- (id)initForPath:(NSString *)apath 
				gridIndex:(int)index 
				 delegate:(id)adelegate;

- (void)setPath:(NSString *)apath;

- (void)select;

- (void)unselect;

- (void)clickOnLabel;

- (void)setLabelFrame;

- (void)setPosition:(NSPoint)pos;

- (void)setPosition:(NSPoint)pos gridIndex:(int)index;

- (NSPoint)position;

- (NSPoint)center;

- (void)setGridIndex:(int)index;

- (int)gridindex;

- (NSTextField *)label;

- (NSString *)type;

- (NSString *)path;

- (NSString *)myName;

- (int)labelWidth;

- (NSSize)iconShift;

- (BOOL)isSelect;

- (void)setLocked:(BOOL)value;

- (BOOL)isLocked;

- (id)delegate;

- (void)setDelegate:(id)aDelegate;

@end

@interface SmallIcon (DraggingSource)

- (void)startExternalDragOnEvent:(NSEvent *)event;

- (void)declareAndSetShapeOnPasteboard:(NSPasteboard *)pb;

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag;

@end

@interface SmallIcon (DraggingDestination)

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
@interface NSObject (SmallIconDelegateMethods)

- (void)unselectIconsDifferentFrom:(id)aicon;

- (void)setShiftClickValue:(BOOL)value;

- (void)setTheCurrentSelection;

- (NSArray *)getTheCurrentSelection;

- (void)openTheCurrentSelection:(id)paths newViewer:(BOOL)newv;

- (id)menuForRightMouseEvent:(NSEvent *)theEvent;

@end

#endif // SMALLICON_H

