/* GWFunctions.h
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

 
#ifndef FUNCTIONS_H
#define FUNCTIONS_H

@class NSString;
@class NSMenuItem;

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

#ifndef MAKE_LOCALIZED_LABEL
#define MAKE_LOCALIZED_LABEL(label, rect, str, comm, align, release, view) { \
label = [[NSTextField alloc] initWithFrame: rect];	\
[label setFont: [NSFont systemFontOfSize: 12]]; \
if (align == 'c') [label setAlignment: NSCenterTextAlignment]; \
else if (align == 'r') [label setAlignment: NSRightTextAlignment]; \
else [label setAlignment: NSLeftTextAlignment]; \
[label setBackgroundColor: [NSColor windowBackgroundColor]]; \
[label setBezeled: NO]; \
[label setEditable: NO]; \
[label setSelectable: NO]; \
if (str) [label setStringValue: NSLocalizedString(str, comm)]; \
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

#ifndef ICNMAX
#define ICNMAX 48
#endif

NSString *fixPath(NSString *s, const char *c);

NSString *cutFileLabelText(NSString *filename, id label, int lenght);

NSString *subtractPathComponentToPath(NSString *apath, NSString *firstpart);

BOOL subPathOfPath(NSString *p1, NSString *p2);

NSString *pathFittingInContainer(id container, NSString *fullPath, int margins);

NSString *relativePathFittingInContainer(id container, NSString *fullPath);

int pathComponentsToPath(NSString *path);

NSString *commonPrefixInArray(NSArray *a);

int comparePaths(id *p1, id *p2, void *context);

int compareCells(id *c1, id *c2, void *context);

int compareCellsRemote(id *c1, id *c2, void *context);

int compareDimmedCells(id *c1, id *c2, void *context);

int compIcons(id *c1, id *c2, void *context);

NSString *fileSizeDescription(unsigned long long size);

NSMenuItem *addItemToMenu(NSMenu *menu, NSString *str, 
														NSString *comm, NSString *sel, NSString *key);

#endif
