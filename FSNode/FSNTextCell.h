/* FSNTextCell.h
 *  
 * Copyright (C) 2004-2013 Free Software Foundation, Inc.
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#ifndef FSN_TEXT_CELL_H
#define FSN_TEXT_CELL_H

#import <Foundation/Foundation.h>
#import <AppKit/NSTextFieldCell.h>
#import "FSNodeRep.h"

@class NSImage;

@interface FSNTextCell : NSTextFieldCell 
{
  NSDictionary *fontAttr;
  NSString *dots;
  NSSize titlesize;
  BOOL dateCell;
  NSString *uncutTitle; 
  NSImage *icon;
}

- (void)setIcon:(NSImage *)icn;

- (NSImage *)icon;

- (float)uncutTitleLenght;

- (void)setDateCell:(BOOL)value;

- (BOOL)isDateCell;

- (NSString *)cutTitle:(NSString *)title 
            toFitWidth:(float)width;

- (NSString *)cutDateTitle:(NSString *)title 
                toFitWidth:(float)width;

@end

#endif // FSN_TEXT_CELL_H
