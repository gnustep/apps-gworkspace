/* TimeDateView.m
 *  
 * Copyright (C) 2004-2013 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
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
#import "TimeDateView.h"
#import "Inspector.h"

static const int tf_posx[11] = { 5, 14, 24, 28, 37, 40, 17, 17, 22, 27, 15 };
static const int posy[4]  = { 1, 13, 29, 38 };

@implementation TimeDateView

- (void)dealloc
{
  RELEASE (maskImage);
  RELEASE (hour1Image);
  RELEASE (hour2Image);
  RELEASE (hour3Image);
  RELEASE (minute1Image);
  RELEASE (minute2Image);
  RELEASE (dayweekImage);
  RELEASE (daymont1Image);
  RELEASE (daymont2Image);
  RELEASE (monthImage);
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame: frameRect];
  
  if (self)
    {
      maskImage = nil;
      yearlabel = [NSTextFieldCell new];
      [yearlabel setFont: [NSFont systemFontOfSize: 8]];
      [yearlabel setAlignment: NSCenterTextAlignment];    
    }
  
  return self;
}

- (void)setDate:(NSCalendarDate *)adate
{
  CREATE_AUTORELEASE_POOL (pool);
  NSBundle *bundle;
  NSString *imgName;
  NSString *imagepath;
  NSImage *image;
  int n, hour, minute, dayOfWeek, dayOfMonth, month;
	
  hour = [adate hourOfDay];
  minute = [adate minuteOfHour];
  dayOfWeek = [adate dayOfWeek];
  dayOfMonth = [adate dayOfMonth];
  month = [adate monthOfYear];

  bundle = [NSBundle bundleForClass: [Inspector class]];
  
  imagepath = [bundle pathForResource: @"Mask" ofType: @"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile: imagepath]; 
	ASSIGN (maskImage, image);
  RELEASE (image);
 
  //
  // hour
  //
  n = hour/10;
  imgName = [NSString stringWithFormat: @"LED-%d", n];		
  imagepath = [bundle pathForResource: imgName ofType: @"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile: imagepath]; 
  ASSIGN (hour1Image, image);
  RELEASE (image);
	
  n = hour%10;		
  imgName = [NSString stringWithFormat: @"LED-%d", n];
  imagepath = [bundle pathForResource: imgName ofType: @"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile: imagepath]; 
  ASSIGN (hour2Image, image);
  RELEASE (image);
  
  imagepath = [bundle pathForResource: @"LED-Colon" ofType: @"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile: imagepath]; 
  ASSIGN (hour3Image, image);
  RELEASE (image);

  //
  // minute
  //
  n = minute/10;
  imgName = [NSString stringWithFormat: @"LED-%d", n];
  imagepath = [bundle pathForResource: imgName ofType: @"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile: imagepath]; 
  ASSIGN (minute1Image, image);
  RELEASE (image);
  
  n = minute%10;
  imgName = [NSString stringWithFormat: @"LED-%d", n];
  imagepath = [bundle pathForResource: imgName ofType: @"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile: imagepath]; 
  ASSIGN (minute2Image, image);
  RELEASE (image);

  //
  // dayOfWeek
  //
  imgName = [NSString stringWithFormat: @"Weekday-%d", dayOfWeek];
  imagepath = [bundle pathForResource: imgName ofType: @"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile: imagepath]; 
  ASSIGN (dayweekImage, image);
  RELEASE (image);

  //
  // dayOfMonth
  //
  n = dayOfMonth/10;
  imgName = [NSString stringWithFormat: @"Date-%d", n];
  imagepath = [bundle pathForResource: imgName ofType: @"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile: imagepath]; 
  ASSIGN (daymont1Image, image);
  RELEASE (image);

  n = dayOfMonth%10;
  imgName = [NSString stringWithFormat: @"Date-%d", n];
  imagepath = [bundle pathForResource: imgName ofType: @"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile: imagepath]; 
  ASSIGN (daymont2Image, image);
  RELEASE (image);

  //
  // month
  //
  n = month;
  imgName = [NSString stringWithFormat: @"Month-%d", n];
  imagepath = [bundle pathForResource: imgName ofType: @"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile: imagepath]; 
  ASSIGN (monthImage, image);
  RELEASE (image);
  
  [yearlabel setStringValue: [NSString stringWithFormat: @"%li", (long int)[adate yearOfCommonEra]]];

  RELEASE (pool);
  [self setNeedsDisplay: YES];
}

- (void)drawRect:(NSRect)rect
{
  NSRect r;
  NSSize s; 
  NSPoint p;
  CGFloat h;
	
  if (maskImage == nil) {
    return;
  }
  
  s = [maskImage size];
  h = s.height;
  r = NSInsetRect(rect, (rect.size.width - s.width)/2, 
                  (rect.size.height - s.height)/2);
  p = NSMakePoint(r.origin.x, r.origin.y);
  [maskImage compositeToPoint: NSMakePoint(0, 13) 
                    operation: NSCompositeSourceOver];
  
  //
  // hour
  //
  p.x = tf_posx[0];
  p.y = h - posy[0];
  [hour1Image compositeToPoint: p operation: NSCompositeSourceOver];
  p.x = tf_posx[1];
  [hour2Image compositeToPoint: p operation: NSCompositeSourceOver];
  p.x = tf_posx[2];
  [hour3Image compositeToPoint: p operation: NSCompositeSourceOver];
  
  //
  // minute
  //
  p.x = tf_posx[3];
  [minute1Image compositeToPoint: p operation: NSCompositeSourceOver];
  p.x = tf_posx[4];
  [minute2Image compositeToPoint: p operation: NSCompositeSourceOver];

  //
  // dayOfWeek
  //
  p.x = tf_posx[6];
  p.y = h - posy[1];
  [dayweekImage compositeToPoint: p operation: NSCompositeSourceOver];
  
  //
  // dayOfMonth
  //
  p.x = tf_posx[7];  
  p.y = h - posy[2];
  [daymont1Image compositeToPoint: p operation: NSCompositeSourceOver];
  p.x = tf_posx[9];
  [daymont2Image compositeToPoint: p operation: NSCompositeSourceOver];
  
  //
  // month
  //
  p.x = tf_posx[10];
  p.y = h - posy[3];
  [monthImage compositeToPoint: p operation: NSCompositeSourceOver];
  
  [yearlabel drawInteriorWithFrame: NSMakeRect(0, 0, rect.size.width, 12)
                            inView: self];
}

@end
