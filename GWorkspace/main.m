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
#include "GWFunctions.h"
#include "GWorkspace.h"
#include "GNUstep.h"

void createMenu();
  
int main(int argc, char **argv, char **env)
{
	CREATE_AUTORELEASE_POOL (pool);
  GWorkspace *gw = [GWorkspace gworkspace];
	NSApplication *app = [NSApplication sharedApplication];
  
	createMenu();
	
  [app setDelegate: gw];    
	[app run];
	RELEASE (pool);
  
  return 0;
}

void createMenu()
{
  NSMenu *mainMenu;
  NSMenu *menu;
  NSMenu *subenu;
	NSMenu *windows, *services;  
	NSMenuItem *menuItem;

	// Main
  mainMenu = AUTORELEASE ([[NSMenu alloc] initWithTitle: @"GWorkspace"]);
    	
	// Info 	
	menuItem = addItemToMenu(mainMenu, @"Info", @"", nil, @"");
	menu = AUTORELEASE ([NSMenu new]);
	[mainMenu setSubmenu: menu forItem: menuItem];	
	addItemToMenu(menu, @"Info Panel...", @"", @"showInfo:", @"");
	addItemToMenu(menu, @"Preferences...", @"", @"showPreferences:", @"");
	addItemToMenu(menu, @"Help...", @"", nil, @"?");
	 
	// File
	menuItem = addItemToMenu(mainMenu, @"File", @"", nil, @"");
	menu = AUTORELEASE ([NSMenu new]);
	[mainMenu setSubmenu: menu forItem: menuItem];		
	addItemToMenu(menu, @"Open", @"", @"openSelection:", @"o");
	addItemToMenu(menu, @"Open as Folder", @"", @"openSelectionAsFolder:", @"O");
	addItemToMenu(menu, @"Open With...", @"", @"openWith:", @"");
	addItemToMenu(menu, @"New Folder", @"", @"newFolder:", @"n");
	addItemToMenu(menu, @"New File", @"", @"newFile:", @"N");
	addItemToMenu(menu, @"Duplicate", @"", @"duplicateFiles:", @"u");
	addItemToMenu(menu, @"Move to Recycler", @"", @"deleteFiles:", @"d");
	addItemToMenu(menu, @"Empty Recycler", @"", @"emptyRecycler:", @"");
	addItemToMenu(menu, @"Check for disks", @"", @"checkRemovableMedia:", @"E");
	addItemToMenu(menu, @"Run...", @"", @"runCommand:", @"");  
	addItemToMenu(menu, @"Print...", @"", @"print:", @"p");

	// Edit
	menuItem = addItemToMenu(mainMenu, @"Edit", @"", nil, @"");
	menu = AUTORELEASE ([NSMenu new]);
	[mainMenu setSubmenu: menu forItem: menuItem];	
	addItemToMenu(menu, @"Cut", @"", @"cut:", @"x");
	addItemToMenu(menu, @"Copy", @"", @"copy:", @"c");
	addItemToMenu(menu, @"Paste", @"", @"paste:", @"v");
	addItemToMenu(menu, @"Select All", @"", @"selectAllInViewer:", @"a");

	// View
	menuItem = addItemToMenu(mainMenu, @"View", @"", nil, @"");
	menu = AUTORELEASE ([NSMenu new]);
	[mainMenu setSubmenu: menu forItem: menuItem];	
	addItemToMenu(menu, @"Browser", @"", @"setViewerType:", @"b");
	addItemToMenu(menu, @"Icon", @"", @"setViewerType:", @"i");
	addItemToMenu(menu, @"List", @"", @"setViewerType:", @"l");
	  menuItem = addItemToMenu(menu, @"Viewer behaviour", @"", nil, @"");
	  subenu = AUTORELEASE ([NSMenu new]);
	  [menu setSubmenu: subenu forItem: menuItem];	
	  addItemToMenu(subenu, @"Browsing", @"", @"setViewerBehaviour:", @"B");
	  addItemToMenu(subenu, @"Spatial", @"", @"setViewerBehaviour:", @"S");
	
    menuItem = addItemToMenu(menu, @"Show", @"", nil, @"");
	  subenu = AUTORELEASE ([NSMenu new]);
	  [menu setSubmenu: subenu forItem: menuItem];	
	  addItemToMenu(subenu, @"Name only", @"", @"setShownType:", @"");
	  addItemToMenu(subenu, @"Kind", @"", @"setShownType:", @"");
	  addItemToMenu(subenu, @"Size", @"", @"setShownType:", @"");
	  addItemToMenu(subenu, @"Modification date", @"", @"setShownType:", @"");
	  addItemToMenu(subenu, @"Owner", @"", @"setShownType:", @"");
      
    menuItem = addItemToMenu(menu, @"Icon Size", @"", nil, @"");
	  subenu = AUTORELEASE ([NSMenu new]);
	  [menu setSubmenu: subenu forItem: menuItem];	
	  addItemToMenu(subenu, @"24", @"", @"setIconsSize:", @"");
	  addItemToMenu(subenu, @"28", @"", @"setIconsSize:", @"");
	  addItemToMenu(subenu, @"32", @"", @"setIconsSize:", @"");
	  addItemToMenu(subenu, @"36", @"", @"setIconsSize:", @"");
	  addItemToMenu(subenu, @"40", @"", @"setIconsSize:", @"");
	  addItemToMenu(subenu, @"44", @"", @"setIconsSize:", @"");
	  addItemToMenu(subenu, @"48", @"", @"setIconsSize:", @"");
      
    menuItem = addItemToMenu(menu, @"Icon Position", @"", nil, @"");
	  subenu = AUTORELEASE ([NSMenu new]);
	  [menu setSubmenu: subenu forItem: menuItem];	
	  addItemToMenu(subenu, @"Up", @"", @"setIconsPosition:", @"");
	  addItemToMenu(subenu, @"Left", @"", @"setIconsPosition:", @"");
      
    menuItem = addItemToMenu(menu, @"Label Size", @"", nil, @"");
	  subenu = AUTORELEASE ([NSMenu new]);
	  [menu setSubmenu: subenu forItem: menuItem];	
	  addItemToMenu(subenu, @"10", @"", @"setLabelSize:", @"");
	  addItemToMenu(subenu, @"11", @"", @"setLabelSize:", @"");
	  addItemToMenu(subenu, @"12", @"", @"setLabelSize:", @"");
	  addItemToMenu(subenu, @"13", @"", @"setLabelSize:", @"");
	  addItemToMenu(subenu, @"14", @"", @"setLabelSize:", @"");
	  addItemToMenu(subenu, @"15", @"", @"setLabelSize:", @"");
	  addItemToMenu(subenu, @"16", @"", @"setLabelSize:", @"");
      
//	  addItemToMenu(menu, @"Label Color...", @"", @"chooseLabelColor:", @"");
	  
//    addItemToMenu(menu, @"Background Color...", @"", @"chooseBackColor:", @"");
      
	// Tools
	menuItem = addItemToMenu(mainMenu, @"Tools", @"", nil, @"");
	menu = AUTORELEASE ([NSMenu new]);
	[mainMenu setSubmenu: menu forItem: menuItem];	
	addItemToMenu(menu, @"Viewer", @"", @"showViewer:", @"V");	
		
    menuItem = addItemToMenu(menu, @"Inspectors", @"", nil, @"");
		subenu = AUTORELEASE ([NSMenu new]);
		[menu setSubmenu: subenu forItem: menuItem];	
		addItemToMenu(subenu, @"Show Inspectors", @"", nil, @"");
		addItemToMenu(subenu, @"Attributes", @"", @"showAttributesInspector:", @"1");
		addItemToMenu(subenu, @"Contents", @"", @"showContentsInspector:", @"2");
		addItemToMenu(subenu, @"Tools", @"", @"showToolsInspector:", @"3");
		addItemToMenu(subenu, @"Annotations", @"", @"showAnnotationsInspector:", @"4");
		
    menuItem = addItemToMenu(menu, @"History", @"", nil, @"");
		subenu = AUTORELEASE ([NSMenu new]);
		[menu setSubmenu: subenu forItem: menuItem];
		addItemToMenu(subenu, @"Show History", @"", @"showHistory:", @"H");
		addItemToMenu(subenu, @"Go backward", @"", @"goBackwardInHistory:", @"");
		addItemToMenu(subenu, @"Go forward", @"", @"goForwardInHistory:", @"");
	
  addItemToMenu(menu, @"Show Desktop", @"", @"showDesktop:", @"");
	addItemToMenu(menu, @"Show Recycler", @"", @"showRecycler:", @"");
	addItemToMenu(menu, @"Finder", @"", @"showFinder:", @"f");
		
    menuItem = addItemToMenu(menu, @"Fiend", @"", nil, @"");
		subenu = AUTORELEASE ([NSMenu new]);
		[menu setSubmenu: subenu forItem: menuItem];
		
    menuItem = addItemToMenu(menu, @"Tabbed Shelf", @"", nil, @"");
		subenu = AUTORELEASE ([NSMenu new]);
		[menu setSubmenu: subenu forItem: menuItem];    
	
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

