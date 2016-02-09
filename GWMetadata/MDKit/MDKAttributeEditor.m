/* MDKAttributeEditor.m
 *  
 * Copyright (C) 2006-2013 Free Software Foundation, Inc.
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

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#import "MDKAttributeEditor.h"
#import "MDKAttribute.h"
#import "MDKWindow.h"

enum {
  B_YES = 0,
  B_NO = 1,
  IS = 2,
  IS_NOT = 3,
  CONTAINS = 4,
  CONTAINS_NOT = 5,
  STARTS_WITH = 6,
  ENDS_WITH = 7,
  LESS_THEN = 8,
  EQUAL_TO = 9,
  GREATER_THEN = 10,  
  TODAY = 11,
  WITHIN = 12,
  BEFORE = 13,
  AFTER = 14,
  EXACTLY = 15
};

enum {
  EMPTY,
  ALT_1,
  FIELD,
  ALT_2
};


#define VAL_ORIG NSMakePoint(105, 3)

static NSMutableCharacterSet *skipSet = nil;


@implementation MDKAttributeEditor

+ (void)initialize
{
  static BOOL initialized = NO;

  if (initialized == NO) {
    initialized = YES;

    if (skipSet == nil) {      
      NSCharacterSet *set;

      skipSet = [NSMutableCharacterSet new];

      set = [NSCharacterSet controlCharacterSet];
      [skipSet formUnionWithCharacterSet: set];

      set = [NSCharacterSet illegalCharacterSet];
      [skipSet formUnionWithCharacterSet: set];

      set = [NSCharacterSet symbolCharacterSet];
      [skipSet formUnionWithCharacterSet: set];

      set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
      [skipSet formUnionWithCharacterSet: set];

      set = [NSCharacterSet characterSetWithCharactersInString: 
                                          @"~`@#$%^_-+\\{}:;\"\',/?"];
      [skipSet formUnionWithCharacterSet: set];  
    }            
  }
}

+ (id)editorForAttribute:(MDKAttribute *)attribute
                inWindow:(MDKWindow *)window
{
  int type = [attribute type];
  Class edclass;
  id editor = nil;
  
  switch (type) {
    case NUMBER:
      edclass = [MDKNumberEditor class];
      break;

    case DATE_TYPE:
      edclass = [MDKDateEditor class];
      break;

    case ARRAY:
      edclass = [MDKArrayEditor class];
      break;

    case STRING:
    case DATA:
    default:
      edclass = [MDKStringEditor class];
      break;
  }
  
  editor = [[edclass alloc] initForAttribute: attribute inWindow: window];
  
  return TEST_AUTORELEASE (editor);
}

- (void)dealloc
{
  RELEASE (valueBox);
  RELEASE (firstValueBox);
  RELEASE (secondValueBox);
  RELEASE (editorBox);
  RELEASE (editorInfo);
    
  [super dealloc];
}

- (id)initForAttribute:(MDKAttribute *)attr
              inWindow:(MDKWindow *)window
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (id)initForAttribute:(MDKAttribute *)attr
              inWindow:(MDKWindow *)window
               nibName:(NSString *)nibname
{
  self = [super init];
  
  if ([NSBundle loadNibNamed: nibname owner: self]) {
    NSDictionary *info = [attr editorInfo];
    NSArray *operatorNums = [info objectForKey: @"operator"];
    int editmode = [[info objectForKey: @"value_edit"] intValue];
    unsigned i;
    
    RETAIN (editorBox);
    RETAIN (valueBox);
    RETAIN (firstValueBox);
    [firstValueBox removeFromSuperview];
    [firstValueBox setFrameOrigin: VAL_ORIG];    
    RETAIN (secondValueBox);
    [secondValueBox removeFromSuperview];
    [secondValueBox setFrameOrigin: VAL_ORIG];
    RELEASE (win);

    attribute = attr;
    mdkwindow = window;
    stateChangeLock = 0;
    
    editorInfo = [NSMutableDictionary new];
    [editorInfo setObject: [attribute name] forKey: @"attrname"];
    [editorInfo setObject: [NSNumber numberWithBool: YES] forKey: @"casesens"];
    [editorInfo setObject: [NSMutableArray array] forKey: @"values"];
    [editorInfo setObject: [NSNumber numberWithInt: 0] forKey: @"opmenu_index"];    
    [editorInfo setObject: [NSNumber numberWithInt: 0] forKey: @"valmenu_index"];    
       
    [operatorPopup removeAllItems];
    
    for (i = 0; i < [operatorNums count]; i++) {
      int opnum = [[operatorNums objectAtIndex: i] intValue];
      NSString *title;
    
      switch (opnum) {
        case B_YES:
          title = NSLocalizedString(@"YES", @"");
          break;
        case B_NO:
          title = NSLocalizedString(@"NO", @"");
          break;
        case IS:
          title = NSLocalizedString(@"is", @"");
          break;
        case IS_NOT:
          title = NSLocalizedString(@"is not", @"");
          break;
        case CONTAINS:
          title = NSLocalizedString(@"contains", @"");
          break;
        case CONTAINS_NOT:
          title = NSLocalizedString(@"contains not", @"");
          break;
        case STARTS_WITH:
          title = NSLocalizedString(@"starts with", @"");
          break;
        case ENDS_WITH:
          title = NSLocalizedString(@"ends with", @"");
          break;
        case LESS_THEN:
          title = NSLocalizedString(@"less than", @"");
          break;
        case EQUAL_TO:
          title = NSLocalizedString(@"equal to", @"");
          break;
        case GREATER_THEN:
          title = NSLocalizedString(@"greater than", @"");
          break;
        case TODAY:
          title = NSLocalizedString(@"is today", @"");
          break;
        case WITHIN:
          title = NSLocalizedString(@"is within", @"");
          break;
        case BEFORE:
          title = NSLocalizedString(@"is before", @"");
          break;
        case AFTER:
          title = NSLocalizedString(@"is after", @"");
          break;
        case EXACTLY:
          title = NSLocalizedString(@"is exactly", @"");
          break;
        default:
          title = @"";
          break;
      }
    
      [operatorPopup addItemWithTitle: title];
      [[operatorPopup itemAtIndex: i] setTag: opnum];
    }
    
    [operatorPopup selectItemAtIndex: 0];
    
    if (editmode != FIELD) {
      [valueBox removeFromSuperview];
    }
    
    if (editmode == ALT_1) {    
      NSArray *titles = [info objectForKey: @"value_menu"];
      NSArray *objects = [info objectForKey: @"value_set"];
      
      [valuesPopup removeAllItems];
      
      for (i = 0; i < [titles count]; i++) {
        [valuesPopup addItemWithTitle: [titles objectAtIndex: i]];
        [[valuesPopup itemAtIndex: i] setRepresentedObject: [objects objectAtIndex: i]];
      }
      
      [valuesPopup selectItemAtIndex: 0];
      [[editorBox contentView] addSubview: (NSView *)firstValueBox];
      
    } else if (editmode == ALT_2) {   
      [[editorBox contentView] addSubview: (NSView *)secondValueBox];    
    }
    
    [self setDefaultValues: info];
    
  } else {
    NSLog(@"failed to load %@!", nibname);
    DESTROY (self);
  }
  
  return self;
}

- (void)setDefaultValues:(NSDictionary *)info
{
  NSMutableArray *values = [editorInfo objectForKey: @"values"];
  int tag = [[operatorPopup selectedItem] tag];
  MDKOperatorType type = [self operatorTypeForTag: tag];
  int editmode = [[info objectForKey: @"value_edit"] intValue];
  NSString *defvalue = [info objectForKey: @"search_value"];
  
  [editorInfo setObject: [NSNumber numberWithInt: type] forKey: @"optype"];
  
  if (editmode == EMPTY) {    
    [values addObject: defvalue];
  
  } else if (editmode == ALT_1) {    
    [values addObject: [[valuesPopup selectedItem] representedObject]];

  } else if (editmode == FIELD) {    
    if (defvalue) {
      [values addObject: defvalue];
    }
    
  } else if (editmode == ALT_2) {    
    /* this must be managed in the subclasses */
  }
}

