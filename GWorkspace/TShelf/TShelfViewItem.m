/*  -*-objc-*-
 *  TShelfViewItem.m: Implementation of the TShelfViewItem Class 
 *  of the GNUstep GWorkspace application
 *
 *  Copyright (c) 2003 Enrico Sersale <enrico@dtedu.net>
 *  
 *  Author: Enrico Sersale
 *  Date: July 2003
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

#include <AppKit/AppKit.h>
#include "TShelfViewItem.h"
#include "TShelfView.h"

@implementation TShelfViewItem

- (id)init
{
  self = [super init];

  if (self) {
    state = NSBackgroundTab;
  }
  
  return self;
}

- (void)dealloc
{
  RELEASE (label);
  RELEASE (view);
  RELEASE (color);
  
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
			                        [tview font], NSFontAttributeName, nil];
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
}

- (NSString *)truncatedLabelAtLenght:(float)lenght
{
	NSString *cutname = nil;
  NSString *reststr = nil;
  NSString *dots;
	NSFont *labfont;
  NSDictionary *attr;
	float w, cw, dotslenght;
	int i;

	cw = 0;
	labfont = [tview font];
  
  attr = [NSDictionary dictionaryWithObjectsAndKeys: 
			                        labfont, NSFontAttributeName, nil];  
  
  dots = @"...";  
	dotslenght = [dots sizeWithAttributes: attr].width;  
  
  w = [label sizeWithAttributes: attr].width;
  
	if (w > lenght) {
		i = 0;
		while (cw <= (lenght - dotslenght)) {
			if (i == [label cStringLength]) {
				break;
      }
			cutname = [label substringToIndex: i];
			reststr = [label substringFromIndex: i];
      cw = [cutname sizeWithAttributes: attr].width;
			i++;
		}	
		if ([cutname isEqual: label] == NO) {      
			if ([reststr cStringLength] <= 3) { 
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
  NSGraphicsContext *ctxt = GSCurrentContext();
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

  DPSgsave(ctxt);

  if (state == NSSelectedTab) {
    fRect.origin.y -= 1;
    fRect.size.height += 1;
    [[NSColor controlBackgroundColor] set];
    NSRectFill(fRect);
  } else if (state == NSBackgroundTab) {
    [[NSColor controlBackgroundColor] set];
    NSRectFill(fRect);
  } else {
    [[NSColor controlBackgroundColor] set];
  }

  attr = [NSDictionary dictionaryWithObjectsAndKeys: 
			                        [tview font], NSFontAttributeName,
			                [NSColor blackColor], NSForegroundColorAttributeName,
			                nil];
  
  [string drawInRect: lRect withAttributes: attr];

  DPSgrestore(ctxt);
}

- (void)drawImage:(NSImage *)image inRect:(NSRect)tabRect
{
  NSGraphicsContext *ctxt = GSCurrentContext();
  NSRect fRect;
  NSPoint p;
  
  rect = tabRect;
  fRect = tabRect;
  p = fRect.origin;
  p.x += 2;
  p.y += 4;
  
  DPSgsave(ctxt);

  if (state == NSSelectedTab) {
    fRect.origin.y -= 1;
    fRect.size.height += 1;
    [[NSColor controlBackgroundColor] set];
    NSRectFill(fRect);
  } else if (state == NSBackgroundTab) {
    [[NSColor controlBackgroundColor] set];
    NSRectFill(fRect);
  } else {
    [[NSColor controlBackgroundColor] set];
  }

  [image compositeToPoint: p operation: NSCompositeSourceOver];

  DPSgrestore(ctxt);  
}

@end
