/* GWSDServerPref.h
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
 *
 * This file is part of the GNUstep GWRemote application
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

#ifndef GWSD_SERVER_PREF_H
#define GWSD_SERVER_PREF_H

#include <Foundation/NSObject.h>
#include "PreferencesProtocol.h"

@interface GWSDServerPref : NSObject <PreferencesProtocol>
{
  IBOutlet id win;
  IBOutlet id prefbox;
  IBOutlet id serverbox;    
  IBOutlet id popUp;
  IBOutlet id addButt;
  IBOutlet id removeButt;
  IBOutlet id nameField;  

  NSMutableArray *serversNames;
  NSString *serverName;
  id gwremote;  
}

- (IBAction)chooseServer:(id)sender;

- (IBAction)addServer:(id)sender;

- (IBAction)removeServer:(id)sender;

- (void)updateDefaults;

- (void)makePopUp;

@end

#endif // GWSD_SERVER_PREF_H
