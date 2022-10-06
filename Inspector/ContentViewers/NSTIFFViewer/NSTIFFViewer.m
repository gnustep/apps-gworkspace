/* NSTIFFViewer.m
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
#include "NSTIFFViewer.h"

@implementation NSTIFFViewer

- (void)dealloc
{
  RELEASE (typeDescriprion);
  RELEASE (icon);
  RELEASE (imview);
  RELEASE (errLabel);
  
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect
          inspector:(id)insp
{
  self = [super initWithFrame: frameRect];
  
  if(self) {
    NSRect r = [self bounds];
    
    r.origin.y += 30;
    r.size.height -= 30;
    
    imview = [[NSImageView alloc] initWithFrame: r];
    [imview setEditable: NO];
    [imview setImageFrameStyle: NSImageFrameGrayBezel];
    [imview setImageAlignment: NSImageAlignCenter];
    [self addSubview: imview]; 
    
    r.origin.x = 10;
    r.origin.y -= 20;
    r.size.width = 90;
    r.size.height = 20;
    widthLabel = [[NSTextField alloc] initWithFrame: r];	
    [widthLabel setBackgroundColor: [NSColor windowBackgroundColor]];
    [widthLabel setBezeled: NO];
    [widthLabel setEditable: NO];
    [widthLabel setSelectable: NO];
    [widthLabel setStringValue: @""];
    [self addSubview: widthLabel]; 
    RELEASE (widthLabel);

    r.origin.x = 160;
    heightLabel = [[NSTextField alloc] initWithFrame: r];	
    [heightLabel setBackgroundColor: [NSColor windowBackgroundColor]];
    [heightLabel setBezeled: NO];
    [heightLabel setEditable: NO];
    [heightLabel setSelectable: NO];
    [heightLabel setAlignment: NSRightTextAlignment];
    [heightLabel setStringValue: @""];
    [self addSubview: heightLabel]; 
    RELEASE (heightLabel);

    r.origin.x = 2;
    r.origin.y = 170;
    r.size.width = [self bounds].size.width - 4;
    r.size.height = 25;
    errLabel = [[NSTextField alloc] initWithFrame: r];	
    [errLabel setFont: [NSFont systemFontOfSize: 18]];
    [errLabel setAlignment: NSCenterTextAlignment];
    [errLabel setBackgroundColor: [NSColor windowBackgroundColor]];
    [errLabel setTextColor: [NSColor darkGrayColor]];	
    [errLabel setBezeled: NO];
    [errLabel setEditable: NO];
    [errLabel setSelectable: NO];
    [errLabel setStringValue: NSLocalizedString(@"Invalid Contents", @"")];

    inspector = insp;
    valid = YES;
    
    ASSIGN (typeDescriprion, NSLocalizedString(@"Image data", @""));
    ASSIGN (icon, [NSImage imageNamed: @"tiffPboard"]);
  
    [self setContextHelp];
  }
	
	return self;
}

- (void)displayPath:(NSString *)path
{
}

- (void)displayData:(NSData *)data 
             ofType:(NSString *)type
{
  NSImage *image = [[NSImage alloc] initWithData: data];

  if ([self superview]) { 
    [inspector dataContentsReadyForType: typeDescriprion useIcon: icon];
  }

  if (image) {
    NSSize is = [image size];
    float width = is.width;
    float height = is.height;
    NSSize rs = [imview bounds].size;
    NSString *str;

    if (valid == NO) {
      valid = YES;
      [errLabel removeFromSuperview];
      [self addSubview: imview]; 
    }
    
    if ((width <= rs.width) && (height <= rs.height)) {
      [imview setImageScaling: NSScaleNone];
    } else {
      [imview setImageScaling: NSScaleProportionally];
    }

    [imview setImage: image];
    RELEASE (image);
    
    str = NSLocalizedString(@"Width:", @"");
    str = [NSString stringWithFormat: @"%@ %.0f", str, width];
    [widthLabel setStringValue: str];

    str = NSLocalizedString(@"Height:", @"");
    str = [NSString stringWithFormat: @"%@ %.0f", str, height];
    [heightLabel setStringValue: str];

  } else {
    if (valid == YES) {
      valid = NO;
      [imview removeFromSuperview];
			[self addSubview: errLabel];
      [widthLabel setStringValue: @""];
      [heightLabel setStringValue: @""];
    }
  }
}

- (NSString *)currentPath
{
  return nil;
}

- (void)stopTasks
{
}

- (BOOL)canDisplayPath:(NSString *)path
{
	return NO;
}

- (BOOL)canDisplayDataOfType:(NSString *)type
{
  return ([type isEqual: NSTIFFPboardType]);
}

- (NSString *)winname
{
	return NSLocalizedString(@"NSTIFF Inspector", @"");	
}

- (NSString *)description
{
	return NSLocalizedString(@"This Inspector allow you view NSTIFF pasteboard data", @"");	
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