- (void)restoreSavedState:(NSDictionary *)info
{
  id entry = [info objectForKey: @"values"];
  
  if (entry && [entry count]) {
    NSMutableArray *values = [editorInfo objectForKey: @"values"];
    
    [values removeAllObjects];
    [values addObjectsFromArray: entry];
  }

  entry = [info objectForKey: @"opmenu_index"];
  
  if (entry) {
    stateChangeLock++;
    [operatorPopup selectItemAtIndex: [entry intValue]];  
    [self operatorPopupAction: operatorPopup];
    stateChangeLock--;
  }
}

- (BOOL)hasValidValues
{
  return ([[editorInfo objectForKey: @"values"] count] > 0); 
}

- (void)stateDidChange
{
  stateChangeLock = (stateChangeLock < 0) ? 0 : stateChangeLock;

  if (stateChangeLock == 0) {
    [mdkwindow editorStateDidChange: self];
  }
}

- (IBAction)operatorPopupAction:(id)sender
{
  int index = [sender indexOfSelectedItem];
  
  if (index != [[editorInfo objectForKey: @"opmenu_index"] intValue]) {
    int tag = [[sender selectedItem] tag]; 
    MDKOperatorType type = [self operatorTypeForTag: tag];

    [editorInfo setObject: [NSNumber numberWithInt: type] forKey: @"optype"];    
    [editorInfo setObject: [NSNumber numberWithInt: [sender indexOfSelectedItem]]
                   forKey: @"opmenu_index"];    
    [self stateDidChange];
  }
}

