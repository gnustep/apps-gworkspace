/* RunExternalController.m
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
#include "RunExternalController.h"
#include "CompletionField.h"
#include "GWorkspace.h"
#include "GNUstep.h"

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
  
  if (self) {
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
      return self;
    } else {  
      NSDictionary *environment = [[NSProcessInfo processInfo] environment];
      NSString *paths = [environment objectForKey: @"PATH"];  
      
      ASSIGN (pathsArr, [paths componentsSeparatedByString: @":"]);
  
		  cfield = [[CompletionField alloc] init];
      [cfield setFrame: [[fieldBox contentView] frame]];
      [cfield setNextKeyView: okButt]; 
      [fieldBox addSubview: cfield];      
      [fieldBox sizeToFit];
      RELEASE (cfield);
      
      fm = [NSFileManager defaultManager];
    }
  }
  
  return self;  
}

- (NSString *)checkCommand:(NSString *)comm
{
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
    
  return nil;
}

- (void)activate
{
  [NSApp runModalForWindow: win];
  
  if (result == NSAlertDefaultReturn) {
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
      } else {
        NSRunAlertPanel(NULL, NSLocalizedString(@"No executable found!", @""),
                                    NSLocalizedString(@"OK", @""), NULL, NULL);   
      }
    }
  }
}

- (IBAction)cancelButtAction:(id)sender
{
  result = NSAlertAlternateReturn;
  [NSApp stopModal];
  [win close];
}

- (IBAction)okButtAction:(id)sender
{
  result = NSAlertDefaultReturn;
  [NSApp stopModal];
  [win close];
}

@end
