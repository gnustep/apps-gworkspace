/* ExecuteController.m
 *  
 * Copyright (C) 2003-2024 Free Software Foundation, Inc.
 *
 * Authors: Enrico Sersale
 *          Riccardo Mottola
 *
 * Date: July 2024
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

#import "ExecuteController.h"
#import "CompletionField.h"
#import "FSNode.h"


@implementation ExecuteController

- (void)dealloc
{
  RELEASE (win);
  RELEASE (pathsArr);
  [super dealloc];
}

- (instancetype)initWithNibName:(NSString *)nibName
{
  self = [super init];
  
  if (self)
    {
      if ([NSBundle loadNibNamed: nibName owner: self] == NO)
        {
          NSLog(@"failed to load %@!", nibName);
          [self release];
          return nil;
        }
      else
        {
          [okButt setTitle:NSLocalizedString(@"OK", @"")];
          [cancelButt setTitle:NSLocalizedString(@"Cancel", @"")];
        }
    }

  return self;
}

- (NSWindow *)win
{
  return win;
}

- (IBAction)cancelButtAction:(id)sender
{
  [win close];
}

- (NSString *)checkCommand:(NSString *)comm
{
  if ([comm isAbsolutePath])
    {
      FSNode *node = [FSNode nodeWithPath: comm];

      if ([node isApplication])
        {
          // standardize path, to remove e.g. trailing /
          return [comm stringByStandardizingPath];
        }

      if (node && [node isPlain] && [node isExecutable])
        {
          return comm;
        }
    }
  else
    {
      NSUInteger i;

      // check if we suppose an application
      if ([comm hasSuffix:@".app"])
        {
          NSLog(@"assume app name");
          return comm;
        }
      else
        {
          // we look for a standard tool or executable
          for (i = 0; i < [pathsArr count]; i++)
            {
              NSString *basePath = [pathsArr objectAtIndex: i];
              NSArray *contents = [fm directoryContentsAtPath: basePath];

              if (contents && [contents containsObject: comm])
                {
                  NSString *fullPath = [basePath stringByAppendingPathComponent: comm];

                  if ([fm isExecutableFileAtPath: fullPath])
                    {
                      return fullPath;
                    }
                }
            }
        }
    }

  return nil;
}

- (void)activate
{
  [win makeKeyAndOrderFront: nil];
  [cfield setString: @""];
  [win makeFirstResponder: cfield];
}

- (IBAction)okButtAction:(id)sender
{
}

- (void)completionFieldDidEndLine:(id)afield
{
}

- (void)windowWillClose:(NSNotification *)aNotification
{
}


@end
