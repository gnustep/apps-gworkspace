/* RecyclerPrefs.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: June 2004
 *
 * This file is part of the GNUstep Recycler application
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

#ifndef RECYCLER_PREFS_H
#define RECYCLER_PREFS_H

#include <Foundation/Foundation.h>

@class Recycler;

@interface RecyclerPrefs: NSObject
{
  IBOutlet id win;
  IBOutlet id dockButt;
  IBOutlet id explLabel;
  
  Recycler *recycler;
}

- (IBAction)setDockable:(id)sender;

- (void)activate;

- (void)updateDefaults;

- (NSWindow *)win;

@end 

#endif // RECYCLER_PREFS_H
