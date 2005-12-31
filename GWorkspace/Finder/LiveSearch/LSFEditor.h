/* LSFEditor.h
 *  
 * Copyright (C) 2005 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2005
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

#ifndef LSF_EDITOR_H
#define LSF_EDITOR_H

#include <Foundation/Foundation.h>

@class NSMatrix;
@class LSFolder;
@class FindModuleView;

@interface LSFEditor : NSObject 
{
  IBOutlet id win;
  IBOutlet id searchLabel;
  IBOutlet NSScrollView *placesScroll;
  NSMatrix *placesMatrix;  
  IBOutlet id modulesLabel;
  IBOutlet NSBox *modulesBox;
  IBOutlet id recursiveSwitch;
  IBOutlet id cancelButt;
  IBOutlet id saveButt;

  NSMutableArray *modules;
  NSMutableArray *fmviews;

  id folder;
  id finder;
}

- (id)initForFolder:(id)fldr;

- (void)setModules;

- (void)activate;

- (NSArray *)modules;

- (NSArray *)usedModules;

- (id)firstUnusedModule;

- (id)moduleWithName:(NSString *)mname;

- (void)addModule:(FindModuleView *)aview;

- (void)removeModule:(FindModuleView *)aview;

- (void)findModuleView:(FindModuleView *)aview 
        changeModuleTo:(NSString *)mname;

- (IBAction)buttonsAction:(id)sender;

- (void)tile;

- (NSWindow *)win;

@end

#endif // LSF_EDITOR_H
