/* DesktopWindow.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: May 2004
 *
 * This file is part of the GNUstep Desktop application
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
#include "DesktopWindow.h"
#include "DesktopView.h"
#include "GNUstep.h"

@implementation DesktopWindow

- (void)dealloc
{
  [super dealloc];
}

- (id)init
{	
	self = [super initWithContentRect: [[NSScreen mainScreen] frame]
                          styleMask: NSBorderlessWindowMask
				  						      backing: NSBackingStoreBuffered
                              defer: NO];
	if (self) {
    [self setReleasedWhenClosed: NO]; 
    desktopView = [DesktopView new];
    [self setContentView: desktopView];
    RELEASE (desktopView);
	}
  
	return self;
}

- (void)activate
{
	[self setLevel: NSDesktopWindowLevel];
  [self orderFront: nil];
}

- (void)deactivate
{
  [self orderOut: self];
}

- (DesktopView *)desktopView
{
  return desktopView;
}

- (BOOL)canBecomeKeyWindow
{
	return YES;
}

- (BOOL)canBecomeMainWindow
{
	return YES;
}

- (void)becomeKeyWindow
{
  [super becomeKeyWindow];
}

- (void)makeKeyWindow
{
  [super makeKeyWindow];
}

- (void)resignKeyWindow
{
  [super resignKeyWindow];
}

- (void)becomeMainWindow
{
  [super becomeMainWindow];
}

- (void)makeMainWindow
{
  [super makeMainWindow];
}

- (void)resignMainWindow
{
  [super resignMainWindow];
}

@end
