/*  -*-objc-*-
 *  TimeDateView.m: Implementation of the TimeDateView Class 
 *  of the GNUstep GWorkspace application
 *
 *  Copyright (c) 2001 Enrico Sersale <enrico@imago.ro>
 *  
 *  Author: Enrico Sersale
 *  Date: August 2001
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "TimeDateView.h"
#include "GNUstep.h"

#define LED_COLON 10
#define LED_AM    11
#define LED_PM    12
#define DATE_COLON 11

static const int tf_posx[11] = {5, 14, 24, 28, 37, 40, 17, 17, 22, 27, 15};
static const int posy[4]  = {14, 26, 42, 51};

@implementation TimeDateView

- (void)dealloc
{
	TEST_RELEASE (maskImage);
	TEST_RELEASE (hour1Image);
	TEST_RELEASE (hour2Image);
	TEST_RELEASE (hour3Image);
	TEST_RELEASE (minute1Image);
	TEST_RELEASE (minute2Image);
	TEST_RELEASE (dayweekImage);
	TEST_RELEASE (daymont1Image);
	TEST_RELEASE (daymont2Image);
	TEST_RELEASE (monthImage);
  [super dealloc];
}

- (id)init
{
	self = [super init];
	if (self) {
		maskImage = nil;
	}
	return self;
}

- (void)setDate:(NSCalendarDate *)adate
{
	NSString *imgName;
	int n, hour, minute, dayOfWeek, dayOfMonth, month;
	
	hour = [adate hourOfDay];
	minute = [adate minuteOfHour];
	dayOfWeek = [adate dayOfWeek];
	dayOfMonth = [adate dayOfMonth];
	month = [adate monthOfYear];

	ASSIGN (maskImage, [NSImage imageNamed: @"Mask.tiff"]);

	//
	// hour
	//
	n = hour/10;
	imgName = [NSString stringWithFormat: @"LED-%d.tiff", n];		
	ASSIGN (hour1Image, [NSImage imageNamed: imgName]);
	
	n = hour%10;		
	imgName = [NSString stringWithFormat: @"LED-%d.tiff", n];
	ASSIGN (hour2Image, [NSImage imageNamed: imgName]);
  
	n = LED_COLON;
	imgName = [NSString stringWithFormat: @"LED-%d.tiff", n];
	ASSIGN (hour3Image, [NSImage imageNamed: imgName]);

	//
	// minute
	//
	n = minute/10;
	imgName = [NSString stringWithFormat: @"LED-%d.tiff", n];
	ASSIGN (minute1Image, [NSImage imageNamed: imgName]);

	n = minute%10;
	imgName = [NSString stringWithFormat: @"LED-%d.tiff", n];
	ASSIGN (minute2Image, [NSImage imageNamed: imgName]);

	//
	// dayOfWeek
	//
	imgName = [NSString stringWithFormat: @"Weekday-%d.tiff", dayOfWeek];
	ASSIGN (dayweekImage, [NSImage imageNamed: imgName]);

	//
	// dayOfMonth
	//
	n = dayOfMonth/10;
	imgName = [NSString stringWithFormat: @"Date-%d.tiff", n];
	ASSIGN (daymont1Image, [NSImage imageNamed: imgName]);

	n = dayOfMonth%10;
	imgName = [NSString stringWithFormat: @"Date-%d.tiff", n];
	ASSIGN (daymont2Image, [NSImage imageNamed: imgName]);

	//
	// month
	//
	n = month;
	imgName = [NSString stringWithFormat: @"Month-%d.tiff", n];
	ASSIGN (monthImage, [NSImage imageNamed: imgName]);
	
	[self setNeedsDisplay: YES];
}

- (void)drawRect:(NSRect)rect
{
	NSRect r;
	NSSize s; 
	NSPoint p;
	float h;
	
	if(maskImage == nil)
		return;
		
  s = [maskImage size];
	h = s.height;
  r = NSInsetRect(rect, (rect.size.width - s.width)/2, 
													      (rect.size.height - s.height)/2);
	p = NSMakePoint(r.origin.x, r.origin.y);
	[maskImage compositeToPoint: NSZeroPoint operation: NSCompositeSourceOver];

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
}

@end
