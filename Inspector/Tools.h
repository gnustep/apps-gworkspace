/* Tools.h
 *  
 * Copyright (C) 2004-2024 Free Software Foundation, Inc.
 *
 * Authors: Enrico Sersale
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
 * Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
 */

#ifndef TOOLS_H
#define TOOLS_H

#include <Foundation/Foundation.h>

@class NSMatrix;
@class NSTextField;
@class NSButton;
@class NSWorkspace;
@class IconView;

@interface Tools : NSObject
{
  IBOutlet NSWindow *win;
  IBOutlet NSBox *mainBox;
  IBOutlet NSBox *topBox;
  IBOutlet IconView *iconView;
  IBOutlet NSTextField *titleField;

  IBOutlet NSBox *toolsBox;  
  NSTextField *errLabel;

  IBOutlet id explLabel1;
  IBOutlet NSScrollView *scrollView;
  NSMatrix *matrix; 

  IBOutlet NSTextField *defAppLabel;
  IBOutlet NSTextField *defAppField;
  IBOutlet NSTextField *defPathLabel;
  IBOutlet NSTextField *defPathField;

  IBOutlet NSTextField *explLabel2;
  IBOutlet NSTextField *explLabel3;

  IBOutlet NSButton *okButt;

  NSArray *insppaths;
  NSString *currentApp;
  NSMutableArray *extensions;

  NSWorkspace *ws;
  
  id inspector;
}

- (instancetype)initForInspector:(id)insp;

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
