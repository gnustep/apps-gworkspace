/* main.m
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
  #endif
#include "GWorkspace.h"
#include "GNUstep.h"

  #ifdef GNUSTEP 
void createMenu();
  #endif
  
int main(int argc, char **argv, char **env)
{
	CREATE_AUTORELEASE_POOL (pool);
  GWorkspace *gw = [GWorkspace gworkspace];
	NSApplication *app = [NSApplication sharedApplication];
  
#ifdef GNUSTEP
	createMenu();
#else
  [NSBundle loadNibNamed: @"MainMenu"  owner: gw];
#endif
	
  [app setDelegate: gw];    
	[app run];
	RELEASE (pool);
  
  return 0;
}

#ifdef GNUSTEP 
void createMenu()
{
  NSMenu *mainMenu;
	NSMenu *info, *file, *edit, *view, *tools;
	NSMenu *inspmenu, *fiendmenu, *tshelfmenu, *hismenu;
	NSMenu *windows, *services;  
	NSMenuItem *menuItem;

	// Main
  mainMenu = AUTORELEASE ([[NSMenu alloc] initWithTitle: @"GWorkspace"]);
    	
	// Info 	
	menuItem = addItemToMenu(mainMenu, @"Info", @"", nil, @"");
	info = AUTORELEASE ([NSMenu new]);
	[mainMenu setSubmenu: info forItem: menuItem];	
	addItemToMenu(info, @"Info Panel...", @"", @"showInfo:", @"");
	addItemToMenu(info, @"Preferences...", @"", @"showPreferences:", @"");
	addItemToMenu(info, @"Help...", @"", nil, @"?");
	 
	// File
	menuItem = addItemToMenu(mainMenu, @"File", @"", nil, @"");
	file = AUTORELEASE ([NSMenu new]);
	[mainMenu setSubmenu: file forItem: menuItem];		
	addItemToMenu(file, @"Open", @"", @"openSelection:", @"o");
	addItemToMenu(file, @"Open as Folder", @"", @"openSelectionAsFolder:", @"O");
	addItemToMenu(file, @"Open With...", @"", @"openWith:", @"");
	addItemToMenu(file, @"New Folder", @"", @"newFolder:", @"n");
	addItemToMenu(file, @"New File", @"", @"newFile:", @"N");
	addItemToMenu(file, @"Duplicate", @"", @"duplicateFiles:", @"u");
	addItemToMenu(file, @"Destroy", @"", @"deleteFiles:", @"d");
	addItemToMenu(file, @"Empty Recycler", @"", @"emptyRecycler:", @"");
	addItemToMenu(file, @"Check for disks", @"", @"checkRemovableMedia:", @"E");
	addItemToMenu(file, @"Run...", @"", @"runCommand:", @"");  
	addItemToMenu(file, @"Print...", @"", @"print:", @"p");

	// Edit
	menuItem = addItemToMenu(mainMenu, @"Edit", @"", nil, @"");
	edit = AUTORELEASE ([NSMenu new]);
	[mainMenu setSubmenu: edit forItem: menuItem];	
	addItemToMenu(edit, @"Cut", @"", @"cut:", @"x");
	addItemToMenu(edit, @"Copy", @"", @"copy:", @"c");
	addItemToMenu(edit, @"Paste", @"", @"paste:", @"v");
	addItemToMenu(edit, @"Select All", @"", @"selectAllInViewer:", @"a");

	// View
	menuItem = addItemToMenu(mainMenu, @"View", @"", nil, @"");
	view = AUTORELEASE ([NSMenu new]);
	[mainMenu setSubmenu: view forItem: menuItem];	
				
	// Tools
	menuItem = addItemToMenu(mainMenu, @"Tools", @"", nil, @"");
	tools = AUTORELEASE ([NSMenu new]);
	[mainMenu setSubmenu: tools forItem: menuItem];	
	addItemToMenu(tools, @"Viewer", @"", @"showViewer:", @"V");	
		menuItem = addItemToMenu(tools, @"Inspectors", @"", nil, @"");
		inspmenu = AUTORELEASE ([NSMenu new]);
		[tools setSubmenu: inspmenu forItem: menuItem];	
		addItemToMenu(inspmenu, @"Show Inspectors", @"", nil, @"");
		addItemToMenu(inspmenu, @"Attributes", @"", @"showAttributesInspector:", @"1");
		addItemToMenu(inspmenu, @"Contents", @"", @"showContentsInspector:", @"2");
		addItemToMenu(inspmenu, @"Tools", @"", @"showToolsInspector:", @"3");
		menuItem = addItemToMenu(tools, @"History", @"", nil, @"");
		hismenu = AUTORELEASE ([NSMenu new]);
		[tools setSubmenu: hismenu forItem: menuItem];
		addItemToMenu(hismenu, @"Show History", @"", @"showHistory:", @"H");
		addItemToMenu(hismenu, @"Go backward", @"", @"goBackwardInHistory:", @"");
		addItemToMenu(hismenu, @"Go forward", @"", @"goForwardInHistory:", @"");
	addItemToMenu(tools, @"Show Desktop", @"", @"showDesktop:", @"");
	addItemToMenu(tools, @"Show Recycler", @"", @"showRecycler:", @"");
	addItemToMenu(tools, @"Finder", @"", @"showFinder:", @"f");
	addItemToMenu(tools, @"Applications...", @"", @"showApps:", @"");
		menuItem = addItemToMenu(tools, @"Fiend", @"", nil, @"");
		fiendmenu = AUTORELEASE ([NSMenu new]);
		[tools setSubmenu: fiendmenu forItem: menuItem];
		menuItem = addItemToMenu(tools, @"Tabbed Shelf", @"", nil, @"");
		tshelfmenu = AUTORELEASE ([NSMenu new]);
		[tools setSubmenu: tshelfmenu forItem: menuItem];    
	addItemToMenu(tools, @"XTerm", @"", @"startXTerm:", @"t");

	// Windows
	menuItem = addItemToMenu(mainMenu, @"Windows", @"", nil, @"");
	windows = AUTORELEASE ([NSMenu new]);
	[mainMenu setSubmenu: windows forItem: menuItem];		
	addItemToMenu(windows, @"Arrange in Front", @"", nil, @"");
	addItemToMenu(windows, @"Miniaturize Window", @"", nil, @"");
	addItemToMenu(windows, @"Close Window", @"", @"closeMainWin:", @"w");

	// Services 
	menuItem = addItemToMenu(mainMenu, @"Services", @"", nil, @"");
	services = AUTORELEASE ([NSMenu new]);
	[mainMenu setSubmenu: services forItem: menuItem];		

	// Hide
	addItemToMenu(mainMenu, @"Hide", @"", @"hide:", @"h");
	
	// Quit
	addItemToMenu(mainMenu, @"Quit", @"", @"terminate:", @"Q");

	[mainMenu update];

	[[NSApplication sharedApplication] setServicesMenu: services];
	[[NSApplication sharedApplication] setWindowsMenu: windows];
	[[NSApplication sharedApplication] setMainMenu: mainMenu];		
}
#endif

