/* FTPHandler.h
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

#ifndef FTP_HANDLER_H
#define FTP_HANDLER_H

#include <Foundation/Foundation.h>

@interface FTPHandler: NSObject
{
  id dispatcher;

  NSString *hostname;
  NSString *usrname;
  NSString *usrpass;
  
  NSFileHandle *sockHandle;
  BOOL usePasv;
    
  NSTimer *tmoutTimer;
  int timeout;
  BOOL waitingReply;
  BOOL repTimeout;
  
  NSString *currentComm;  
  NSMutableDictionary *commandReply;
    
  NSMutableArray *fileOperations;
  int opindex;
}

+ (BOOL)canViewScheme:(NSString *)scheme;

+ (void)connectWithPorts:(NSArray *)portArray;

- (id)initWithDispatcheConnection:(NSConnection *)conn;

- (void)connectToHostWithName:(NSString *)hname
                     userName:(NSString *)name
                     password:(NSString *)passwd
                      timeout:(int)tmout;

- (NSString *)hostname;

- (id)dispatcher;

- (oneway void)_unregister;

- (void)checkTimeout:(id)sender;

- (int)sendCommand:(NSString *)str 
         withParam:(NSString *)param
          getError:(NSString **)errstr; 

- (int)getReply:(NSString **)errstr;

- (NSString *)readControlLine;

- (void)flushControlLine:(NSString *)codestr;

- (NSFileHandle *)getDataHandle;

- (NSFileHandle *)fileHandleForConnectingAtPort:(unsigned)port;

- (NSFileHandle *)fileHandleForWithLocalPort;

- (NSData *)readDataFrom:(NSFileHandle *)handle;

- (NSString *)readStringFrom:(NSFileHandle *)handle;

- (oneway void)_nextCommand:(NSData *)cmdinfo;

- (void)doList:(NSString *)path;

- (void)sendReplyToDispatcher;

- (oneway void)_startFileOperation:(NSData *)opinfo;

- (oneway void)_stopFileOperation:(NSData *)opinfo;

- (void)fileOperationTerminated:(id)op;

@end

#endif // FTP_HANDLER_H

