/* Dispatcher.h
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#ifndef DISPATCHER_H
#define DISPATCHER_H

#include <Foundation/Foundation.h>
#include "GWNet.h"

@interface Dispatcher: NSObject
{
  NSConnection *viewerConn;
  id viewer;
  
  NSConnection *handlerConn;
  id handler;

  NSNotificationCenter *nc;
}

- (void)handlerConnectionDidDie:(NSNotification *)notification;


//
// methods for the viewer
//
- (void)setViewer:(id)aViewer 
     handlerClass:(Class)aClass
       connection:(NSConnection *)aConnection;

- (oneway void)nextCommand:(NSData *)cmdinfo;

- (oneway void)startFileOperation:(NSData *)opinfo;

- (oneway void)stopFileOperation:(NSData *)opinfo;

- (oneway void)unregister;


//
// methods for the handler
//
- (void)_setHandler:(id)anObject;

- (oneway void)_replyToViewer:(NSData *)reply;

- (oneway void)_fileOperationStarted:(NSData *)opinfo;

- (oneway void)_fileOperationUpdated:(NSData *)opinfo;

- (oneway void)_fileTransferStarted:(NSData *)opinfo;

- (oneway void)_fileTransferUpdated:(NSData *)opinfo;

- (BOOL)_fileOperationError:(NSData *)opinfo;

- (oneway void)_fileOperationDone:(NSData *)opinfo;

@end

#endif // DISPATCHER_H

