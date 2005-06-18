/* ClipBook.m
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 *Date: October 2003
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "ClipBook.h"
#include "ClipBookWindow.h"

#ifndef PB_MAXF
  #define PB_MAXF 9999
#endif

static ClipBook *clipbook = nil;

@implementation ClipBook

+ (void)initialize
{
	static BOOL initialized = NO;
	
	if (initialized == YES) {
		return;
  }
	
	initialized = YES;
}

+ (void)registerForServices
{
  NSMutableArray *pbtypes = [NSMutableArray array];
  
  [pbtypes addObject: NSStringPboardType];
  [pbtypes addObject: NSRTFPboardType];
  [pbtypes addObject: NSRTFDPboardType];
  [pbtypes addObject: NSTIFFPboardType];
  [pbtypes addObject: NSColorPboardType];
  [pbtypes addObject: @"IBViewPboardType"];

	[NSApp registerServicesMenuSendTypes: pbtypes returnTypes: pbtypes];
}

+ (ClipBook *)clipbook
{
	if (clipbook == nil) {
		clipbook = [[ClipBook alloc] init];
	}	
  return clipbook;
}

- (void)dealloc
{
  TEST_RELEASE (pdDir);
  RELEASE (cbwin);
  
	[super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSUserDefaults *defaults;  
  id entry;
  NSString *basePath;
  BOOL isdir;
  
  [isa registerForServices];
  
  fm = [NSFileManager defaultManager];

	defaults = [NSUserDefaults standardUserDefaults];
			
  entry = [defaults objectForKey: @"pbfnum"];
  if (entry) {
    pbFileNum = [entry intValue];
  } else {
    pbFileNum = 0;
  }      

  basePath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
  basePath = [basePath stringByAppendingPathComponent: @"ClipBook"];

  if (([fm fileExistsAtPath: basePath isDirectory: &isdir] && isdir) == NO) {
    if ([fm createDirectoryAtPath: basePath attributes: nil] == NO) {
      NSLog(@"Can't create the ClipBook directory! Quitting now.");
      [NSApp terminate: self];
    }
  }

	pdDir = [basePath stringByAppendingPathComponent: @"PBData"];

	if ([fm fileExistsAtPath: pdDir isDirectory: &isdir] == NO) {
    if ([fm createDirectoryAtPath: pdDir attributes: nil] == NO) {
      NSLog(@"Can't create pasteboard data directory! Quitting now.");
      [NSApp terminate: self];
    }
	} else {
		if (isdir == NO) {
			NSLog (@"Warning - %@ is not a directory - quitting now!", pdDir);			
			[NSApp terminate: self];
		}
  }
  
  RETAIN (pdDir);

  cbwin = [ClipBookWindow new];
  [cbwin activate];
}

- (BOOL)applicationShouldTerminate:(NSApplication *)app 
{
  [self updateDefaults];
  [cbwin updateDefaults];
  
  return YES;
}

- (NSString *)pdDir
{
  return pdDir;
}

- (NSString *)pbFilePath
{
  NSString *pbFileNName;

	pbFileNum++;
  
	if (pbFileNum >= PB_MAXF) {
		pbFileNum = 0;
	}
  
  pbFileNName = [NSString stringWithFormat: @"%i", pbFileNum];
  
  return [pdDir stringByAppendingPathComponent: pbFileNName];
}

- (NSArray *)pbTypes
{
  return [NSArray arrayWithObjects: NSStringPboardType,
                                        NSRTFPboardType,
                                        NSRTFDPboardType,
                                        NSTIFFPboardType,
                                        NSFileContentsPboardType,
                                        NSColorPboardType,
                                        @"IBViewPboardType",
                                        nil];
}

- (void)updateDefaults
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  [defaults setObject: [NSString stringWithFormat: @"%i", pbFileNum]
               forKey: @"pbfnum"];

  [defaults synchronize];
}

- (void)cut:(id)sender
{
  [cbwin doCut];    
}

- (void)copy:(id)sender
{
  [cbwin doCopy];    
}

- (void)paste:(id)sender
{
  [cbwin doPaste];    
}

- (void)showInfo:(id)sender
{
  NSMutableDictionary *d = [NSMutableDictionary dictionary];
  
  [d setObject: @"ClipBook" forKey: @"ApplicationName"];
  [d setObject: NSLocalizedString(@"GNUstep Pasteboard Viewer", @"")
      	forKey: @"ApplicationDescription"];
  [d setObject: @"ClipBook 0.6" forKey: @"ApplicationRelease"];
  [d setObject: @"10 2003" forKey: @"FullVersionID"];
  [d setObject: [NSArray arrayWithObject: @"Enrico Sersale <enrico@imago.ro>."]
        forKey: @"Authors"];
  [d setObject: NSLocalizedString(@"See http://www.gnustep.it/enrico/clipbook", @"") forKey: @"URL"];
  [d setObject: @"Copyright (C) 2003 Free Software Foundation, Inc."
        forKey: @"Copyright"];
  [d setObject: NSLocalizedString(@"Released under the GNU General Public License 2.0", @"")
        forKey: @"CopyrightDescription"];
  
  [NSApp orderFrontStandardInfoPanelWithOptions: d];
}

@end