- (IBAction)valuesPopupAction:(id)sender
{
  [editorInfo setObject: [NSNumber numberWithInt: [sender indexOfSelectedItem]]
                 forKey: @"valmenu_index"];    
}

- (MDKOperatorType)operatorTypeForTag:(int)tag
{
  MDKOperatorType type;

  [editorInfo removeObjectForKey: @"leftwild"];        
  [editorInfo removeObjectForKey: @"rightwild"];        
  
  switch (tag) {
    case GREATER_THEN:
    case AFTER:
      type = MDKGreaterThanOperatorType;    
      break;

    case TODAY:
    case WITHIN:
      type = MDKGreaterThanOrEqualToOperatorType;    
      break;

    case LESS_THEN:
    case BEFORE:
      type = MDKLessThanOperatorType;    
      break;
  
    case IS_NOT:
      type = MDKNotEqualToOperatorType; 
      break;
          
    case CONTAINS_NOT:    
      type = MDKNotEqualToOperatorType; 
      [editorInfo setObject: [NSNumber numberWithBool: YES] forKey: @"rightwild"];        
      [editorInfo setObject: [NSNumber numberWithBool: YES] forKey: @"leftwild"];         
      break;
    
    case B_YES:
    case B_NO:
    case IS:
    case EQUAL_TO:
    case EXACTLY:
      type = MDKEqualToOperatorType;    
      break;
    
    case CONTAINS:
      type = MDKEqualToOperatorType;        
      [editorInfo setObject: [NSNumber numberWithBool: YES] forKey: @"rightwild"];        
      [editorInfo setObject: [NSNumber numberWithBool: YES] forKey: @"leftwild"];
      break;
    
    case STARTS_WITH:
      type = MDKEqualToOperatorType;        
      [editorInfo setObject: [NSNumber numberWithBool: YES] forKey: @"rightwild"];    
      break;
    
    case ENDS_WITH:
      type = MDKEqualToOperatorType;        
      [editorInfo setObject: [NSNumber numberWithBool: YES] forKey: @"leftwild"];
      break;
    
    default:
      type = MDKEqualToOperatorType;    
      break;
  }
  
  return type;
}

- (NSView *)editorView
{
  return editorBox;
}

- (MDKAttribute *)attribute
{
  return attribute;
}

- (NSDictionary *)editorInfo
{
  return editorInfo;
}

@end


@implementation MDKStringEditor

- (void)dealloc
{    
  [super dealloc];
}

- (id)initForAttribute:(MDKAttribute *)attr
              inWindow:(MDKWindow *)window
{
  self = [super initForAttribute: attr 
                        inWindow: window
                         nibName: @"MDKStringEditor"];
  
  if (self) {
    NSBundle *bundle = [NSBundle bundleForClass: [self class]];
    NSString *impath;
    NSImage *image;
    
    impath = [bundle pathForResource: @"switchOff" ofType: @"tiff"];
    image = [[NSImage alloc] initWithContentsOfFile: impath];
    [caseSensButt setImage: image];    
    RELEASE (image);

    impath = [bundle pathForResource: @"switchOn" ofType: @"tiff"];
    image = [[NSImage alloc] initWithContentsOfFile: impath];
    [caseSensButt setAlternateImage: image];    
    RELEASE (image);

    [caseSensButt setState: NSOnState];    
    
    [caseSensButt setToolTip: NSLocalizedString(@"Case sensitive switch", @"")];     
  
    [valueField setDelegate: self];
  } 
  
  return self;
}

- (void)restoreSavedState:(NSDictionary *)info
{
  int editmode;
  id entry;
  
  [super restoreSavedState: info];
  
  editmode = [[[attribute editorInfo] objectForKey: @"value_edit"] intValue];
  
  if (editmode == FIELD) {
    NSArray *values = [editorInfo objectForKey: @"values"];
    
    if ([values count]) {
      NSString *word = [values objectAtIndex: 0];
      
      word = [self removeWildcardsFromString: word];
      [valueField setStringValue: word];
    }
  } else {
    entry = [info objectForKey: @"valmenu_index"];
  
    if (entry) {
      [valuesPopup selectItemAtIndex: [entry intValue]];  
      [self valuesPopupAction: valuesPopup];
    }  
  }
  
  entry = [info objectForKey: @"casesens"];
  
  if (entry) {
    [caseSensButt setState: ([entry boolValue] ? NSOnState : NSOffState)];
    [self caseSensButtAction: caseSensButt];
  }
}

