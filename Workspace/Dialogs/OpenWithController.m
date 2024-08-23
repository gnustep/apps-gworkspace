/* OpenWithController.m
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

#import "OpenWithController.h"
#import "CompletionField.h"
#import "GWorkspace.h"
#import "FSNode.h"


@implementation OpenWithController

- (void)dealloc
{
  [super dealloc];
}

- (instancetype)init
{
  self = [super initWithNibName:@"OpenWith"];
  
  if (self)
    {
      gw = [GWorkspace gworkspace];

      [win setTitle:NSLocalizedString(@"Open With", @"")];
      [firstLabel setStringValue:NSLocalizedString(@"Type the name or the path of the application", @"")];
      [secondLabel setStringValue:NSLocalizedString(@"to use to open the current selection", @"")];
    }

  return self;
}

- (void)activate
{
  NSArray *selpaths = RETAIN ([gw selectedPaths]);
  NSWorkspace *ws = [NSWorkspace sharedWorkspace];
  NSUInteger i;

  // first we check incoming selection or it is useless to check for a command
  for (i = 0; i < [selpaths count]; i++)
    {
      NSString *spath = [selpaths objectAtIndex: i];
      NSString *defApp = nil, *fileType = nil;

      [ws getInfoForFile: spath application: &defApp type: &fileType];

      if ((fileType == nil)
          || (([fileType isEqual: NSPlainFileType] == NO)
              && ([fileType isEqual: NSShellCommandFileType] == NO)))
        {
          NSRunAlertPanel(NULL, NSLocalizedString(@"Can't edit a directory!", @""),
                          NSLocalizedString(@"OK", @""), NULL, NULL);
          RELEASE (selpaths);
          return;
        }
    }

  [NSApp runModalForWindow: win];

  RELEASE (selpaths);
}


- (IBAction)cancelButtAction:(id)sender
{
  result = NSAlertAlternateReturn;
  [NSApp stopModal];
  [win close];
}

- (IBAction)okButtAction:(id)sender
{
  NSString *str = [cfield string];
  NSUInteger i;
  result = NSAlertDefaultReturn;
  [NSApp stopModal];
  [win close];

  if ([str length])
    {
      NSArray *selpaths = [gw selectedPaths];
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
            {
              NSUInteger i;

              for (i = 0; i < [selpaths count]; i++)
                {
                  NSString *fileName = [selpaths objectAtIndex:i];

                  [[NSWorkspace sharedWorkspace] openFile:fileName withApplication: command];
                }
            }
          else
            {
              [args addObjectsFromArray:selpaths];
              [NSTask launchedTaskWithLaunchPath: command arguments: args];
            }
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
  [win makeFirstResponder: okButt];
}

@end
