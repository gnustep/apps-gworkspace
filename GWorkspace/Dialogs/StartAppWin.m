/* StartAppWin.m
 *  
 * Copyright (C) 2004-2010 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
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

#import "StartAppWin.h"


static NSString *nibName = @"StartAppWin";

@implementation StartAppWin

- (void)dealloc
{
  RELEASE (win);
  [super dealloc];
}

- (id)init
{
	self = [super init];

  if (self) {
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
      DESTROY (self);
      return self;
    } else {
      NSRect wframe = [win frame];
      NSRect scrframe = [[NSScreen mainScreen] frame];
      NSRect winrect = NSMakeRect((scrframe.size.width - wframe.size.width) / 2,
                              (scrframe.size.height - wframe.size.height) / 2,
                               wframe.size.width,
                               wframe.size.height);
      
      [win setFrame: winrect display: NO];
      [win setDelegate: self];  
         
      /* Internationalization */
      [startLabel setStringValue: NSLocalizedString(@"starting:", @"")];      
	  }			
  }
  
	return self;
}

- (void)showWindowWithTitle:(NSString *)title
                    appName:(NSString *)appname
                  operation:(NSString *)operation
               maxProgValue:(double)maxvalue
{
  if (win) {
    [win setTitle: title];
    [startLabel setStringValue: operation];
    [nameField setStringValue: appname];

    [progInd setMinValue: 0.0];
    [progInd setMaxValue: maxvalue];
    [progInd setDoubleValue: 0.0];

    if ([win isVisible] == NO) {
      [win orderFrontRegardless];
    }
  }
}
                 
- (void)updateProgressBy:(double)incr
{
  [progInd incrementBy: incr];
}

- (NSWindow *)win
{
  return win;
}

- (BOOL)windowShouldClose:(id)sender
{
	return YES;
}

@end