- (IBAction)operatorPopupAction:(id)sender
{
  int index = [sender indexOfSelectedItem];
  BOOL changed = (index != [[editorInfo objectForKey: @"opmenu_index"] intValue]);

  stateChangeLock++;
  [super operatorPopupAction: sender];
    
  if ([[[attribute editorInfo] objectForKey: @"value_edit"] intValue] == FIELD) {
    NSMutableArray *values = [editorInfo objectForKey: @"values"];
  
    if ([values count]) {
      NSString *oldword = [values objectAtIndex: 0];
      NSString *word = [self removeWildcardsFromString: oldword];
            
      word = [self appendWildcardsToString: word];
            
      if ([word isEqual: oldword] == NO) {
        [values removeAllObjects];
        [values addObject: word];
      }
    }
  }
  
  stateChangeLock--;
  
  if (changed) {
    [self stateDidChange];
  }
}

- (IBAction)valuesPopupAction:(id)sender
{
  int index = [sender indexOfSelectedItem];

  if (index != [[editorInfo objectForKey: @"valmenu_index"] intValue]) {
    NSMutableArray *values = [editorInfo objectForKey: @"values"];
    NSString *oldvalue = ([values count] ? [values objectAtIndex: 0] : nil);    
    NSString *newvalue = [[valuesPopup selectedItem] representedObject];

    [super valuesPopupAction: sender];

    if ((oldvalue == nil) || ([oldvalue isEqual: newvalue] == NO)) {
      [values removeAllObjects];
      [values addObject: newvalue];
      [self stateDidChange];
    }
  }
}

- (IBAction)caseSensButtAction:(id)sender
{
  if ([sender state] == NSOnState) {
    [editorInfo setObject: [NSNumber numberWithBool: YES] forKey: @"casesens"];  
  } else {
    [editorInfo setObject: [NSNumber numberWithBool: NO] forKey: @"casesens"];
  }
  
  [self stateDidChange];
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
  NSMutableArray *values = [editorInfo objectForKey: @"values"];
  NSString *str = [valueField stringValue];

  if ([str length]) {
    NSScanner *scanner = [NSScanner scannerWithString: str];
    NSString *word, *oldword;
    
    if ([values count]) {
      oldword = [self removeWildcardsFromString: [values objectAtIndex: 0]];
    } else {
      oldword = [NSString string];
    }
    
    if ([scanner scanUpToCharactersFromSet: skipSet intoString: &word]) {            
      if (word && ([word isEqual: oldword] == NO)) {
        [values removeAllObjects];
        [values addObject: [self appendWildcardsToString: word]];
        [valueField setStringValue: word];
        [self stateDidChange];
      } else {
        [valueField setStringValue: oldword];
      }
    } else {
      [valueField setStringValue: oldword];
    }
  } else {
    [values removeAllObjects];
    [self stateDidChange];
  }
}

- (NSString *)appendWildcardsToString:(NSString *)str
{
  if (str) {
    NSMutableString *wilded = [NSMutableString stringWithCapacity: [str length]];

    if ([editorInfo objectForKey: @"leftwild"]) {
      [wilded appendString: @"*"];
    }  

    [wilded appendString: str];

    if ([editorInfo objectForKey: @"rightwild"]) {
      [wilded appendString: @"*"];
    }

    return [wilded makeImmutableCopyOnFail: NO];  
  }
  
  return nil;
}

- (NSString *)removeWildcardsFromString:(NSString *)str
{
  if (str) {
    NSMutableString *mstr = [str mutableCopy];
  
    [mstr replaceOccurrencesOfString: @"*" 
                          withString: @"" 
                             options: NSLiteralSearch
                               range: NSMakeRange(0, [mstr length])];
  
    return [mstr autorelease];
  }
  
  return nil;
}

@end


@implementation MDKArrayEditor

- (void)dealloc
{
  [super dealloc];
}

