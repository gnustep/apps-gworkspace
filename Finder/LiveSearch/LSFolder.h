/* LSFolder.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: October 2004
 *
 * This file is part of the GNUstep Finder application
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#ifndef LS_FOLDER_H
#define LS_FOLDER_H

#include <Foundation/Foundation.h>
#include "FSNodeRep.h"

//@class Finder;

@interface LSFolder : NSObject 
{
  FSNode *node;

  NSArray *searchPaths;
  NSDictionary *searchCriteria;
  NSMutableArray *foundPaths;
  NSDate *lastUpdate;

  id finder;
  BOOL watcherSuspended;
}

- (id)initForNode:(FSNode *)anode
     contentsInfo:(NSDictionary *)info;

- (void)setNode:(FSNode *)anode;

- (FSNode *)node;

- (BOOL)watcherSuspended;

- (void)setWatcherSuspended:(BOOL)value;

@end

#endif // LS_FOLDER_H
