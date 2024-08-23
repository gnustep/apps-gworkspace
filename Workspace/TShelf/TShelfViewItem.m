/* TShelfViewItem.m
 *  
 * Copyright (C) 2003-2010 Free Software Foundation, Inc.
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#import <AppKit/AppKit.h>
#import <GNUstepBase/GNUstep.h>

#import "TShelfViewItem.h"
#import "TShelfView.h"

@implementation TShelfViewItem

- (id)initWithTabType:(int)type
{
  self = [super init];

  if (self) {
    state = NSBackgroundTab;
    tabtype = type;
  }
  
  return self;
}

- (void)dealloc
{
  RELEASE (label);
  RELEASE (view);
  RELEASE (color);
  RELEASE (labfont);
  
  [super dealloc];
}

- (void)setLabel:(NSString *)labstr
{
  ASSIGN (label, labstr);
}

- (NSString *)label
{
  return label;
}

- (NSSize)sizeOfLabel:(NSString *)str
{
  NSDictionary *attr = [NSDictionary dictionaryWithObjectsAndKeys: 
			                        labfont, NSFontAttributeName, nil];
  return [str sizeWithAttributes: attr];
}

- (void)setView:(NSView *)v
{
  ASSIGN (view, v);
}

- (NSView *)view
{
  return view;
}

- (void)setColor:(NSColor *)clr
{
  ASSIGN (color, clr);
}

- (NSColor *)color
{
  return color;
}

- (NSTabState)tabState
{
  return state;
}

- (TShelfView *)tView
{
  return tview;
}

- (NSRect)tabRect
{
  return rect;
}

- (void)setTabState:(NSTabState)tabState
{
  state = tabState;
}

- (void)setTShelfView:(TShelfView *)tView
{
  tview = tView;
  
  if (tabtype == FILES_TAB) {
    ASSIGN (labfont, [tview font]);
  } else {
    ASSIGN (labfont, [tview italicFont]);
  }
}

- (NSString *)truncatedLabelAtLenght:(float)lenght
{
	NSString *cutname = nil;
  NSString *reststr = nil;
  NSString *dots;
  NSDictionary *attr;
	float w, cw, dotslenght;
	int i;

	cw = 0;
  
  attr = [NSDictionary dictionaryWithObjectsAndKeys: 
			                        labfont, NSFontAttributeName, nil];  
  
  dots = @"...";  
	dotslenght = [dots sizeWithAttributes: attr].width;  
  
  w = [label sizeWithAttributes: attr].width;
  
	if (w > lenght) {
		i = 0;
		while (cw <= (lenght - dotslenght)) {
			if (i == [label length]) {
				break;
      }
			cutname = [label substringToIndex: i];
			reststr = [label substringFromIndex: i];
      cw = [cutname sizeWithAttributes: attr].width;
			i++;
		}	
		if ([cutname isEqual: label] == NO) {      
			if ([reststr length] <= 3) { 
				return label;
			} else {
				cutname = [cutname stringByAppendingString: dots];
      }
		} else {
			return label;
		}	
	} else {
		return label;
	}
  
	return cutname;
}

- (void)setInitialFirstResponder:(NSView *)v
{
  firstResponder = v;
}

- (id)initialFirstResponder
{
  return firstResponder;
}

- (void)drawLabelInRect:(NSRect)tabRect
{
  NSRect lRect;
  NSRect fRect;
  NSDictionary *attr;
  NSString *string;
  float labw = [self sizeOfLabel: label].width;
  float maxw = tabRect.size.width;
  
  rect = tabRect;
  fRect = tabRect;
  lRect = tabRect;

  if (labw > (maxw - 10)) {
    string = [self truncatedLabelAtLenght: (maxw - 10)];
  } else {
    string = label;
  }
  
  labw = [self sizeOfLabel: string].width;
  lRect.origin.x += (maxw - labw) / 2;
  lRect.size.width = labw;
  
  if (state == NSSelectedTab) {
    fRect.origin.y -= 1;
    fRect.size.height += 1;
    [[NSColor controlColor] set];
    NSRectFill(fRect);
  } else if (state == NSBackgroundTab) {
    [[NSColor controlBackgroundColor] set];
    NSRectFill(fRect);
  } else {
    [[NSColor controlBackgroundColor] set];
  }

  attr = [NSDictionary dictionaryWithObjectsAndKeys: 
			                        labfont, NSFontAttributeName,
			                [NSColor blackColor], NSForegroundColorAttributeName,
			                nil];
  
  [string drawInRect: lRect withAttributes: attr];
}

- (void)drawImage:(NSImage *)image inRect:(NSRect)tabRect
{
  NSRect fRect;
  NSPoint p;
  
  rect = tabRect;
  fRect = tabRect;
  p = fRect.origin;
  p.x += 2;
  p.y += 4;
  
  if (state == NSSelectedTab) {
    fRect.origin.y -= 1;
    fRect.size.height += 1;
    [[NSColor controlColor] set];
    NSRectFill(fRect);
  } else if (state == NSBackgroundTab) {
    [[NSColor controlBackgroundColor] set];
    NSRectFill(fRect);
  } else {
    [[NSColor controlBackgroundColor] set];
  }
  
  if (image) {
    [image compositeToPoint: p operation: NSCompositeSourceOver];
  }
}

@end
