/* FModuleCrDate.m
 *  
 * Copyright (C) 2004-2016 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
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

#include <math.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "FinderModulesProtocol.h"

static NSString *nibName = @"FModuleCrDate";

@interface FModuleCrDate : NSObject <FinderModulesProtocol>
{  
  IBOutlet id win;
  IBOutlet NSBox *controlsBox;
  IBOutlet id isPopUp;
  IBOutlet id whenPopUp;
  IBOutlet id dateField;
  IBOutlet id dateStepper;
  double stepperValue;
  NSInteger index;
  BOOL used;

  NSFileManager *fm;
  NSCalendarDate *date;
  NSTimeInterval interval;
  NSInteger how;
}

- (IBAction)popUpAction:(id)sender; 

- (IBAction)stepperAction:(id)sender; 

@end

@implementation FModuleCrDate

#define TODAY   0
#define WITHIN  1
#define BEFORE  2
#define AFTER   3
#define EXACTLY 4

#define LAST_DAY     0
#define LAST_2DAYS   1
#define LAST_3DAYS   2
#define LAST_WEEK    3
#define LAST_2WEEKS  4
#define LAST_3WEEKS  5
#define LAST_MONTH   6
#define LAST_2MONTHS 7
#define LAST_3MONTHS 8
#define LAST_6MONTHS 9

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

- (void)dealloc
{
  RELEASE (controlsBox);
  RELEASE (whenPopUp);
  RELEASE (dateField);
  RELEASE (dateStepper); 
  RELEASE (date);
  [super dealloc];
}

- (id)initInterface
{
	self = [super init];

  if (self) {
    NSDateFormatter *formatter;
    NSRect r;
    
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
      DESTROY (self);
      return self;
    }

    RETAIN (controlsBox);
    RELEASE (win);

    used = NO;
    index = 0;
    
    [dateField setStringValue: @""];
    r = [dateField frame];
    r.origin.y = 0;
    [dateField setFrame: r];
    
    r = [dateStepper frame];
    r.origin.y = 0;
    [dateStepper setFrame: r];
    [dateStepper setMaxValue: MONTH6_TI];
    [dateStepper setMinValue: 0];
    [dateStepper setIncrement: 1];
    [dateStepper setAutorepeat: YES];
    [dateStepper setValueWraps: YES];
    
    stepperValue = MONTH3_TI;
    [dateStepper setDoubleValue: stepperValue];
    
    RETAIN (whenPopUp);
    RETAIN (dateField);
    RETAIN (dateStepper);
    
    [whenPopUp removeFromSuperview];
    
    formatter = [[NSDateFormatter alloc] initWithDateFormat: @"%m %d %Y"
                                       allowNaturalLanguage: NO];
    [[dateField cell] setFormatter: formatter];
    RELEASE (formatter);
    
    /* Internationalization */    
    [isPopUp removeAllItems];
    [isPopUp insertItemWithTitle: NSLocalizedString(@"is today", @"") atIndex: TODAY];
    [isPopUp insertItemWithTitle: NSLocalizedString(@"is within", @"") atIndex: WITHIN];
    [isPopUp insertItemWithTitle: NSLocalizedString(@"is before", @"") atIndex: BEFORE];
    [isPopUp insertItemWithTitle: NSLocalizedString(@"is after", @"") atIndex: AFTER];
    [isPopUp insertItemWithTitle: NSLocalizedString(@"is exactly", @"") atIndex: EXACTLY];
    [isPopUp selectItemAtIndex: TODAY]; 

    [whenPopUp removeAllItems];
    [whenPopUp insertItemWithTitle: NSLocalizedString(@"the last day", @"") atIndex: LAST_DAY];
    [whenPopUp insertItemWithTitle: NSLocalizedString(@"the last 2 days", @"") atIndex: LAST_2DAYS];
    [whenPopUp insertItemWithTitle: NSLocalizedString(@"the last 3 days", @"") atIndex: LAST_3DAYS];
    [whenPopUp insertItemWithTitle: NSLocalizedString(@"the last week", @"") atIndex: LAST_WEEK];
    [whenPopUp insertItemWithTitle: NSLocalizedString(@"the last 2 weeks", @"") atIndex: LAST_2WEEKS];
    [whenPopUp insertItemWithTitle: NSLocalizedString(@"the last 3 weeks", @"") atIndex: LAST_3WEEKS];
    [whenPopUp insertItemWithTitle: NSLocalizedString(@"the last month", @"") atIndex: LAST_MONTH];
    [whenPopUp insertItemWithTitle: NSLocalizedString(@"the last 2 months", @"") atIndex: LAST_2MONTHS];
    [whenPopUp insertItemWithTitle: NSLocalizedString(@"the last 3 months", @"") atIndex: LAST_3MONTHS];
    [whenPopUp insertItemWithTitle: NSLocalizedString(@"the last 6 months", @"") atIndex: LAST_6MONTHS];
    [whenPopUp selectItemAtIndex: LAST_DAY]; 
  }
  
  return self;
}

