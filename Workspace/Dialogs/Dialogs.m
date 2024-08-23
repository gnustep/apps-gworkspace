/* Dialogs.m
 *  
 * Copyright (C) 2003-2010 Free Software Foundation, Inc.
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <GNUstepBase/GNUstep.h>

#import "GWFunctions.h"
#import "Dialogs.h"


@implementation SympleDialogView

- (id)initWithFrame:(NSRect)frameRect useSwitch:(BOOL)swtch
{
  self = [super initWithFrame: frameRect];

  if (self) {
    useSwitch = swtch;
  }
  
  return self;
}

- (void)drawRect:(NSRect)rect
{
  if (useSwitch) {
	  STROKE_LINE (darkGrayColor, 0, 121, 240, 121);
	  STROKE_LINE (whiteColor, 0, 120, 240, 120);
  } else {
	  STROKE_LINE (darkGrayColor, 0, 91, 240, 91);
	  STROKE_LINE (whiteColor, 0, 90, 240, 90);  
  }
	STROKE_LINE (darkGrayColor, 0, 45, 240, 45);
	STROKE_LINE (whiteColor, 0, 44, 240, 44);
}

@end

@implementation SympleDialog

- (void)dealloc
{
  [super dealloc];
}

- (id)initWithTitle:(NSString *)title 
           editText:(NSString *)etext
        switchTitle:(NSString *)swtitle
{
  NSRect r = swtitle ? NSMakeRect(0, 0, 240, 160) : NSMakeRect(0, 0, 240, 120);
  
	self = [super initWithContentRect: r
					                styleMask: NSTitledWindowMask 
                            backing: NSBackingStoreRetained 
                              defer: NO];
  if(self) {
    NSFont *font;
    
    useSwitch = swtitle ? YES : NO;
    
  	dialogView = [[SympleDialogView alloc] initWithFrame: [self frame] 
                                               useSwitch: useSwitch];
    AUTORELEASE (dialogView);

    font = [NSFont systemFontOfSize: 18];

    r = useSwitch ? NSMakeRect(10, 125, 200, 20) : NSMakeRect(10, 95, 200, 20);
		titlefield = [[NSTextField alloc] initWithFrame: r];
		[titlefield setBackgroundColor: [NSColor windowBackgroundColor]];
		[titlefield setBezeled: NO];
		[titlefield setEditable: NO];
		[titlefield setSelectable: NO];
		[titlefield setFont: font];
		[titlefield setStringValue: title];
		[dialogView addSubview: titlefield]; 
    RELEASE (titlefield);

    r = useSwitch ? NSMakeRect(30, 86, 180, 22) : NSMakeRect(30, 56, 180, 22);
		editfield = [[NSTextField alloc] initWithFrame: r];
		[editfield setStringValue: etext];
		[dialogView addSubview: editfield];
	  RELEASE (editfield);

    if (useSwitch) {
	    switchButt = [[NSButton alloc] initWithFrame: NSMakeRect(30, 62, 180, 16)];
	    [switchButt setButtonType: NSSwitchButton];
	    [switchButt setTitle: swtitle];
		  [dialogView addSubview: switchButt]; 
	    RELEASE (switchButt);
    }

	  cancelbutt = [[NSButton alloc] initWithFrame: NSMakeRect(100, 10, 60, 25)];
	  [cancelbutt setButtonType: NSMomentaryLight];
	  [cancelbutt setTitle: NSLocalizedString(@"Cancel", @"")];
	  [cancelbutt setTarget: self];
	  [cancelbutt setAction: @selector(buttonAction:)];		
		[dialogView addSubview: cancelbutt]; 
	  RELEASE (cancelbutt);

	  okbutt = [[NSButton alloc] initWithFrame: NSMakeRect(170, 10, 60, 25)];
	  [okbutt setButtonType: NSMomentaryLight];
	  [okbutt setTitle: NSLocalizedString(@"OK", @"")];
	  [okbutt setTarget: self];
	  [okbutt setAction: @selector(buttonAction:)];		
		[dialogView addSubview: okbutt]; 
    RELEASE (okbutt);	

		[self setContentView: dialogView];
		[self setTitle: @""];

    [self setInitialFirstResponder: editfield];
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

- (int)switchButtState
{
  if (useSwitch) {
    return [switchButt state];
  }
  return 0;
}

- (void)buttonAction:(id)sender
{
	if (sender == okbutt) {
    result = NSAlertDefaultReturn;
  } else {
    result = NSAlertAlternateReturn;
  }

  [[NSApplication sharedApplication] stopModal];
  [self orderOut: nil];
}

@end
