/* GWScrollView.m
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
#include "GWScrollView.h"
#include "GNUstep.h"

#ifndef max
#define max(a,b) ((a) > (b) ? (a):(b))
#endif

#ifndef min
#define min(a,b) ((a) < (b) ? (a):(b))
#endif

// static int scrollVal = 0;

@implementation GWScrollView

- (void)setDelegate:(id)anObject
{
  delegate = anObject;
}

- (id)delegate
{
  return delegate;
}

- (void)reflectScrolledClipView:(NSClipView*)aClipView
{
  NSScroller *scroller = [self horizontalScroller];
  NSScrollerPart hitPart = [scroller hitPart];

  [super reflectScrolledClipView: aClipView];  
	
/*    
  if (hitPart == NSScrollerKnob) {
    int scrl = [scroller floatValue];
    
    if ((max(scrollVal, scrl) - min(scrollVal, scrl)) < 10) {
      return;
    } else {
      scrollVal = scrl;
    }
  }
*/  
  [delegate gwscrollView: self scrollViewScrolled: aClipView hitPart: hitPart];      
}

@end
