/* Tools.h
 *  
 * Copyright (C) 2004-2021 Free Software Foundation, Inc.
 *
 * Authors: Enrico Sersale <enrico@imago.ro>
 *          Riccardo Mottola
 * Date: January 2004
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

#ifndef TOOLS_H
#define TOOLS_H

#include <Foundation/Foundation.h>

@class NSMatrix;
@class NSTextField;
@class NSWorkspace;

@interface Tools : NSObject
{
  IBOutlet id win;
  IBOutlet id mainBox;
  IBOutlet id topBox;
  IBOutlet id iconView;
  IBOutlet id titleField;

  IBOutlet id toolsBox;  
  NSTextField *errLabel;

  IBOutlet id explLabel1;
  IBOutlet NSScrollView *scrollView;
  NSMatrix *matrix; 

  IBOutlet id defAppLabel;
  IBOutlet id defAppField;
  IBOutlet id defPathLabel;
  IBOutlet id defPathField;

  IBOutlet id explLabel2;
  IBOutlet id explLabel3;

  IBOutlet id okButt;

	NSArray *insppaths;
  NSString *currentApp;
  NSMutableArray *extensions;

  NSWorkspace *ws;
  
  id inspector;
}

- (id)initForInspector:(id)insp;

- (NSView *)inspView;

- (NSString *)winname;

- (void)activateForPaths:(NSArray *)paths;

- (BOOL)findApplicationsForPaths:(NSArray *)paths;

- (IBAction)setDefaultApplication:(id)sender;

- (void)setCurrentApplication:(id)sender;

- (void)openFile:(id)sender;

- (void)watchedPathDidChange:(NSDictionary *)info;

@end

#endif // TOOLS_H
