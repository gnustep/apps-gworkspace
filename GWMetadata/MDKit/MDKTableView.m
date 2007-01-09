/* MDKTableView.m
 *  
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@fibernet.ro>
 * Date: December 2006
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "MDKTableView.h"

@implementation MDKTableView

- (void)dealloc
{
  RELEASE (controlViews);    
  [super dealloc];
}

- (id)initWithFrame:(NSRect)rect
{
  self = [super initWithFrame: rect];
  
  if (self) {
    controlViews = [NSMutableArray new];
  }
  
  return self;
}

- (void)addControlView:(NSView *)cview
{
  [controlViews addObject: cview];
  [self addSubview: cview];
  [cview setFrame: NSZeroRect];
}

- (void)removeControlView:(NSView *)cview
{
  [cview removeFromSuperview];
  [controlViews removeObject: cview];
}

- (NSImage *)dragImageForRows:(NSArray *)dragRows
			                  event:(NSEvent *)dragEvent 
	            dragImageOffset:(NSPointPointer)dragImageOffset
{
  NSImage *image = [[self delegate] tableView: self 
                             dragImageForRows: dragRows];
  if (image) {
    return image;
  }
  
  return [super dragImageForRows: dragRows
  		                     event: dragEvent 
		             dragImageOffset: dragImageOffset];
}

- (void)setFrame:(NSRect)rect
{
  int i;

  for (i = 0; i < [controlViews count]; i++) {
    [[controlViews objectAtIndex: i] setFrame: NSZeroRect];
  } 
  
  [super setFrame: rect];
}

- (void)keyDown:(NSEvent *)theEvent
{
	NSString *characters = [theEvent characters];
	unichar character = 0;

  if ([characters length] > 0) {
		character = [characters characterAtIndex: 0];
	}

  if (character == NSCarriageReturnCharacter) {    
    [self sendAction: [self doubleAction] to: [self target]];
    return;
  }      
  
  [super keyDown: theEvent];
}

@end






