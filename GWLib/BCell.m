/* BCell.m
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
#include "GWProtocol.h"
#include "GWFunctions.h"
#include "BCell.h"
#include "GNUstep.h"

@implementation BCell

- (void)dealloc
{
  TEST_RELEASE (paths);
  TEST_RELEASE (path);
  TEST_RELEASE (icon);  
  TEST_RELEASE (highlight);    
  [super dealloc];
}

- (id)init
{
  self = [super init];

  if (self) {
    icon = nil;
    highlight = nil;
    [self setAllowsMixedState: NO];
  }
  
  return self;
}

- (id)initIconCell
{
  self = [super init];

  if (self) {
    #ifdef GNUSTEP 
		  Class gwclass = [[NSBundle mainBundle] principalClass];
    #else
		  Class gwclass = [[NSBundle mainBundle] classNamed: @"GWorkspace"];
    #endif

		gworkspace = (id<GWProtocol>)[gwclass gworkspace];  
    paths = nil;
    path = nil;
    icon = nil;
    highlight = nil;
    iconSelected = NO;
    [self setAllowsMixedState: NO];
  }
  
  return self;
}

- (void)setPaths:(NSArray *)p
{
  ASSIGN (paths, p);

  if ([paths count] == 1) {
    ASSIGN (path, [paths objectAtIndex: 0]);
    [self setStringValue: [path lastPathComponent]];
    ASSIGN (icon, [gworkspace smallIconForFile: path]);  
    iconSelected = NO;
  } else {
    DESTROY (path);
    ASSIGN (icon, [gworkspace smallIconForFiles: paths]);  
  }
  
  ASSIGN (highlight, [gworkspace smallHighlightIcon]);
}

- (NSArray *)paths
{
  return paths;
}

- (BOOL)selectIcon
{
  if (iconSelected) {
    return NO;
  }
  
  iconSelected = YES;
  return YES;
}

- (BOOL)unSelectIcon
{
  if (iconSelected == NO) {
    return NO;
  }

  iconSelected = NO;
  return YES;
}

- (NSSize)cellSize
{
  NSSize s = [super cellSize];

  if (highlight) {
    s.height = [highlight size].height + 2;
  }
  
  return s;
}

- (NSSize)iconSize
{
  if (highlight) {
    return [highlight size];
  }
  
  return NSZeroSize;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
  NSWindow *cvWin = [controlView window];
  NSRect title_rect = cellFrame;
  NSString *title;
  NSString *cuttitle;  
  float textlenght;
  NSSize size;

  if (!cvWin) {
    return;
  }

  title = [[self stringValue] copy];
  size = [controlView frame].size;   
  
  textlenght = size.width;
  
  if (icon) {
    textlenght -= [highlight size].width + 4;
  }
  
  if ([self isLeaf] == YES) {
    textlenght -= 20; 
  } else {
    textlenght -= 35; 
  }
  cuttitle = cutFileLabelText(title, self, textlenght);  
  [self setStringValue: cuttitle];        
  
  if (icon == nil) {
    [super drawInteriorWithFrame: title_rect inView: controlView];
    [self setStringValue: title];          
    RELEASE (title);  
    return;  
    
  } else {
    NSRect icon_rect;    
    NSRect highlight_rect;    
    NSColor	*backColor;
    BOOL showsFirstResponder;

    [controlView lockFocus];

    if ([self isHighlighted] || [self state]) {
      backColor = [self highlightColorInView: controlView];
    } else {
      backColor = [cvWin backgroundColor];
    }
    [backColor set];
    NSRectFill(cellFrame);	

    showsFirstResponder = [self showsFirstResponder];
    [self setShowsFirstResponder: NO];

    highlight_rect.origin = cellFrame.origin;
    highlight_rect.size = [highlight size];
    highlight_rect.origin.x += 1;
    highlight_rect.origin.y += (cellFrame.size.height - highlight_rect.size.height) / 2.0;
    if ([controlView isFlipped]) {
	    highlight_rect.origin.y += highlight_rect.size.height;
    }
    
    icon_rect.origin = cellFrame.origin;
    icon_rect.size = [icon size];
    icon_rect.origin.x += (highlight_rect.size.width - icon_rect.size.width) / 2.0;    
    icon_rect.origin.y += (cellFrame.size.height - icon_rect.size.height) / 2.0;
    if ([controlView isFlipped]) {
	    icon_rect.origin.y += icon_rect.size.height;
    }

    title_rect.origin.x += highlight_rect.size.width + 1;	
    title_rect.size.width -= highlight_rect.size.width + 1;	

    [super drawInteriorWithFrame: title_rect inView: controlView];
        
    if (iconSelected) {
//      [highlight setBackgroundColor: backColor];
      [highlight compositeToPoint: highlight_rect.origin 
	                      operation: NSCompositeSourceOver];    
    }

    if (iconSelected == NO) {
//      [icon setBackgroundColor: backColor];
    }
    
    if ([self isEnabled]) {
      [icon compositeToPoint: icon_rect.origin 
	                 operation: NSCompositeSourceOver];
    } else {
			[icon dissolveToPoint: icon_rect.origin fraction: 0.3];
    }

    if (showsFirstResponder == YES) {
      [self setShowsFirstResponder: showsFirstResponder];
      NSDottedFrameRect(cellFrame);
    }

    [controlView unlockFocus];

    [self setStringValue: title];
    RELEASE (title);  
  }
}

@end
