/* GWViewerWindow.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: July 2004
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

#include <AppKit/AppKit.h>
#include "GWViewerWindow.h"
#include "GNUstep.h"

@implementation GWViewerWindow

- (void)dealloc
{  
  [super dealloc];
}

- (id)init
{
  unsigned int style = NSTitledWindowMask | NSClosableWindowMask 
				                  | NSMiniaturizableWindowMask | NSResizableWindowMask;

  self = [super initWithContentRect: NSZeroRect
                          styleMask: style
                            backing: NSBackingStoreBuffered 
                              defer: NO];
  return self; 
}

- (void)setDelegate:(id)adelegate
{
  delegate = adelegate;
  [super setDelegate: adelegate];
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
{	
  return [delegate validateItem: menuItem];
}

- (void)openSelection:(id)sender
{
  [delegate openSelectionInNewViewer: NO];
}

- (void)openSelectionAsFolder:(id)sender
{
  [delegate openSelectionAsFolder];
}

- (void)newFolder:(id)sender
{
  [delegate newFolder];
}

- (void)newFile:(id)sender
{
  [delegate newFile];
}

- (void)duplicateFiles:(id)sender
{
  [delegate duplicateFiles];
}

- (void)deleteFiles:(id)sender
{
  [delegate deleteFiles];
}

- (void)setViewerBehaviour:(id)sender
{
  [delegate setViewerBehaviour: sender];
}

- (void)setViewerType:(id)sender
{
  [delegate setViewerType: sender];
}

- (void)setShownType:(id)sender
{
  [delegate setShownType: sender];
}

- (void)setExtendedShownType:(id)sender
{
  [delegate setExtendedShownType: sender];
}

- (void)setIconsSize:(id)sender
{
  [delegate setIconsSize: sender];
}

- (void)setIconsPosition:(id)sender
{
  [delegate setIconsPosition: sender];
}

- (void)setLabelSize:(id)sender
{
  [delegate setLabelSize: sender];
}

- (void)chooseLabelColor:(id)sender
{
  [delegate chooseLabelColor: sender];
}

- (void)chooseBackColor:(id)sender
{
  [delegate chooseBackColor: sender];
}

- (void)selectAllInViewer:(id)sender
{
  [delegate selectAllInViewer];
}

- (void)showTerminal:(id)sender
{
  [delegate showTerminal];
}

- (void)print:(id)sender
{
	[super print: sender];
}

@end
