- (id)initWithSearchCriteria:(NSDictionary *)criteria
                  searchTool:(id)tool
{
	self = [super init];

  if (self) {
    how = [[criteria objectForKey: @"how"] intValue];

    if ((how == TODAY) || (how == WITHIN)) {
      interval = [[criteria objectForKey: @"limit"] doubleValue];
    } else {
      ASSIGN (date, [criteria objectForKey: @"date"]);
    }
    
    fm = [NSFileManager defaultManager];
  }
  
	return self;
}

- (IBAction)popUpAction:(id)sender
{
  if (sender == isPopUp) {
    NSInteger idx = [sender indexOfSelectedItem];
    NSView *view = [controlsBox contentView];
    NSArray *views = [view subviews];

    if (idx == TODAY) {
      if ([views containsObject: dateField]) {
        [dateField removeFromSuperview];
        [dateStepper removeFromSuperview];
      }
      if ([views containsObject: whenPopUp]) {
        [whenPopUp removeFromSuperview];
      }
      
    } else if (idx == WITHIN) {
      if ([views containsObject: dateField]) {
        [dateField removeFromSuperview];
        [dateStepper removeFromSuperview];
      }
      if ([views containsObject: whenPopUp] == NO) {
        [view addSubview: whenPopUp];
      }
      
    } else if ((idx == BEFORE) || (idx == AFTER) || (idx == EXACTLY)) {
      if ([views containsObject: whenPopUp]) {
        [whenPopUp removeFromSuperview];
      }

      if ([views containsObject: dateField] == NO) {
        NSCalendarDate *cdate = [NSCalendarDate calendarDate];
        int month = [cdate monthOfYear];
        int day = [cdate dayOfMonth];
        int year = [cdate yearOfCommonEra];
        NSString *str = [NSString stringWithFormat: @"%i %i %i", month, day, year];
      
        [view addSubview: dateField];
        [dateField setStringValue: str];
        [view addSubview: dateStepper];
      }
    }
  }
}

- (IBAction)stepperAction:(id)sender
{
  NSString *str = [dateField stringValue];  

  if ([str length]) {
    NSCalendarDate *cdate = [NSCalendarDate dateWithString: str
                                            calendarFormat: @"%m %d %Y"];
    if (cdate) {   
      double sv = [sender doubleValue];
      int month, day, year;
    
      if (sv > stepperValue) {
        cdate = [cdate addTimeInterval: DAY_TI];
      } else if (sv < stepperValue) {
        cdate = [cdate addTimeInterval: -DAY_TI];
      }
    
      month = [cdate monthOfYear];
      day = [cdate dayOfMonth];
      year = [cdate yearOfCommonEra];    

      str = [NSString stringWithFormat: @"%i %i %i", month, day, year];
      [dateField setStringValue: str];

      stepperValue = sv;
    }
  } 
}

- (void)setControlsState:(NSDictionary *)info
{
  NSNumber *num = [info objectForKey: @"how"];
  
  if (num) {
    NSInteger idx = [num integerValue];

    [isPopUp selectItemAtIndex: idx];
    [self popUpAction: isPopUp];

    if (idx == WITHIN) {
      NSNumber *limnum = [info objectForKey: @"limit"];
      int whenidx = 0;

      if (limnum) {
        double limit = [limnum doubleValue];
      
        if (limit == DAY_TI) {
          whenidx = LAST_DAY;
        } else if (limit == DAYS2_TI) {
          whenidx = LAST_2DAYS;
        } else if (limit == DAYS3_TI) {
          whenidx = LAST_3DAYS;
        } else if (limit == WEEK_TI) {
          whenidx = LAST_WEEK;
        } else if (limit == WEEK2_TI) {
          whenidx = LAST_2WEEKS;
        } else if (limit == WEEK3_TI) {
          whenidx = LAST_3WEEKS;
        } else if (limit == MONTH_TI) {
          whenidx = LAST_MONTH;
        } else if (limit == MONTH2_TI) {
          whenidx = LAST_2MONTHS;
        } else if (limit == MONTH3_TI) {
          whenidx = LAST_3MONTHS;
        } else if (limit == MONTH6_TI) {
          whenidx = LAST_6MONTHS;
        } 
      }

      [whenPopUp selectItemAtIndex: whenidx];
    
    } else if ((idx == BEFORE) || (idx == AFTER) || (idx == EXACTLY)) {
      NSCalendarDate *cdate = [info objectForKey: @"date"];

      if (cdate) {
        int month = [cdate monthOfYear];
        int day = [cdate dayOfMonth];
        int year = [cdate yearOfCommonEra];
        NSString *str = [NSString stringWithFormat: @"%i %i %i", month, day, year];
      
        [dateField setStringValue: str];
      }
    }    
  }  
}

