/* FSNBrowserCell.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <math.h>
#include "FSNBrowserCell.h"
#include "FSNode.h"

#define DEFAULT_ISIZE (24.0)
#define HLIGHT_H_FACT (0.8125)

static id <DesktopApplication> desktopApp = nil;

@implementation FSNBrowserCell

- (void)dealloc
{
  TEST_RELEASE (node); 
  TEST_RELEASE (selection);
  TEST_RELEASE (selectionTitle);
  TEST_RELEASE (icon); 
  TEST_RELEASE (highlightPath);
  RELEASE (fontAttr);
  RELEASE (dots);
  
  [super dealloc];
}

+ (void)initialize
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *appName = [defaults stringForKey: @"DesktopApplicationName"];
  NSString *selName = [defaults stringForKey: @"DesktopApplicationSelName"];

  if (appName && selName) {
    #ifdef GNUSTEP 
		Class desktopAppClass = [[NSBundle mainBundle] principalClass];
    #else
		Class desktopAppClass = [[NSBundle mainBundle] classNamed: appName];
    #endif
    SEL sel = NSSelectorFromString(selName);

    desktopApp = [desktopAppClass performSelector: sel];
  }
}

- (id)init
{
  self = [super init];
  
  if (self) {
    icnsize = DEFAULT_ISIZE;
    ASSIGN (fontAttr, [NSDictionary dictionaryWithObject: [self font] 
                                                  forKey: NSFontAttributeName]);
    ASSIGN (dots, [NSString stringWithString: @"..."]);
    dtslenght = [dots sizeWithAttributes: fontAttr].width;     
    cutTitleSel = @selector(cutTitle:toFitWidth:);
    cutTitle = (cutIMP)[self methodForSelector: cutTitleSel]; 
       
    node = nil;
    selection = nil;
    selectionTitle = nil;    
    icon = nil;
    highlightPath = nil;
    hlightRect = NSZeroRect;
    
    isLocked = NO;
    iconSelected = NO;
  }

  return self;
}

- (void)setIcon
{
  if (node) {
    hlightRect = NSZeroRect;
    hlightRect.size.width = ceil(icnsize / 3 * 4);
    hlightRect.size.height = ceil(hlightRect.size.width * HLIGHT_H_FACT);
    if ((icnsize - hlightRect.size.height) < 2) {
      hlightRect.size.height = icnsize + 2;
    }
    ASSIGN (highlightPath, [FSNodeRep highlightPathOfSize: hlightRect.size]);
    ASSIGN (icon, [FSNodeRep iconOfSize: icnsize forNode: node]);
  }
}

- (NSString *)path
{
  if (node) {
    return [node path];
  }
  return nil;
}

- (NSString *)cutTitle:(NSString *)title 
            toFitWidth:(float)width
{
  if ([title sizeWithAttributes: fontAttr].width > width) {
    int tl = [title cStringLength];
  
    if (tl <= 5) {
      return dots;
    } else {
      int fpto = (tl / 2) - 2;
      int spfr = fpto + 3;
      NSString *fp = [title substringToIndex: fpto];
      NSString *sp = [title substringFromIndex: spfr];
      NSString *dotted = [NSString stringWithFormat: @"%@%@%@", fp, dots, sp];
      int dl = [dotted cStringLength];
      float dotl = [dotted sizeWithAttributes: fontAttr].width;
      int p = 0;

      while (dotl > width) {
        if (dl <= 5) {
          return dots;
        }        

        if (p) {
          fpto--;
        } else {
          spfr++;
        }
        p = !p;

        fp = [title substringToIndex: fpto];
        sp = [title substringFromIndex: spfr];
        dotted = [NSString stringWithFormat: @"%@%@%@", fp, dots, sp];
        dotl = [dotted sizeWithAttributes: fontAttr].width;
        dl = [dotted cStringLength];
      }      
      
      return dotted;
    }
  }
  
  return title;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame 
		                   inView:(NSView *)controlView
{
  NSRect title_rect = cellFrame;
  float textlenght = title_rect.size.width;
  BOOL showsFirstResponder = [self showsFirstResponder];
  NSString *title = [[self stringValue] copy];
  NSString *cuttitle;  

#define MARGIN (2.0)
 
  if (icon) {
    textlenght -= ([icon size].width + (MARGIN * 2));
  }
  
  textlenght -= MARGIN;
  cuttitle = (*cutTitle)(self, cutTitleSel, title, textlenght);
  [self setStringValue: cuttitle];        

  if (icon == nil) {
    [super drawInteriorWithFrame: title_rect inView: controlView];
    
  } else {
    NSRect icon_rect;    
    NSRect highlight_rect;    

    [controlView lockFocus];

    [self setShowsFirstResponder: NO];
    
    highlight_rect = hlightRect;
    if ([controlView isFlipped]) {
	    highlight_rect.origin.y += highlight_rect.size.height;
    }
    
    highlight_rect.origin = cellFrame.origin;
    highlight_rect.origin.x += 1;
    highlight_rect.origin.y += (cellFrame.size.height - highlight_rect.size.height) / 2.0;
    if ([controlView isFlipped]) {
	    highlight_rect.origin.y += highlight_rect.size.height;
    }

    icon_rect.origin = cellFrame.origin;
    icon_rect.size = NSMakeSize(icnsize, icnsize);
    if (highlight_rect.size.width > 0) {
      icon_rect.origin.x += (highlight_rect.size.width - icon_rect.size.width) / 2.0;
    } else {
      icon_rect.origin.x += MARGIN;
    }
    icon_rect.origin.y += ((cellFrame.size.height - icon_rect.size.height) / 2.0);
    if ([controlView isFlipped]) {
	    icon_rect.origin.y += icon_rect.size.height;
    }
    
    title_rect.origin.x += (icon_rect.size.width + (MARGIN * 2));	
    title_rect.size.width -= (icon_rect.size.width + (MARGIN * 2));	

    if ([self isHighlighted]) {
	    [[self highlightColorInView: controlView] set];
    } else {
      [[NSColor controlBackgroundColor] set];
	  }
	  NSRectFill(cellFrame);
            
    [super drawInteriorWithFrame: title_rect inView: controlView];
        
    if ([self isEnabled]) {
      if (iconSelected) {
        [[self highlightColorInView: controlView] set];
        [highlightPath fill];
      
    //   [openicon compositeToPoint: icon_rect.origin 
	  //                     operation: NSCompositeSourceOver];
                         
      } else {
        [icon compositeToPoint: icon_rect.origin 
	                   operation: NSCompositeSourceOver];
      }
    } else {
			[icon dissolveToPoint: icon_rect.origin fraction: 0.3];
    }

    if (showsFirstResponder) {
      [self setShowsFirstResponder: showsFirstResponder];
      NSDottedFrameRect(cellFrame);
    }

    [controlView unlockFocus];
  }

  [self setStringValue: title];          
  RELEASE (title);  
}


//
// FSNodeRep protocol
//
- (void)setNode:(FSNode *)anode
{
  DESTROY (selection);
  DESTROY (selectionTitle);
  ASSIGN (node, anode);
  if (icon) {
    [self setIcon];
  }
  [self setNodeInfoShowType: showType];  
  [self setLocked: [node isLocked]];
}

- (FSNode *)node
{
  return node;
}

- (void)showSelection:(NSArray *)selnodes
{
  int i;

  ASSIGN (node, [selnodes objectAtIndex: 0]);
  ASSIGN (selection, selnodes);
  if (icon) {
    ASSIGN (icon, [FSNodeRep multipleSelectionIconOfSize: icnsize]);
  }  
  ASSIGN (selectionTitle, ([NSString stringWithFormat: @"%i %@", 
                  [selection count], NSLocalizedString(@"elements", @"")]));
  [self setStringValue: selectionTitle];

  [self setLocked: NO];
  for (i = 0; i < [selnodes count]; i++) {
    if ([FSNodeRep isNodeLocked: [selnodes objectAtIndex: i]]) {
      [self setLocked: YES];
      break;
    }
  }
}

- (void)setFont:(NSFont *)fontObj
{
  [super setFont: fontObj];
}

- (void)setIconSize:(float)isize
{
  icnsize = isize;
  [self setIcon];
}

- (void)setNodeInfoShowType:(FSNInfoType)type
{
  showType = type;

  if (selection) {
    [self setStringValue: selectionTitle];
    return;
  }

  switch(showType) {
    case FSNInfoNameType:
      [self setStringValue: [node name]];
      break;
    case FSNInfoKindType:
      [self setStringValue: [node typeDescription]];
      break;
    case FSNInfoDateType:
      [self setStringValue: [node modDateDescription]];
      break;
    case FSNInfoSizeType:
      [self setStringValue: [node sizeDescription]];
      break;
    case FSNInfoOwnerType:
      [self setStringValue: [node owner]];
      break;
    default:
      [self setStringValue: [node name]];
      break;
  }
}

- (void)setLocked:(BOOL)value
{
	if (isLocked == value) {
		return;
	}
	isLocked = value;
	[self setEnabled: isLocked];
}

- (BOOL)isLocked
{
	return isLocked;
}

- (int)compareAccordingToName:(FSNBrowserCell *)aCell
{
  return [node compareAccordingToName: [aCell node]];
}

- (int)compareAccordingToKind:(FSNBrowserCell *)aCell
{
  return [node compareAccordingToKind: [aCell node]];
}

- (int)compareAccordingToDate:(FSNBrowserCell *)aCell
{
  return [node compareAccordingToDate: [aCell node]];
}

- (int)compareAccordingToSize:(FSNBrowserCell *)aCell
{
  return [node compareAccordingToSize: [aCell node]];
}

- (int)compareAccordingToOwner:(FSNBrowserCell *)aCell
{
  return [node compareAccordingToOwner: [aCell node]];
}

- (int)compareAccordingToGroup:(FSNBrowserCell *)aCell
{
  return [node compareAccordingToGroup: [aCell node]];
}

@end











