/* RemoteTerminalView.h
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

#ifndef REMOTE_TERMINAL_VIEW
#define REMOTE_TERMINAL_VIEW

#include <Foundation/Foundation.h>
#include <AppKit/NSTextView.h>

@class NSString;
@class RemoteTerminal;

@interface RemoteTerminalView: NSTextView
{
  RemoteTerminal *terminal;
  NSString *prompt;
  NSDictionary *fontDict;
  long cursor;
}

- (id)initWithFrame:(NSRect)frame 
         inTerminal:(RemoteTerminal *)aTerminal
         remoteHost:(NSString *)hostname;

- (void)insertShellOutput:(NSString *)str;

@end

#endif // REMOTE_TERMINAL_VIEW

