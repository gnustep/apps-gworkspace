/* DesktopWindow.m
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
#include "GWFunctions.h"
  #else
#include <GWorkspace/GWFunctions.h>
  #endif
#include "DesktopWindow.h"
#include "DesktopView.h"
#include "GNUstep.h"

@implementation DesktopWindow

- (void)dealloc
{
  RELEASE (desktopView);
  [super dealloc];
}

- (id)init
{	
	self = [super initWithContentRect: [[NSScreen mainScreen] frame]
                          styleMask: NSBorderlessWindowMask
				  						      backing: NSBackingStoreRetained 
                              defer: NO];
	if(self) {
    [self setReleasedWhenClosed: NO]; 
    desktopView = [[DesktopView alloc] init];
    [self setContentView: desktopView];
	}
	return self;
}

- (void)activate
{
#ifdef GNUSTEP 
	[self setLevel: NSDesktopWindowLevel];
  [self orderFront: nil];
#endif
}

- (void)deactivate
{
  [self orderOut: self];
}

- (id)desktopView
{
  return desktopView;
}

- (BOOL)canBecomeKeyWindow
{
	return NO;
}

- (BOOL)canBecomeMainWindow
{
	return NO;
}

@end
