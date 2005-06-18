/* SMBHandler.h
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

#ifndef SMB_HANDLER_H
#define SMB_HANDLER_H

#include <Foundation/Foundation.h>

@class SMBFileManager;

@interface SMBHandler: NSObject
{
  id dispatcher;

  NSString *hosturl;
  NSString *usrname;
  NSString *usrpass;
  
  SMBFileManager *manager;
    
  NSMutableDictionary *commandReply;
      
  NSMutableArray *fileOperations;
  int opindex;
}

+ (BOOL)canViewScheme:(NSString *)scheme;

+ (void)connectWithPorts:(NSArray *)portArray;

- (id)initWithDispatcheConnection:(NSConnection *)conn;

- (void)connectToHost:(NSString *)hostname
             userName:(NSString *)name
             password:(NSString *)passwd;

- (NSString *)hosturl;

- (id)dispatcher;

- (SMBFileManager *)manager;

- (oneway void)_unregister;

- (oneway void)_nextCommand:(NSData *)cmdinfo;

- (void)sendReplyToDispatcher;

- (void)contentsAt:(NSString *)path;

- (NSDictionary *)dummyAttributes;

- (oneway void)_startFileOperation:(NSData *)opinfo;

- (oneway void)_stopFileOperation:(NSData *)opinfo;

- (void)fileOperationTerminated:(id)op;

@end

#endif // SMB_HANDLER_H

