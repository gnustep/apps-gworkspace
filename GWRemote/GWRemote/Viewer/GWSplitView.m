/*  -*-objc-*-
 *  GWSplitView.m: Implementation of the GWSplitView Class 
 *  of the GNUstep GWRemote application
 *
 *  Copyright (c) 2001 Enrico Sersale <enrico@imago.ro>
 *  
 *  Author: Enrico Sersale
 *  Date: August 2001
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "GWSplitView.h"
#include "ViewerWindow.h"
#include "GNUstep.h"
#include <GWorkspace/GWNotifications.h>
#include <GWorkspace/GWFunctions.h>

@implementation GWSplitView 

- (void)dealloc
{
  int i;
  
  for (i = 0; i < [indicators count]; i++) {
    [[indicators objectAtIndex: i] invalidate];
  }
  RELEASE (indicators);  
  RELEASE (diskInfoField);
  TEST_RELEASE (diskInfoString);
  RELEASE (fopInfoField);
  TEST_RELEASE (fopInfoString);
#ifndef GNUSTEP
	RELEASE (_backgroundColor);
#endif	
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect viewer:(id)viewer
{
  self = [super initWithFrame: frameRect]; 
 		
  vwr = (ViewerWindow *)viewer;
  
  diskInfoField = [NSTextFieldCell new];
  [diskInfoField setFont: [NSFont systemFontOfSize: 10]];
  [diskInfoField setBordered: NO];
  [diskInfoField setAlignment: NSLeftTextAlignment];
  [diskInfoField setTextColor: [NSColor grayColor]];		
  
	diskInfoString = nil;
  diskInfoRect = NSZeroRect;
  
  fopInfoField = [NSTextFieldCell new];
  [fopInfoField setFont: [NSFont systemFontOfSize: 10]];
  [fopInfoField setBordered: NO];
  [fopInfoField setAlignment: NSLeftTextAlignment];
  [fopInfoField setTextColor: [NSColor grayColor]];		
  
	fopInfoString = nil;
	fopInfoRect = NSZeroRect;
  
  indicators = [[NSMutableArray alloc] initWithCapacity: 1];
  
#ifndef GNUSTEP
	ASSIGN (_backgroundColor, [NSColor controlBackgroundColor]);
#endif		
	
  return self;
}

- (void)updateDiskSpaceInfo:(NSString *)info
{
  if (info) {
    ASSIGN (diskInfoString, info);
  } else {
    DESTROY (diskInfoString);
  }
  [self setNeedsDisplayInRect: diskInfoRect];
}

- (void)updateFileOpInfo:(NSString *)info
{
  if (info) {
    ASSIGN (fopInfoString, info);
  } else {
    DESTROY (fopInfoString);
  }
  [self setNeedsDisplayInRect: fopInfoRect];
}

- (void)startIndicatorForOperation:(NSString *)operation
{
  FileOpIndicator *indicator = [[FileOpIndicator alloc] initInSplitView: self 
                                                  withOperationName: operation];
  [indicators addObject: indicator];
  RELEASE (indicator);
}

- (void)stopIndicatorForOperation:(NSString *)operation
{
  FileOpIndicator *indicator = [self firstIndicatorForOperation: operation];
  
  if (indicator) {
    [indicator invalidate];
    [indicators removeObject: indicator];
    [self updateFileOpInfo: nil]; 
  }
}

- (FileOpIndicator *)firstIndicatorForOperation:(NSString *)operation
{
  int i;
  
  for (i = 0; i < [indicators count]; i++) {
    FileOpIndicator *indicator = [indicators objectAtIndex: i];
    if ([[indicator operation] isEqual: operation]) {
      return indicator;
    }
  }
  
  return nil;
}

- (float)dividerThickness
{
  return 11;
}

- (void)drawDividerInRect:(NSRect)aRect
{
  diskInfoRect = NSMakeRect(8, aRect.origin.y, 200, 10);    
  fopInfoRect = NSMakeRect(aRect.size.width - 68, aRect.origin.y, 60, 10);
  
  [super drawDividerInRect: aRect];   
  [diskInfoField setBackgroundColor: [self backgroundColor]];
  [fopInfoField setBackgroundColor: [self backgroundColor]];
	
	if (diskInfoString != nil) {
  	[diskInfoField setStringValue: diskInfoString]; 
	} else {
  	[diskInfoField setStringValue: @""]; 
  }

  [diskInfoField drawWithFrame: diskInfoRect inView: self];
                                    
	if (fopInfoString != nil) {     
  	[fopInfoField setStringValue: fopInfoString]; 
	} else {
  	[fopInfoField setStringValue: @""]; 
  }
  
  [fopInfoField drawWithFrame: fopInfoRect inView: self];
}

#ifndef GNUSTEP
	- (NSColor*)backgroundColor
	{
  	return _backgroundColor;
	}

	- (void)setBackgroundColor:(NSColor *)aColor
	{
  	ASSIGN(_backgroundColor, aColor);
	}
#endif		

@end


@implementation FileOpIndicator 

- (void)dealloc
{
  if (timer && [timer isValid]) {
    [timer invalidate];
  }
  RELEASE (operation);
  TEST_RELEASE (statusStr);
  [super dealloc];
}

- (id)initInSplitView:(GWSplitView *)split 
    withOperationName:(NSString *)opname
{
  self = [super init];
  
  if (self) {
    ASSIGN (operation, opname);
    gwsplit = split;
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
  [gwsplit updateFileOpInfo: statusStr];
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
