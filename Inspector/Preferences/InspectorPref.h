/* InspectorPref.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
 *
 * This file is part of the GNUstep Inspector application
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

#ifndef INSPECTOR_PREF
#define INSPECTOR_PREF

#include <Foundation/Foundation.h>

@class NSMatrix;

@interface InspectorPref: NSObject
{
  IBOutlet id win;
  IBOutlet id scroll;
  NSMatrix *matrix;
  IBOutlet id descrLabel;
  IBOutlet id descrView;
  IBOutlet id locLabel;
  IBOutlet id locField;
  IBOutlet id extLabel;
  IBOutlet id extField;
  IBOutlet id nameLabel;
  IBOutlet id nameField;
  IBOutlet id changeButt;
  IBOutlet id cancelButt;
  BOOL savemode;
  id inspector;
}

- (id)initForInspector:(id)insp;
                 
- (void)activate;

- (void)setSaveMode:(BOOL)mode;

- (void)addViewer:(id)viewer;

- (void)removeViewer:(id)viewer;

- (void)removeAllViewers;

- (void)matrixAction:(id)sender;

- (IBAction)buttonAction:(id)sender;

- (void)updateDefaults;

- (NSWindow *)win;

@end 

#endif // INSPECTOR_PREF
