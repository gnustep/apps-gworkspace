/* GWViewerWindow.m
 *  
 * Copyright (C) 2004-2013 Free Software Foundation, Inc.
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#import <AppKit/AppKit.h>
#import <GNUstepBase/GNUstep.h>
#import "GWViewerWindow.h"


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


- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
{	
  return [[self delegate] validateItem: menuItem];
}

- (void)openSelection:(id)sender
{
  [[self delegate] openSelectionInNewViewer: NO];
}

- (void)openSelectionAsFolder:(id)sender
{
  [[self delegate] openSelectionAsFolder];
}

- (void)openWith:(id)sender
{
  [[self delegate] openSelectionWith];
}

- (void)newFolder:(id)sender
{
  [[self delegate] newFolder];
}

- (void)newFile:(id)sender
{
  [[self delegate] newFile];
}

- (void)duplicateFiles:(id)sender
{
  [[self delegate] duplicateFiles];
}

- (void)recycleFiles:(id)sender
{
  [[self delegate] recycleFiles];
}

- (void)deleteFiles:(id)sender
{
  [[self delegate] deleteFiles];
}

- (void)goBackwardInHistory:(id)sender
{
  [[self delegate] goBackwardInHistory];
}

- (void)goForwardInHistory:(id)sender
{
  [[self delegate] goForwardInHistory];
}

- (void)setViewerType:(id)sender
{
  [[self delegate] setViewerType: sender];
}

- (void)setShownType:(id)sender
{
  [[self delegate] setShownType: sender];
}

- (void)setExtendedShownType:(id)sender
{
  [[self delegate] setExtendedShownType: sender];
}

- (void)setIconsSize:(id)sender
{
  [[self delegate] setIconsSize: sender];
}

- (void)setIconsPosition:(id)sender
{
  [[self delegate] setIconsPosition: sender];
}

- (void)setLabelSize:(id)sender
{
  [[self delegate] setLabelSize: sender];
}

- (void)chooseLabelColor:(id)sender
{
  [[self delegate] chooseLabelColor: sender];
}

- (void)chooseBackColor:(id)sender
{
  [[self delegate] chooseBackColor: sender];
}

- (void)selectAllInViewer:(id)sender
{
  [[self delegate] selectAllInViewer];
}

- (void)showTerminal:(id)sender
{
  [[self delegate] showTerminal];
}

- (void)keyDown:(NSEvent *)theEvent 
{
  unsigned flags = [theEvent modifierFlags];
  NSString *characters = [theEvent characters];
  unichar character = 0;
		
  if ([characters length] > 0)
    {
      character = [characters characterAtIndex: 0];
    }
		
  switch (character)
    {
    case NSLeftArrowFunctionKey:
      if ((flags & NSCommandKeyMask) || (flags & NSControlKeyMask))
	{
	  [[self delegate] goBackwardInHistory];
	}
      return;

    case NSRightArrowFunctionKey:			
      if ((flags & NSCommandKeyMask) || (flags & NSControlKeyMask))
	{
	  [[self delegate] goForwardInHistory];
	} 
      return;

    case NSBackspaceKey:
      if (flags & NSShiftKeyMask)
	{
	  [[self delegate] emptyTrash];
	}
      else
	{
	  [[self delegate] recycleFiles];
	}
      return;
    }
	
  [super keyDown: theEvent];
}

- (void)print:(id)sender
{
	[super print: sender];
}

@end
