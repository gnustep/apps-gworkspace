/* InspectorsController.m
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
#include <math.h>
  #ifdef GNUSTEP 
#include "GWFunctions.h"
#include "InspectorsProtocol.h"
#include "GWLib.h"
  #else
#include <GWorkspace/GWFunctions.h>
#include <GWorkspace/InspectorsProtocol.h>
#include <GWorkspace/GWLib.h>
  #endif
#include "InspectorsController.h"
#include "Attributes.h"
#include "Contents.h"
#include "Tools.h"
#include "Permissions.h"
#include "GWorkspace.h"
#include "GNUstep.h"

#ifdef GNUSTEP 
  #define WINHEIGHT 446
#else
  #define WINHEIGHT 428
#endif

static NSString *nibName = @"InspectorsWin";

@implementation InspectorsController

- (void)dealloc
{
	TEST_RELEASE (win);
	TEST_RELEASE (currentPaths);
	TEST_RELEASE (inspectors);
  [super dealloc];
}

- (id)initForPaths:(NSArray *)paths
{
  self = [super init];
    
  if(self) {
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"Inspectors Controller: failed to load %@!", nibName);
    } else {    
      if ([win setFrameUsingName: @"inspectorsWin"] == NO) {
        [win setFrame: NSMakeRect(100, 100, 276, WINHEIGHT) display: NO];
      }
      [win setDelegate: self];  

		  inspectors = [[NSMutableArray alloc] initWithCapacity: 1];

      currentInspector = (id<InspectorsProtocol>)[[Attributes alloc] init];	
      [inspectors addObject: currentInspector]; 
      DESTROY (currentInspector);

      currentInspector = (id<InspectorsProtocol>)[[Contents alloc] init];	
      [inspectors addObject: currentInspector]; 
      DESTROY (currentInspector);

      currentInspector = (id<InspectorsProtocol>)[[Tools alloc] init];	
      [inspectors addObject: currentInspector]; 
      DESTROY (currentInspector);

      currentInspector = (id<InspectorsProtocol>)[[Permissions alloc] init];	
      [inspectors addObject: currentInspector]; 
      DESTROY (currentInspector);
      
      showingPb = NO;
      
      [self activateInspector: popUp];
      
      [self setPaths: paths];
    } 
  }
  
  return self;
}

- (void)setPaths:(NSArray *)paths
{
  NSString *path;
  NSString *s;
  int count;
  
	if (paths == nil) {
		return;
	}
	if(([currentPaths isEqualToArray: paths]) && (showingPb == NO)) {
		return;
	}
  
  if (showingPb && currentInspector) {
    [win setTitle: [currentInspector winname]];
  }
  
	ASSIGN (currentPaths, paths);
  showingPb = NO;
  path = [currentPaths objectAtIndex: 0];
  count = [currentPaths count];

  if (count == 1) {
    NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile: path];
	  NSSize size = [icon size];
  
    if ((size.width > ICNMAX) || (size.height > ICNMAX)) {
      NSSize newsize;

      if (size.width >= size.height) {
        newsize.width = ICNMAX;
        newsize.height = floor(ICNMAX * size.height / size.width + 0.5);
      } else {
        newsize.height = ICNMAX;
        newsize.width  = floor(ICNMAX * size.width / size.height + 0.5);
      }

	    [icon setScalesWhenResized: YES];
	    [icon setSize: newsize];  
    }
  
    [iconView setImage: icon]; 		
    [nameField setStringValue: [path lastPathComponent]];    
		s = [path stringByDeletingLastPathComponent];
		s = relativePathFittingInContainer(pathField, s);
		[pathField setStringValue: s];
  } else {
    [iconView setImage: [NSImage imageNamed: @"MultipleSelection.tiff"]];
		[nameField setStringValue: [NSString stringWithFormat: @"%i items", count]];  
		s = [path stringByDeletingLastPathComponent];
		s = relativePathFittingInContainer(pathField, s);
		[pathField setStringValue: s];  
  }
  
	[currentInspector activateForPaths: currentPaths];
}

- (void)showPasteboardData:(NSData *)data 
                    ofType:(NSString *)type
                  typeIcon:(NSImage *)icon
{
	if (currentInspector && [currentInspector isKindOfClass: [Contents class]]) {
    [win setTitle: NSLocalizedString(@"Pasteboard Inspector", @"")];
    [iconView setImage: icon]; 	
    [nameField setStringValue: type];   
    [pathField setStringValue: @""];
    [currentInspector showPasteboardData: data ofType: type];
    showingPb = YES;
	}
}

- (IBAction)activateInspector:(id)sender
{
  int index = [sender indexOfSelectedItem];
  
  if ([inspectors count] <= index) {
    return;
  }
	if (currentInspector 
        && (currentInspector == [inspectors objectAtIndex: index])) {
    return;
	}

  if (currentInspector) {
    [currentInspector deactivate];  
  }

  currentInspector = [inspectors objectAtIndex: index];
	[win setTitle: [currentInspector winname]];
	[lowBox addSubview: [currentInspector inspView]];	 
  
  if (showingPb) {
    [self setPaths: currentPaths];
  }
   
	[currentInspector activateForPaths: currentPaths];
}

- (void)showAttributes
{
  [popUp selectItemAtIndex: 0];
  [self activateInspector: popUp];
}

- (void)showContents
{
  [popUp selectItemAtIndex: 1];
  [self activateInspector: popUp];
}

- (void)showTools
{
  [popUp selectItemAtIndex: 2];
  [self activateInspector: popUp];
}

- (void)showPermissions
{
  [popUp selectItemAtIndex: 3];
  [self activateInspector: popUp];
}

- (NSArray *)currentPaths
{
	return currentPaths;
}

- (void)updateDefaults
{
  [win saveFrameUsingName: @"inspectorsWin"];
}

- (id)myWin
{
  return win;
}

- (BOOL)windowShouldClose:(id)sender
{
  [self updateDefaults];
	return YES;
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
{
	return YES;
}
	
@end
