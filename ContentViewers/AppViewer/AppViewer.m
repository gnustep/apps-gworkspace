/* AppViewer.m
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
  #ifdef GNUSTEP 
#include "InspectorsProtocol.h"
#include "GWLib.h"
  #else
#include <GWorkspace/InspectorsProtocol.h>
#include <GWorkspace/GWLib.h>
  #endif
#include "AppViewer.h"
#include "GNUstep.h"

@implementation AppViewer

- (void) dealloc
{
	TEST_RELEASE (matrix);
	RELEASE (scroll);
	RELEASE (label);
	RELEASE (bundlePath);
  [super dealloc];
}

- (id)initInPanel:(id)apanel withFrame:(NSRect)frame index:(int)idx
{
	self = [super init];
	
	if (self) {	
		id cell;
		 
		[self setAutoresizesSubviews: NO];
		[self setFrame: frame];
		panel = (id<InspectorsProtocol>)apanel;
		ws = [NSWorkspace sharedWorkspace];
		index = idx;
		
  	label = [[NSTextField alloc] init];	
  	[label setAlignment: NSCenterTextAlignment];
  	[label setBackgroundColor: [NSColor windowBackgroundColor]];
  	[label setTextColor: [NSColor grayColor]];	
  	[label setBezeled: NO];
  	[label setEditable: NO];
  	[label setSelectable: NO];
		[label setFrame: NSMakeRect(30, 125, 197, 20)];
		[label setFont: [NSFont systemFontOfSize: 12]];
		localizedStr = NSLocalizedString(@"Open these kinds of documents:", @"");
		[label setStringValue: localizedStr];
  	[self addSubview: label];
		
    scroll = [[NSScrollView alloc] initWithFrame: NSMakeRect(30, 35, 197, 87)];
    [scroll setBorderType: NSBezelBorder];
    [scroll setHasHorizontalScroller: YES];
    [scroll setHasVerticalScroller: NO]; 
    [scroll setAutoresizingMask: NSViewHeightSizable | NSViewWidthSizable];
    [self addSubview: scroll]; 
		
    cell = AUTORELEASE ([NSButtonCell new]);
    [cell setButtonType: NSPushOnPushOffButton];
    [cell setImagePosition: NSImageOnly]; 
				
    matrix = [[NSMatrix alloc] initWithFrame: NSZeroRect
				            				mode: NSRadioModeMatrix prototype: cell
			       												numberOfRows: 0 numberOfColumns: 0];
    [matrix setIntercellSpacing: NSZeroSize];
    [matrix setCellSize: NSMakeSize(64, 64)];
		[matrix setAllowsEmptySelection: YES];
		[scroll setDocumentView: matrix];	
				
		valid = YES;
  }
	
	return self;
}

- (void)setBundlePath:(NSString *)path
{
  ASSIGN (bundlePath, path);
}

- (NSString *)bundlePath
{
  return bundlePath;
}

- (void)setIndex:(int)idx
{
  index = idx;
}

- (void)activateForPath:(NSString *)path
{
  NSBundle *bundle;
  NSDictionary *info;
  NSMutableArray *extensions;
  NSMutableDictionary *iconsdict;
    
  extensions = [NSMutableArray arrayWithCapacity: 1];  
  iconsdict = [NSMutableDictionary dictionaryWithCapacity: 1];  
  bundle = [NSBundle bundleWithPath: path];
  info = [bundle infoDictionary]; 
	
  if (info != nil) {
  	NSString *iname;
		id cell;
		id typesarr;
    id typesAndIcons;
    int i, j, count;
		    
    typesAndIcons = [info objectForKey: @"NSTypes"];
    
    if ([typesAndIcons isKindOfClass: [NSArray class]]) {
      i = [typesAndIcons count];
      
      while (i-- > 0) {
        id entry = [typesAndIcons objectAtIndex: i];
        
        if ([entry isKindOfClass: [NSDictionary class]] == NO) {
					continue;
				}
				
        typesarr = [entry objectForKey: @"NSUnixExtensions"];

        if ([typesarr isKindOfClass: [NSArray class]] == NO) {
					continue;
				}
				
        j = [typesarr count];
        iname = [entry objectForKey: @"NSIcon"];

        while (j-- > 0) {
          NSString *ext = [[typesarr objectAtIndex: j] lowercaseString];
          [extensions addObject: ext];
          if(iname != nil) {
            [iconsdict setObject: iname forKey: ext];
          }
        }
      }
    }

		if (valid == NO) {
			[label setFrame: NSMakeRect(30, 125, 197, 20)];
			[label setFont: [NSFont systemFontOfSize: 12]];
			localizedStr = NSLocalizedString(@"Open these kinds of documents:", @"");
			[label setStringValue: localizedStr];
			[self addSubview: scroll]; 
			valid = YES;
		}		
			
		count = [extensions count];
		
    for (i = 0; i < count; i++) {
			NSString *ext1 = [extensions objectAtIndex: i];
			NSString *icnname1 = [iconsdict objectForKey: ext1];

    	for (j = 0; j < count; j++) {
				NSString *ext2 = [extensions objectAtIndex: j];
				NSString *icnname2 = [iconsdict objectForKey: ext2];

				if ((i != j) && ([icnname1 isEqual: icnname2])) {
					[iconsdict removeObjectForKey: ext1];
				}
			}
		}

		(NSArray *)extensions = [iconsdict allKeys];
		count = [extensions count];
		
		[scroll setFrame: NSMakeRect(30, 35, 197, 87)];
		[matrix renewRows: 1 columns: count];
		[matrix sizeToCells];
		
    for (i = 0; i < count; i++) {
      NSString *ext = [extensions objectAtIndex: i];
			NSString *icnname = [iconsdict objectForKey: ext];
			NSString *iconPath = [bundle pathForImageResource: icnname];
      NSImage *image = [[NSImage alloc] initWithContentsOfFile: iconPath]; 
			cell = [matrix cellAtRow: 0 column: i];
			[cell setTitle: ext];
			[cell setImage: image];     
      RELEASE (image);
		}
		[matrix sizeToCells];
		
  } else { 
		if (valid == YES) {
			[label setFrame: NSMakeRect(2, 133, 255, 25)];	
			[label setFont: [NSFont systemFontOfSize: 18]];
			localizedStr = NSLocalizedString(@"Invalid Contents", @"");
			[label setStringValue: localizedStr];
			[scroll removeFromSuperview]; 
			valid = NO;
		}		
  }
}

- (BOOL)displayData:(NSData *)data ofType:(NSString *)type
{
  return NO;
}

- (BOOL)stopTasks
{
  return YES;
}

- (void)deactivate
{
	[self removeFromSuperview];
}

- (BOOL)canDisplayFileAtPath:(NSString *)path
{
	NSString *defApp, *fileType;
		
	[ws getInfoForFile: path application: &defApp type: &fileType];
	
	if ([fileType isEqual: NSApplicationFileType]) {
		return YES;
  }

	return NO;
}

- (BOOL)canDisplayData:(NSData *)data ofType:(NSString *)type
{
  return NO;
}

- (int)index
{
	return index;
}

- (NSString *)winname
{
	return NSLocalizedString(@"App Inspector", @"");
}

@end









