/*  -*-objc-*-
 *  PathsPopUp.m: Implementation of the PathsPopUp Class 
 *  of the GNUstep GWorkspace application
 *
 *  Copyright (c) 2002 Enrico Sersale <enrico@imago.ro>
 *  
 *  Author: Enrico Sersale
 *  Date: February 2002
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "PathsPopUp.h"

@implementation PathsPopUp

- (id)initWithFrame:(NSRect)frameRect pullsDown:(BOOL)flag
{
	self = [super initWithFrame: frameRect pullsDown: flag];
	newViewer = NO;
	return self;
}

- (void)mouseDown:(NSEvent *)theEvent
{
	newViewer = ([theEvent modifierFlags] == NSControlKeyMask);
	[super mouseDown: theEvent];
}

- (BOOL)newViewer
{
	return newViewer;
}

@end
