/* FSNIconsView.h
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

#ifndef FSN_ICONS_VIEW_H
#define FSN_ICONS_VIEW_H

#include <Foundation/Foundation.h>
#include <AppKit/NSView.h>
#include "FSNodeRep.h"

@class NSColor;
@class NSFont;
@class FSNode;
@class FSNIcon;
@class FSNIconNameEditor;

@interface FSNIconsView : NSView <FSNodeRepContainer>
{
  FSNode *node;
  NSString *infoPath;
  NSMutableArray *icons;
  FSNInfoType infoType;
  NSString *extInfoType;
  
  NSImage *verticalImage;
  NSImage *horizontalImage;

  FSNSelectionMask selectionMask;
  NSArray *lastSelection;

  FSNIconNameEditor *nameEditor;
  FSNIcon *editIcon;

  int iconSize;
  int labelTextSize;
  NSFont *labelFont;
  int iconPosition;

  NSSize gridSize;
  int colcount;

	BOOL isDragTarget;

  NSString *charBuffer;	
	NSTimeInterval lastKeyPressed;
  
  NSColor *backColor;

  id <DesktopApplication> desktopApp;
}

- (void)sortIcons;

- (NSDictionary *)readNodeInfo;

- (void)updateNodeInfo;

- (void)calculateGridSize;

- (void)tile;

- (void)scrollIconToVisible:(FSNIcon *)icon;

- (NSString *)selectIconWithPrefix:(NSString *)prefix;

- (void)selectIconInPrevLine;

- (void)selectIconInNextLine;

- (void)selectPrevIcon;

- (void)selectNextIcon;

@end


@interface FSNIconsView (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender;

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender;

- (void)draggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

@end


@interface FSNIconsView (IconNameEditing)

- (void)updateNameEditor;

- (void)controlTextDidChange:(NSNotification *)aNotification;

- (void)controlTextDidEndEditing:(NSNotification *)aNotification;

- (BOOL)fileManager:(NSFileManager *)manager 
              shouldProceedAfterError:(NSDictionary *)errorDict;

- (void)fileManager:(NSFileManager *)manager willProcessPath:(NSString *)path;

@end

#endif // FSN_ICONS_VIEW_H
