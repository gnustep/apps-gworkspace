/* GWSplitView.m
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
#include "GWNotifications.h"
#include "GWSplitView.h"
#include "ViewersWindow.h"
#include "GNUstep.h"

@implementation GWSplitView 

- (void)dealloc
{
  RELEASE (diskInfoField);
  TEST_RELEASE (diskInfoString);

  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect viewer:(id)viewer
{
  self = [super initWithFrame: frameRect]; 
 		
  vwr = (ViewersWindow *)viewer;
  
  diskInfoField = [NSTextFieldCell new];
  [diskInfoField setFont: [NSFont systemFontOfSize: 10]];
  [diskInfoField setBordered: NO];
  [diskInfoField setAlignment: NSLeftTextAlignment];
  [diskInfoField setTextColor: [NSColor grayColor]];		
  
	diskInfoString = nil;
  diskInfoRect = NSZeroRect;
      
  return self;
}

- (void)updateDiskSpaceInfo:(NSString *)info
{
  if (info) {
    ASSIGN (diskInfoString, info);
  } else {
    DESTROY (diskInfoString);
  }

	if (diskInfoString) {
  	[diskInfoField setStringValue: diskInfoString]; 
	} else {
  	[diskInfoField setStringValue: @""]; 
  }
   
  [diskInfoField drawWithFrame: diskInfoRect inView: self];
}

- (float)dividerThickness
{
  return 11;
}

- (void)drawDividerInRect:(NSRect)aRect
{
  diskInfoRect = NSMakeRect(8, aRect.origin.y, 200, 10);    
  
  [super drawDividerInRect: aRect];   
  [diskInfoField setBackgroundColor: [self backgroundColor]];
	
	if (diskInfoString != nil) {
  	[diskInfoField setStringValue: diskInfoString]; 
	} else {
  	[diskInfoField setStringValue: @""]; 
  }

  [diskInfoField drawWithFrame: diskInfoRect inView: self];
}

@end
