/* OpenUrlDlog.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
 *
 * This file is part of the GNUstep GWNet application
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

#ifndef OPEN_URL_DLOG_H
#define OPEN_URL_DLOG_H

#include <Foundation/Foundation.h>

@class NSMatrix;

@interface OpenUrlDlog : NSObject
{
  IBOutlet id win;
  IBOutlet id urlLabel;
  IBOutlet id urlField;
  
  IBOutlet id addButt;
    
  IBOutlet id scroll;
  NSMatrix *urlsMatrix;

  IBOutlet id buttRemove;
  
  IBOutlet id buttCancel;
  IBOutlet id buttOk;
    
  IBOutlet id loginWin;
  IBOutlet id userLabel;
  IBOutlet id userField;
  IBOutlet id passwdLabel;
  IBOutlet id passwdField;
  
  IBOutlet id buttCancelLogin;
  IBOutlet id buttOkLogin;
  
  int result;
  
  id gwnet;
}

- (void)chooseUrl;

- (int)runLoginDialogForHost:(NSString *)hostname;

- (NSString *)username;

- (NSString *)password;

- (IBAction)addButtAction:(id)sender;

- (void)matrixAction:(id)sender;

- (IBAction)removeAction:(id)sender;

- (IBAction)cancelAction:(id)sender;

- (IBAction)okAction:(id)sender;

- (IBAction)cancelLoginAction:(id)sender;

- (IBAction)okLoginAction:(id)sender;

- (id)urlsWin;

- (id)loginWin;

- (void)updateDefaults;

@end

#endif // OPEN_URL_DLOG_H
