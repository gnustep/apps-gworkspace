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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */


#ifndef DEF_SORTORDER_PREF_H
#define DEF_SORTORDER_PREF_H

#include <Foundation/NSObject.h>
  #ifdef GNUSTEP 
#include "PreferencesProtocol.h"
  #else
#include <GWorkspace/PreferencesProtocol.h>
  #endif

@class GWorkspace;

@interface DefSortOrderPref : NSObject <PreferencesProtocol>
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