- (id)initForAttribute:(MDKAttribute *)attr
              inWindow:(MDKWindow *)window
{
  self = [super initForAttribute: attr 
                        inWindow: window
                         nibName: @"MDKArrayEditor"];
  
  if (self) {
    NSBundle *bundle = [NSBundle bundleForClass: [self class]];
    NSString *impath;
    NSImage *image;
    
    impath = [bundle pathForResource: @"switchOff" ofType: @"tiff"];
    image = [[NSImage alloc] initWithContentsOfFile: impath];
    [caseSensButt setImage: image];    
    RELEASE (image);

    impath = [bundle pathForResource: @"switchOn" ofType: @"tiff"];
    image = [[NSImage alloc] initWithContentsOfFile: impath];
    [caseSensButt setAlternateImage: image];    
    RELEASE (image);
    
    [caseSensButt setToolTip: NSLocalizedString(@"Case sensitive switch", @"")];     
    [caseSensButt setState: NSOnState];    
  
    [valueField setDelegate: self];
  } 
  
  return self;
}

- (void)restoreSavedState:(NSDictionary *)info
{
  NSArray *values;
  id entry;
  
  [super restoreSavedState: info];
  
  values = [editorInfo objectForKey: @"values"];
  
  if ([values count]) {
    [valueField setStringValue: [values componentsJoinedByString: @" "]];
  }
     
  entry = [info objectForKey: @"casesens"];
  
  if (entry) {
    [caseSensButt setState: ([entry boolValue] ? NSOnState : NSOffState)];
    [self caseSensButtAction: caseSensButt];
  }  
}

- (IBAction)caseSensButtAction:(id)sender
{
  if ([sender state] == NSOnState) {
    [editorInfo setObject: [NSNumber numberWithBool: YES] forKey: @"casesens"];  
  } else {
    [editorInfo setObject: [NSNumber numberWithBool: NO] forKey: @"casesens"];
  }
  
  [self stateDidChange];
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
  NSMutableArray *values = [editorInfo objectForKey: @"values"];
  NSString *str = [valueField stringValue];

  if ([str length]) {    
    NSMutableArray *words = [NSMutableArray array];
    NSScanner *scanner = [NSScanner scannerWithString: str];
    
    while ([scanner isAtEnd] == NO) {
      NSString *word;
      
      if ([scanner scanUpToCharactersFromSet: skipSet intoString: &word]) {
        if (word && [word length]) {
          [words addObject: word];
        }         
      } else {
        break;
      }
    }
    
    if ([words count] && ([words isEqual: values] == NO)) {
      [values removeAllObjects];
      [values addObjectsFromArray: words];
      [self stateDidChange];
    } 
    
    str = [values componentsJoinedByString: @" "];
    [valueField setStringValue: str];      
  
  } else {
    [values removeAllObjects];
    [self stateDidChange];
  }
}

@end


@implementation MDKNumberEditor

- (void)dealloc
{
  [super dealloc];
}

- (id)initForAttribute:(MDKAttribute *)attr
              inWindow:(MDKWindow *)window
{
  self = [super initForAttribute: attr 
                        inWindow: window
                         nibName: @"MDKNumberEditor"];
  
  if (self) {
    NSNumberFormatter *formatter = [NSNumberFormatter new];

    [formatter setAllowsFloats: ([attribute numberType] == NUM_FLOAT)];
    [[valueField cell] setFormatter: formatter];
    RELEASE (formatter);    

    [valueField setStringValue: @"0"];
    [valueField setDelegate: self];    
  } 
  
  return self;
}

- (void)restoreSavedState:(NSDictionary *)info
{
  int editmode;
  id entry;
  
  [super restoreSavedState: info];
  
  editmode = [[[attribute editorInfo] objectForKey: @"value_edit"] intValue];
  
  if (editmode == FIELD) { 
    NSArray *values = [editorInfo objectForKey: @"values"];
    
    if ([values count]) {
      [valueField setStringValue: [values objectAtIndex: 0]];
    }
  
  } else if (editmode == ALT_1) {  
    entry = [info objectForKey: @"valmenu_index"];
  
    if (entry) {
      [valuesPopup selectItemAtIndex: [entry intValue]];  
      [self valuesPopupAction: valuesPopup];
    }  
  } 
}

- (IBAction)operatorPopupAction:(id)sender
{
  int index = [sender indexOfSelectedItem];
  
  if (index != [[editorInfo objectForKey: @"opmenu_index"] intValue]) {
    int editmode = [[[attribute editorInfo] objectForKey: @"value_edit"] intValue];

    [super operatorPopupAction: sender];

    if (editmode == EMPTY) {
      [self stateDidChange];  
    }
  }
}