- (id)controls
{
  return controlsBox;
}

- (NSString *)moduleName
{
  return NSLocalizedString(@"date created", @"");
}

- (BOOL)used
{
  return used;
}

- (void)setInUse:(BOOL)value
{
  used = value;
}

- (NSInteger)index
{
  return index;
}

- (void)setIndex:(NSInteger)idx
{
  index = idx;
}

- (NSDictionary *)searchCriteria
{
  NSMutableDictionary *criteria = [NSMutableDictionary dictionary];
  NSCalendarDate *cdate = [NSCalendarDate calendarDate];
  NSTimeInterval limit = 0.0;
  NSInteger idx = [isPopUp indexOfSelectedItem];
  
  if (idx == TODAY) {
    NSCalendarDate *midnight;

    midnight = [NSCalendarDate dateWithYear: [cdate yearOfCommonEra]
                                      month: [cdate monthOfYear]
                                        day: [cdate dayOfMonth]
                                       hour: 0
                                     minute: 0
                                     second: 0
                                   timeZone: [cdate timeZone]];
    
    limit = [midnight timeIntervalSinceNow];
         
  } else if (idx == WITHIN) {
    int when = [whenPopUp indexOfSelectedItem];

    switch(when) {
      case LAST_DAY:
        limit = DAY_TI;
        break;
      case LAST_2DAYS:
        limit = DAYS2_TI;
        break;
      case LAST_3DAYS:
        limit = DAYS3_TI;
        break;
      case LAST_WEEK:
        limit = WEEK_TI;
        break;
      case LAST_2WEEKS:
        limit = WEEK2_TI;
        break;
      case LAST_3WEEKS:
        limit = WEEK3_TI;
        break;
      case LAST_MONTH:
        limit = MONTH_TI;
        break;
      case LAST_2MONTHS:
        limit = MONTH2_TI;
        break;
      case LAST_3MONTHS:
        limit = MONTH3_TI;
        break;
      case LAST_6MONTHS:
        limit = MONTH6_TI;
        break;
    }
      
  } else if ((idx == BEFORE) || (idx == AFTER) || (idx == EXACTLY)) {
    NSString *str = [dateField stringValue];  

    if ([str length]) { 
      cdate = [NSCalendarDate dateWithString: str
                              calendarFormat: @"%m %d %Y"];
    }  
  }

  [criteria setObject: [NSNumber numberWithDouble: limit] forKey: @"limit"];
  [criteria setObject: cdate forKey: @"date"];
  [criteria setObject: [NSNumber numberWithInt: idx] forKey: @"how"];

  return criteria;
}

- (BOOL)checkPath:(NSString *)path 
   withAttributes:(NSDictionary *)attributes
{
  NSDate *cd = [attributes fileCreationDate];

  if (how == TODAY) {
    return (interval <= [cd timeIntervalSinceNow]);

  } else if (how == WITHIN) {
    return (fabs([cd timeIntervalSinceNow]) <= interval);

  } else if ((how == BEFORE) || (how == AFTER) || (how == EXACTLY)) {      
    NSCalendarDate *cdate = [cd dateWithCalendarFormat: [date calendarFormat] 
                                              timeZone: [date timeZone]];

    if (how == BEFORE) { 
      if ([[date earlierDate: cd] isEqualToDate: cd]) {
        return ([cdate dayOfMonth] != [date dayOfMonth]);
      }

    } else if (how == AFTER) { 
      if ([[date earlierDate: cd] isEqualToDate: date]) {
        return ([cdate dayOfMonth] != [date dayOfMonth]);
      }

    } else if (how == EXACTLY) {
      if (fabs([cd timeIntervalSinceDate: date]) < DAY_TI) {
        return ([cdate dayOfMonth] == [date dayOfMonth]);
      }  
    }
  }    
  
  return NO;
}

- (NSComparisonResult)compareModule:(id <FinderModulesProtocol>)module
{
  NSInteger i1 = [self index];
  NSInteger i2 = [module index];

  if (i1 < i2) {
    return NSOrderedAscending;
  } else if (i1 > i2) {
    return NSOrderedDescending;
  } 

  return NSOrderedSame;
}

- (BOOL)reliesOnModDate
{
  return NO;
}

- (BOOL)metadataModule
{
  return NO;
}

@end
