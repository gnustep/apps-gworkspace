/* ExecuteController.h
 *  
 * Copyright (C) 2003-2024 Free Software Foundation, Inc.
 *
 * Authors: Enrico Sersale
 *          Riccardo Mottola
 *
 * Date: July 2024
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

#ifndef EXECUTE_CONTROLLER_H
#define EXECUTE_CONTROLLER_H


#import <Foundation/Foundation.h>

@class CompletionField;
@class NSBox;
@class NSWindow;

@interface ExecuteController : NSObject 
{
  IBOutlet id win;
  IBOutlet NSTextField *titleLabel;
  IBOutlet id firstLabel;
  IBOutlet id secondLabel;
  IBOutlet id cancelButt;
  IBOutlet id okButt;

  IBOutlet CompletionField *cfield;
  NSInteger result;

  NSArray *pathsArr;
  NSFileManager *fm;
}

- (instancetype)initWithNibName:(NSString *)nibName NS_DESIGNATED_INITIALIZER;

- (NSString *)checkCommand:(NSString *)comm;

- (void)activate;

- (NSWindow *)win;

- (IBAction)cancelButtAction:(id)sender;

- (IBAction)okButtAction:(id)sender;

- (void)completionFieldDidEndLine:(id)afield;

@end

#endif
