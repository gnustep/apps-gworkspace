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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <AppKit/AppKit.h>
#include "NSTIFFViewer.h"

@implementation NSTIFFViewer

- (void)dealloc
{
  TEST_RELEASE (bundlePath);
  TEST_RELEASE (dataRep);
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
    NSRect r = [self frame];
    
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
    r.size.width = [self frame].size.width - 4;
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
    bundlePath = nil;
    dataRep = nil;
    
    ASSIGN (typeDescriprion, NSLocalizedString(@"Image data", @""));
    ASSIGN (icon, [NSImage imageNamed: @"tiffPboard"]);
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

- (void)setDataRepresentation:(NSData *)rep
{
  ASSIGN (dataRep, rep);
}

- (NSData *)dataRepresentation
{
  return dataRep;
}

- (void)setIsRemovable:(BOOL)value
{
  removable = value;
}

- (BOOL)isRemovable
{
  return removable;
}

- (void)setIsExternal:(BOOL)value
{
  external = value;
}

- (BOOL)isExternal
{
  return external;
}

- (void)displayPath:(NSString *)path
{
}

- (void)displayLastPath:(BOOL)forced
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
    NSSize rs = [imview frame].size;
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

@end
