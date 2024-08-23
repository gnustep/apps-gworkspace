/* HistoryPref.h
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: September 2004
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

#ifndef HISTORY_PREF_H
#define HISTORY_PREF_H

#include <Foundation/Foundation.h>
#include "PrefProtocol.h"

@interface HistoryPref : NSObject <PrefProtocol>
{
  IBOutlet id win;
  IBOutlet id prefbox;  
  IBOutlet id cacheBox;  
  IBOutlet id cacheField;
  IBOutlet id stepper;
  
  id gworkspace;
}

- (IBAction)stepperAction:(id)sender;

@end

#endif // HISTORY_PREF_H
