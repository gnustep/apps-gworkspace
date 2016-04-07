/* FSNPathComponentsViewer.m
 *  
 * Copyright (C) 2005-2016 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: October 2005
 *
 * This file is part of the GNUstep FSNode framework
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

#include <math.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <GNUstepBase/GNUstep.h>


#import "FSNPathComponentsViewer.h"
#import "FSNode.h"
#import "FSNFunctions.h"

#define BORDER 8.0

#define ELEM_MARGIN 4
#define COMP_MARGIN 4

#define ICN_SIZE 24
#define BRANCH_SIZE 7

static NSImage *branchImage;

@implementation FSNPathComponentsViewer

- (void)dealloc
{
  RELEASE (components);
  
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame: frameRect];
  
  if (self) {  
    components = [NSMutableArray new];
    [self setAutoresizingMask: NSViewWidthSizable];
  }
  
  return self;
}

- (void)showComponentsOfSelection:(NSArray *)selection
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableArray *allComponents = [NSMutableArray array];
  NSArray *firstComponents; 
  NSString *commonPath = path_separator();
  unsigned index = 0;
  BOOL common = YES;
  unsigned maxLength = 0;
  NSArray *newSelection;
  unsigned selcount;
  FSNode *node;
  FSNPathComponentView *component;
  unsigned i;

  for (i = 0; i < [components count]; i++) {
    [[components objectAtIndex: i] removeFromSuperview];
  }

  [components removeAllObjects];
  lastComponent = nil;
  openComponent = nil;  
  
  if ((selection == nil) || ([selection count] == 0)) {
    [self tile];
    RELEASE (arp);
    return;
  }
  
  for (i = 0; i < [selection count]; i++) {
    FSNode *fn = [selection objectAtIndex: i];
    [allComponents addObject: [FSNode pathComponentsToNode: fn]];
  }

  for (i = 0; i < [allComponents count]; i++) {
    unsigned count = [[allComponents objectAtIndex: i] count];
    
    if (maxLength < count) {
      maxLength = count;
    }
  }
  
  firstComponents = [allComponents objectAtIndex: 0];
  
  while (index < [firstComponents count]) {
    NSString *p1 = [firstComponents objectAtIndex: index];
  
    for (i = 0; i < [allComponents count]; i++) {
      NSArray *cmps2 = [allComponents objectAtIndex: i];
  
      if (index < [cmps2 count]) {
        NSString *p2 = [cmps2 objectAtIndex: index];
        
        if ([p1 isEqual: p2] == NO) {
          common = NO;
          break;
        }
        
      } else {
        common = NO;  
        break;
      }
    }
  
    if (common) {
      if ([p1 isEqual: path_separator()] == NO) {
        commonPath = [commonPath stringByAppendingPathComponent: p1];
      }

    } else {
      break;
    }
  
    index++;
  }
    
  newSelection = [commonPath pathComponents];
  
  selcount = [newSelection count]; 
  
  node = nil;
  for (i = 0; i < selcount; i++) {   
    FSNode *pn = nil;
    
    if (i != 0) {
      pn = node;
    }
    
    node = [FSNode nodeWithRelativePath: [newSelection objectAtIndex: i] 
                                 parent: pn];
                                 
    component = [[FSNPathComponentView alloc] initForNode: node
                                                 iconSize: ICN_SIZE];

    [self addSubview: component];
    [components addObject: component];
    
    if (i == (selcount -1)) {
      lastComponent = component;
      [lastComponent setLeaf: ([selection count] == 1)];
    }
    
    RELEASE (component);
  }
    
  [self tile];
  RELEASE (arp);
}

- (void)mouseMovedOnComponent:(FSNPathComponentView *)component
{
  if (openComponent != component) {
    if (component != lastComponent) {
      openComponent = component;
    } else {
      openComponent = nil;
    }
    [self tile];
  }
}

- (void)doubleClickOnComponent:(FSNPathComponentView *)component
{
  NSWorkspace *ws = [NSWorkspace sharedWorkspace];
  FSNode *node = [component node];
  NSString *path = [node path];
      
  if ([node isDirectory] || [node isMountPoint]) {
    if ([node isApplication]) {
      [ws launchApplication: path];
    } else if ([node isPackage]) {
      [ws openFile: path];
    } else {
      [ws selectFile: path inFileViewerRootedAtPath: path];    
    }        
  } else if ([node isPlain] || [node isExecutable]) {
    [ws openFile: path];    
  } else if ([node isApplication]) {
    [ws launchApplication: path];    
  }
}

- (void)tile
{
  float minWidth = [FSNPathComponentView minWidthForIconSize: ICN_SIZE];
  float orx = BORDER;
  unsigned i;
      
  for (i = 0; i < [components count]; i++) {
    FSNPathComponentView *component = [components objectAtIndex: i];
    float fullWidth = [component fullWidth];
    NSRect r;
    
    if ((component == openComponent) || (component == lastComponent)) {
      r = NSMakeRect(orx, BORDER, fullWidth, ICN_SIZE);
    } else {
      r = NSMakeRect(orx, BORDER, minWidth, ICN_SIZE);
    }
    
    [component setFrame: NSIntegralRect(r)];
        
    orx += (r.size.width + COMP_MARGIN);
  }

  [self setNeedsDisplay: YES];
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldFrameSize
{
  [super resizeWithOldSuperviewSize: oldFrameSize];
  [self tile];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
  openComponent = nil;
  [self tile];
}

@end


@implementation FSNPathComponentView

- (void)dealloc
{
  RELEASE (node);
  RELEASE (hostname);
  RELEASE (icon);
  RELEASE (label);
  RELEASE (fontAttr);
  
  [super dealloc];  
}

+ (void)initialize
{
  static BOOL initialized = NO;

  if (initialized == NO)
    {
      
      branchImage = [NSBrowserCell branchImage];
      initialized = YES;
    }
}

- (id)initForNode:(FSNode *)anode
         iconSize:(int)isize
{
  self = [super init];
  
  if (self) {
    NSFont *font = [NSFont systemFontOfSize: 12];
    
    ASSIGN (node, anode);
    iconSize = isize;
    iconRect = NSMakeRect(0, 0, iconSize, iconSize);

    fsnodeRep = [FSNodeRep sharedInstance];    
    ASSIGN (icon, [fsnodeRep iconOfSize: iconSize forNode: node]);
    isLeaf = NO;

		if ([[node path] isEqual: path_separator()] && ([node isMountPoint] == NO)) {
		  NSHost *host = [NSHost currentHost];
		  NSString *hname = [host name];
		  NSRange range = [hname rangeOfString: @"."];

		  if (range.length != 0) {	
			  hname = [hname substringToIndex: range.location];
		  } 			
      
		  ASSIGN (hostname, hname);
		} 

    label = [NSTextFieldCell new];
    [label setAlignment: NSLeftTextAlignment];
    [label setFont: font];
    [label setStringValue: (hostname ? hostname : [node name])];
    ASSIGN (fontAttr, [NSDictionary dictionaryWithObject: font
                                                  forKey: NSFontAttributeName]);    

    brImgRect = NSMakeRect(0, 0, BRANCH_SIZE, BRANCH_SIZE);
  }
  
  return self;
}

- (FSNode *)node
{
  return node;
}

- (void)setLeaf:(BOOL)value
{
  isLeaf = value;
}

+ (float)minWidthForIconSize:(int)isize
{
  return (isize + ELEM_MARGIN + ELEM_MARGIN + BRANCH_SIZE);
}

- (float)fullWidth
{
  return (iconRect.size.width + ELEM_MARGIN  
                   + [self uncuttedLabelLenght] + ELEM_MARGIN + BRANCH_SIZE);
}

- (float)uncuttedLabelLenght
{
  return [(hostname ? hostname : [node name]) sizeWithAttributes: fontAttr].width; 
}

- (void)tile
{
  float minwidth = [FSNPathComponentView minWidthForIconSize: ICN_SIZE];
 
  labelRect.size.width = [self uncuttedLabelLenght];
      
  if (labelRect.size.width <= ([self bounds].size.width - minwidth)) {
    labelRect.origin.x = iconRect.size.width + ELEM_MARGIN;
    labelRect.size.height = [fsnodeRep heightOfFont: [label font]];
    labelRect.origin.y = (iconRect.size.height - labelRect.size.height) / 2;  
    labelRect = NSIntegralRect(labelRect);  
  } else {
    labelRect = NSZeroRect;
  } 
       
  brImgRect.origin.x = iconRect.size.width + ELEM_MARGIN + labelRect.size.width + ELEM_MARGIN;
  brImgRect.origin.y = ((iconRect.size.height / 2) - (BRANCH_SIZE / 2));
  brImgRect = NSIntegralRect(brImgRect);
  
  [self setNeedsDisplay: YES]; 
}

- (void)mouseMoved:(NSEvent *)theEvent
{
  [viewer mouseMovedOnComponent: self];
}

- (void)mouseUp:(NSEvent *)theEvent
{
  if ([theEvent clickCount] > 1) {
    [viewer doubleClickOnComponent: self];
  }
}

- (void)viewDidMoveToSuperview
{
  [super viewDidMoveToSuperview];
  viewer = (FSNPathComponentsViewer *)[self superview];
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
  return YES;
}

- (void)setFrame:(NSRect)frameRect
{
  if (NSEqualRects([self frame], frameRect) == NO) {
    [super setFrame: frameRect];
    [self tile];
  }
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldFrameSize
{
  [super resizeWithOldSuperviewSize: oldFrameSize];
  [self tile];
}

- (void)drawRect:(NSRect)rect
{	 
  [icon compositeToPoint: iconRect.origin operation: NSCompositeSourceOver];      
  
  if (NSIsEmptyRect(labelRect) == NO) {
    [label drawWithFrame: labelRect inView: self];
  }
       
  if (isLeaf == NO) {
    [branchImage compositeToPoint: brImgRect.origin 
                        operation: NSCompositeSourceOver];
  }
}

@end
