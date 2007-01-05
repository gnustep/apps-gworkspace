/* MDKAttributeEditor.h
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

#ifndef MDK_ATTRIBUTE_EDITOR_H
#define MDK_ATTRIBUTE_EDITOR_H

#include <Foundation/Foundation.h>
#include "MDKQuery.h"

@class MDKAttribute;
@class MDKStringEditor;
@class NSBox;
@class NSTextField;
@class NSPopUpMenu;
@class NSButton;
@class NSStepper;
@class NSView;

@interface MDKAttributeEditor : NSObject 
{
  IBOutlet id win;
  IBOutlet NSBox *editorBox;
  
  IBOutlet NSPopUpMenu *operatorPopup;
  
  IBOutlet NSBox *valueBox;  
  IBOutlet NSTextField *valueField;
  
  IBOutlet NSBox *firstValueBox;
  IBOutlet NSPopUpMenu *valuesPopup;
  
  IBOutlet NSBox *secondValueBox;
  
  MDKAttribute *attribute;  
  NSMutableDictionary *editorInfo;
  
  int stateChangeLock;
}

+ (id)editorForAttribute:(MDKAttribute *)attribute;

- (id)initForAttribute:(MDKAttribute *)attr;

- (id)initForAttribute:(MDKAttribute *)attr
               nibName:(NSString *)nibname;

- (void)setDefaultValues:(NSDictionary *)info;

- (void)restoreSavedState:(NSDictionary *)info;

- (BOOL)hasValidValues;

- (void)stateDidChange;

- (IBAction)operatorPopupAction:(id)sender;

- (IBAction)valuesPopupAction:(id)sender;

- (MDKOperatorType)operatorTypeForTag:(int)tag;

- (NSView *)editorView;

- (MDKAttribute *)attribute;  

- (NSDictionary *)editorInfo;

@end


@interface MDKStringEditor : MDKAttributeEditor 
{
  IBOutlet NSButton *caseSensButt;
}

- (IBAction)caseSensButtAction:(id)sender;

- (NSString *)appendWildcardsToString:(NSString *)str;

- (NSString *)removeWildcardsFromString:(NSString *)str;

@end


@interface MDKArrayEditor : MDKAttributeEditor 
{
  IBOutlet NSButton *caseSensButt;
}

- (IBAction)caseSensButtAction:(id)sender;

@end


@interface MDKNumberEditor : MDKAttributeEditor 
{
}

@end


@interface MDKDateEditor : MDKAttributeEditor 
{
  IBOutlet NSTextField *dateField;
  IBOutlet NSStepper *dateStepper;
  
  double stepperValue;
}

- (IBAction)stepperAction:(id)sender; 

- (void)parseDateString:(NSString *)str;

- (NSCalendarDate *)midnight;

- (NSTimeInterval)midnightStamp;

@end


@interface MDKTextContentEditor : NSObject 
{
  NSTextField *searchField;
  NSArray *textContentWords;
  NSMutableCharacterSet *skipSet;  
}

- (id)initWithSearchField:(NSTextField *)field;

- (void)setTextContentWords:(NSArray *)words;

- (NSArray *)textContentWords;

@end

#endif // MDK_ATTRIBUTE_EDITOR_H

