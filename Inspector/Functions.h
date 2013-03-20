/* Functions.h
 *  
 * Copyright (C) 2004-2013 Free Software Foundation, Inc.
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

 
#import "config.h"

@class NSString;
@class NSMenuItem;

#define GWDebugLog(format, args...) \
  do { if (GW_DEBUG_LOG) \
    NSLog(format , ## args); } while (0)

#ifndef MAKE_LABEL
#define MAKE_LABEL(label, rect, str, align, release, view) { \
label = [[NSTextField alloc] initWithFrame: rect];	\
[label setFont: [NSFont systemFontOfSize: 12]]; \
if (align == 'c') [label setAlignment: NSCenterTextAlignment]; \
else if (align == 'r') [label setAlignment: NSRightTextAlignment]; \
else [label setAlignment: NSLeftTextAlignment]; \
[label setBackgroundColor: [NSColor windowBackgroundColor]]; \
[label setBezeled: NO]; \
[label setEditable: NO]; \
[label setSelectable: NO]; \
if (str) [label setStringValue: str]; \
[view addSubview: label]; \
if (release) RELEASE (label); \
}
#endif

#ifndef STROKE_LINE
#define STROKE_LINE(c, x1, y1, x2, y2) { \
[[NSColor c] set]; \
[NSBezierPath strokeLineFromPoint: NSMakePoint(x1, y1) \
toPoint: NSMakePoint(x2, y2)]; \
}
#endif

NSString *fixpath(NSString *s, const char *c);

NSString *relativePathFit(id container, NSString *fullPath);

NSString *fsDescription(unsigned long long size);

