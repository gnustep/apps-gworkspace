/* main.m
 *  
 * Copyright (C) 2007 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@fibernet.ro>
 * Date: January 2007
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
#include "MDFinder.h"
  
int main(int argc, char **argv, char **env)
{
	CREATE_AUTORELEASE_POOL (pool);
	NSApplication *app = [NSApplication sharedApplication];
  	
  [app setDelegate: [MDFinder mdfinder]];    
	[app run];
	RELEASE (pool);
  
  return 0;
}

