/* Banner.m
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
#include "GWNotifications.h"
  #else
#include <GWorkspace/GWNotifications.h>
  #endif
#include "Banner.h"
#include "PathsPopUp.h"
#include "GNUstep.h"

@implementation Banner

- (void)dealloc
{
  int i;
  
  for (i = 0; i < [indicators count]; i++) {
    [[indicators objectAtIndex: i] invalidate];
  }
  RELEASE (indicators);  
	RELEASE (leftLabel);
	RELEASE (pathsPopUp);
	RELEASE (rightLabel);
  [super dealloc];
}

- (id)init
{
	self = [super initWithFrame: NSZeroRect];

	if (self) {
		leftLabel = [[NSTextField alloc] initWithFrame: NSZeroRect];	
		[leftLabel setAlignment: NSLeftTextAlignment];
		[leftLabel setBackgroundColor: [NSColor windowBackgroundColor]];
		[leftLabel setTextColor: [NSColor grayColor]];
		[leftLabel setFont: [NSFont systemFontOfSize: 10]];
		[leftLabel setBezeled: NO];
		[leftLabel setEditable: NO];
		[leftLabel setSelectable: NO];
		[leftLabel setStringValue: @""];
    [self addSubview: leftLabel]; 

		pathsPopUp = [[PathsPopUp alloc] initWithFrame: NSZeroRect pullsDown: NO];
		[self addSubview: pathsPopUp];   
		
		rightLabel = [[NSTextField alloc] initWithFrame: NSZeroRect];	
		[rightLabel setAlignment: NSRightTextAlignment];
		[rightLabel setBackgroundColor: [NSColor windowBackgroundColor]];
		[rightLabel setTextColor: [NSColor grayColor]];
		[rightLabel setFont: [NSFont systemFontOfSize: 10]];
		[rightLabel setBezeled: NO];
		[rightLabel setEditable: NO];
		[rightLabel setSelectable: NO];
		[rightLabel setStringValue: @""];
    [self addSubview: rightLabel]; 
    
    indicators = [[NSMutableArray alloc] initWithCapacity: 1];    
	}
	
	return self;
}

- (void)updateInfo:(NSString *)infoString
{
	if (infoString) {
		[leftLabel setStringValue: infoString];
	} else {
		[leftLabel setStringValue: @""];
	}
}

- (void)updateRightLabel:(NSString *)info
{
  if (info) {
    [rightLabel setStringValue: info];
  } else {
    [rightLabel setStringValue: @""];
  }
  [rightLabel setNeedsDisplay: YES];
}

- (PathsPopUp *)pathsPopUp
{
	return pathsPopUp;
}

- (void)startIndicatorForOperation:(NSString *)operation
{
  FOpIndicator *indicator = [[FOpIndicator alloc] initForBanner: self 
                                                  operationName: operation];
  [indicators addObject: indicator];
  RELEASE (indicator);
}

- (void)stopIndicatorForOperation:(NSString *)operation
{
  FOpIndicator *indicator = [self firstIndicatorForOperation: operation];
  
  if (indicator) {
    [indicator invalidate];
    [indicators removeObject: indicator];
    [self updateRightLabel: nil]; 
  }
}

- (FOpIndicator *)firstIndicatorForOperation:(NSString *)operation
{
  int i;
  
  for (i = 0; i < [indicators count]; i++) {
    FOpIndicator *indicator = [indicators objectAtIndex: i];
    if ([[indicator operation] isEqual: operation]) {
      return indicator;
    }
  }
  
  return nil;
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldFrameSize
{
	int popupwidth = 100;
	float w = [self frame].size.width;
	float leftspace = ((w - popupwidth) / 2) - 8;
	float rightspace = w - popupwidth - leftspace - 4;

	w = (w < 0) ? 0 : w;
	leftspace = (leftspace < 0) ? 0 : leftspace;
	rightspace = (rightspace < 0) ? 0 : rightspace;
	
	[pathsPopUp setFrame: NSMakeRect((w - popupwidth) / 2, 4, popupwidth, 20)];
	[leftLabel setFrame: NSMakeRect(4, 4, leftspace, 20)];
	[rightLabel setFrame: NSMakeRect(w - rightspace + 4, 4, rightspace - 4, 20)];
}

@end


@implementation FOpIndicator 

- (void)dealloc
{
  if (timer && [timer isValid]) {
    [timer invalidate];
  }
  RELEASE (operation);
  TEST_RELEASE (statusStr);
  [super dealloc];
}

- (id)initForBanner:(Banner *)abanner operationName:(NSString *)opname
{
  self = [super init];
  
  if (self) {
    ASSIGN (operation, opname);
    banner = abanner;
    timer = nil;
    statusStr = nil;
    valid = NO;
    
    if (opname == NSWorkspaceMoveOperation) {
      ASSIGN (statusStr, NSLocalizedString(@"Move ...", @""));      
    } else if (opname == NSWorkspaceCopyOperation) {
      ASSIGN (statusStr, NSLocalizedString(@"Copy ...", @""));      
    } else if (opname == NSWorkspaceLinkOperation) {
      ASSIGN (statusStr, NSLocalizedString(@"Link ...", @""));      
    } else if (opname == NSWorkspaceCompressOperation) {
      ASSIGN (statusStr, NSLocalizedString(@"Compress ...", @""));      
    } else if (opname == NSWorkspaceDecompressOperation) {
      ASSIGN (statusStr, NSLocalizedString(@"Decompress ...", @""));      
    } else if (opname == NSWorkspaceDestroyOperation) {
      ASSIGN (statusStr, NSLocalizedString(@"Destroy ...", @""));      
    } else if (opname == NSWorkspaceRecycleOperation) {
      ASSIGN (statusStr, NSLocalizedString(@"Recycler ...", @""));      
    } else if (opname == NSWorkspaceDuplicateOperation) {
      ASSIGN (statusStr, NSLocalizedString(@"Duplicate ...", @""));      
    } else if (opname == GWorkspaceRecycleOutOperation) {
      ASSIGN (statusStr, NSLocalizedString(@"Recycler ...", @""));      
    } else if (opname == GWorkspaceEmptyRecyclerOperation) {
      ASSIGN (statusStr, NSLocalizedString(@"Destroy ...", @""));      
    }

    if (statusStr) {
      timer = [NSTimer scheduledTimerWithTimeInterval: 1.0 
												target: self selector: @selector(update:) 
																					userInfo: nil repeats: YES];
      valid = YES;
    }
  }
  
  return self;
}

- (void)update:(id)sender
{
  [banner updateRightLabel: statusStr];
}

- (NSString *)operation
{
  return operation;
}

- (void)invalidate
{
  valid = NO;
  if (timer && [timer isValid]) {
    [timer invalidate];
  }
}

- (BOOL)isValid
{
  return valid;
}

@end
