/* MDKAttributeView.h
 *  
 * Copyright (C) 2006-2018 Free Software Foundation, Inc.
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

#ifndef MDK_ATTRIBUTE_VIEW_H
#define MDK_ATTRIBUTE_VIEW_H

#import <Foundation/Foundation.h>

@class NSBox;
@class NSPopUpButton;
@class NSButton;
@class MDKWindow;
@class MDKAttribute;

@interface MDKAttributeView : NSObject 
{
  IBOutlet id win;
  IBOutlet NSBox *mainBox;
  IBOutlet NSPopUpButton *popUp;
  IBOutlet NSBox *editorBox;
  IBOutlet NSButton *removeButt;
  IBOutlet NSButton *addButt;

  MDKWindow *mdkwindow;
  MDKAttribute *attribute;
  NSMutableArray *usedAttributesNames;
  
  NSString *otherstr;
}

- (id)initInWindow:(MDKWindow *)awindow;

- (NSBox *)mainBox;

- (void)setAttribute:(MDKAttribute *)attr;

- (void)updateMenuForAttributes:(NSArray *)attributes;

- (void)attributesDidChange:(NSArray *)attributes;

- (void)setAddEnabled:(BOOL)value;

- (void)setRemoveEnabled:(BOOL)value;

- (MDKAttribute *)attribute;

- (IBAction)popUpAction:(id)sender;

- (IBAction)buttonsAction:(id)sender;

@end

#endif // MDK_ATTRIBUTE_VIEW_H