- (IBAction)valuesPopupAction:(id)sender
{
  int index = [sender indexOfSelectedItem];

  if (index != [[editorInfo objectForKey: @"valmenu_index"] intValue]) {
    NSMutableArray *values = [editorInfo objectForKey: @"values"];
    NSString *oldvalue = ([values count] ? [values objectAtIndex: 0] : nil);    
    NSString *newvalue = [[valuesPopup selectedItem] representedObject];

    [super valuesPopupAction: sender];

    if ((oldvalue == nil) || ([oldvalue isEqual: newvalue] == NO)) {
      [values removeAllObjects];
      [values addObject: newvalue];
      [self stateDidChange];
    }
  }
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
  NSMutableArray *values = [editorInfo objectForKey: @"values"];
  NSString *str = [valueField stringValue];

  if ([str length]) {    
    BOOL isfloat = ([attribute numberType] == NUM_FLOAT);   
    float newval = [str floatValue];
    NSString *oldstr;    
    
    if ([values count]) {
      oldstr = [values objectAtIndex: 0];
    } else {
      oldstr = (isfloat ? @"0.0" : @"0");
    } 
    
    if (newval != 0.0) {
      NSString *formstr = (isfloat ? @"%f" : @"%.0f");
      NSString *newstr = [NSString stringWithFormat: formstr, newval];
      
      if ([newstr isEqual: oldstr] == NO) {
        [values removeAllObjects];
        [values addObject: newstr];
        [self stateDidChange];
      }

    } else {
      [valueField setStringValue: oldstr];
    }
  } else {
    [values removeAllObjects];
    [self stateDidChange];
  }
}

@end


enum {
  LAST_DAY,
  LAST_2DAYS,
  LAST_3DAYS,
  LAST_WEEK,
  LAST_2WEEKS,
  LAST_3WEEKS,
  LAST_MONTH,
  LAST_2MONTHS,
  LAST_3MONTHS,
  LAST_6MONTHS
};

#define MINUTE_TI (60.0)
#define HOUR_TI   (MINUTE_TI * 60)
#define DAY_TI    (HOUR_TI * 24)
#define DAYS2_TI  (DAY_TI * 2)
#define DAYS3_TI  (DAY_TI * 3)
#define WEEK_TI   (DAY_TI * 7)
#define WEEK2_TI  (WEEK_TI * 2)
#define WEEK3_TI  (WEEK_TI * 3)
#define MONTH_TI  (DAY_TI * 30)
#define MONTH2_TI ((MONTH_TI * 2) + DAY_TI)
#define MONTH3_TI ((MONTH_TI * 3) + (DAY_TI * 1.5))
#define MONTH6_TI ((MONTH_TI * 6) + (DAY_TI * 3))

static NSString *calformat = @"%m %d %Y";

@implementation MDKDateEditor

- (void)dealloc
{
  [super dealloc];
}

- (id)initForAttribute:(MDKAttribute *)attr
              inWindow:(MDKWindow *)window
{
  self = [super initForAttribute: attr 
                        inWindow: window
                         nibName: @"MDKDateEditor"];
  
  if (self) {
    NSDateFormatter *formatter;
    int index;
        
    [dateStepper setMaxValue: MONTH6_TI];
    [dateStepper setMinValue: 0.0];
    [dateStepper setIncrement: 1.0];
    [dateStepper setAutorepeat: YES];
    [dateStepper setValueWraps: YES];

    [secondValueBox removeFromSuperview];

    stepperValue = MONTH3_TI;
    [dateStepper setDoubleValue: stepperValue];
    
    [dateField setDelegate: self];

    formatter = [[NSDateFormatter alloc] initWithDateFormat: calformat
                                       allowNaturalLanguage: NO];
    [[dateField cell] setFormatter: formatter];
    RELEASE (formatter);
    
    [valuesPopup removeAllItems];
    
    [valuesPopup addItemWithTitle: NSLocalizedString(@"the last day", @"")];
    [valuesPopup addItemWithTitle: NSLocalizedString(@"the last 2 days", @"")];
    [valuesPopup addItemWithTitle: NSLocalizedString(@"the last 3 days", @"")];
    [valuesPopup addItemWithTitle: NSLocalizedString(@"the last week", @"")];
    [valuesPopup addItemWithTitle: NSLocalizedString(@"the last 2 weeks", @"")];
    [valuesPopup addItemWithTitle: NSLocalizedString(@"the last 3 weeks", @"")];
    [valuesPopup addItemWithTitle: NSLocalizedString(@"the last month", @"")];
    [valuesPopup addItemWithTitle: NSLocalizedString(@"the last 2 months", @"")];
    [valuesPopup addItemWithTitle: NSLocalizedString(@"the last 3 months", @"")];
    [valuesPopup addItemWithTitle: NSLocalizedString(@"the last 6 months", @"")];
    [valuesPopup selectItemAtIndex: LAST_DAY]; 
    
    index = [operatorPopup indexOfItemWithTag: TODAY]; 
    [operatorPopup selectItemAtIndex: index];     
    [editorInfo setObject: [NSNumber numberWithInt: index]
                   forKey: @"opmenu_index"];    
  
    [editorInfo setObject: [NSNumber numberWithInt: LAST_DAY] 
                   forKey: @"valmenu_index"];      
  } 
  
  return self;
}

