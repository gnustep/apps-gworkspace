/* AppViewer.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
 *
 * This file is part of the GNUstep Inspector application
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

#include <AppKit/AppKit.h>
#include "AppViewer.h"

@implementation AppViewer

- (void)dealloc
{
	RELEASE (scroll);
	RELEASE (explField);
  RELEASE (errLabel);
  TEST_RELEASE (currentPath);
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect
          inspector:(id)insp
{
	self = [super initWithFrame: frameRect];
	
	if (self) {	
    NSRect r, vr;
    float x, y, w, h;
		id cell;
    
    r = [self frame];
    
    x = 5;
    y = r.origin.y + 182;
    w = r.size.width - 10;
    h = 20;
    vr = NSMakeRect(x, y, w, h);
  	explField = [[NSTextField alloc] init];	
		[explField setFrame: vr];
  	[explField setAlignment: NSCenterTextAlignment];
		[explField setFont: [NSFont systemFontOfSize: 12]];
  	[explField setBackgroundColor: [NSColor windowBackgroundColor]];
  	[explField setTextColor: [NSColor darkGrayColor]];	
  	[explField setBezeled: NO];
  	[explField setEditable: NO];
  	[explField setSelectable: NO];
		[explField setStringValue: NSLocalizedString(@"Open these kinds of documents:", @"")];
  	[self addSubview: explField];
		
    w = 196;    
    h = 94;
    x = (r.size.width - w) / 2;
    y = r.origin.y + 85;
    vr = NSMakeRect(x, y, w, h);    
    scroll = [[NSScrollView alloc] initWithFrame: vr];
    [scroll setBorderType: NSBezelBorder];
    [scroll setHasHorizontalScroller: YES];
    [scroll setHasVerticalScroller: NO]; 
    [self addSubview: scroll]; 
		
    cell = [NSButtonCell new];
    [cell setButtonType: NSPushOnPushOffButton];
    [cell setImagePosition: NSImageAbove]; 
				
    matrix = [[NSMatrix alloc] initWithFrame: NSZeroRect
				            				mode: NSRadioModeMatrix prototype: cell
			       												numberOfRows: 0 numberOfColumns: 0];
    RELEASE (cell);
    [matrix setIntercellSpacing: NSZeroSize];
    h = [[scroll contentView] frame].size.height;
    [matrix setCellSize: NSMakeSize(64, h)];
		[matrix setAllowsEmptySelection: YES];
		[scroll setDocumentView: matrix];	
    RELEASE (matrix);

    x = 5;
    y = r.origin.y + 162;
    w = r.size.width - 10;
    h = 25;
    vr = NSMakeRect(x, y, w, h);
  	errLabel = [[NSTextField alloc] init];	
		[errLabel setFrame: vr];
  	[errLabel setAlignment: NSCenterTextAlignment];
		[errLabel setFont: [NSFont systemFontOfSize: 18]];
  	[errLabel setBackgroundColor: [NSColor windowBackgroundColor]];
  	[errLabel setTextColor: [NSColor darkGrayColor]];	
  	[errLabel setBezeled: NO];
  	[errLabel setEditable: NO];
  	[errLabel setSelectable: NO];
		[errLabel setStringValue: NSLocalizedString(@"Invalid Contents", @"")];

    currentPath = nil;

    inspector = insp;
    ws = [NSWorkspace sharedWorkspace];
				
		valid = YES;
    
    [self setContextHelp];
  }
	
	return self;
}

- (void)displayPath:(NSString *)path
{
  NSBundle *bundle;
  NSDictionary *info;
  BOOL infok;
  
  ASSIGN (currentPath, path);

  if ([self superview]) {      
    [inspector contentsReadyAt: currentPath];
  }
  
  infok = YES;
  bundle = [NSBundle bundleWithPath: currentPath];
  info = [bundle infoDictionary]; 
	
  if (info) {
    id typesAndIcons = [info objectForKey: @"NSTypes"];
    
    if (typesAndIcons && [typesAndIcons isKindOfClass: [NSArray class]]) {
      NSMutableArray *extensions = [NSMutableArray array];  
      NSMutableDictionary *iconsdict = [NSMutableDictionary dictionary];
  	  NSString *iname;
		  id cell;
		  id typesarr;        
      int i, j, count;
    
      i = [typesAndIcons count];
      
      while (i-- > 0) {
        id entry = [typesAndIcons objectAtIndex: i];
        
        if ([entry isKindOfClass: [NSDictionary class]] == NO) {
					continue;
				}
				
        typesarr = [(NSDictionary *)entry objectForKey: @"NSUnixExtensions"];

        if ([typesarr isKindOfClass: [NSArray class]] == NO) {
					continue;
				}
				
        j = [typesarr count];
        iname = [(NSDictionary *)entry objectForKey: @"NSIcon"];

        while (j-- > 0) {
          NSString *ext = [[typesarr objectAtIndex: j] lowercaseString];
          [extensions addObject: ext];
          if (iname != nil) {
            [iconsdict setObject: iname forKey: ext];
          }
        }
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

		  extensions = [NSMutableArray arrayWithArray: [iconsdict allKeys]];
		  count = [extensions count];

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
      
		  if (valid == NO) {
			  [errLabel removeFromSuperview]; 
        [self addSubview: explField];       
        [self addSubview: scroll];       
			  valid = YES;
		  }		
      
    } else {
      infok = NO;  
    }
		
  } else { 
		infok = NO;  		
  }
  
  if (infok == NO) {
    if (valid == YES) {
			[explField removeFromSuperview]; 
			[scroll removeFromSuperview]; 
      [self addSubview: errLabel];       
			valid = NO;
    }
  }  
}

- (void)displayLastPath:(BOOL)forced
{
  [self displayPath: currentPath];
}

- (void)displayData:(NSData *)data 
             ofType:(NSString *)type
{
}

- (NSString *)currentPath
{
  return currentPath;
}

- (void)stopTasks
{
}

- (BOOL)canDisplayPath:(NSString *)path
{
	NSString *defApp = nil, *fileType = nil;
		
	[ws getInfoForFile: path 
         application: &defApp 
                type: &fileType];
	
  return (fileType && [fileType isEqual: NSApplicationFileType]);
}

- (BOOL)canDisplayDataOfType:(NSString *)type
{
  return NO;
}

- (NSString *)winname
{
	return NSLocalizedString(@"Application Inspector", @"");
}

- (NSString *)description
{
	return NSLocalizedString(@"Displays info about an application bundle", @"");	
}

- (void)setContextHelp
{
  NSBundle *bundle = [NSBundle bundleForClass: [self class]];
  NSString *hpath = [bundle pathForResource: @"Help" ofType: @"rtfd"];
  NSAttributedString *help = [[NSAttributedString alloc] initWithPath: hpath
                                                   documentAttributes: NULL];
                                    
  [[NSHelpManager sharedHelpManager] setContextHelp: help withObject: self];
                                    
  RELEASE (help);
}

@end









