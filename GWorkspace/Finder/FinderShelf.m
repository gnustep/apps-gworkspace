/* FinderShelf.m
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


#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
  #ifdef GNUSTEP 
#include "GWFunctions.h"
  #else
#include <GWorkspace/GWFunctions.h>
  #endif
#include "Shelf/Shelf.h"
#include "IconViewsIcon.h"
#include "GWorkspace.h"
#include "GNUstep.h"

@interface IconViewsIcon (FinderShelfSorting)
- (NSComparisonResult)finderIconCompare:(FinderShelfIcon *)other;
@end

@implementation IconViewsIcon (FinderShelfSorting)

- (NSComparisonResult)finderIconCompare:(FinderShelfIcon *)other
{
	if ([other gridindex] > [self gridindex]) {
		return NSOrderedAscending;	
	} else {
		return NSOrderedDescending;	
	}

	return NSOrderedSame;
}

@end

@implementation FinderShelf

- (void)addIconWithPaths:(NSArray *)iconpaths 
					withGridIndex:(int)index 
{
	FinderShelfIcon *icon = [[FinderShelfIcon alloc] initForPaths: iconpaths 
        										gridIndex: index inContainer: self];
														
	if (gpoints != NULL) {
		if (index < pcount) {
			gpoints[index].used = 1;
		}
	}
														
	[icons addObject: icon];  
	[self addSubview: icon];
	[self addSubview: [icon myLabel]];
	RELEASE (icon);    
	[self sortIcons];	
	[self resizeWithOldSuperviewSize: [self frame].size];  
}

- (void)sortIcons
{
	NSArray *sortedIcons = [icons sortedArrayUsingSelector: @selector(finderIconCompare:)];	
	[icons removeAllObjects];
	[icons addObjectsFromArray: sortedIcons];
}

- (void)mouseDown:(NSEvent *)theEvent
{
  [self unselectOtherIcons: nil];
  [delegate shelf: self mouseDown: theEvent];
}

@end

