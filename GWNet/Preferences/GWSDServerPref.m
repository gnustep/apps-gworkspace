/* GWSDServerPref.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
 *
 * This file is part of the GNUstep GWNet application
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
#include "GWSDServerPref.h"
#include "GWRemote.h"
#include "GWNetFunctions.h"
#include "GNUstep.h"

static NSString *nibName = @"GWSDServerPref";

static NSString *prefName = nil;

@implementation GWSDServerPref

+ (void)initialize
{
  ASSIGN (prefName, NSLocalizedString(@"gwsd server", @""));
}

+ (NSString *)prefName
{
  return prefName;
}

- (void)dealloc
{
  TEST_RELEASE (prefbox);
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
    } else {
	    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];      
      id entry;
      
      RETAIN (prefbox);
      RELEASE (win);
      
      [nameField setStringValue: @""];
            
      gwremote = [GWRemote gwremote];
      
      serverName = nil;
      serversNames = [NSMutableArray new];

      entry = [defaults objectForKey: @"serversnames"];
      if (entry && [entry count]) {
        [serversNames addObjectsFromArray: entry];
      }
      
      [self makePopUp];
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
  return prefName;
}

- (IBAction)chooseServer:(id)sender
{
  ASSIGN (serverName, [sender titleOfSelectedItem]);
  [nameField setStringValue: serverName];
}

- (IBAction)addServer:(id)sender
{
  NSString *sname = [nameField stringValue];
  NSArray *items = [popUp itemArray];
  BOOL duplicate = NO;
  int i;
  
  for (i = 0; i < [items count]; i++) {
    if ([[[items objectAtIndex: i] title] isEqual: sname]) {
      duplicate = YES;
      break;
    }
  }
  
  if (duplicate == NO) {
    [serversNames addObject: sname];
    [self makePopUp];
    [self updateDefaults];
  }
}

- (IBAction)removeServer:(id)sender
{
  if ([[popUp itemArray] count] == 1) {
    NSRunAlertPanel(NULL, NSLocalizedString(@"You can't remove the last server!", @""), 
                                  NSLocalizedString(@"OK", @""), NULL, NULL);   
  } else {
    NSString *title = [popUp titleOfSelectedItem];
    
    [serversNames removeObject: title];
    DESTROY (serverName);
    [self makePopUp];
    [self updateDefaults];
  }
}

- (void)updateDefaults
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];  
  
  if ([serversNames count]) {
    [defaults setObject: serversNames forKey: @"serversnames"];
	  [defaults synchronize];
    [gwremote serversListChanged];
  }
}

- (void)makePopUp
{
  [popUp removeAllItems];

  if (serversNames && [serversNames count]) {
    int i;

    for (i = 0; i < [serversNames count]; i++) {
      [popUp addItemWithTitle: [serversNames objectAtIndex: i]];
    }

    [popUp selectItemAtIndex: ([[popUp itemArray] count] -1)];
    [self chooseServer: popUp];
  
  } else {
    [popUp addItemWithTitle: NSLocalizedString(@"no servers", @"")];
  }
}

@end
