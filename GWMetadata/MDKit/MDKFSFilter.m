/* MDKFSFilter.m
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
#include "MDKFSFilter.h"

@implementation MDKFSFilter

- (void)dealloc
{
  TEST_RELEASE (srcvalue);
  [super dealloc];
}

+ (id)filterForAttribute:(MDKAttribute *)attr
            operatorType:(MDKOperatorType)type
             searchValue:(id)value
{
  Class filterclass = NSClassFromString([attr fsFilterClassName]);
  
  if (filterclass) {
    id filter = [[filterclass alloc] initWithSearchValue: value 
                                            operatorType: type];
    return AUTORELEASE (filter);
  } else 

  return nil;
}

- (id)initWithSearchValue:(id)value
             operatorType:(MDKOperatorType)type
{
  self = [super init];
  
  if (self) {  
    ASSIGN (srcvalue, value);
    optype = type;
  }

  return self;
}

- (BOOL)filterNode:(FSNode *)node
{
  [self subclassResponsibility: _cmd];
  return NO;
}

@end

@implementation MDKFSFilterOwner

- (BOOL)filterNode:(FSNode *)node
{
  NSString *owner = [node owner];

  switch (optype) {
    case MDKEqualToOperatorType:      
      return [srcvalue isEqual: owner];      
      break;

    case MDKNotEqualToOperatorType:      
      return ([srcvalue isEqual: owner] == NO);      
      break;
  
    default:
      break;
  }

  return NO;
}

@end


@implementation MDKFSFilterOwnerId

- (id)initWithSearchValue:(id)value
             operatorType:(MDKOperatorType)type
{
  self = [super initWithSearchValue: value operatorType: type];
  
  if (self) {  
    uid = [srcvalue intValue];
  }

  return self;
}

- (BOOL)filterNode:(FSNode *)node
{
  int ownerid = [[node ownerId] intValue];
  
  switch (optype) {
    case MDKEqualToOperatorType:      
      return (uid == ownerid);      
      break;

    case MDKNotEqualToOperatorType:      
      return (uid != ownerid);      
      break;
  
    default:
      break;
  }

  return NO;
}

@end


@implementation MDKFSFilterGroup

- (BOOL)filterNode:(FSNode *)node
{
  NSString *group = [node group];

  switch (optype) {
    case MDKEqualToOperatorType:      
      return [srcvalue isEqual: group];      
      break;

    case MDKNotEqualToOperatorType:      
      return ([srcvalue isEqual: group] == NO);      
      break;
  
    default:
      break;
  }

  return NO;
}

@end


@implementation MDKFSFilterGroupId

- (id)initWithSearchValue:(id)value
             operatorType:(MDKOperatorType)type
{
  self = [super initWithSearchValue: value operatorType: type];
  
  if (self) {  
    gid = [srcvalue intValue];
  }

  return self;
}

- (BOOL)filterNode:(FSNode *)node
{
  int groupid = [[node groupId] intValue];

  switch (optype) {
    case MDKEqualToOperatorType:      
      return (gid == groupid);      
      break;

    case MDKNotEqualToOperatorType:      
      return (gid != groupid);      
      break;
  
    default:
      break;
  }

  return NO;
}

@end


@implementation MDKFSFilterSize

- (id)initWithSearchValue:(id)value
             operatorType:(MDKOperatorType)type
{
  self = [super initWithSearchValue: value operatorType: type];
  
  if (self) {  
    fsize = (unsigned long long)[srcvalue intValue];
  }

  return self;
}

- (BOOL)filterNode:(FSNode *)node
{
  unsigned long long ndsize = ([node fileSize] >> 10);

  switch (optype) {
    case MDKLessThanOperatorType:
      return (ndsize < fsize);      
      break;
  
    case MDKEqualToOperatorType:      
      return (ndsize == fsize);      
      break;

    case MDKGreaterThanOperatorType:      
      return (ndsize > fsize);      
      break;
  
    default:
      break;
  }

  return NO;
}

@end


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

@implementation MDKFSFilterModDate

- (id)initWithSearchValue:(id)value
             operatorType:(MDKOperatorType)type
{
  self = [super initWithSearchValue: value operatorType: type];
  
  if (self) {  
    midnight = [srcvalue floatValue];
    nextMidnight = midnight + DAY_TI;
  }

  return self;
}

- (BOOL)filterNode:(FSNode *)node
{
  NSDate *moddate = [node modificationDate];
  NSTimeInterval modint = [moddate timeIntervalSinceReferenceDate];

  switch (optype) {
    case MDKGreaterThanOrEqualToOperatorType:      
      return (modint >= midnight);      
      break;

    case MDKLessThanOperatorType:      
      return (modint < midnight);      
      break;
  
    case MDKGreaterThanOperatorType:      
      return (modint >= nextMidnight);      
      break;
  
    case MDKEqualToOperatorType:      
      return ((modint >= midnight) && (modint < nextMidnight));      
      break;
  
    default:
      break;
  }

  return NO;
}

@end


@implementation MDKFSFilterCrDate

- (id)initWithSearchValue:(id)value
             operatorType:(MDKOperatorType)type
{
  self = [super initWithSearchValue: value operatorType: type];
  
  if (self) {  
    midnight = [srcvalue floatValue];
    nextMidnight = midnight + DAY_TI;
  }

  return self;
}

- (BOOL)filterNode:(FSNode *)node
{
  NSDate *crdate = [node creationDate];
  NSTimeInterval crint = [crdate timeIntervalSinceReferenceDate];

  switch (optype) {
    case MDKGreaterThanOrEqualToOperatorType:      
      return (crint >= midnight);      
      break;

    case MDKLessThanOperatorType:      
      return (crint < midnight);      
      break;
  
    case MDKGreaterThanOperatorType:      
      return (crint >= nextMidnight);      
      break;
  
    case MDKEqualToOperatorType:      
      return ((crint >= midnight) && (crint < nextMidnight));      
      break;
  
    default:
      break;
  }
  
  return NO;
}

@end






















