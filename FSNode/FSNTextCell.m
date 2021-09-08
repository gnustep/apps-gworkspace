/* FSNTextCell.m
 *  
 * Copyright (C) 2004-2021 Free Software Foundation, Inc.
 *
 * Authors: Enrico Sersale <enrico@imago.ro>
 *          Riccardo Mottola <rm@gnu.org>
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "FSNTextCell.h"


@implementation FSNTextCell

- (void)dealloc
{
  RELEASE (uncutTitle);
  RELEASE (fontAttr);
  RELEASE (dots);
  RELEASE (icon);  
  [super dealloc];
}

- (id)init
{
  self = [super init];

  if (self)
    {
      ASSIGN (fontAttr, [NSDictionary dictionaryWithObject: [self font]
				      forKey: NSFontAttributeName]);
      ASSIGN (dots, @"...");
      titlesize = NSMakeSize(0, 0);
      icon = nil;
      dateCell = NO;
    }

  return self;
}

- (id)copyWithZone:(NSZone *)zone
{
  FSNTextCell *c = [super copyWithZone: zone];

  c->fontAttr = [fontAttr copyWithZone: zone];
  c->dots = [dots copyWithZone: zone];

  c->dateCell = dateCell;
  
  if (uncutTitle) {
    c->uncutTitle = [uncutTitle copyWithZone: zone];
  } else {
    c->uncutTitle = nil;
  }

  RETAIN (icon);

  return c;
}

- (void)setStringValue:(NSString *)aString
{
  [super setStringValue: aString];
  titlesize = [[self stringValue] sizeWithAttributes: fontAttr]; 
}

- (void)setFont:(NSFont *)fontObj
{
  [super setFont: fontObj];
  ASSIGN (fontAttr, [NSDictionary dictionaryWithObject: [self font] 
                                                forKey: NSFontAttributeName]);
  titlesize = [[self stringValue] sizeWithAttributes: fontAttr];   
}

- (void)setIcon:(NSImage *)icn
{ 
  ASSIGN (icon, icn);
}

- (NSImage *)icon
{
  return icon;
}

- (float)uncutTitleLenght
{
  return titlesize.width;
}

- (void)setDateCell:(BOOL)value
{
  dateCell = value;
}

- (BOOL)isDateCell
{
  return dateCell;
}

- (NSString *)cutTitle:(NSString *)title 
            toFitWidth:(float)width
{
  int tl = [title length];
  
  if (tl <= 5)
    {
      return dots;
    }
  else
    {
      int fpto = (tl / 2) - 2;
      int spfr = fpto + 3;
      NSString *fp = [title substringToIndex: fpto];
      NSString *sp = [title substringFromIndex: spfr];
      NSString *dotted = [NSString stringWithFormat: @"%@%@%@", fp, dots, sp];
      int dl = [dotted length];
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
        dl = [dotted length];
      }      
      
      return dotted;
    }
  
  return title;
}

- (NSString *)cutDateTitle:(NSString *)title 
                toFitWidth:(float)width
{
  NSUInteger tl = [title length];
    
  if (tl <= 5)
    {
      return dots;
    }
  else
    {
      NSString *format = @"%b %d %Y";
      NSCalendarDate *date = [NSCalendarDate dateWithString: title
                                             calendarFormat: format];
      if (date)
        {
          NSString *descr;
        
          format = @"%m/%d/%y";
          descr = [date descriptionWithCalendarFormat: format 
                                             timeZone: [NSTimeZone localTimeZone] locale: nil];
        
          if ([descr sizeWithAttributes: fontAttr].width > width) {
            return [self cutTitle: descr toFitWidth: width];
          } else {
            return descr;
          }
        
        }
      else
        {
          return [self cutTitle: title toFitWidth: width];
        }
    }
  
  return title;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame 
                       inView:(NSView *)controlView
{
  NSRect title_rect = cellFrame;
  CGFloat textlength;
  NSString *cutTitle;  

#define MARGIN (2.0)
 
  textlength = title_rect.size.width - MARGIN;
  if (icon)
    textlength -= ([icon size].width + (MARGIN * 2));

  ASSIGN (uncutTitle, [self stringValue]);
  /* we calculate the reduced title only if necessary */
  cutTitle = nil;
  if ([uncutTitle sizeWithAttributes: fontAttr].width > textlength)
    {
      if (dateCell)
        cutTitle = [self cutDateTitle:uncutTitle toFitWidth:textlength];
      else
        cutTitle = [self cutTitle:uncutTitle toFitWidth:textlength];
      [self setStringValue: cutTitle];
    }
  else
    {
      [self setStringValue: uncutTitle];
    }

  title_rect.size.height = titlesize.height;
  title_rect.origin.y += ((cellFrame.size.height - titlesize.height) / 2.0);

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
    title_rect = NSIntegralRect(title_rect);

    [super drawInteriorWithFrame: title_rect inView: controlView];

    [icon compositeToPoint: icon_rect.origin 
		 operation: NSCompositeSourceOver];
  }

  /* we reset the title to the orginal string */
  if (cutTitle)
    [self setStringValue: uncutTitle];
}

- (BOOL)startTrackingAt:(NSPoint)startPoint inView:(NSView *)controlView
{
  return NO;
}

@end
