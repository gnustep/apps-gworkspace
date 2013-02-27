/* MDKResultCell.m
 *  
 * Copyright (C) 2006-2013 Free Software Foundation, Inc.
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
#include "MDKResultCell.h"

@implementation MDKResultCell

- (void)dealloc
{
  TEST_RELEASE (icon);  
  [super dealloc];
}

- (id)init
{
  self = [super init];

  if (self) {
    icon = nil;
    headCell = NO;
  }

  return self;
}

- (id)copyWithZone:(NSZone *)zone
{
  MDKResultCell *c = [super copyWithZone: zone];

  c->headCell = headCell;  
  TEST_RETAIN (icon);
  
  return c;
}

- (void)setIcon:(NSImage *)icn
{
  ASSIGN (icon, icn);
}

- (void)setHeadCell:(BOOL)value
{
  headCell = value;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame 
		                   inView:(NSView *)controlView
{
  if (headCell == NO) {
    NSRect title_rect = cellFrame;

  #define MARGIN (2.0)

    if (icon == nil) {
      [super drawInteriorWithFrame: title_rect inView: controlView];
      return;
      
    } else {
      NSRect icon_rect;    

      icon_rect.origin = cellFrame.origin;
      icon_rect.size = [icon size];
      icon_rect.origin.x += MARGIN;
      icon_rect.origin.y += ((cellFrame.size.height - icon_rect.size.height) / 2.0);
      if ([controlView isFlipped]) {
	      icon_rect.origin.y += icon_rect.size.height;
      }

      title_rect.origin.x += (icon_rect.size.width + (MARGIN * 2));	
      title_rect.size.width -= (icon_rect.size.width + (MARGIN * 2));	

      [super drawInteriorWithFrame: title_rect inView: controlView];

      [icon compositeToPoint: icon_rect.origin 
	                 operation: NSCompositeSourceOver];
    }
  
  } else {
    [[NSColor blueColor] set];
    NSRectFill(cellFrame);
  }
}

- (BOOL)startTrackingAt:(NSPoint)startPoint inView:(NSView *)controlView
{
  return NO;
}

@end
