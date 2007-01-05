/* MDKFSFilter.h
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

#ifndef MDK_FS_FILTER_H
#define MDK_FS_FILTER_H

#include <Foundation/Foundation.h>
#include "MDKQuery.h"
#include "MDKAttribute.h"
#include "FSNode.h"

@interface MDKFSFilter : NSObject 
{
  id srcvalue;
  MDKOperatorType optype;
}

+ (id)filterForAttribute:(MDKAttribute *)attr
            operatorType:(MDKOperatorType)type
             searchValue:(id)value;

- (id)initWithSearchValue:(id)value
             operatorType:(MDKOperatorType)type;

- (BOOL)filterNode:(FSNode *)node;

@end


@interface MDKFSFilterOwner : MDKFSFilter 

@end

@interface MDKFSFilterOwnerId : MDKFSFilter 
{
  int uid;
}

@end

@interface MDKFSFilterGroup : MDKFSFilter 

@end

@interface MDKFSFilterGroupId : MDKFSFilter 
{
  int gid;
}

@end

@interface MDKFSFilterSize : MDKFSFilter 
{
  unsigned long long fsize;
}

@end

@interface MDKFSFilterModDate : MDKFSFilter 
{
  NSTimeInterval midnight;
  NSTimeInterval nextMidnight;
}

@end

@interface MDKFSFilterCrDate : MDKFSFilter 
{
  NSTimeInterval midnight;
  NSTimeInterval nextMidnight;  
}

@end

#endif // MDK_FS_FILTER_H

