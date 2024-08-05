/* RunExternalController.m
 *  
 * Copyright (C) 2003-2024 Free Software Foundation, Inc.
 *
 * Authors: Enrico Sersale
 *          Riccardo Mottola
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

#import "RunExternalController.h"
#import "CompletionField.h"
#import "GWorkspace.h"


@implementation RunExternalController

- (void)dealloc
{
  [super dealloc];
}

- (instancetype)init
{
  self = [super initWithNibName:@"RunExternal"];

  if (self)
    {
      [win setFrameUsingName: @"run_external"];

      [win setTitle:NSLocalizedString(@"Run", @"")];
      [titleLabel setStringValue:NSLocalizedString(@"Run", @"")];
      [secondLabel setStringValue:NSLocalizedString(@"Type the command to execute:", @"")];
    }

  return self;
}


- (IBAction)okButtAction:(id)sender
{
  NSString *str = [cfield string];
  NSUInteger i;

  if ([str length])
    {
      NSArray *components = [str componentsSeparatedByString: @" "];
      NSMutableArray *args = [NSMutableArray array];
      NSString *command = [components objectAtIndex: 0];

      for (i = 1; i < [components count]; i++)
        {
          [args addObject: [components objectAtIndex: i]];
        }

      command = [self checkCommand: command];
      if (command)
        {
          if ([command hasSuffix:@".app"])
            [[NSWorkspace sharedWorkspace] launchApplication: command];
          else
            [NSTask launchedTaskWithLaunchPath: command arguments: args];
          [win close];
        }
      else
        {
          NSRunAlertPanel(NULL, NSLocalizedString(@"No executable found!", @""),
                          NSLocalizedString(@"OK", @""), NULL, NULL);
        }
    }
}

- (void)completionFieldDidEndLine:(id)afield
{
  [super completionFieldDidEndLine:afield];
  [win makeFirstResponder: okButt];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
  [super windowWillClose:aNotification];
  [win saveFrameUsingName: @"run_external"];
}

@end
