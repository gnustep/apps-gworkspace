/* main.m
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
#include "Desktop.h"
#include "GNUstep.h"

void createMenu();

int main(int argc, char **argv, char **env)
{
	CREATE_AUTORELEASE_POOL (pool);
  Desktop *desktop = [Desktop desktop];
	NSApplication *app = [NSApplication sharedApplication];

	createMenu();

  [app setDelegate: desktop];    
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
	NSMenu *info, *file, *edit, *tools;
	NSMenu *inspmenu;
	NSMenu *windows, *services;  
	NSMenuItem *menuItem;

	// Main
  mainMenu = AUTORELEASE ([[NSMenu alloc] initWithTitle: @"Desktop"]);
    	
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
	addMenuItem(file, @"Open", @"", @"openSelection:", @"o");
	addMenuItem(file, @"New Folder", @"", @"newFolder:", @"n");
	addMenuItem(file, @"Duplicate", @"", @"duplicateFiles:", @"u");
	addMenuItem(file, @"Move to Recycler", @"", @"moveToTrash:", @"");
	addMenuItem(file, @"Empty Recycler", @"", @"emptyTrash:", @"");
	addMenuItem(file, @"Print...", @"", @"print:", @"p");

	// Edit
	menuItem = addMenuItem(mainMenu, @"Edit", @"", nil, @"");
	edit = AUTORELEASE ([NSMenu new]);
	[mainMenu setSubmenu: edit forItem: menuItem];	
	addMenuItem(edit, @"Cut", @"", @"cut:", @"x");
	addMenuItem(edit, @"Copy", @"", @"copy:", @"c");
	addMenuItem(edit, @"Paste", @"", @"paste:", @"v");
	addMenuItem(edit, @"Select All", @"", @"selectAll:", @"a");
				
	// Tools
	menuItem = addMenuItem(mainMenu, @"Tools", @"", nil, @"");
	tools = AUTORELEASE ([NSMenu new]);
	[mainMenu setSubmenu: tools forItem: menuItem];	
		menuItem = addMenuItem(tools, @"Inspectors", @"", nil, @"");
		inspmenu = AUTORELEASE ([NSMenu new]);
		[tools setSubmenu: inspmenu forItem: menuItem];	
		addMenuItem(inspmenu, @"Show Inspectors", @"", @"showInspector:", @"");
		addMenuItem(inspmenu, @"Attributes", @"", @"showAttributesInspector:", @"1");
		addMenuItem(inspmenu, @"Contents", @"", @"showContentsInspector:", @"2");
		addMenuItem(inspmenu, @"Tools", @"", @"showToolsInspector:", @"3");

	// Windows
	menuItem = addMenuItem(mainMenu, @"Windows", @"", nil, @"");
	windows = AUTORELEASE ([NSMenu new]);
	[mainMenu setSubmenu: windows forItem: menuItem];		
	addMenuItem(windows, @"Arrange in Front", @"", nil, @"");
	addMenuItem(windows, @"Miniaturize Window", @"", nil, @"");
	addMenuItem(windows, @"Close Window", @"", @"closeMainWin:", @"w");

	// Services 
	menuItem = addMenuItem(mainMenu, @"Services", @"", nil, @"");
	services = AUTORELEASE ([NSMenu new]);
	[mainMenu setSubmenu: services forItem: menuItem];		

	// Hide
	addMenuItem(mainMenu, @"Hide", @"", @"hide:", @"h");
	
	// Quit
	addMenuItem(mainMenu, @"Quit", @"", @"terminate:", @"");

	[mainMenu update];

	[[NSApplication sharedApplication] setServicesMenu: services];
	[[NSApplication sharedApplication] setWindowsMenu: windows];
	[[NSApplication sharedApplication] setMainMenu: mainMenu];		
}
