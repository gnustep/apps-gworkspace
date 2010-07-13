/* IconsPref.m
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

#import "IconsPref.h"
#import "GWorkspace.h"

static NSString *nibName = @"IconsPref";

@implementation IconsPref

- (void)dealloc
{
  RELEASE (prefbox);
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
     
      gw = [GWorkspace gworkspace];
  
      [thumbCheck setState: [defaults boolForKey: @"usesthumbnails"] ? NSOnState : NSOffState];  
      
      /* Internationalization */
      [thumbbox setTitle: NSLocalizedString(@"Thumbnails", @"")];
      [thumbCheck setTitle: NSLocalizedString(@"use thumbnails", @"")];
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
  return NSLocalizedString(@"Icons", @"");
}

- (IBAction)setUnsetThumbnails:(id)sender
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
  unsigned int state = [sender state];

  [defaults setBool: ((state == NSOnState) ? YES : NO) 
             forKey: @"usesthumbnails"];
  [defaults synchronize];  
  
  [gw setUsesThumbnails: ((state == NSOnState) ? YES : NO)];
}

@end
