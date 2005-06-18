/* DefSortOrderPref.h
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
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


#ifndef DEF_SORTORDER_PREF_H
#define DEF_SORTORDER_PREF_H

#include <Foundation/Foundation.h>
#include "PrefProtocol.h"

@class GWorkspace;

@interface DefSortOrderPref : NSObject <PrefProtocol>
{
  IBOutlet id win;
  IBOutlet id prefbox;  
  IBOutlet id selectbox;  
  IBOutlet id matrix;
  IBOutlet id sortinfo1;
  IBOutlet id sortinfo2;  
  IBOutlet id setButt;

	int sortType;	
}

- (IBAction)changeType:(id)sender;

- (IBAction)setNewSortType:(id)sender;

@end

#endif // DEF_SORTORDER_PREF_H
