/* TShelfView.m
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


#include <AppKit/AppKit.h>
  #ifdef GNUSTEP 
#include "GWLib.h"
  #else
#include <GWorkspace/GWLib.h>
  #endif
#include "TShelfView.h"
#include "TShelfViewItem.h"
#include "GWorkspace.h"
#include "GNUstep.h"

@implementation TShelfView

- (id)initWithFrame:(NSRect)rect
{
  self = [super initWithFrame: rect];
  
  if (self) {
    buttw = 10;
    
    ASSIGN (items, [NSMutableArray array]);
    ASSIGN (font, [NSFont boldSystemFontOfSize: 0]);
    
    hideButton = [[NSButton alloc] initWithFrame: NSMakeRect (0,0, buttw, rect.size.height)];
    [hideButton setImage: [NSImage imageNamed: @"Dimple.tiff"]];
    [hideButton setImagePosition: NSImageOnly];
    [hideButton setTarget: self];
    [hideButton setAction: @selector (hideShowTabs:)];
    [self addSubview: hideButton];
        
    lastItem = nil;
    selected = nil;
    hiddentabs = NO;
  }
  
  return self;
}

- (void)dealloc
{
  RELEASE (items);
  RELEASE (font);
  RELEASE (hideButton);
  
  [super dealloc];
}

- (void)addTabItem:(TShelfViewItem *)item
{
  [self insertTabItem: item atIndex: [items count]];
}

- (BOOL)insertTabItem:(TShelfViewItem *)item
		          atIndex:(int)index
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
  unsigned i = [items indexOfObject: item];
  
  if ((i == NSNotFound) || (item == lastItem)) {
    return NO;
  }
  
  if ([item isEqual: selected]) {
    [[selected view] removeFromSuperview];
    selected = nil;
  }

  [items removeObjectAtIndex: i];
  
  return YES;
}

- (int)indexOfItem:(TShelfViewItem *)item
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
  NSView *selectedView;

  if (selected != nil) {
    [selected setTabState: NSBackgroundTab];
	  [[selected view] removeFromSuperview];
	}

  selected = item;

  selectedItem = [items indexOfObject: selected];
  [selected setTabState: NSSelectedTab];

  selectedView = [selected view];

  if (selectedView != nil) {
	  [self addSubview: selectedView];
	  [selectedView setFrame: [self contentRect]];
  	[selectedView resizeWithOldSuperviewSize: [selectedView frame].size]; 
	  [[self window] makeFirstResponder: [selected initialFirstResponder]];
  }
      
  [self setNeedsDisplay: YES];  
}

- (void)selectTabItemAtIndex:(int)index
{
  if (index < 0) {
    [self selectTabItem: nil];
  } else {
    [self selectTabItem: [items objectAtIndex: index]];
  }
}

- (NSFont *)font
{
  return font;
}

- (NSRect)contentRect
{
  NSRect cRect = [self bounds];

  cRect.origin.y += 1; 
  cRect.origin.x += (0.5 + buttw); 
  cRect.size.width -= (2 + buttw);
  cRect.size.height -= 26.5;

  return cRect;
}

- (void)drawRect:(NSRect)rect
{
  float borderThickness;
  int howMany = [items count];
  int i;
  int *states = NSZoneMalloc (NSDefaultMallocZone(), sizeof(int) * howMany);
  int previousState = 0;
  NSRect aRect = [self bounds];
  NSPoint p = aRect.origin;
  NSSize s = aRect.size;
  NSRect buttRect = NSMakeRect(p.x - 2 + buttw, p.y, s.width + 4 - buttw, s.height - 24);
  float lastxspace = 34;
  float itemxspace = (aRect.size.width - lastxspace - buttw) / (howMany - 1);
  NSImage *backImage = [[GWorkspace gworkspace] tshelfBackground];
  
  if (backImage) {  
    [backImage compositeToPoint: NSMakePoint (0.0, 0.0) 
                      operation: NSCompositeSourceOver];
  }
  
	aRect.size.height -= 24;

	NSDrawButton(buttRect, NSZeroRect);
	borderThickness = 2;

  if (selected == NO) {
    [self selectTabItemAtIndex: 0];
  }
	
  for (i = 0; i < howMany; i++) {
    states[i] = [[items objectAtIndex: i] tabState];
  }
  
  for (i = howMany - 1; i >= 0; i--) {
	  NSRect r;
	  NSPoint iP;
	  TShelfViewItem *anItem = [items objectAtIndex: i];
	  NSTabState itemState;
    NSBezierPath *bpath;
    
	  itemState = [anItem tabState];

	  if (i == (howMany - 1)) {
	    iP.x = aRect.size.width;
	    iP.y = aRect.size.height;

      iP.x = aRect.size.width - lastxspace;

	    if (itemState == NSSelectedTab) {
        iP.y -= 1;
        if (howMany > 1) {
		      [[NSImage imageNamed: @"tabUnSelectToSelectedJunction.tiff"]
			          compositeToPoint: iP operation: NSCompositeSourceOver];
        } else {
		      [[NSImage imageNamed: @"tabSelectedLeft.tiff"]
		        compositeToPoint: iP operation: NSCompositeSourceOver];
        }
        iP.y += 1;
        
		  } else if (itemState == NSBackgroundTab) {
        if (howMany > 1) {
          previousState = states[i - 1];
      
		      if (previousState == NSSelectedTab) {
		        iP.y -= 1;
		        [[NSImage imageNamed: @"tabSelectedToUnSelectedJunction.tiff"]
			                  compositeToPoint: iP operation: NSCompositeSourceOver];
		        iP.y += 1;
		      } else {
		        [[NSImage imageNamed: @"tabUnSelectedJunction.tiff"]
			            compositeToPoint: iP operation: NSCompositeSourceOver];
		      }
      
        } else {
		      [[NSImage imageNamed: @"tabUnSelectedLeft.tiff"]
		            compositeToPoint: iP operation: NSCompositeSourceOver];
        }
	    } 

	    r.origin.x = iP.x + 13;
	    r.origin.y = aRect.size.height;
	    r.size.width = lastxspace - 13;
	    r.size.height = 23;
      
      bpath = [NSBezierPath bezierPath];
      [bpath setLineWidth: 1];
      [bpath moveToPoint: NSMakePoint(r.origin.x, r.origin.y + 24)];
      [bpath relativeLineToPoint: NSMakePoint(r.size.width, 0)];
      [[NSColor whiteColor] set];
      [bpath stroke];
      
      [anItem drawImage: [NSImage imageNamed: @"DragableDocument.tiff"]
                 inRect: r];

	  } else {
      iP.x -= itemxspace;
	    iP.y = aRect.size.height;
      
      if (i != 0) {
        previousState = states[i - 1];
      
	      if (itemState == NSSelectedTab) {
		      iP.y -= 1;
		      [[NSImage imageNamed: @"tabUnSelectToSelectedJunction.tiff"]
		                compositeToPoint: iP operation: NSCompositeSourceOver];
		    } else if (itemState == NSBackgroundTab) {
		      if (previousState == NSSelectedTab) {
		        iP.y -= 1;
		        [[NSImage imageNamed: @"tabSelectedToUnSelectedJunction.tiff"]
			                  compositeToPoint: iP operation: NSCompositeSourceOver];
		        iP.y += 1;
		      } else {
		        [[NSImage imageNamed: @"tabUnSelectedJunction.tiff"]
			            compositeToPoint: iP operation: NSCompositeSourceOver];
		      }
		    } 
        
	      r.origin.x = iP.x + 13;
	      r.origin.y = aRect.size.height;
	      r.size.width = itemxspace - 13;
	      r.size.height = 23;
        
      } else {
	      r.origin.x = iP.x;
	      r.origin.y = aRect.size.height;
	      r.size.width = itemxspace;
	      r.size.height = 23;
      }

//	    DPSsetgray(ctxt, 1);

      bpath = [NSBezierPath bezierPath];
      [bpath setLineWidth: 1];
      [bpath moveToPoint: NSMakePoint(r.origin.x, r.origin.y + 24)];
      [bpath relativeLineToPoint: NSMakePoint(r.size.width, 0)];
      [[NSColor whiteColor] set];
      [bpath stroke];
      
	    [anItem drawLabelInRect: r];
	  }  
	}
  
  NSZoneFree (NSDefaultMallocZone(), states);
}


- (BOOL)isOpaque
{
  return NO;
}

- (TShelfViewItem*)tabItemAtPoint:(NSPoint)point
{
  int howMany = [items count];
  int i;

  point = [self convertPoint: point fromView: nil];

  for (i = 0; i < howMany; i++) {
    TShelfViewItem *anItem = [items objectAtIndex: i];

    if(NSPointInRect(point, [anItem tabRect])) {
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

- (void)setHiddenTabs:(BOOL)value
{
  NSRect frame = [[self window] frame];
  NSRect scrframe = [[NSScreen mainScreen] frame];
  NSRect winrect;

  hiddentabs = value;

  if (hiddentabs == NO) {
    winrect = NSMakeRect(frame.origin.x, frame.origin.y, 
                                  scrframe.size.width, frame.size.height);
	  [[self window]  setFrame: winrect display: YES];
  } else {
    winrect = NSMakeRect(frame.origin.x, frame.origin.y, 10, frame.size.height);
	  [[self window]  setFrame: winrect display: YES];
  }
}

- (void)hideShowTabs:(id)sender
{
  NSRect frame = [[self window] frame];
  NSRect scrframe = [[NSScreen mainScreen] frame];
  NSRect winrect;
    
  if (hiddentabs) {
    winrect = NSMakeRect(frame.origin.x, frame.origin.y, 
                                  scrframe.size.width, frame.size.height);
	  [[self window]  setFrame: winrect display: YES];
    hiddentabs = NO;
  } else {
    winrect = NSMakeRect(frame.origin.x, frame.origin.y, 10, frame.size.height);
	  [[self window]  setFrame: winrect display: YES];
	  hiddentabs = YES;
  }
  
  [[GWorkspace gworkspace] makeTshelfBackground];
}

- (BOOL)hiddenTabs
{
  return hiddentabs;
}

- (void)mouseDown:(NSEvent *)theEvent
{
  NSPoint location = [theEvent locationInWindow];
  TShelfViewItem *anItem = [self tabItemAtPoint: location];
    
  if (anItem  &&  ([anItem isEqual: selected] == NO)) {
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

@end
