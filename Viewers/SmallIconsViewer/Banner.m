/* Banner.m
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
#include "GWNotifications.h"
#include "Banner.h"
#include "PathsPopUp.h"
#include "GNUstep.h"

@implementation Banner

- (void)dealloc
{
	RELEASE (leftLabel);
	RELEASE (pathsPopUp);
  [super dealloc];
}

- (id)init
{
	self = [super initWithFrame: NSZeroRect];

	if (self) {
		leftLabel = [[NSTextField alloc] initWithFrame: NSZeroRect];	
		[leftLabel setAlignment: NSLeftTextAlignment];
		[leftLabel setBackgroundColor: [NSColor windowBackgroundColor]];
		[leftLabel setTextColor: [NSColor grayColor]];
		[leftLabel setFont: [NSFont systemFontOfSize: 10]];
		[leftLabel setBezeled: NO];
		[leftLabel setEditable: NO];
		[leftLabel setSelectable: NO];
		[leftLabel setStringValue: @""];
    [self addSubview: leftLabel]; 

		pathsPopUp = [[PathsPopUp alloc] initWithFrame: NSZeroRect pullsDown: NO];
		[self addSubview: pathsPopUp];   
 	}
	
	return self;
}

- (void)updateInfo:(NSString *)infoString
{
	if (infoString) {
		[leftLabel setStringValue: infoString];
	} else {
		[leftLabel setStringValue: @""];
	}
}

- (PathsPopUp *)pathsPopUp
{
	return pathsPopUp;
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldFrameSize
{
	int popupwidth = 100;
	float w = [self frame].size.width;
	float leftspace = ((w - popupwidth) / 2) - 8;
	float rightspace = w - popupwidth - leftspace - 4;

	w = (w < 0) ? 0 : w;
	leftspace = (leftspace < 0) ? 0 : leftspace;
	rightspace = (rightspace < 0) ? 0 : rightspace;
	
	[pathsPopUp setFrame: NSMakeRect((w - popupwidth) / 2, 4, popupwidth, 20)];
	[leftLabel setFrame: NSMakeRect(4, 4, leftspace, 20)];
}

@end
