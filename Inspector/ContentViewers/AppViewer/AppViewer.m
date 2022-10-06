/* AppViewer.m
 *  
 * Copyright (C) 2004-2021 Free Software Foundation, Inc.
 *
 * Authors: Enrico Sersale <enrico@imago.ro>
 *          Riccardo Mottola <rm@gnu.org>
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

#import <AppKit/AppKit.h>
#import "AppViewer.h"

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
	
  if (self)
    {	
      NSRect r, vr;
      CGFloat x, y, w, h;
      NSButtonCell *cell;
    
      r = [self bounds];
    
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
      h = [[scroll contentView] bounds].size.height;
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
  BOOL infoIsOk;
  
  ASSIGN (currentPath, path);

  if ([self superview])      
    [inspector contentsReadyAt: currentPath];
  
  infoIsOk = NO;
  bundle = [NSBundle bundleWithPath: currentPath];
  info = [bundle infoDictionary]; 

  if (info)
    {
      NSFileManager *fm = [NSFileManager defaultManager];
      id typesAndIcons = [info objectForKey: @"NSTypes"];

      if (typesAndIcons && [typesAndIcons isKindOfClass: [NSArray class]])
	{
	  NSMutableArray *extensions = [NSMutableArray array];  
	  NSMutableDictionary *iconsdict = [NSMutableDictionary dictionary];
	  NSString *iname;
	  NSCell *cell;
	  NSUInteger i, j, count;
    
	  for (i = 0; i < [typesAndIcons count]; i++)
	    {
	      id typesarr;
	      id entry = [typesAndIcons objectAtIndex: i];
        
	      if ([entry isKindOfClass: [NSDictionary class]] == NO)
		continue;
				
	      typesarr = [(NSDictionary *)entry objectForKey: @"NSUnixExtensions"];

	      if ([typesarr isKindOfClass: [NSArray class]] == NO)
		continue;
				
	      iname = [(NSDictionary *)entry objectForKey: @"NSIcon"];

	      for (j = 0; j < [typesarr count]; j++)
		{
		  NSString *ext = [[typesarr objectAtIndex: j] lowercaseString];
		  if ([extensions indexOfObject:ext] == NSNotFound)
		    {
		      [extensions addObject: ext];
		      if (iname != nil)
			{
			  [iconsdict setObject: iname forKey: ext];
			}
		    }
		}
	    }

	  count = [extensions count];

	  [matrix renewRows: 1 columns: count];
	  [matrix sizeToCells];

	  for (i = 0; i < count; i++)
	    {
	      NSString *ext = [extensions objectAtIndex: i];
	      NSString *icnname;
	      NSString *iconPath;

	      cell = [matrix cellAtRow: 0 column: i];
	      [cell setTitle: ext];

	      icnname = [iconsdict objectForKey: ext];
	      if ([icnname length] > 0)
		{
		  iconPath = [bundle pathForImageResource: icnname];
		  if (iconPath && [fm fileExistsAtPath: iconPath])
		    {
		      NSImage *image = [[NSImage alloc] initWithContentsOfFile: iconPath];
		      [cell setImage: image];
		      RELEASE (image);
		    }
		}
	      else
		{
		  [cell setImage: nil]; // reset icon
		}
	    }
	  [matrix sizeToCells];
      
	  if (valid == NO)
	    {
	      [errLabel removeFromSuperview]; 
	      [self addSubview: explField];       
	      [self addSubview: scroll];       
	      valid = YES;
	    }
          infoIsOk = YES;
	}
    }
  
  if (infoIsOk == NO && valid == YES)
    {
      [explField removeFromSuperview]; 
      [scroll removeFromSuperview]; 
      [self addSubview: errLabel];       
      valid = NO;
    }
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
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *bpath = [[NSBundle bundleForClass: [self class]] bundlePath];
  NSString *resPath = [bpath stringByAppendingPathComponent: @"Resources"];
  NSArray *languages = [NSUserDefaults userLanguages];
  unsigned i;
     
  for (i = 0; i < [languages count]; i++) {
    NSString *language = [languages objectAtIndex: i];
    NSString *langDir = [NSString stringWithFormat: @"%@.lproj", language];  
    NSString *helpPath = [langDir stringByAppendingPathComponent: @"Help.rtfd"];
  
    helpPath = [resPath stringByAppendingPathComponent: helpPath];
  
    if ([fm fileExistsAtPath: helpPath]) {
      NSAttributedString *help = [[NSAttributedString alloc] initWithPath: helpPath
                                                       documentAttributes: NULL];
      if (help) {
        [[NSHelpManager sharedHelpManager] setContextHelp: help forObject: self];
        RELEASE (help);
      }
    }
  }
}

@end









