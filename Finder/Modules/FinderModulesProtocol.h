/* FinderModulesProtocol.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
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

#ifndef FINDER_MODULES_PROTOCOL_H
#define FINDER_MODULES_PROTOCOL_H

@protocol FinderModulesProtocol

- (id)initInterface;

- (id)initWithSearchCriteria:(NSDictionary *)criteria;

- (id)controls;

- (NSString *)moduleName;

- (BOOL)used;

- (void)setInUse:(BOOL)value;

- (int)index;

- (void)setIndex:(int)idx;

- (NSDictionary *)searchCriteria;

- (BOOL)checkPath:(NSString *)path 
   withAttributes:(NSDictionary *)attributes;

- (int)compareModule:(id <FinderModulesProtocol>)module;

- (BOOL)reliesOnModDate;

- (BOOL)reliesOnDirModDate;

@end 

#endif // FINDER_MODULES_PROTOCOL_H