- (void)setDefaultValues:(NSDictionary *)info
{
  NSMutableArray *values = [editorInfo objectForKey: @"values"];
  NSCalendarDate *midnight = [self midnight];
  NSTimeInterval interval = [midnight timeIntervalSinceReferenceDate];
  NSString *datestr = [midnight descriptionWithCalendarFormat: calformat];  
  
  [super setDefaultValues: info];
  [values addObject: [NSString stringWithFormat: @"%f", interval]];
  [dateField setStringValue: datestr];
}

- (void)restoreSavedState:(NSDictionary *)info
{
  NSArray *values;

  [super restoreSavedState: info];
  
  values = [editorInfo objectForKey: @"values"];
  
  if (values && [values count]) {
    NSTimeInterval interval = [[values objectAtIndex: 0] floatValue];  
    NSCalendarDate *date = [NSCalendarDate dateWithTimeIntervalSinceReferenceDate: interval];
  
    [dateField setStringValue: [date descriptionWithCalendarFormat: calformat]];  
  }   
}

- (IBAction)operatorPopupAction:(id)sender
{
  int index = [sender indexOfSelectedItem];
  
  if (index != [[editorInfo objectForKey: @"opmenu_index"] intValue]) {
    int tag = [[sender selectedItem] tag];
    NSView *view = [editorBox contentView];
    NSArray *views = [view subviews];

    stateChangeLock++;
    [super operatorPopupAction: sender];

    if (tag == TODAY) {
      if ([views containsObject: secondValueBox]) {
        [secondValueBox removeFromSuperview];
      }
      if ([views containsObject: firstValueBox]) {
        [firstValueBox removeFromSuperview];
      }

      [valuesPopup selectItemAtIndex: LAST_DAY];     
      [self valuesPopupAction: valuesPopup];

    } else if (tag == WITHIN) {
      if ([views containsObject: secondValueBox]) {
        [secondValueBox removeFromSuperview];
      }
      if ([views containsObject: firstValueBox] == NO) {
        [view addSubview: firstValueBox];
      }

      [self valuesPopupAction: valuesPopup];

    } else if ((tag == BEFORE) || (tag == AFTER) || (tag == EXACTLY)) {
      if ([views containsObject: firstValueBox]) {
        [firstValueBox removeFromSuperview];
      } 
      if ([views containsObject: secondValueBox] == NO) {
        [view addSubview: secondValueBox];
      }
    }

    stateChangeLock--;
    [self stateDidChange]; 
  }   
}

- (IBAction)valuesPopupAction:(id)sender
{
  int index = [sender indexOfSelectedItem];
  NSMutableArray *values = [editorInfo objectForKey: @"values"];
  NSCalendarDate *midnight = [self midnight]; 
  NSTimeInterval interval = [midnight timeIntervalSinceReferenceDate] + DAY_TI;
  NSString *datestr;

  stateChangeLock++;  
  [super valuesPopupAction: sender];

  switch (index) {
    case LAST_DAY:
      interval -= DAY_TI;
      break;
    case LAST_2DAYS:
      interval -= DAYS2_TI;
      break;
    case LAST_3DAYS:
      interval -= DAYS3_TI;
      break;
    case LAST_WEEK:
      interval -= WEEK_TI;
      break;
    case LAST_2WEEKS:
      interval -= WEEK2_TI;
      break;
    case LAST_3WEEKS:
      interval -= WEEK3_TI;
      break;
    case LAST_MONTH:
      interval -= MONTH_TI;
      break;
    case LAST_2MONTHS:
      interval -= MONTH2_TI;
      break;
    case LAST_3MONTHS:
      interval -= MONTH3_TI;
      break;
    case LAST_6MONTHS:
      interval -= MONTH6_TI;
      break;
  }

  [values removeAllObjects];
  [values addObject: [NSString stringWithFormat: @"%f", interval]]; 

  midnight = [NSCalendarDate dateWithTimeIntervalSinceReferenceDate: interval];  
  datestr = [midnight descriptionWithCalendarFormat: calformat]; 
  [dateField setStringValue: datestr];

  stateChangeLock--;
  [self stateDidChange];   
}

