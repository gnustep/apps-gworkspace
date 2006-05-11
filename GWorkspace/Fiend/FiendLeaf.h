/* FiendLeaf.h
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#ifndef FIENDLEAF_H
#define FIENDLEAF_H

#include <Foundation/Foundation.h>
#include <AppKit/NSView.h>

@class NSImage;
@class NSTextFieldCell;
@class Fiend;
@class NSWorkspace;
@class GWorkspace;
@class FSNode;

@interface LeafPosition : NSObject 
{
  NSRect r;
  int posx, posy;
}

- (id)initWithPosX:(int)px posY:(int)py relativeToPoint:(NSPoint)p;

- (NSRect)lfrect;

- (int)posx;

- (int)posy;

- (BOOL)containsPoint:(NSPoint)p;

@end


@interface FiendLeaf : NSView
{
  FSNode *node;
  NSString *layerName;
  NSImage *tile, *hightile, *icon;
	NSTextFieldCell *namelabel;
  	
	BOOL isGhost;
  BOOL isDragTarget;
  BOOL forceCopy;  
  int posx, posy;
	
  NSTimer *dissTimer;
  float dissFraction;	
	int dissCounter;
	BOOL dissolving;

  NSFileManager *fm;
	NSWorkspace *ws;
  GWorkspace *gw;
  Fiend *fiend;
}

- (id)initWithPosX:(int)px
              posY:(int)py
   relativeToPoint:(NSPoint)p
           forPath:(NSString *)apath
           inFiend:(Fiend *)afiend 
         layerName:(NSString *)lname 
        ghostImage:(NSImage *)ghostimage;

- (void)setPosX:(int)px posY:(int)py relativeToPoint:(NSPoint)p;

- (int)posx;

- (int)posy;

- (NSPoint)iconPosition;

- (FSNode *)node;

- (NSImage *)icon;

- (NSString *)layerName;

- (void)startDissolve;

- (BOOL)dissolveAndReturnWhenDone;

@end

@interface FiendLeaf (DraggingDestination)

- (BOOL)isDragTarget;

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender;

- (void)draggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

@end

#endif // FIENDLEAF_H

