/* FileOperation.h
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

#ifndef FILE_OPERATION_H
#define FILE_OPERATION_H

#include <Foundation/Foundation.h>
#include "GWNet.h"

@interface FileOperation: NSObject
{
  id handler;
  NSDictionary *operationInfo;
  NSConnection *conn;
  id opexecutor;
  int ref;
  BOOL opdone;
  
  NSTimer *timer;
}

- (id)initWithOperationInfo:(NSDictionary *)info
                 forHandler:(id)hndl;

- (int)ref;

- (void)checkExecutor:(id)sender;

- (void)connectionDidDie:(NSNotification *)notification;

- (void)stopOperation;

- (void)registerFileOperation:(id)anObject;

- (void)fileOperationStarted:(NSData *)opinfo;

- (void)fileOperationUpdated:(NSData *)opinfo;

- (void)fileTransferStarted:(NSData *)opinfo;

- (void)fileTransferUpdated:(NSData *)opinfo;

- (BOOL)fileOperationError:(NSData *)opinfo;

- (oneway void)fileOperationDone:(NSData *)opinfo;

@end

#endif // FILE_OPERATION_H

