/* OperationPrefs.h
 *  
 * Copyright (C) 2004-2016 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
 *
 * This file is part of the GNUstep Operation application
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

#ifndef OPERATION_PREFS_H
#define OPERATION_PREFS_H

#import <Foundation/Foundation.h>
#import "PrefProtocol.h"

@interface OperationPrefs : NSObject <PrefProtocol>
{
  IBOutlet id win;
  IBOutlet id prefbox;
  IBOutlet id tabView;

  NSTabViewItem *statusItem;
  IBOutlet id statusBox;
  IBOutlet id statChooseButt;
  IBOutlet id statuslabel;
  IBOutlet id statusinfo1;
  IBOutlet id statusinfo2;

  NSTabViewItem *confirmItem;
  IBOutlet id confirmBox;
  IBOutlet id confMatrix;
  IBOutlet id labelinfo1;
  IBOutlet id labelinfo2;

  BOOL showstatus;
}

- (IBAction)setUnsetStatWin:(id)sender;

- (IBAction)setUnsetFileOp:(id)sender;

@end

#endif // OPERATION_PREFS_H
