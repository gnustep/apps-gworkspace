/* MDKResultsCategory.h
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

#ifndef MDK_RESULTS_CATEGORY_H
#define MDK_RESULTS_CATEGORY_H

#include <Foundation/Foundation.h>
#include <AppKit/NSView.h>

@class MDKWindow;
@class NSTextField;
@class NSButton;
@class NSBox;
@class ControlsView;
@class NSColor;

@interface MDKResultsCategory : NSObject 
{
  NSString *name;
  NSArray *results;
  NSRange range;
  int globcount;
  
  BOOL showHeader;
  BOOL showFooter;
  BOOL closed;
  BOOL showall;
  
  MDKResultsCategory *prev;  
  MDKResultsCategory *next;
  
  MDKWindow *mdkwin;
  
  IBOutlet id win;
  
  IBOutlet NSBox *headBox;
  ControlsView *headView;
  IBOutlet NSButton *openCloseButt;
  IBOutlet NSTextField *nameLabel;
  IBOutlet NSButton *topFiveHeadButt;

  IBOutlet NSBox *footBox;
  ControlsView *footView;
  IBOutlet NSButton *topFiveFootButt;
}

- (id)initWithCategoryName:(NSString *)cname
                  menuName:(NSString *)mname
                  inWindow:(MDKWindow *)awin;

- (NSString *)name;

- (void)setResults:(NSArray *)res;

- (BOOL)hasResults;

- (id)resultAtIndex:(int)index;

- (void)calculateRanges;

- (NSRange)range;

- (int)globalCount;

- (BOOL)showFooter;

- (void)setPrev:(MDKResultsCategory *)cat;

- (MDKResultsCategory *)prev;

- (void)setNext:(MDKResultsCategory *)cat;

- (MDKResultsCategory *)next;

- (MDKResultsCategory *)last;

- (void)updateButtons;

- (IBAction)openCloseButtAction:(id)sender;

- (IBAction)topFiveHeadButtAction:(id)sender;

- (IBAction)topFiveFootButtAction:(id)sender;

- (NSView *)headControls;

- (NSView *)footControls;

@end


@interface ControlsView : NSView
{
  NSColor *backColor;
}

- (void)setColor:(NSColor *)color;

@end

#endif // MDK_RESULTS_CATEGORY_H

