/* ClipBookWindow.h
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: October 2003
 *
 * This file is part of the GNUstep ClipBook application
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

#ifndef CLIP_BOOK_WINDOW_H
#define CLIP_BOOK_WINDOW_H

#include <Foundation/Foundation.h>

@class NSBox;
@class NSImageView;
@class ClipBook;
@class PBViewer;
@class PBIconView;

@interface ClipBookWindow : NSObject
{
  IBOutlet id win;

  IBOutlet id elementsField;
  IBOutlet id totalSizeField;
  IBOutlet id showHideButt;

  IBOutlet id viewersBox;
  NSRect viewerRect;
     
  IBOutlet id iconBox;
  PBIconView *iconView;
  IBOutlet id pbIndexField;
  IBOutlet id pbSizeField;
  IBOutlet id pbNameField;
 
  IBOutlet id fwdButt;
  IBOutlet id bckwButt; 
  
  NSArray *dataTypes;
  
  PBViewer *viewer;
  NSBox *emptyBox;
  NSBox *invalidBox;
  
  ClipBook *clipbook;
  NSString *pbdir;
  NSString *pbDescrName;
  NSString *pbDescrPath;
  NSMutableArray *pbDescr;
  int index;
  
  BOOL hideContents;
  BOOL isDragTarget;
  
  NSFileManager *fm;
}

- (void)activate;

- (NSData *)readSelectionFromPasteboard:(NSPasteboard *)pboard 
                                 ofType:(NSString **)pbtype;
- (void)doCut;

- (void)doCopy;

- (void)doPaste;

- (void)showPbData;

- (NSData *)currentPBDataOfType:(NSString **)dtype;

- (IBAction)forwardBackwardAction:(id)sender;

- (void)showNext:(BOOL)fwd;

- (void)checkStoredData;

- (void)showPbInfo:(NSDictionary *)info;

- (void)updateTotalSizeLabels;

- (IBAction)showHideContents:(id)sender;

- (void)updateDefaults;

- (id)myWin;

@end

@interface ClipBookWindow (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender;

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender;

- (void)draggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

@end


@interface PBIconView : NSImageView
{
  int dragdelay;
}

@end

@interface PBIconView (DraggingSource)

- (void)startExternalDragOnEvent:(NSEvent *)event;

- (BOOL)declareAndSetShapeOnPasteboard:(NSPasteboard *)pb;

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag;

- (void)draggedImage:(NSImage *)anImage 
						 endedAt:(NSPoint)aPoint 
					 deposited:(BOOL)flag;

@end

#endif // CLIP_BOOK_WINDOW_H




