/* BIcon.h
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


#ifndef BICON_H
#define BICON_H

#include <AppKit/NSView.h>

#define ICONPOSITION(s1, s2) (NSMakePoint(((int)(s1).width - (int)(s2).width) >> 1, \
((int)(s1).height - (int)(s2).height) >> 1))

#define ONICON(p, s1, s2) ([self mouse: (p) \
inRect: NSMakeRect(((int)(s1).width - (int)(s2).width) >> 1,\
((int)(s1).height - (int)(s2).height) >> 1, 48, 48)])

@class NSString;
@class NSArray;
@class NSFileManager;
@class NSEvent;
@class NSPasteboard;
@class NSImage;
@class NSTextField;
@class BIconLabel;

@interface BIcon : NSView
{
  NSArray *paths;
  NSString *fullpath;
  NSString *name;
  NSString *hostname;
	
	BOOL isRootIcon;	
  BOOL singlepath;
  NSString *type;
	BOOL isPakage;
  BOOL isbranch;
  BOOL dimmed;
  BOOL locked;

	NSImage *icon, *highlight, *arrow;  
	BIconLabel *namelabel;	
      
  id delegate;
  
  BOOL isSelect;
  BOOL contestualMenu;

  int dragdelay;
  BOOL isDragTarget;
  BOOL onSelf;

  NSFileManager *fm;
}  

- (void)setDelegate:(id)aDelegate;

- (id)delegate;

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

- (void)setBranch:(BOOL)value;

- (BOOL)isBranch;

- (void)setDimmed:(BOOL)value;

- (BOOL)isDimmed;

- (void)setLocked:(BOOL)value;

- (BOOL)isLocked;

- (BOOL)isRootIcon;

- (NSArray *)paths;

- (NSString *)name;

- (NSString *)hostname;

- (NSImage *)icon;

- (NSSize)iconShift;

@end


@interface BIcon (DraggingSource)

- (void)startExternalDragOnEvent:(NSEvent *)event
                 withMouseOffset:(NSSize)offset;

- (void)declareAndSetShapeOnPasteboard:(NSPasteboard *)pb;

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag;

- (void)draggedImage:(NSImage *)anImage 
						 endedAt:(NSPoint)aPoint 
					 deposited:(BOOL)flag;

@end


@interface BIcon (DraggingDestination)

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

@interface NSObject (BIconDelegateMethods)

- (void)icon:(BIcon *)sender setFrameOfLabel:(NSTextField *)label;

- (void)unselectOtherIcons:(BIcon *)selicon;

- (void)unselectNameEditor;

- (void)restoreSelectionAfterDndOfIcon:(BIcon *)dndicon;

- (void)clickOnIcon:(BIcon *)clicked;

- (void)doubleClickOnIcon:(BIcon *)clicked newViewer:(BOOL)isnew;

@end

#endif // BICON_H
