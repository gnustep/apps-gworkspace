/* Dialogs.m
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
#include "GWFunctions.h"
  #else
#include <GWorkspace/GWFunctions.h>
  #endif
#include "Dialogs.h"
#include "GNUstep.h"

@implementation FileOpsDialogView

- (void)drawRect:(NSRect)rect
{
	STROKE_LINE (darkGrayColor, 0, 91, 240, 91);
	STROKE_LINE (whiteColor, 0, 90, 240, 90);
	STROKE_LINE (darkGrayColor, 0, 45, 240, 45);
	STROKE_LINE (whiteColor, 0, 44, 240, 44);
}

@end

@implementation FileOpsDialog

- (void)dealloc
{
  RELEASE (titlefield);
	RELEASE (editfield);
	RELEASE (cancelbutt);
	RELEASE (okbutt);	
  [super dealloc];
}

- (id)initWithTitle:(NSString *)title editText:(NSString *)etext;
{
	self = [super initWithContentRect: NSMakeRect(0, 0, 240, 120) 
					                styleMask: NSTitledWindowMask 
                            backing: NSBackingStoreRetained 
                              defer: NO];
  	if(self) {
      NSFont *font;

  		dialogView = [[FileOpsDialogView alloc] initWithFrame: [self frame]];
      AUTORELEASE (dialogView);
		  
      font = [NSFont systemFontOfSize: 18];
		
		  titlefield = [[NSTextField alloc] initWithFrame: NSMakeRect(10, 95, 200, 20)];
		  [titlefield setBackgroundColor: [NSColor windowBackgroundColor]];
		  [titlefield setBezeled: NO];
		  [titlefield setEditable: NO];
		  [titlefield setSelectable: NO];
		  [titlefield setFont: font];
		  [titlefield setStringValue: title];
		  [dialogView addSubview: titlefield]; 

		  editfield = [[NSTextField alloc] initWithFrame: NSMakeRect(30, 56, 180, 22)];
		  [editfield setStringValue: etext];
		  [dialogView addSubview: editfield];

	  	cancelbutt = [[NSButton alloc] initWithFrame: NSMakeRect(100, 10, 60, 25)];
	  	[cancelbutt setButtonType: NSMomentaryLight];
	  	[cancelbutt setTitle: NSLocalizedString(@"Cancel", @"")];
	  	[cancelbutt setTarget: self];
	  	[cancelbutt setAction: @selector(buttonAction:)];		
		  [dialogView addSubview: cancelbutt]; 

	  	okbutt = [[NSButton alloc] initWithFrame: NSMakeRect(170, 10, 60, 25)];
	  	[okbutt setButtonType: NSMomentaryLight];
	  	[okbutt setTitle: NSLocalizedString(@"OK", @"")];
	  	[okbutt setTarget: self];
	  	[okbutt setAction: @selector(buttonAction:)];		
		  [dialogView addSubview: okbutt]; 
      [self makeFirstResponder: okbutt];

		  [self setContentView: dialogView];
		  [self setTitle: @""];
	}

	return self;
}

- (int)runModal
{
  [[NSApplication sharedApplication] runModalForWindow: self];
  return result;
}

- (NSString *)getEditFieldText
{
	return [editfield stringValue];
}

- (void)buttonAction:(id)sender
{
	if (sender == okbutt) {
    result = NSAlertDefaultReturn;
  } else {
    result = NSAlertAlternateReturn;
  }

  [self orderOut: self];
  [[NSApplication sharedApplication] stopModal];
}

@end
