/* FileOpsPref.h
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */


#ifndef FILE_OPS_PREF_H
#define FILE_OPS_PREF_H

#include <Foundation/NSObject.h>
  #ifdef GNUSTEP 
#include "PreferencesProtocol.h"
  #else
#include <GWorkspace/PreferencesProtocol.h>
  #endif

@class GWorkspace;

@interface FileOpsPref : NSObject <PreferencesProtocol>
{
  IBOutlet id win;
  IBOutlet id prefbox;
  IBOutlet id tabView;

  IBOutlet id statusItem;
  IBOutlet id statusBox;
  IBOutlet id statChooseButt;
  IBOutlet id statuslabel;
  IBOutlet id labelinfo1;
  IBOutlet id labelinfo2;
  IBOutlet id statActivButt;

  IBOutlet id confirmItem;
  IBOutlet id confirmBox;
  IBOutlet id confMatrix;
  IBOutlet id statusinfo1;
  IBOutlet id statusinfo2;
  IBOutlet id confActivButt;

  BOOL showstatus;
  GWorkspace *gw;  
}

- (IBAction)setUnsetStatWin:(id)sender;

- (IBAction)activateStatWinChanges:(id)sender;

- (IBAction)setUnsetFileOp:(id)sender;

- (IBAction)activateFileOpChanges:(id)sender;

@end

#endif // FILE_OPS_PREF_H
