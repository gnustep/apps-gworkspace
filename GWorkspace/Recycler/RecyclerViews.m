/* RecyclerViews.m
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
  #ifdef GNUSTEP 
#include "GWLib.h"
#include "GWFunctions.h"
#include "GWNotifications.h"
  #else
#include <GWorkspace/GWLib.h>
#include <GWorkspace/GWFunctions.h>
#include <GWorkspace/GWNotifications.h>
  #endif
#include "RecyclerViews.h"
#include "RecyclerIcon.h"
#include "Recycler.h"
#include "GWorkspace.h"
#include "GNUstep.h"

@implementation LogoView

- (void)dealloc
{
	RELEASE (emptyImg);
	RELEASE (fullImg);
	[super dealloc];
}

- (id)init
{
	self = [super init];
	ASSIGN (emptyImg, [NSImage imageNamed: @"Recycler.tiff"]);
	ASSIGN (fullImg, [NSImage imageNamed: @"RecyclerFull.tiff"]);
	isFull = NO;
	return self;
}

- (void)setIsFull:(BOOL)value
{
	isFull = value;
	[self setNeedsDisplay: YES];
}

- (void)drawRect:(NSRect)rect
{
  [self lockFocus];
	
	STROKE_LINE (darkGrayColor, 90, 0, 90, 100);
	STROKE_LINE (whiteColor, 91, 0, 91, 100);
	
	if (isFull) {
		[fullImg compositeToPoint: NSMakePoint(21, 21) operation: NSCompositeSourceOver]; 
	} else {
		[emptyImg compositeToPoint: NSMakePoint(21, 21) operation: NSCompositeSourceOver]; 
	}
  [self unlockFocus];  
}

@end


@implementation IconsView

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
	RELEASE (icons);  
  [super dealloc];
}

- (id)initForRecycler:(Recycler *)rec
{
	self = [super init];
	
	if (self) {	
		recicler = rec;
		
    fm = [NSFileManager defaultManager];
    gw = [GWorkspace gworkspace];
    
    cellsWidth = [gw shelfCellsWidth];
    
		icons = [[NSMutableArray alloc] initWithCapacity: 1];

    [[NSNotificationCenter defaultCenter] addObserver: self 
                				  selector: @selector(cellsWidthChanged:) 
                					    name: GWShelfCellsWidthChangedNotification
                					  object: nil];
	}
	
	return self;
}

- (void)addIcon:(RecyclerIcon *)icon
{
  [icons addObject: icon];  
	[self addSubview: icon];
	[self addSubview: [icon label]];
	[self resizeWithOldSuperviewSize: [self frame].size];  
	[self setLabelRectOfIcon: icon];
}

- (void)removeIcon:(RecyclerIcon *)icon
{
  [[icon label] removeFromSuperview];
  [icon removeFromSuperview];
  [icons removeObject: icon];
	[self resizeWithOldSuperviewSize: [self frame].size];  
}

- (void)setLabelRectOfIcon:(RecyclerIcon *)icon
{
	NSTextField *label;
	float iconwidth, labwidth, labxpos;
  NSRect labelRect;
  
	label = [icon label];
  
	iconwidth = [icon frame].size.width;
	labwidth = [label frame].size.width;

	if(iconwidth > labwidth) {
		labxpos = [icon frame].origin.x + ((iconwidth - labwidth) / 2);
	} else {
		labxpos = [icon frame].origin.x - ((labwidth - iconwidth) / 2);
	}
	
	labelRect = NSMakeRect(labxpos, [icon frame].origin.y - 15, labwidth, 14);
	[label setFrame: labelRect];
}

- (void)unselectOtherIcons:(id)icon
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    RecyclerIcon *icn = [icons objectAtIndex: i];
    if (icn != icon) {  
      [icn unselect];
    }
  }  
}

- (void)setCurrentSelection:(NSString *)path
{
	[recicler setCurrentSelection: path];      
}

- (NSArray *)icons
{
	return icons;
}

- (int)cellsWidth
{
	return cellsWidth;
}

- (void)cellsWidthChanged:(NSNotification *)notification
{
  int i;
  
  cellsWidth = [gw shelfCellsWidth];  
  for (i = 0; i < [icons count]; i++) {
    [[icons objectAtIndex: i] setLabelWidth];
  }  
  [self resizeWithOldSuperviewSize: [self frame].size];
}

- (void)mouseDown:(NSEvent *)theEvent
{
  [self unselectOtherIcons: nil];
	[self setCurrentSelection: nil];
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldFrameSize
{
  float posx = 0.0;
	int i;
  
	for (i = 0; i < [icons count]; i++) {
		RecyclerIcon *icon = [icons objectAtIndex: i];
    [icon setFrame: NSMakeRect(posx, 18, cellsWidth, 52)];
    [icon setNeedsDisplay: YES];
    posx += cellsWidth;
  }
    
  if (posx != [self frame].size.width) {
    [self setFrame: NSMakeRect(0, 0, posx, 70)];
  }
  
	[self setNeedsDisplay: YES];
}

@end


@implementation RecyclerView

- (void)resizeWithOldSuperviewSize:(NSSize)oldFrameSize
{
  NSRect frame;
  NSView *view;
		
	[super resizeWithOldSuperviewSize: oldFrameSize];		
	frame = [self frame];
	view = [[self subviews] objectAtIndex: 0];
	[view setFrame: NSMakeRect(0, 0, 92, 100)];	
  view = [[self subviews] objectAtIndex: 1];	
	[view setFrame: NSMakeRect(92, 0, frame.size.width - 92, 100)];		
	[self setNeedsDisplay: YES];	
}

@end

