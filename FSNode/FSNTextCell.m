/* FSNTextCell.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
 *
 * This file is part of the GNUstep Finder application
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
#include "FSNTextCell.h"

@implementation FSNTextCell

- (void)dealloc
{
  TEST_RELEASE (uncuttedTitle);
  RELEASE (fontAttr);
  RELEASE (dots);
  TEST_RELEASE (icon);  
  [super dealloc];
}

- (id)init
{
  self = [super init];

  if (self) {
    ASSIGN (fontAttr, [NSDictionary dictionaryWithObject: [self font] 
                                                  forKey: NSFontAttributeName]);
    ASSIGN (dots, [NSString stringWithString: @"..."]);
    dtslenght = [dots sizeWithAttributes: fontAttr].width; 
    titlelenght = 0.0;
    icon = nil;
    dateCell = NO;
    cutTitleSel = @selector(cutTitle:toFitWidth:);
    cutTitle = (cutIMP)[self methodForSelector: cutTitleSel];    
  }

  return self;
}

- (void)setStringValue:(NSString *)aString
{
  [super setStringValue: aString];
  titlelenght = [[self stringValue] sizeWithAttributes: fontAttr].width; 
}

- (void)setFont:(NSFont *)fontObj
{
  [super setFont: fontObj];
  ASSIGN (fontAttr, [NSDictionary dictionaryWithObject: [self font] 
                                                forKey: NSFontAttributeName]);
  titlelenght = [[self stringValue] sizeWithAttributes: fontAttr].width; 
  dtslenght = [dots sizeWithAttributes: fontAttr].width;     
}

- (void)setIcon:(NSImage *)icn
{ 
  ASSIGN (icon, icn);
}

- (NSImage *)icon
{
  return icon;
}

- (float)uncuttedTitleLenght
{
  return titlelenght;
}

- (void)setDateCell:(BOOL)value
{
  dateCell = value;

  if (dateCell) {
    cutTitleSel = @selector(cutDateTitle:toFitWidth:);
    cutTitle = (cutIMP)[self methodForSelector: cutTitleSel];    
  } else {
    cutTitleSel = @selector(cutTitle:toFitWidth:);
    cutTitle = (cutIMP)[self methodForSelector: cutTitleSel];    
  }
}

- (BOOL)isDateCell
{
  return dateCell;
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

- (NSString *)cutDateTitle:(NSString *)title 
                toFitWidth:(float)width
{
  if ([title sizeWithAttributes: fontAttr].width > width) {
    int tl = [title cStringLength];
    
    if (tl <= 5) {
      return dots;
    } else {
      NSString *format = @"%b %d %Y";
      NSCalendarDate *date = [NSCalendarDate dateWithString: title
                                             calendarFormat: format];
      if (date) {
        NSString *descr;
        
        format = @"%m/%d/%y";
        descr = [date descriptionWithCalendarFormat: format 
                            timeZone: [NSTimeZone localTimeZone] locale: nil];
        
        if ([descr sizeWithAttributes: fontAttr].width > width) {
          return [self cutTitle: descr toFitWidth: width];
        } else {
          return descr;
        }
        
      } else {
        return [self cutTitle: title toFitWidth: width];
      }
    }
  }
  
  return title;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame 
		                   inView:(NSView *)controlView
{
  NSRect title_rect = cellFrame;
  float textlenght = title_rect.size.width;
  NSString *cuttitle;  

#define MARGIN (2.0)
 
  if (icon) {
    textlenght -= ([icon size].width + (MARGIN * 2));
  }
  
  textlenght -= MARGIN;
  ASSIGN (uncuttedTitle, [self stringValue]);
  cuttitle = (*cutTitle)(self, cutTitleSel, uncuttedTitle, textlenght);
  [self setStringValue: cuttitle];        

  if (icon == nil) {
    [super drawInteriorWithFrame: title_rect inView: controlView];
    
  } else {
    NSRect icon_rect;    

    icon_rect.origin = cellFrame.origin;
    icon_rect.size = [icon size];
    icon_rect.origin.x += MARGIN;
    icon_rect.origin.y += ((cellFrame.size.height - icon_rect.size.height) / 2.0);
    if ([controlView isFlipped]) {
	    icon_rect.origin.y += icon_rect.size.height;
    }
    
    title_rect.origin.x += (icon_rect.size.width + (MARGIN * 2));	
    title_rect.size.width -= (icon_rect.size.width + (MARGIN * 2));	
    
    [super drawInteriorWithFrame: title_rect inView: controlView];

    [icon compositeToPoint: icon_rect.origin 
	               operation: NSCompositeSourceOver];
  }
  
  [self setStringValue: uncuttedTitle];          
}

@end
