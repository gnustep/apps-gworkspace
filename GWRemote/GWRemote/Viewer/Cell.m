/* Cell.m
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
 *
 * This file is part of the GNUstep GWRemote application
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
#include "Functions.h"
#include "Cell.h"
#include "GNUstep.h"

@implementation Cell

- (void)dealloc
{
  TEST_RELEASE (paths);
  TEST_RELEASE (path);
  [super dealloc];
}

- (id)init
{
  self = [super init];

  if (self) {
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
  } else {
    DESTROY (path);
  }
}

- (NSArray *)paths
{
  return paths;
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
  
  if ([self isLeaf] == YES) {
    textlenght -= 20; 
  } else {
    textlenght -= 35; 
  }
  cuttitle = cutFileLabelText(title, self, textlenght);  
  [self setStringValue: cuttitle];        
  
  [super drawInteriorWithFrame: title_rect inView: controlView];
  [self setStringValue: title];          
  RELEASE (title);  
}

@end
