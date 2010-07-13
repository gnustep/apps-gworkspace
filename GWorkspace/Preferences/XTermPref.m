/* XTermPref.m
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

#import "XTermPref.h"
#import "GWorkspace.h"

static NSString *nibName = @"XTermPref";

@implementation XTermPref

- (void)dealloc
{
  RELEASE (prefbox);
  RELEASE (xterm);
  RELEASE (xtermArgs);
  [super dealloc];
}

- (id)init
{
  self = [super init];

  if (self)
    {  
      if ([NSBundle loadNibNamed: nibName owner: self] == NO)
	{
	  NSLog(@"failed to load %@!", nibName);
	}
      else
	{
	  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];      
	  id entry;
      
	  RETAIN (prefbox);
	  RELEASE (win);

	  useService = [defaults boolForKey: @"terminal_services"];
      
	  if (useService)
	    {
	      [xtermField setSelectable: NO];
	      [argsField setSelectable: NO];
	      [setButt setEnabled: NO];
	      [serviceCheck setState: NSOnState];
	    } else
	    {
	      [serviceCheck setState: NSOffState];
	    }
      
	  entry = [defaults stringForKey: @"defxterm"];
	  if (entry)
	    {
	      ASSIGN (xterm, entry);
	      [xtermField setStringValue: xterm];
	    }

	  entry = [defaults stringForKey: @"defaultxtermargs"];
	  if (entry)
	    {
	      ASSIGN (xtermArgs, entry);
	      [argsField setStringValue: xtermArgs];
	    }
      
	  gw = [GWorkspace gworkspace]; 
  
	  /* Internationalization */
	  [serviceBox setTitle: NSLocalizedString(@"Terminal.app", @"")];
	  [serviceCheck setTitle: NSLocalizedString(@"Use Terminal service", @"")];
	  [xtermLabel setStringValue: NSLocalizedString(@"xterm", @"")];
	  [argsLabel setStringValue: NSLocalizedString(@"arguments", @"")];
	  [setButt setTitle: NSLocalizedString(@"Set", @"")];
	  [fieldsBox setTitle: NSLocalizedString(@"Terminal", @"")];
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
  return NSLocalizedString(@"Terminal", @"");
}

- (IBAction)setUseService:(id)sender
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];      

  useService = ([sender state] == NSOnState);

  if (useService)
    {
      [xtermField setSelectable: NO];
      [argsField setSelectable: NO];
      [setButt setEnabled: NO];
    }
  else
    {
      [xtermField setSelectable: YES];
      [argsField setSelectable: YES];
      [setButt setEnabled: YES];
    }

  [defaults setBool: useService forKey: @"terminal_services"];
  [gw setUseTerminalService: useService];
}

- (IBAction)setXTerm:(id)sender
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];      
  NSString *xt = [xtermField stringValue];
  NSString *xtargs = [argsField stringValue];
  int lngt;
  
  if ([xterm isEqual: xt] && [xtermArgs isEqual: xtargs]) { 
    return;
  }
  
  lngt = [xt length];
  
  if (lngt) {
    BOOL xtok = YES;
    int i;
    
    for (i = 0; i < lngt; i++) {
      unichar c = [xt characterAtIndex: i];
    
      if (c == ' ') {
        xtok = NO;
      }
    }
  
    if (xtok) {
      lngt = [xtargs length];
      xtok = (lngt == 0) ? YES : NO;

      for (i = 0; i < lngt; i++) {
        unichar c = [xtargs characterAtIndex: i];

        if (c != ' ') {
          xtok = YES;
          break;
        }
      }
    }
  
    if (xtok) {
      ASSIGN (xterm, xt);
      ASSIGN (xtermArgs, xtargs);

	    [defaults setObject: xterm forKey: @"defxterm"];
	    [defaults setObject: xtermArgs forKey: @"defaultxtermargs"];
	    [defaults synchronize];
  
      [gw changeDefaultXTerm: xterm arguments: xtermArgs];
    }
  }
}

@end
