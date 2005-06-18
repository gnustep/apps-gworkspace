/* IconLabel.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
 *
 * This file is part of the GNUstep GWNet application
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
#include "IconLabel.h"
#include "Icon.h"
#include "GNUstep.h"

@implementation IconLabel

- (void)dealloc
{
  [super dealloc];
}

- (id)initForIcon:(id)icn
{
  self = [super init];
  icon = (Icon *)icn;
	[self setDelegate: icn];
  return self;  
}

- (void)mouseDown:(NSEvent*)theEvent
{
  if ([icon isSelect] == NO) {
    [icon clickOnLabel];
    return;
  }
  
  [super mouseDown: theEvent];
}

- (void)setFrame:(NSRect)frameRect
{
	if (frameRect.size.width < 0) {
		frameRect.size.width = 0; 
	}
	if (frameRect.size.height < 0) {
		frameRect.size.height = 0;
	}
	[super setFrame: frameRect];
}

- (void)drawRect:(NSRect)rect
{
  if ([icon isDimmed]) {
    return;
  }
  
  [super drawRect: rect];
}

@end
