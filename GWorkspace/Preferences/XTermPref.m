/* XTermPref.m
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
#include "XTermPref.h"
#include "GWorkspace.h"
#include "GNUstep.h"

static NSString *nibName = @"XTermPref";

@implementation XTermPref

- (void)dealloc
{
  TEST_RELEASE (prefbox);
  TEST_RELEASE (xterm);
  TEST_RELEASE (xtermArgs);
  [super dealloc];
}

- (id)init
{
  self = [super init];

  if (self) {  
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
    } else {
	    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];      

      RETAIN (prefbox);
      RELEASE (win);

	    xterm = [defaults stringForKey: @"defxterm"];
      if (xterm != nil) {
        RETAIN (xterm);
		    [xtermLabel setStringValue: xterm];
      }

	    xtermArgs = [defaults stringForKey: @"defaultxtermargs"];
      if (xtermArgs != nil) {
        RETAIN (xtermArgs);
		    [argsLabel setStringValue: xtermArgs];
      }
      
      gw = [GWorkspace gworkspace]; 
  
      /* Internationalization */
      [setButt setTitle: NSLocalizedString(@"Set", @"")];
      [fieldsBox setTitle: NSLocalizedString(@"XTerminal", @"")];
    }
  }
  
  return self;
}

- (NSView *)prefView
{
  return prefbox;
}

- (NSString *)prefName
{
  return @"XTerminal";
}

- (IBAction)setXTerm:(id)sender
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];      
  NSString *xt = [xtermLabel stringValue];
  NSString *xtargs = [argsLabel stringValue];
  
  if ([xterm isEqual: xt] && [xtermArgs isEqual: xtargs]) { 
    return;
  }
  
  ASSIGN (xterm, xt);
  ASSIGN (xtermArgs, xtargs);

	[defaults setObject: xterm forKey: @"defxterm"];
	[defaults setObject: xtermArgs forKey: @"defaultxtermargs"];
	[defaults synchronize];
  
  [gw changeDefaultXTerm: xterm arguments: xtermArgs];
}

@end
