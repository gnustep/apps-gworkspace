/* ShellTask.m
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
 *
 * This file is part of the GNUstep gwsd tool
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

#ifndef SHELL_TASK_H
#define SHELL_TASK_H

#include <Foundation/NSObject.h>

@class NSString;
@class NSTask;
@class NSFileHandle;
@class NSNumber;
@class NSNotificationCenter;
@class NSNotification;
@class GWSd;

@interface ShellTask : NSObject
{
  NSString *shellPath;
  NSTask *task;  
  NSNotificationCenter *nc;
  GWSd *gwsd;
  id gwsdClient;  
  NSNumber *ref;
}

- (id)initWithShellCommand:(NSString *)cmd
                    onPath:(NSString *)apath
                   forGWSd:(GWSd *)gw
                withClient:(id)client
                 refNumber:(NSNumber *)refn;

- (void)stopTask;

- (void)newCommandLine:(NSString *)line;

- (void)taskOut:(NSNotification *)notif;

- (void)taskErr:(NSNotification *)notif;

- (void)endOfTask:(NSNotification *)notif;

- (NSNumber *)refNumber;

@end

#endif // SHELL_TASK_H

