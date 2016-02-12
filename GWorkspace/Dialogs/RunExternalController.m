/* RunExternalController.m
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

#import "RunExternalController.h"
#import "CompletionField.h"
#import "GWorkspace.h"
#import "FSNode.h"


static NSString *nibName = @"RunExternal";

@implementation RunExternalController

- (void)dealloc
{
  RELEASE (win);
  RELEASE (pathsArr);
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self)
    {
      if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
      return self;
    } else {  
      NSDictionary *environment = [[NSProcessInfo processInfo] environment];
      NSString *paths = [environment objectForKey: @"PATH"];  
      
      ASSIGN (pathsArr, [paths componentsSeparatedByString: @":"]);
      
      [win setDelegate: self];
      [win setFrameUsingName: @"run_external"];
      [win setInitialFirstResponder: cfield];

      [win setTitle:NSLocalizedString(@"Run", @"")];
      [titleLabel setStringValue:NSLocalizedString(@"Run", @"")];
      [secondLabel setStringValue:NSLocalizedString(@"Type the command to execute:", @"")];
      [okButt setTitle:NSLocalizedString(@"OK", @"")];
      [cancelButt setTitle:NSLocalizedString(@"Cancel", @"")];
      
      fm = [NSFileManager defaultManager];
    }
  }
  
  return self;  
}

- (NSString *)checkCommand:(NSString *)comm
{  
  if ([comm isAbsolutePath]) {
    FSNode *node = [FSNode nodeWithPath: comm];
  
    if (node && [node isPlain] && [node isExecutable]) {
      return comm;
    }
  } else {
    int i;
    
    for (i = 0; i < [pathsArr count]; i++) {
      NSString *basePath = [pathsArr objectAtIndex: i];
      NSArray *contents = [fm directoryContentsAtPath: basePath];

      if (contents && [contents containsObject: comm]) {
        NSString *fullPath = [basePath stringByAppendingPathComponent: comm];

        if ([fm isExecutableFileAtPath: fullPath]) {
          return fullPath;
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

- (NSWindow *)win
{
  return win;
}

- (IBAction)cancelButtAction:(id)sender
{
  [win close];
}

- (IBAction)okButtAction:(id)sender
{
  NSString *str = [cfield string];
  int i;

  if ([str length]) {
    NSArray *components = [str componentsSeparatedByString: @" "];
    NSMutableArray *args = [NSMutableArray array];
    NSString *command = [components objectAtIndex: 0];

    for (i = 1; i < [components count]; i++) {
      [args addObject: [components objectAtIndex: i]];
    }

    command = [self checkCommand: command];

    if (command) {
      [NSTask launchedTaskWithLaunchPath: command arguments: args];
      [win close];
    } else {
      NSRunAlertPanel(NULL, NSLocalizedString(@"No executable found!", @""),
                                  NSLocalizedString(@"OK", @""), NULL, NULL);   
    }
  }
}

- (void)completionFieldDidEndLine:(id)afield
{
  [win makeFirstResponder: okButt];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
  [win saveFrameUsingName: @"run_external"];
}

@end
