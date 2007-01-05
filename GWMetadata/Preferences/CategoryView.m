/* CategoryView.m
 *  
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: December 2006
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

#include <AppKit/AppKit.h>
#include "CategoryView.h"
#include "CategoriesEditor.h"

#define VIEWW 400
#define VIEWH 28
#define SIZEH 16
#define ORY ((VIEWH - SIZEH) / 2)
#define MARGIN 6
#define ICONSIZE 24
#define ICONPOINT NSMakePoint(MARGIN * 2 + SIZEH, ((VIEWH - ICONSIZE) / 2))
#define BUTTRECT NSMakeRect(MARGIN, ORY, SIZEH, SIZEH)
#define TFIELDORX (MARGIN * 3 + SIZEH + ICONSIZE)
#define TFIELDRECT NSMakeRect(TFIELDORX, ORY, VIEWW - TFIELDORX, SIZEH)
#define UP 0
#define DOWN 1

@implementation CategoryView

- (void)dealloc
{
  RELEASE (catinfo);
  RELEASE (icon);
  RELEASE (backcolor);
  RELEASE (dragImage);
  
  [super dealloc];
}

- (id)initWithCategoryInfo:(NSDictionary *)info 
                  inEditor:(CategoriesEditor *)aneditor
{
  self = [super initWithFrame: NSMakeRect(0, 0, VIEWW, VIEWH)];
  
  if (self) {  
    NSBundle *bundle = [NSBundle bundleForClass: [self class]];
    NSString *imagepath;
    NSArray *rowcolors;
    NSString *name;
    BOOL active;
    
    catinfo = [info mutableCopy];    
    editor = aneditor;
    
    stateButton = [[NSButton alloc] initWithFrame: BUTTRECT];
    [stateButton setButtonType: NSSwitchButton];    
    [stateButton setImage: [NSImage imageNamed: @"common_SwitchOff"]];
    [stateButton setAlternateImage: [NSImage imageNamed: @"common_SwitchOn"]];    
    [stateButton setImagePosition: NSImageOnly];
    active = [[catinfo objectForKey: @"active"] boolValue];
    [stateButton setState: (active ? NSOnState : NSOffState)];
    [stateButton setTarget: self];
    [stateButton setAction: @selector(stateButtonAction:)];    
    [self addSubview: stateButton];
    RELEASE (stateButton);
    
    imagepath = [bundle pathForResource: [catinfo objectForKey: @"icon"]
                                 ofType: @"tiff"];                                 
    icon = [[NSImage alloc] initWithContentsOfFile: imagepath];
           
    titleField = [[CViewTitleField alloc] initWithFrame: TFIELDRECT
                                         inCategoryView: self];
    name = NSLocalizedString([catinfo objectForKey: @"menu_name"], @"");
    [titleField setStringValue: name];
    [self addSubview: titleField];
    RELEASE (titleField);

    rowcolors = [NSColor controlAlternatingRowBackgroundColors];
    ASSIGN (backcolor, [rowcolors objectAtIndex: (([self index] + 2) % 2)]);

    [self createDragImage];
    isDragTarget = NO;
    targetRects[0] = NSMakeRect(0, VIEWH / 2, VIEWW, VIEWH);
    targetRects[1] = NSMakeRect(0, 0, VIEWW, VIEWH / 2);
    insertpos = UP;

    [self registerForDraggedTypes: [NSArray arrayWithObject: @"MDKCategoryPboardType"]];
  }

  return self;
}

- (NSDictionary *)categoryInfo
{
  return catinfo;
}

- (int)index
{
  return [[catinfo objectForKey: @"index"] intValue];
}

- (void)setIndex:(int)index
{
  NSArray *rowcolors = [NSColor controlAlternatingRowBackgroundColors];

  [catinfo setObject: [NSNumber numberWithInt: index] forKey: @"index"];
  ASSIGN (backcolor, [rowcolors objectAtIndex: ((index + 2) % 2)]);
  [self setNeedsDisplay: YES];
}

- (void)createDragImage
{
  NSSize size = NSMakeSize(ICONSIZE + MARGIN + VIEWW - TFIELDORX, ICONSIZE);
  NSRect r = [titleField frame];
  NSBitmapImageRep *rep = nil;

  dragImage = [[NSImage alloc] initWithSize: size];
  [dragImage lockFocus];  
  
  [icon compositeToPoint: NSZeroPoint operation: NSCompositeSourceOver];  
  r.origin.x = ICONSIZE + MARGIN;
  [[titleField cell] drawWithFrame: r inView: self];
  
  r = NSMakeRect(0, 0, size.width, size.height);
  rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect: r];
  [dragImage addRepresentation: rep];
  RELEASE (rep);
  
  [dragImage unlockFocus];  
}

- (void)stateButtonAction:(id)sender
{
  BOOL active = ([sender state] == NSOnState);
  
  [catinfo setObject: [NSNumber numberWithBool: active] forKey: @"active"];
  [editor categoryViewDidChangeState: self];
}

- (void)mouseDown:(NSEvent *)theEvent
{
  NSPoint location = [theEvent locationInWindow];
	NSEvent *nextEvent = nil;
  int dragdelay = 0;
  BOOL startdnd = NO;
  NSSize offset;

  while (1) {
	  nextEvent = [[self window] nextEventMatchingMask:
    							            NSLeftMouseUpMask | NSLeftMouseDraggedMask];

    if ([nextEvent type] == NSLeftMouseUp) {
      [[self window] postEvent: nextEvent atStart: NO];
      break;

    } else {
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
        
  if (startdnd) {  
    NSPasteboard *pb = [NSPasteboard pasteboardWithName: NSDragPboard];	
    NSArray *dndtypes = [NSArray arrayWithObject: @"MDKCategoryPboardType"];
    NSString *str = [NSString stringWithFormat: @"%i", [self index]];
    
    [pb declareTypes: dndtypes owner: nil]; 
    [pb setString: str forType: @"MDKCategoryPboardType"];
    
    [self dragImage: dragImage
                 at: NSZeroPoint 
             offset: offset
              event: theEvent
         pasteboard: pb
             source: self
          slideBack: YES];
  }      
}

- (void)drawRect:(NSRect)rect
{
  [backcolor set];
  NSRectFill(rect);  
  [icon compositeToPoint: ICONPOINT operation: NSCompositeSourceOver];
  
  if (isDragTarget) {
    NSRect r = [self bounds];
    NSPoint p[2];
    
    if (insertpos == UP) {
      p[0] = NSMakePoint(0, r.size.height - 1);
      p[1] = NSMakePoint(r.size.width, r.size.height - 1);
    } else {
      p[0] = NSMakePoint(0, 1);
      p[1] = NSMakePoint(r.size.width, 1);
    }
    
    [[NSColor blackColor] set];
    [NSBezierPath setDefaultLineWidth: 2.0];
    [NSBezierPath strokeLineFromPoint: p[0] toPoint: p[1]];
  }  
}

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag
{
  return NSDragOperationAll;
}

- (BOOL)ignoreModifierKeysWhileDragging
{
  return YES;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb = [sender draggingPasteboard];
  
  if ([[pb types] containsObject: @"MDKCategoryPboardType"]) {
    NSPoint p = [self convertPoint: [sender draggingLocation] fromView: nil];
    NSString *pbstr = [pb stringForType: @"MDKCategoryPboardType"]; 
    int otherind = [pbstr intValue];
    
    if (otherind != [self index]) {
      insertpos = ([self mouse: p inRect: targetRects[0]] ? UP : DOWN); 
      isDragTarget = YES;
      [self setNeedsDisplay: YES];
      return NSDragOperationAll;        
    }    
  } 
  
  isDragTarget = NO;
      
  return NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
  if (isDragTarget) {
    NSPasteboard *pb = [sender draggingPasteboard];
    NSPoint p = [self convertPoint: [sender draggingLocation] fromView: nil];
    int pos = ([self mouse: p inRect: targetRects[0]] ? UP : DOWN); 
                              
    if (pos != insertpos) {
      NSString *pbstr = [pb stringForType: @"MDKCategoryPboardType"]; 
      int otherind = [pbstr intValue];
      int infoind = [self index];
    
      if (((pos == UP) && (otherind != infoind - 1)) 
                    || ((pos == DOWN) && (otherind != infoind + 1))) {
        insertpos = pos;
        [self setNeedsDisplay: YES];
        return NSDragOperationAll;         
      } 
    } else {
      return NSDragOperationAll; 
    }
  }
  
  if (isDragTarget) {
    [self setNeedsDisplay: YES];
    isDragTarget = NO;
  } 
      
  return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  isDragTarget = NO;  
  [self setNeedsDisplay: YES];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pb = [sender draggingPasteboard];
  NSString *pbstr = [pb stringForType: @"MDKCategoryPboardType"]; 
  int otherind = [pbstr intValue];
  int infoind = [self index];

  if (((insertpos == UP) && (otherind == infoind - 1)) 
               || ((insertpos == DOWN) && (otherind == infoind + 1))) {
    isDragTarget = NO; 
    [self setNeedsDisplay: YES];
  }
  
  return isDragTarget;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
  return isDragTarget;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb = [sender draggingPasteboard];
  NSString *pbstr = [pb stringForType: @"MDKCategoryPboardType"]; 
  int index;
  
  isDragTarget = NO;
  [self setNeedsDisplay: YES];

  if (insertpos == UP) {
    index = [self index];
  } else {
    index = [self index] + 1;
  }
    
  [editor moveCategoryViewAtIndex: [pbstr intValue]
                          toIndex: index];
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
  return YES;
}

@end


@implementation CViewTitleField

- (id)initWithFrame:(NSRect)rect
     inCategoryView:(CategoryView *)view
{
  self = [super initWithFrame: rect];

  if (self) {
    cview = view;
    [self setBezeled: NO];
    [self setEditable: NO];
    [self setSelectable: NO];
    [self setDrawsBackground: NO];
  }
  
  return self;
}

- (void)mouseDown:(NSEvent *)theEvent
{
  [cview mouseDown: theEvent];
}

@end











