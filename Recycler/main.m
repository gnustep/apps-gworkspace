/* main.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: June 2004
 *
 * This file is part of the GNUstep Recycler application
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
#include "Recycler.h"
#include "GNUstep.h"

void createMenu();

int main(int argc, char **argv, char **env)
{
	CREATE_AUTORELEASE_POOL (pool);
  Recycler *recycler = [Recycler recycler];
	NSApplication *app = [NSApplication sharedApplication];

	createMenu();

  [app setDelegate: recycler];    
	[app run];
	RELEASE (pool);
  
  return 0;
}

NSMenuItem *addMenuItem(NSMenu *menu, NSString *str, 
																NSString *comm, NSString *sel, NSString *key)
{
	NSMenuItem *item = [menu addItemWithTitle: NSLocalizedString(str, comm)
												action: NSSelectorFromString(sel) keyEquivalent: key]; 
	return item;
}

void createMenu()
{
  NSMenu *mainMenu;
	NSMenu *info, *file, *edit;
	NSMenuItem *menuItem;

	// Main
  mainMenu = AUTORELEASE ([[NSMenu alloc] initWithTitle: @"Recycler"]);
    	
	// Info 	
	menuItem = addMenuItem(mainMenu, @"Info", @"", nil, @"");
	info = AUTORELEASE ([NSMenu new]);
	[mainMenu setSubmenu: info forItem: menuItem];	
	addMenuItem(info, @"Info Panel...", @"", @"showInfo:", @"");
	addMenuItem(info, @"Preferences...", @"", @"showPreferences:", @"");
	addMenuItem(info, @"Help...", @"", nil, @"?");

	// File
	menuItem = addMenuItem(mainMenu, @"File", @"", nil, @"");
	file = AUTORELEASE ([NSMenu new]);
	[mainMenu setSubmenu: file forItem: menuItem];		
	addMenuItem(file, @"Empty Recycler", @"", @"emptyTrash:", @"");

	// Edit
	menuItem = addMenuItem(mainMenu, @"Edit", @"", nil, @"");
	edit = AUTORELEASE ([NSMenu new]);
	[mainMenu setSubmenu: edit forItem: menuItem];	
	addMenuItem(edit, @"Paste", @"", @"paste:", @"v");
	 
	// Hide
	addMenuItem(mainMenu, @"Hide", @"", @"hide:", @"h");
	
	// Quit
	addMenuItem(mainMenu, @"Quit", @"", @"terminate:", @"");

	[mainMenu update];

	[[NSApplication sharedApplication] setMainMenu: mainMenu];		
}
