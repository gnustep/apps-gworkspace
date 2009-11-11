/* OpenWithController.h
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


#import <Foundation/Foundation.h>

@class CompletionField;
@class NSBox;
@class NSWindow;
@class GWorkspace;

@interface OpenWithController : NSObject 
{
  IBOutlet id win;
  IBOutlet id firstLabel;
  IBOutlet id secondLabel;
  IBOutlet id cancelButt;
  IBOutlet id okButt;

  IBOutlet CompletionField *cfield;
  unsigned result;  
  
  NSArray *pathsArr;
  NSFileManager *fm;
  GWorkspace *gw;  
}

- (NSString *)checkCommand:(NSString *)comm;

- (void)activate;

- (NSWindow *)win;

- (IBAction)cancelButtAction:(id)sender;

- (IBAction)okButtAction:(id)sender;

- (void)completionFieldDidEndLine:(id)afield;

@end
