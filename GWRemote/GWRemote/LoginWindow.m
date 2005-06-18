/* LoginWindow.m
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "LoginWindow.h"
#include "GWRemote.h"
#include "Functions.h"
#include "GNUstep.h"

static NSString *nibName = @"LoginWindow";

@implementation LoginWindow

- (void)dealloc
{
  TEST_RELEASE (win);
  TEST_RELEASE (serversNames);
  TEST_RELEASE (serverName);

  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {  
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
    } 
  }
  
  return self;
}

- (void)activate
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];      
  id entry;
  int i;

  [nameField setStringValue: @""];
  [passwordField setStringValue: @""];

  gwremote = [GWRemote gwremote];
       
  serverName = nil;
  serversNames = [NSMutableArray new];
  
  [popUp removeAllItems];
  
  entry = [defaults objectForKey: @"serversnames"];
  if (entry && [entry count]) {
    [serversNames addObjectsFromArray: entry];

    for (i = 0; i < [serversNames count]; i++) {
      [popUp addItemWithTitle: [serversNames objectAtIndex: i]];
    }
    
    entry = [defaults objectForKey: @"currentserver"];
    if (entry) {
      [popUp selectItemWithTitle: entry];
      [self chooseServer: popUp];
    }
  } else {
    [popUp addItemWithTitle: NSLocalizedString(@"no servers", @"")];
  }

  [win makeKeyAndOrderFront: nil];
}

- (IBAction)chooseServer:(id)sender
{
  ASSIGN (serverName, [sender titleOfSelectedItem]);
}

- (IBAction)tryLogin:(id)sender
{
  NSString *server = [popUp titleOfSelectedItem];
  NSString *name = [nameField stringValue];
  NSString *pass = [passwordField stringValue];

  if ([name length] && [pass length]) {
    [gwremote tryLoginOnServer: server withUserName: name userPassword: pass];
  } else {
    NSRunAlertPanel(NULL, NSLocalizedString(@"You must enter an user name and a password!", @""),
                                  NSLocalizedString(@"OK", @""), NULL, NULL);   
  }
  
  [nameField setStringValue: @""];
  [passwordField setStringValue: @""];
}

- (id)myWin
{
  return win;
}

@end
