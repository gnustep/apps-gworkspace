/* NSColorViewer.m
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
#include <math.h>
#include "NSColorViewer.h"
#include "GNUstep.h"

#ifndef PI
#define PI 3.141592653589793
#endif

@implementation NSColorViewer

- (void)dealloc
{
  TEST_RELEASE (bundlePath);
  TEST_RELEASE (dataRep);
  RELEASE (typeDescriprion);
  RELEASE (icon);
  RELEASE (colorView);
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
    
    colorView = [[ColorView alloc] initWithFrame: r];
    [self addSubview: colorView]; 
    
    r.origin.y -= 20;
    r.size.width = 62;
    r.size.height = 20;
    
    r.origin.x = 5;
    redField = [[NSTextField alloc] initWithFrame: r];	
    [redField setBackgroundColor: [NSColor windowBackgroundColor]];
    [redField setBezeled: NO];
    [redField setEditable: NO];
    [redField setSelectable: NO];
    [redField setStringValue: @""];
    [self addSubview: redField]; 
    RELEASE (redField);
    
    r.origin.x += 62;
    greenField = [[NSTextField alloc] initWithFrame: r];	
    [greenField setBackgroundColor: [NSColor windowBackgroundColor]];
    [greenField setBezeled: NO];
    [greenField setEditable: NO];
    [greenField setSelectable: NO];
    [greenField setStringValue: @""];
    [self addSubview: greenField]; 
    RELEASE (greenField);

    r.origin.x += 62;
    blueField = [[NSTextField alloc] initWithFrame: r];	
    [blueField setBackgroundColor: [NSColor windowBackgroundColor]];
    [blueField setBezeled: NO];
    [blueField setEditable: NO];
    [blueField setSelectable: NO];
    [blueField setStringValue: @""];
    [self addSubview: blueField]; 
    RELEASE (blueField);

    r.origin.x += 62;
    alphaField = [[NSTextField alloc] initWithFrame: r];	
    [alphaField setBackgroundColor: [NSColor windowBackgroundColor]];
    [alphaField setBezeled: NO];
    [alphaField setEditable: NO];
    [alphaField setSelectable: NO];
    [alphaField setStringValue: @""];
    [self addSubview: alphaField]; 
    RELEASE (alphaField);
    
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
    
    ASSIGN (typeDescriprion, NSLocalizedString(@"NSColor data", @""));
    ASSIGN (icon, [NSImage imageNamed: @"colorPboard"]);
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
  id c = [NSUnarchiver unarchiveObjectWithData: data];

  if ([self superview]) { 
    [inspector dataContentsReadyForType: typeDescriprion useIcon: icon];
  }

  if (c && [c isKindOfClass: [NSColor class]]) {
    NSColor *color = [c colorUsingColorSpaceName: NSDeviceRGBColorSpace];
    float red, green, blue, alpha;
    float hue, saturation, brightness;
    
    if (valid == NO) {
      valid = YES;
      [errLabel removeFromSuperview];
      [self addSubview: colorView]; 
    }
    
    [color getHue: &hue saturation: &saturation brightness: &brightness alpha: &alpha];
    [colorView setHue: hue saturation: saturation brightness: brightness];
        
    [color getRed: &red green: &green blue: &blue alpha: &alpha];
    [redField setStringValue: [NSString stringWithFormat: @"R: %.2f", red]];
    [greenField setStringValue: [NSString stringWithFormat: @"G: %.2f", green]];
    [blueField setStringValue: [NSString stringWithFormat: @"B: %.2f", blue]];
    [alphaField setStringValue: [NSString stringWithFormat: @"alpha: %.2f", alpha]];

  } else {
    if (valid == YES) {
      valid = NO;
      [colorView removeFromSuperview];
			[self addSubview: errLabel];
      [redField setStringValue: @""];
      [greenField setStringValue: @""];
      [blueField setStringValue: @""];
      [alphaField setStringValue: @""];
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
  return ([type isEqual: NSColorPboardType]);
}

- (NSString *)winname
{
	return NSLocalizedString(@"NSColor Inspector", @"");	
}

- (NSString *)description
{
	return NSLocalizedString(@"This Inspector allow you view NSColor pasteboard data", @"");	
}

@end


@implementation ColorView

- (void)dealloc
{
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame: frameRect];
  
  if(self) {
    isColor = NO;
  }

  return self;
}

- (void)setHue:(float)h saturation:(float)s brightness:(float)b
{
  hue = h;
  saturation = s;
  brightness = b;
  isColor = YES;  
  [self setNeedsDisplay: YES];
}

- (void)drawRect:(NSRect)rect
{
  NSRect frame = [self bounds];
  NSRect r = NSIntersectionRect(frame, rect);

  [[[self window] backgroundColor] set];
  NSRectFill(r);
  NSDrawGrayBezel(frame, rect);

  if (isColor) {
    float cx, cy, cr;
    float x, y;
    float r, a;
    float dx, dy;

    cx = (frame.origin.x + frame.size.width) / 2;
    cy = (frame.origin.y + frame.size.height) / 2;

    frame.origin.x += 20;
    frame.origin.y += 20;
    frame.size.width -= 40;
    frame.size.height -= 40;
    
    cr = frame.size.width;
    
    if (cr > frame.size.height) {
      cr = frame.size.height;
    }
    
    cr = cr / 2 - 2;

    frame.origin.x = floor(frame.origin.x);
    frame.origin.y = floor(frame.origin.y);
    frame.size.width = ceil(frame.size.width) + 1;
    frame.size.height = ceil(frame.size.height) + 1;

    for (y = frame.origin.y; y < frame.origin.y + frame.size.height; y++) {
      for (x = frame.origin.x; x < frame.origin.x + frame.size.width; x++) {
	      dx = x - cx;
	      dy = y - cy;

	      r = dx * dx + dy * dy;
	      r = sqrt(r);
	      r /= cr;
	      if (r > 1) {
	        continue;
        }

	      a = atan2(dy, dx);
	      a = a / 2.0 / PI;
	      if (a < 0) {
	        a += 1;
        }

	      PSsethsbcolor(a, r, brightness);
	      PSrectfill(x,y,1,1);
	    }
    }

    a = hue * 2 * PI;
    r = saturation * cr;

    x = cos(a) * r + cx;
    y = sin(a) * r + cy;

    PSsetgray(0);
    PSrectstroke(x - 4, y - 4, 8, 8);
  }
}

@end









