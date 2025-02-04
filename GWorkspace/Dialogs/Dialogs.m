/* Dialogs.m
 *  
 * Copyright (C) 2003-2025 Free Software Foundation, Inc.
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
 * Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <GNUstepBase/GNUstep.h>

#import "GWFunctions.h"
#import "Dialogs.h"


@implementation GWDialogView

- (id)initWithFrame:(NSRect)frameRect useSwitch:(BOOL)aBool
{
  self = [super initWithFrame: frameRect];

  if (self)
    {
      useSwitch = aBool;
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

@implementation GWDialog

- (void)dealloc
{
  [super dealloc];
}

- (id)initWithTitle:(NSString *)title 
           editText:(NSString *)eText
        switchTitle:(NSString *)swTitle
{
  NSRect r = swTitle ? NSMakeRect(0, 0, 240, 160) : NSMakeRect(0, 0, 240, 120);
  
  self = [super initWithContentRect: r
                          styleMask: NSTitledWindowMask 
                            backing: NSBackingStoreRetained 
                              defer: NO];
  if(self)
    {
      NSFont *font;

      useSwitch = swTitle ? YES : NO;

      dialogView = [[GWDialogView alloc] initWithFrame: [self frame] 
                                             useSwitch: useSwitch];
      AUTORELEASE (dialogView);

      font = [NSFont systemFontOfSize: 18];

      r = useSwitch ? NSMakeRect(10, 125, 200, 20) : NSMakeRect(10, 95, 200, 20);
      titleField = [[NSTextField alloc] initWithFrame: r];
      [titleField setBackgroundColor: [NSColor windowBackgroundColor]];
      [titleField setBezeled: NO];
      [titleField setEditable: NO];
      [titleField setSelectable: NO];
      [titleField setFont: font];
      [titleField setStringValue: title];
      [dialogView addSubview: titleField];
      RELEASE (titleField);

      r = useSwitch ? NSMakeRect(30, 86, 180, 22) : NSMakeRect(30, 56, 180, 22);
      editField = [[NSTextField alloc] initWithFrame: r];
      [editField setStringValue: eText];
      [dialogView addSubview: editField];
      RELEASE (editField);

      if (useSwitch)
        {
          switchButt = [[NSButton alloc] initWithFrame: NSMakeRect(30, 62, 180, 16)];
          [switchButt setButtonType: NSSwitchButton];
          [switchButt setTitle: swTitle];
          [dialogView addSubview: switchButt];
          RELEASE (switchButt);
        }

      cancelButt = [[NSButton alloc] initWithFrame: NSMakeRect(100, 10, 60, 25)];
      [cancelButt setButtonType: NSMomentaryLight];
      [cancelButt setTitle: NSLocalizedString(@"Cancel", @"")];
      [cancelButt setTarget: self];
      [cancelButt setAction: @selector(buttonAction:)];
      [dialogView addSubview: cancelButt];
      RELEASE (cancelButt);

      okButt = [[NSButton alloc] initWithFrame: NSMakeRect(170, 10, 60, 25)];
      [okButt setButtonType: NSMomentaryLight];
      [okButt setTitle: NSLocalizedString(@"OK", @"")];
      [okButt setTarget: self];
      [okButt setAction: @selector(buttonAction:)];
      [dialogView addSubview: okButt];
      RELEASE (okButt);

      [self setContentView: dialogView];
      [self setTitle: @""];

      [self setInitialFirstResponder: editField];
    }
  
  return self;
}

- (NSModalResponse)runModal
{
  [[NSApplication sharedApplication] runModalForWindow: self];
  return result;
}

- (NSString *)getEditFieldText
{
  return [editField stringValue];
}

- (NSControlStateValue)switchButtonState
{
  if (useSwitch)
    {
      return [switchButt state];
    }
  return NSOffState;
}

- (void)buttonAction:(id)sender
{
  if (sender == okButt)
    {
      result = NSAlertDefaultReturn;
    }
  else
    {
    result = NSAlertAlternateReturn;
    }

  [[NSApplication sharedApplication] stopModal];
  [self orderOut: nil];
}

@end
