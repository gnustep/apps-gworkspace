/* GWScrollView.h
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


#ifndef GWSCROLLVIEW_H
#define GWSCROLLVIEW_H

#include <AppKit/NSScrollView.h>

@class NSObject;
@class NSClipView;

@interface GWScrollView : NSScrollView
{
  id delegate;
}

- (void)setDelegate:(id)anObject;

- (id)delegate;

@end

@interface NSObject(GWScrollViewDelegateMethods)

- (void)gwscrollView:(GWScrollView *)sender 
  scrollViewScrolled:(NSClipView *)clip
             hitPart:(NSScrollerPart)hitpart;

@end

#endif // GWSCROLLVIEW_H