- (IBAction)stepperAction:(id)sender
{
  NSString *str = [dateField stringValue];  

  if ([str length]) {
    NSCalendarDate *cdate = [NSCalendarDate dateWithString: str
                                            calendarFormat: calformat];
    if (cdate) {    
      double sv = [sender doubleValue];

      if (sv > stepperValue) {
        cdate = [cdate addTimeInterval: DAY_TI];
      } else if (sv < stepperValue) {
        cdate = [cdate addTimeInterval: -DAY_TI];
      }
      
      str = [cdate descriptionWithCalendarFormat: calformat];       
      [dateField setStringValue: str];

      stepperValue = sv; 
      [editorInfo setObject: [NSNumber numberWithFloat: stepperValue]
                     forKey: @"stepper_val"];    
      
      [self parseDateString: [dateField stringValue]];
    }
  } 
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
  [self parseDateString: [dateField stringValue]];
}

- (void)parseDateString:(NSString *)str
{
  if (str && [str length]) {
    NSCalendarDate *cdate = [NSCalendarDate dateWithString: str
                                            calendarFormat: calformat];
    if (cdate) { 
      NSMutableArray *values = [editorInfo objectForKey: @"values"];
      NSTimeInterval interval = [cdate timeIntervalSinceReferenceDate];
      NSString *intstr = [NSString stringWithFormat: @"%f", interval];
      BOOL sameval = ([values count] && [[values objectAtIndex: 0] isEqual: intstr]);
      
      if (sameval == NO) {
        [values removeAllObjects];
        [values addObject: intstr];           
        [self stateDidChange]; 
      }
    }
  }
}

- (NSCalendarDate *)midnight
{
  NSCalendarDate *midnight = [NSCalendarDate calendarDate];
  
  midnight = [NSCalendarDate dateWithYear: [midnight yearOfCommonEra]
                                    month: [midnight monthOfYear]
                                      day: [midnight dayOfMonth]
                                     hour: 0
                                   minute: 0
                                   second: 0
                                 timeZone: [midnight timeZone]];
  return midnight;
}

- (NSTimeInterval)midnightStamp
{
  return [[self midnight] timeIntervalSinceReferenceDate];
}

@end


@implementation MDKTextContentEditor

- (void)dealloc
{
  RELEASE (textContentWords);
  RELEASE (skipSet);
  
  [super dealloc];
}

- (id)initWithSearchField:(NSTextField *)field
                 inWindow:(MDKWindow *)window
{
  self = [super init];
  
  if (self) {
    NSCharacterSet *set;

    searchField = field;
    [searchField setDelegate: self];
    
    mdkwindow = window;
    
    ASSIGN (textContentWords, [NSArray array]);
    wordsChanged = NO;
    
    skipSet = [NSMutableCharacterSet new];

    set = [NSCharacterSet controlCharacterSet];
    [skipSet formUnionWithCharacterSet: set];

    set = [NSCharacterSet illegalCharacterSet];
    [skipSet formUnionWithCharacterSet: set];

    set = [NSCharacterSet symbolCharacterSet];
    [skipSet formUnionWithCharacterSet: set];

    set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    [skipSet formUnionWithCharacterSet: set];

    set = [NSCharacterSet characterSetWithCharactersInString: 
                                        @"~`@#$%^_-+\\{}:;\"\',/?"];
    [skipSet formUnionWithCharacterSet: set];  
  }
  
  return self;
}

#define WORD_MAX 40
#define WORD_MIN 3

- (void)controlTextDidChange:(NSNotification *)notif
{
  NSString *str = [searchField stringValue];

  wordsChanged = NO;
    
  if ([str length]) {
    CREATE_AUTORELEASE_POOL(arp);
    NSScanner *scanner = [NSScanner scannerWithString: str];
    NSMutableArray *words = [NSMutableArray array];
        
    while ([scanner isAtEnd] == NO) {
      NSString *word;
            
      if ([scanner scanUpToCharactersFromSet: skipSet intoString: &word]) {            
        if (word) {
          unsigned wl = [word length];

          if ((wl >= WORD_MIN) && (wl < WORD_MAX)) { 
            [words addObject: word];
          }
        }
      } else {
        break;
      }
    }

    if ([words count] && ([words isEqual: textContentWords] == NO)) {
      ASSIGN (textContentWords, words);
      wordsChanged = YES;
    }      
    
    RELEASE (arp);
    
  } else {
    ASSIGN (textContentWords, [NSArray array]);
    wordsChanged = YES;
  }

  if (wordsChanged) {
    [mdkwindow editorStateDidChange: self];
  }
}

- (void)setTextContentWords:(NSArray *)words
{
  ASSIGN (textContentWords, words);  
  [searchField setStringValue: [words componentsJoinedByString: @" "]];  
}

- (NSArray *)textContentWords
{
  return textContentWords;
}

- (BOOL)wordsChanged
{
  return wordsChanged;
}

@end


