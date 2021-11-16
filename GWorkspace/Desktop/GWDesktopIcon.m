/* GWDesktopIcon.m
 *  
 * Copyright (C) 2005-2021 Free Software Foundation, Inc.
 *
 * Authors: Enrico Sersale <enrico@imago.ro>
 *          Riccardo Mottola <rm@gnu.org>
 *
 * Date: January 2005
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
 
#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "GWDesktopIcon.h"

@implementation GWDesktopIcon

- (id)initForNode:(FSNode *)anode
     nodeInfoType:(FSNInfoType)type
     extendedType:(NSString *)exttype
         iconSize:(int)isize
     iconPosition:(NSUInteger)ipos
        labelFont:(NSFont *)lfont
        textColor:(NSColor *)tcolor
        gridIndex:(NSUInteger)gindex
        dndSource:(BOOL)dndsrc
        acceptDnd:(BOOL)dndaccept
        slideBack:(BOOL)slback
{
  self = [super initForNode: anode
	       nodeInfoType: type
	       extendedType: exttype
		   iconSize: isize
	       iconPosition: ipos
		  labelFont: lfont
		  textColor: tcolor
		  gridIndex: gindex
		  dndSource: dndsrc
		  acceptDnd: dndaccept
		  slideBack: slback];

  if (self)
    {
      drawLabelBackground = YES;
    }

  return self;
}

- (void)mouseDown:(NSEvent *)theEvent
{
  NSWindow *win = [self window];
  NSPoint location = [theEvent locationInWindow];
  NSPoint selfloc = [self convertPoint: location fromView: nil];
  BOOL onself = NO;
  NSEvent *nextEvent = nil;
  BOOL startdnd = NO;
  NSSize offset;

  [win makeMainWindow];
  [win makeKeyWindow];

  if (icnPosition == NSImageOnly) {
    onself = [self mouse: selfloc inRect: icnBounds];
  } else {
    onself = ([self mouse: selfloc inRect: icnBounds]
	      || [self mouse: selfloc inRect: labelRect]);
  }

  if (onself) {
    if (selectable == NO) {
      return;
    }

    if ([theEvent clickCount] == 1) {
      if (isSelected == NO) {
        [container stopRepNameEditing];
        [container repSelected: self];
      }
      
      if ([theEvent modifierFlags] & NSShiftKeyMask) {
        [container setSelectionMask: FSNMultipleSelectionMask];
         
	if (isSelected) {
          if ([container selectionMask] == FSNMultipleSelectionMask) {
	    [self unselect];
            [container selectionDidChange];	
	    return;
          }
        } else {
	  [self select];
	}
        
      } else {
        [container setSelectionMask: NSSingleSelectionMask];
        
        if (isSelected == NO) {
	  [self select];
	}
      }
    
      if (dndSource) {
        while (1) {
	  nextEvent = [win nextEventMatchingMask:
			     NSLeftMouseUpMask | NSLeftMouseDraggedMask];

          if ([nextEvent type] == NSLeftMouseUp) {
            [win postEvent: nextEvent atStart: YES];
            break;

          } else if (([nextEvent type] == NSLeftMouseDragged)
		     && ([self mouse: selfloc inRect: icnBounds])) {
	    if (dragdelay < 5) {
              dragdelay++;
            } else {     
              NSPoint p = [nextEvent locationInWindow];
              offset = NSMakeSize(p.x - location.x, p.y - location.y); 
              startdnd = YES;        
              break;
            }
          }
        }
      }
      
      if (startdnd == YES) {  
        [container stopRepNameEditing];
        [self startExternalDragOnEvent: theEvent withMouseOffset: offset];   
      }
      
      editstamp = [theEvent timestamp];       
    }
    
  } else {
    [container mouseDown: theEvent];
  }
}

@end
