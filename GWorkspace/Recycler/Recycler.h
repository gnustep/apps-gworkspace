/* Recycler.h
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


#ifndef RECYCLER_H
#define RECYCLER_H

#include <AppKit/NSView.h>

@class NSWindow;
@class NSImage;
@class RecyclerView;
@class LogoView;
@class IconsView;
@class NSString;
@class NSDictionary;
@class NSMutableDictionary;
@class NSMutableArray;
@class NSFileManager;
@class GWorkspace;

@interface Recycler : NSView 
{
  NSWindow *win;
  NSImage *tile, *emptyImg, *fullImg;
	BOOL isFull;
	BOOL isOpen;
  BOOL isDragTarget;
	BOOL watching;
	
	NSWindow *recyclerWin;
	RecyclerView *recyclerView;
	LogoView *logoView;
	IconsView *iconsView;
	NSMutableArray *icons;
	
	NSString *trashPath;
	NSMutableDictionary *contentsDict;
	
	NSString *selectedPath;
	
  NSFileManager *fm;
  GWorkspace *gw;  
}

- (id)initWithTrashPath:(NSString *)trashpath;

- (void)activate;

- (NSWindow *)myWin;

- (NSWindow *)recyclerWin;

- (void)makeTrashContents;

- (BOOL)isFull;

- (BOOL)isOpen;

- (NSString *)selectedPath;

- (BOOL)verifyDictionaryForFileName:(NSString *)fname;

- (void)setCurrentSelection:(NSString *)path;

- (void)updateDefaults;

- (void)saveDictionary;

- (void)fileSystemWillChange:(NSNotification *)notification;

- (void)fileSystemDidChange:(NSNotification *)notification;

- (void)setWatcher;

- (void)unsetWatcher;

- (void)watcherNotification:(NSNotification *)notification;

- (void)emptyRecycler;

- (void)putAway;

@end

@interface Recycler (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender;

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender;

- (void)draggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

@end

#endif // RECYCLER_H
