/* MDKAttributeEditor.h
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

#ifndef MDK_ATTRIBUTE_EDITOR_H
#define MDK_ATTRIBUTE_EDITOR_H

#import <Foundation/Foundation.h>
#import "MDKQuery.h"

@class MDKAttribute;
@class MDKWindow;
@class MDKStringEditor;
@class NSBox;
@class NSTextField;
@class NSPopUpButton;
@class NSButton;
@class NSStepper;
@class NSView;

@interface MDKAttributeEditor : NSObject <NSTextFieldDelegate>
{
  IBOutlet id win;
  IBOutlet NSBox *editorBox;
  
  IBOutlet NSPopUpButton *operatorPopup;
  
  IBOutlet NSBox *valueBox;  
  IBOutlet NSTextField *valueField;
  
  IBOutlet NSBox *firstValueBox;
  IBOutlet NSPopUpButton *valuesPopup;
  
  IBOutlet NSBox *secondValueBox;
  
  MDKAttribute *attribute;  
  NSMutableDictionary *editorInfo;
  
  int stateChangeLock;
  
  id mdkwindow;
}

+ (id)editorForAttribute:(MDKAttribute *)attribute
                inWindow:(MDKWindow *)window;

- (id)initForAttribute:(MDKAttribute *)attr
              inWindow:(MDKWindow *)window;

- (id)initForAttribute:(MDKAttribute *)attr
              inWindow:(MDKWindow *)window
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


@interface MDKTextContentEditor : NSObject <NSTextFieldDelegate>
{
  NSTextField *searchField;
  NSArray *textContentWords;
  BOOL wordsChanged;
  NSMutableCharacterSet *skipSet;  
  id mdkwindow;
}

- (id)initWithSearchField:(NSTextField *)field
                 inWindow:(MDKWindow *)window;

- (void)setTextContentWords:(NSArray *)words;

- (NSArray *)textContentWords;

- (BOOL)wordsChanged;

@end

#endif // MDK_ATTRIBUTE_EDITOR_H

