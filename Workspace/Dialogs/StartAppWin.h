/* StartAppWin.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
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

#ifndef START_APP_WIN
#define START_APP_WIN

#include <Foundation/Foundation.h>

@interface StartAppWin: NSObject
{
  IBOutlet id win;
  IBOutlet id startLabel;
  IBOutlet id nameField;
  IBOutlet id progInd;
}
                 
- (void)showWindowWithTitle:(NSString *)title
                    appName:(NSString *)appname
                  operation:(NSString *)operation              
               maxProgValue:(double)maxvalue;

- (void)updateProgressBy:(double)incr;

- (NSWindow *)win;

@end 

#endif // START_APP_WIN
