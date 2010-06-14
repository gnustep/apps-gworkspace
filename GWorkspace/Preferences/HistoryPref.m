/* HistoryPref.m
 *  
 * Copyright (C) 2003-2010 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: September 2004
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

#include <math.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <GNUstepBase/GNUstep.h>

#import "FSNodeRep.h"
#import "HistoryPref.h"
#import "GWorkspace.h"

#define CACHE_MAX 10000
#define CACHE_MIN 4

static NSString *nibName = @"HistoryPref";

@implementation HistoryPref

- (void)dealloc
{
	RELEASE (prefbox);
  [super dealloc];
}

- (id)init
{
	self = [super init];
	if(self) {
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
    } else {
      int cachemax;
    
      RETAIN (prefbox);
      RELEASE (win);

      gworkspace = [GWorkspace gworkspace];

      [stepper setMaxValue: CACHE_MAX];
      [stepper setMinValue: CACHE_MIN];
      [stepper setIncrement: 1];
      [stepper setAutorepeat: YES];
      [stepper setValueWraps: NO];
      
      cachemax = [gworkspace maxHistoryCache];
      [cacheField setStringValue: [NSString stringWithFormat: @"%i", cachemax]];
      [stepper setDoubleValue: cachemax];
 
	    /* Internationalization */
	    [cacheBox setTitle: NSLocalizedString(@"Number of saved paths", @"")];
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
  return NSLocalizedString(@"History", @"");
}

- (IBAction)stepperAction:(id)sender;
{
  int sv = floor([sender doubleValue]);

  [cacheField setStringValue: [NSString stringWithFormat: @"%i", sv]];
  [gworkspace setMaxHistoryCache: sv];
}

@end




