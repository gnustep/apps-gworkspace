/* XTermPref.h
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


#ifndef XTERM_PREF_H
#define XTERM_PREF_H

#include <Foundation/Foundation.h>
#include "PrefProtocol.h"

@class GWorkspace;

@interface XTermPref : NSObject <PrefProtocol>
{
  IBOutlet id win;
  IBOutlet id prefbox;
  IBOutlet id fieldsBox;
  IBOutlet id xtermLabel;
  IBOutlet id argsLabel;
  IBOutlet id setButt;

  NSString *xterm;
  NSString *xtermArgs;
  GWorkspace *gw;  
}

- (IBAction)setXTerm:(id)sender;

@end

#endif // XTERM_PREF_H
