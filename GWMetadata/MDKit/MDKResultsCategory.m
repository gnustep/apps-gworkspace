/* MDKResultsCategory.m
 *  
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@fibernet.ro>
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "MDKResultsCategory.h"
#include "MDKWindow.h"
#include "FSNode.h"

#define MIN_LINES 5
#define TOP_FIVE 0
#define ALL_RESULTS 1

static NSString *nibName = @"MDKCategoryControls";

static NSAttributedString *topFiveHeadButtTitle = nil;
static NSImage *whiteArrowRight = nil;
static NSImage *whiteArrowDown = nil;

@implementation MDKResultsCategory

+ (void)initialize
{
  static BOOL initialized = NO;

  if (initialized == NO) {
    NSString *str = NSLocalizedString(@"Show top 5", @"");
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    id style;
    NSBundle *bundle;
    NSString *impath;   
    
    [dict setObject: [NSColor whiteColor]
             forKey: NSForegroundColorAttributeName];    
    [dict setObject: [NSFont boldSystemFontOfSize: 12]
             forKey: NSFontAttributeName];    
    style = [NSMutableParagraphStyle defaultParagraphStyle];
    [style setAlignment: NSRightTextAlignment];    
    [dict setObject: style forKey: NSParagraphStyleAttributeName];
    
    topFiveHeadButtTitle = [[NSAttributedString alloc] initWithString: str 
                                                           attributes: dict];
    
    bundle = [NSBundle bundleForClass: [self class]];
    impath = [bundle pathForResource: @"whiteArrowRight" ofType: @"tiff"];
    whiteArrowRight = [[NSImage alloc] initWithContentsOfFile: impath];  
    impath = [bundle pathForResource: @"whiteArrowDown" ofType: @"tiff"];
    whiteArrowDown = [[NSImage alloc] initWithContentsOfFile: impath];  
    
    initialized = YES;               
  }
}

- (void)dealloc
{
  RELEASE (name);
  RELEASE (headView);
  RELEASE (footView);

  [super dealloc];
}

- (id)initWithCategoryName:(NSString *)cname
                  menuName:(NSString *)mname
                  inWindow:(MDKWindow *)awin
{
  self = [super init];
  
  if (self) {
    if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
      DESTROY (self);
      return self;
    }  
    
    headView = [[ControlsView alloc] initWithFrame: [headBox frame]];
    [headView setColor: [NSColor disabledControlTextColor]];    
    [openCloseButt setImage: whiteArrowDown];
    [headView addSubview: openCloseButt];
    [nameLabel setTextColor: [NSColor whiteColor]];
    [headView addSubview: nameLabel];
    [headView addSubview: topFiveHeadButt];

    footView = [[ControlsView alloc] initWithFrame: [footBox frame]];
    [footView setColor: [NSColor controlBackgroundColor]];
    [footView addSubview: topFiveFootButt];

    RELEASE (win);
    
    [nameLabel setStringValue: NSLocalizedString(mname, @"")];
    [topFiveHeadButt setTitle: @""];
    [topFiveHeadButt setEnabled: NO];
    
    ASSIGN (name, cname);
    mdkwin = awin;
        
    prev = nil;
    next = nil;
    
    showall = NO; 
    closed = NO;
    showHeader = NO;
    showFooter = NO;
    
    results = nil;
    range = NSMakeRange(0, 0);
    globcount = 0;
  }
  
  return self;
}

- (NSString *)name
{
  return name;
}

- (void)setResults:(NSArray *)res
{
  results = res;
  range = NSMakeRange(0, 0);
  showHeader = NO;
  showFooter = NO;
  closed = ([openCloseButt state] == NSOffState); 
}

- (BOOL)hasResults
{
  return ([results count] > 0);
}

- (id)resultAtIndex:(int)index
{
  if (index < (range.location + range.length)) {
    int pos = (index - range.location);
    
    if (showHeader && (pos == 0)) {
      return [NSDictionary dictionaryWithObjectsAndKeys: self, @"category",
                                 [NSNumber numberWithBool: YES], @"head", nil];      
    }
        
    if (pos <= range.length) {
      if ((pos == (range.length - 1)) && showFooter) {
        return [NSDictionary dictionaryWithObjectsAndKeys: self, @"category",
                                  [NSNumber numberWithBool: NO], @"head", nil];      
      }      
        
      pos--;
      return [results objectAtIndex: pos];
    }
    
  } else if (next) {
    return [next resultAtIndex: index];
  }
  
  return nil;
}

- (void)calculateRanges
{
  int count = [results count];
  
  showHeader = (count > 0);
  showFooter = (count > MIN_LINES);

  range.length = 0;
  globcount = count;
  
  if (prev == nil) {
    range.location = 0;    
  } else {
    NSRange pr = [prev range];  
          
    range.location = (pr.location + pr.length);    
    globcount += [prev globalCount];
  } 
  
  if (closed == NO) {
    if (showall) {
      range.length = count;  
    } else {
      if (count > MIN_LINES) {
        range.length = MIN_LINES;
      } else {
        range.length = count;
      }
    }
  } else {
    range.length = 0;  
    showFooter = NO;
  }
  
  if (showHeader) {
    range.length++;        
  }

  if (showFooter) {
    range.length++;
  }    
  
  [self updateButtons];
  
  if (next) {
    [next calculateRanges];
  }
}

- (NSRange)range
{
  return range;
}

- (int)globalCount
{
  return globcount;
}

- (BOOL)showFooter
{
  return showFooter;
}

- (void)setPrev:(MDKResultsCategory *)cat
{
  prev = cat;
}

- (MDKResultsCategory *)prev
{
  return prev;
}

- (void)setNext:(MDKResultsCategory *)cat
{
  next = cat;
}

- (MDKResultsCategory *)next
{
  return next;
}

- (MDKResultsCategory *)last
{
  if (next) {
    return [next last];
  }  
  return self;
}

- (void)updateButtons
{
  NSString *str;
  
  if (closed) {
    [openCloseButt setImage: whiteArrowRight];
    [topFiveHeadButt setTitle: @""];
    [topFiveHeadButt setEnabled: NO];
  
  } else {
    [openCloseButt setImage: whiteArrowDown];
  
    if (showall) {  
      if (range.length > MIN_LINES) {  
        str = NSLocalizedString(@"Show top 5", @"");
        [topFiveHeadButt setAttributedTitle: topFiveHeadButtTitle];
        [topFiveHeadButt setEnabled: YES];
        [topFiveFootButt setTitle: str];
        [topFiveFootButt setTag: TOP_FIVE];
      }

    } else {
      [topFiveHeadButt setTitle: @""];
      [topFiveHeadButt setEnabled: NO];

      if (range.length > MIN_LINES) {
        str = NSLocalizedString(@"more...", @"");
        str = [NSString stringWithFormat: @"%lu %@",
			(unsigned long)([results count] - MIN_LINES), str];
        [topFiveFootButt setTitle: str];
        [topFiveFootButt setTag: ALL_RESULTS];      
      }
    }
  }
}

- (IBAction)openCloseButtAction:(id)sender
{
  if ([sender state] == NSOnState) {
    closed = NO;    
  } else {
    closed = YES;
    showFooter = NO;
  }
  
  [mdkwin updateCategoryControls: YES removeSubviews: NO];
}

- (IBAction)topFiveHeadButtAction:(id)sender
{
  showall = NO;  
  [mdkwin updateCategoryControls: YES removeSubviews: NO];
}

- (IBAction)topFiveFootButtAction:(id)sender
{
  showall = ([sender tag] == ALL_RESULTS);
  [mdkwin updateCategoryControls: YES removeSubviews: NO];
}

- (NSView *)headControls
{
  return headView;
}

- (NSView *)footControls
{
  return footView;
}

@end


@implementation ControlsView

- (void)dealloc
{
  RELEASE (backColor);    
  [super dealloc];
}

- (id)initWithFrame:(NSRect)rect
{
  self = [super initWithFrame: rect];
  
  if (self) {
    ASSIGN (backColor, [NSColor controlBackgroundColor]);
  }
  
  return self;
}

- (void)setColor:(NSColor *)color
{
  ASSIGN (backColor, color);
}

- (void)drawRect:(NSRect)rect
{
  [backColor set];
  NSRectFill(rect);
}

@end




