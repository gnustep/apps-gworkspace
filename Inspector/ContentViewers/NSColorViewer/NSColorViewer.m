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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <AppKit/AppKit.h>
#include <math.h>
#include "NSColorViewer.h"

#ifndef PI
#define PI 3.141592653589793
#endif

@implementation NSColorViewer

- (void)dealloc
{
  RELEASE (typeDescriprion);
  RELEASE (icon);
  RELEASE (colorsView);
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
    
    colorsView = [[ColorsView alloc] initWithFrame: r];
    [self addSubview: colorsView]; 
    
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
    
    ASSIGN (typeDescriprion, NSLocalizedString(@"NSColor data", @""));
    ASSIGN (icon, [NSImage imageNamed: @"colorPboard"]);
    
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
  id c = [NSUnarchiver unarchiveObjectWithData: data];

  if ([self superview]) { 
    [inspector dataContentsReadyForType: typeDescriprion useIcon: icon];
  }

  if (c && [c isKindOfClass: [NSColor class]]) {
    NSColor *color = [c colorUsingColorSpaceName: NSDeviceRGBColorSpace];
    CGFloat red = 0.0, green = 0.0, blue = 0.0, alpha = 0.0;
    CGFloat hue = 0.0, saturation = 0.0, brightness = 0.0;
    
    if (valid == NO) {
      valid = YES;
      [errLabel removeFromSuperview];
      [self addSubview: colorsView]; 
    }
    
    [color getHue: &hue saturation: &saturation brightness: &brightness alpha: &alpha];
    [colorsView setHue: hue saturation: saturation brightness: brightness];
        
    [color getRed: &red green: &green blue: &blue alpha: &alpha];
    [redField setStringValue: [NSString stringWithFormat: @"R: %.2f", red]];
    [greenField setStringValue: [NSString stringWithFormat: @"G: %.2f", green]];
    [blueField setStringValue: [NSString stringWithFormat: @"B: %.2f", blue]];
    [alphaField setStringValue: [NSString stringWithFormat: @"alpha: %.2f", alpha]];

  } else {
    if (valid == YES) {
      valid = NO;
      [colorsView removeFromSuperview];
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


@implementation ColorsView

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









