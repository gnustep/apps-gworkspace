/*
 *  TimeDateView.h: Interface and declarations for the TimeDateView Class 
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

#ifndef TIMEDATEVIEW_H
#define TIMEDATEVIEW_H

#include <AppKit/NSView.h>

@class NSCalendarDate;
@class NSImage;

@interface TimeDateView : NSView
{
	NSImage *maskImage;
	NSImage *hour1Image, *hour2Image, *hour3Image;
	NSImage *minute1Image, *minute2Image;
	NSImage *dayweekImage;
	NSImage *daymont1Image, *daymont2Image;
	NSImage *monthImage;
}

- (void)setDate:(NSCalendarDate *)adate;

@end

#endif // TIMEDATEVIEW_H


