/* MYViewer.m
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
#include <GWProtocol.h>
#include <GWFunctions.h>
#include <GWNotifications.h>
  #else
#include <GWorkspace/GWProtocol.h>
#include <GWorkspace/GWFunctions.h>
#include <GWorkspace/GWNotifications.h>
  #endif
#include "MYViewer.h"
#include "GNUstep.h"

@implementation MYViewer

- (void)dealloc
{
  TEST_RELEASE (rootPath);
  TEST_RELEASE (selectedPaths);
  [super dealloc];
}

- (id)init
{
	self = [super initWithFrame: NSZeroRect];
	
	if (self) {
    #ifdef GNUSTEP 
		  Class gwclass = [[NSBundle mainBundle] principalClass];
    #else
		  Class gwclass = [[NSBundle mainBundle] classNamed: @"GWorkspace"];
    #endif
		gworkspace = (id<GWProtocol>)[gwclass gworkspace];
		rootPath = nil;
		selectedPaths = nil;
	}
	
	return self;
}

//
// NSCopying 
//
- (id)copyWithZone:(NSZone *)zone
{
  MYViewer *vwr = [[MYViewer alloc] init]; 	
  return vwr;
}

//
// ViewersProtocol
//
- (void)setRootPath:(NSString *)rpath 
         viewedPath:(NSString *)vpath 
          selection:(NSArray *)selection
           delegate:(id)adelegate
           viewApps:(BOOL)canview
{
	[self setDelegate: adelegate];
  ASSIGN (rootPath, rpath);
	TEST_RELEASE (selectedPaths);
	selectedPaths = [[NSArray alloc] initWithObjects: rootPath, nil]; 
  viewsapps = canview;
  
  fm = [NSFileManager defaultManager];
}

- (NSString *)menuName
{
	return @"MyViewer";
}

- (NSString *)shortCut
{
	return @"m";
}

- (BOOL)usesShelf
{
	return YES;
}

- (BOOL)fixedResizeIncrements
{
	return YES;
}

- (NSImage *)miniicon
{
	NSBundle *bundle = [NSBundle bundleForClass: [self class]];
	NSString *imgpath = [bundle pathForResource: @"miniwindow" ofType: @"tiff"];
	NSImage *img = [[NSImage alloc] initWithContentsOfFile: imgpath];	
	return AUTORELEASE (img);
}

- (void)setSelectedPaths:(NSArray *)paths
{

}

- (void)setCurrentSelection:(NSArray *)paths
{	

}

- (void)selectAll
{

}

- (NSArray *)selectedPaths
{
  return selectedPaths;
}

- (NSString *)currentViewedPath
{  
  return nil;
}

- (NSPoint)locationOfIconForPath:(NSString *)path
{
	return NSZeroPoint;
}

- (void)unsetWatchers
{

}

- (void)setResizeIncrement:(int)increment
{
  resizeIncrement = increment;
}

- (void)setAutoSynchronize:(BOOL)value
{
  autoSynchronize = value;
}

- (id)viewerView
{
  return nil;
}

- (BOOL)viewsApps
{
  return viewsapps;
}

- (id)delegate
{
  return delegate;
}

- (void)setDelegate:(id)anObject
{	
  delegate = anObject;
}

@end
