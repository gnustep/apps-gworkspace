/* TShelfView.m
 *  
 * Copyright (C) 2003-2012 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 *         Riccardo Mottola <rm@gnu.org>
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

#import "TShelfView.h"
#import "TShelfViewItem.h"
#import "TShelfIconsView.h"
#import "GWorkspace.h"


#define SPECIAL_TAB_W 54
#define BUTTORX 25
#define BUTTSZ 9
#define BUTTSPACE 12
#define TAB_H 24
#define LAB_MARGIN 13
#define BEZ_TAB_W 14

@implementation TShelfView

- (id)initWithFrame:(NSRect)rect
{
  self = [super initWithFrame: rect];
  
  if (self) {
    NSRect r = NSZeroRect;
    
    ASSIGN (items, [NSMutableArray array]);
    
    font = [NSFont fontWithName: @"Helvetica-Bold" size: 12];
    if (font == nil) {
      font = [NSFont boldSystemFontOfSize: 0];
    }
    RETAIN (font);

    italicFont = [NSFont fontWithName: @"Helvetica-BoldOblique" size: 12];
    if (italicFont == nil) {
      italicFont = [NSFont boldSystemFontOfSize: 0];
    }
    RETAIN (italicFont);
    
    r.size = NSMakeSize(BUTTSZ, BUTTSZ);
    r.origin.y = rect.size.height - TAB_H + (int)((TAB_H - BUTTSZ) / 2);
    r.origin.x = rect.size.width - (BUTTSZ * 2 + BUTTSPACE);
                  
    rewButt = [[NSButton alloc] initWithFrame: r];
    [rewButt setButtonType: NSMomentaryLight];    
    [rewButt setBordered: NO];    
    [rewButt setTarget: self];
    [rewButt setAction: @selector (buttonsAction:)];
    [self addSubview: rewButt];
    RELEASE (rewButt);        
    
    r.origin.x += BUTTSPACE;
    
    ffButt = [[NSButton alloc] initWithFrame: r];
    [ffButt setButtonType: NSMomentaryLight];    
    [ffButt setBordered: NO];    
    [ffButt setTarget: self];
    [ffButt setAction: @selector (buttonsAction:)];
    [self addSubview: ffButt];
    RELEASE (ffButt);        

    [self setButtonsEnabled: NO];   
                    
    lastItem = nil;
    selected = nil;
  }
  
  return self;
}

- (void)dealloc
{
  RELEASE (items);
  RELEASE (font);
  RELEASE (italicFont);
  
  [super dealloc];
}

- (void)addTabItem:(TShelfViewItem *)item
{
  [self insertTabItem: item atIndex: [items count]];
}

- (BOOL)insertTabItem:(TShelfViewItem *)item
	      atIndex:(NSUInteger)index
{
  if (lastItem) {
    if (index == [items count]) {
      index--;
    }
    RETAIN (lastItem);
    [items removeObject: lastItem];
  }

  [item setTShelfView: self];
  [items insertObject: item atIndex: index];
  
  if (lastItem) {
    [items insertObject: lastItem atIndex: [items count]];
    RELEASE (lastItem);
  }  
  
  return YES;
}

- (void)setLastTabItem:(TShelfViewItem *)item
{
  lastItem = item;
  [item setTShelfView: self];
  [items insertObject: item atIndex: [items count]];
}

- (BOOL)removeTabItem:(TShelfViewItem *)item
{
  NSUInteger i = [items indexOfObject: item];
  
  if ((i == NSNotFound) || (item == lastItem)) {
    return NO;
  }
  
  if (item == selected) {
    [[selected view] removeFromSuperview];
    selected = nil;
  }

  [items removeObjectAtIndex: i];
  
  return YES;
}

- (NSUInteger)indexOfItem:(TShelfViewItem *)item
{
  return [items indexOfObject: item];
}

- (TShelfViewItem *)selectedTabItem
{
  if ((selectedItem == NSNotFound) || ([items count] == 0)) {
    return nil;
  }
  
  return [items objectAtIndex: selectedItem];
}

- (void)selectTabItem:(TShelfViewItem *)item
{
  TShelfIconsView *selectedView;

  if (item == nil)
    return;

  if (selected != nil)
    {
      [selected setTabState: NSBackgroundTab];
      selectedView = (TShelfIconsView *)[selected view];
      if ([selectedView iconsType] == DATA_TAB) {
	[selectedView setCurrentPBIcon: nil];
      }
      [[selected view] removeFromSuperview];
    }

  selected = item;

  selectedItem = [items indexOfObject: selected];
  [selected setTabState: NSSelectedTab];

  selectedView = (TShelfIconsView *)[selected view];

  if (selectedView != nil)
    {
      [self addSubview: selectedView];
      [selectedView setFrame: [self contentRect]];
      [selectedView resizeWithOldSuperviewSize: [selectedView frame].size]; 
      [selectedView unselectOtherIcons: nil];
      if ([selectedView iconsType] == DATA_TAB)
	{
	  [selectedView setCurrentPBIcon: nil];
	}
      [[self window] makeFirstResponder: [selected initialFirstResponder]];
    }
  
  [self setButtonsEnabled: (lastItem && (lastItem == selected))];
      
  [self setNeedsDisplay: YES]; 
}

- (void)selectTabItemAtIndex:(NSUInteger)index
{
  [self selectTabItem: [items objectAtIndex: index]];
}

- (void)selectLastItem
{
  if (lastItem)
    {
      [self selectTabItem: lastItem];
    }
}

- (NSFont *)font
{
  return font;
}

- (NSFont *)italicFont
{
  return italicFont;
}

- (NSRect)contentRect
{
  NSRect cRect = [self bounds];

  cRect.origin.y += 1; 
  cRect.size.height -= 26.5;

  return cRect;
}

void drawLeftTabBezier(NSPoint origin, float tabh, 
		       NSColor *sc, NSColor *fc, BOOL seltab)
{
  NSBezierPath *path = [NSBezierPath bezierPath];
  NSPoint endp = NSMakePoint(origin.x + BEZ_TAB_W, origin.y + tabh);
  NSPoint cp1 = NSMakePoint(origin.x + (BEZ_TAB_W / 2), origin.y);
  NSPoint cp2 = NSMakePoint(origin.x + BEZ_TAB_W - (BEZ_TAB_W / 2), origin.y + tabh);
  
  [path moveToPoint: origin];
  [path curveToPoint: endp controlPoint1: cp1 controlPoint2: cp2];
  [sc set];
  [path stroke];
  
  [path lineToPoint: NSMakePoint(origin.x + BEZ_TAB_W, origin.y)];
  [path closePath];
  [fc set];
  [path fill];
  
  if (seltab) {
    path = [NSBezierPath bezierPath];
    [path moveToPoint: origin];
    [path lineToPoint: NSMakePoint(origin.x + BEZ_TAB_W, origin.y)];
    [path stroke];
  }
}

void drawRightTabBezier(NSPoint origin, float tabh, 
			NSColor *sc, NSColor *fc, BOOL seltab)
{
  NSBezierPath *path = [NSBezierPath bezierPath];
  NSPoint endp = NSMakePoint(origin.x - BEZ_TAB_W, origin.y + tabh);
  NSPoint cp1 = NSMakePoint(origin.x - (BEZ_TAB_W / 2), origin.y);
  NSPoint cp2 = NSMakePoint(origin.x - BEZ_TAB_W + (BEZ_TAB_W / 2), origin.y + tabh);
  
  [path moveToPoint: origin];
  [path curveToPoint: endp controlPoint1: cp1 controlPoint2: cp2];
  [sc set];
  [path stroke];
  
  [path lineToPoint: NSMakePoint(origin.x - BEZ_TAB_W, origin.y)];
  [path closePath];
  [fc set];
  [path fill];

  if (seltab) {
    path = [NSBezierPath bezierPath];
    [path moveToPoint: origin];
    [path lineToPoint: NSMakePoint(origin.x - BEZ_TAB_W, origin.y)];
    [path stroke];
  }
}

- (void)drawRect:(NSRect)rect
{
  NSRect aRect = [self bounds];
  NSPoint p = aRect.origin;
  NSSize s = aRect.size;
  NSUInteger count;  
  int itemxspace;
  NSImage *backImage;
  NSColor *scolor;
  NSColor *fcolor;
  NSPoint selp[2];
  NSBezierPath *bpath;
  NSUInteger i;
  NSPoint ipoint;
  
  backImage = [[GWorkspace gworkspace] tshelfBackground];
  if (backImage)
    [backImage compositeToPoint: NSZeroPoint operation: NSCompositeSourceOver];

  count = [items count];
  itemxspace = (int)((aRect.size.width - SPECIAL_TAB_W) / (count - 1));
  
  [[NSColor controlColor] set];
  NSRectFill(NSMakeRect(p.x, p.y, s.width, s.height - TAB_H));

  if (selected == nil) {
    [self selectTabItemAtIndex: 0];
  }
	  
  selp[0] = NSZeroPoint;
  selp[1] = NSZeroPoint;

  aRect.size.height -= TAB_H;
  
  ipoint = NSMakePoint (0,0);
  for (i = count; i > 0; i--)
    {
      TShelfViewItem *anItem = [items objectAtIndex: i-1];
      NSRect r;
    
      if (i == count)
	{
	  ipoint.x = (int)(aRect.size.width - SPECIAL_TAB_W);
	  ipoint.y = aRect.size.height;
	  
	  if ([anItem tabState] == NSSelectedTab)
	    {
	      selp[0] = ipoint;
	      fcolor = [NSColor controlColor];
	    } 
	  else
	    {
	      fcolor = [NSColor controlBackgroundColor];
	    }
      
	  scolor = [NSColor whiteColor];
      
	  drawLeftTabBezier(ipoint, TAB_H, scolor, fcolor, NO);

	  r.origin.x = ipoint.x + LAB_MARGIN;
	  r.origin.y = aRect.size.height;
	  r.size.width = SPECIAL_TAB_W - LAB_MARGIN;
	  r.size.height = TAB_H -1;
      
	  bpath = [NSBezierPath bezierPath];
	  [bpath setLineWidth: 1];
	  [bpath moveToPoint: NSMakePoint(r.origin.x, r.origin.y + TAB_H)];
	  [bpath relativeLineToPoint: NSMakePoint(r.size.width, 0)];
	  [scolor set];
	  [bpath stroke];
	  
	  [anItem drawImage: nil inRect: r];

	  }
      else
	{
	  ipoint.y = aRect.size.height;
	  
	  if ([anItem tabState] == NSSelectedTab)
	    {
	      selp[1] = NSMakePoint(ipoint.x + BEZ_TAB_W, ipoint.y);
	      fcolor = [NSColor controlColor];
	    }
	  else
	    {
	      fcolor = [NSColor controlBackgroundColor];
	    }
      
      scolor = [NSColor blackColor];
      drawRightTabBezier(NSMakePoint(ipoint.x + BEZ_TAB_W, ipoint.y), 
                                                  TAB_H, scolor, fcolor, NO);
      ipoint.x -= itemxspace;

      if (i != 0) {
        if ([anItem tabState] == NSSelectedTab) {
          selp[0] = ipoint;
        }
        
        scolor = [NSColor whiteColor];
        drawLeftTabBezier(ipoint, TAB_H, scolor, fcolor, NO);
              
	      r.origin.x = ipoint.x + LAB_MARGIN;
	      r.origin.y = aRect.size.height;
	      r.size.width = itemxspace - LAB_MARGIN;
	      r.size.height = TAB_H -1;
        
      } else {
	      r.origin.x = ipoint.x;
	      r.origin.y = aRect.size.height;
	      r.size.width = itemxspace;
	      r.size.height = TAB_H -1;
      }
      
      scolor = [NSColor whiteColor];

      bpath = [NSBezierPath bezierPath];
      [bpath setLineWidth: 1];
      [bpath moveToPoint: NSMakePoint(r.origin.x, r.origin.y + TAB_H)];
      [bpath relativeLineToPoint: NSMakePoint(r.size.width, 0)];
      [scolor set];
      [bpath stroke];
      
	    [anItem drawLabelInRect: r];
	  }  
	}
  
  fcolor = [NSColor controlColor];
  
  if (NSEqualPoints(selp[0], NSZeroPoint) == NO) {
    scolor = [NSColor whiteColor];
    drawLeftTabBezier(selp[0], TAB_H, scolor, fcolor, YES);

    bpath = [NSBezierPath bezierPath];
    [bpath setLineWidth: 1];
    [bpath moveToPoint: NSMakePoint(p.x - 2, aRect.size.height)];
    [bpath lineToPoint: selp[0]];
    [scolor set];
    [bpath stroke];
  }
  
  if (NSEqualPoints(selp[1], NSZeroPoint) == NO) {
    scolor = [NSColor blackColor];
    drawRightTabBezier(selp[1], TAB_H, scolor, fcolor, YES);
        
    scolor = [NSColor whiteColor];
    bpath = [NSBezierPath bezierPath];
    [bpath setLineWidth: 1];
    [bpath moveToPoint: selp[1]];
    [bpath lineToPoint: NSMakePoint(s.width, aRect.size.height)];
    [scolor set];
    [bpath stroke];
  }
}

- (BOOL)isOpaque
{
  return YES;
}

- (TShelfViewItem *)tabItemAtPoint:(NSPoint)point
{
  NSUInteger count = [items count];
  NSUInteger i;

  point = [self convertPoint: point fromView: nil];

  for (i = 0; i < count; i++) {
    TShelfViewItem *anItem = [items objectAtIndex: i];

    if (NSPointInRect(point, [anItem tabRect])) {
	    return anItem;
    }
  }
  
  return nil;
}

- (TShelfViewItem *)lastTabItem
{
  return lastItem;
}

- (NSArray *)items
{
  return items;
}

- (void)buttonsAction:(id)sender
{

}

- (void)setButtonsEnabled:(BOOL)enabled
{
  [rewButt setEnabled: enabled];  
  [ffButt setEnabled: enabled];  

  if (enabled) {
    [rewButt setImage: [NSImage imageNamed: @"REWArrow.tiff"]];
    [ffButt setImage: [NSImage imageNamed: @"FFArrow.tiff"]];
  } else {
    [rewButt setImage: [NSImage imageNamed: @"REWArrow_disabled.tiff"]];
    [ffButt setImage: [NSImage imageNamed: @"FFArrow_disabled.tiff"]];
  }
}

- (void)mouseDown:(NSEvent *)theEvent
{
  NSPoint location = [theEvent locationInWindow];
  TShelfViewItem *anItem = [self tabItemAtPoint: location];
    
  if (anItem && (anItem != selected)) {
    [self selectTabItem: anItem];
  }
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent*)theEvent
{
  return YES;
}

- (void)setSingleClickLaunch:(BOOL)value
{
  NSUInteger i;

  for (i = 0; i < [items count]; i++)
    {
      TShelfViewItem *tViewItem;
      TShelfIconsView *iView;

      tViewItem = [items objectAtIndex: i];
      iView = (TShelfIconsView *)[tViewItem view];
      [iView setSingleClickLaunch: value];
    }
}

@end
