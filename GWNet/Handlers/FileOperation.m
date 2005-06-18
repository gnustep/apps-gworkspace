/* FileOperation.m
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

#include "FileOperation.h"
#include "FTPHandler.h"
#include "SMBHandler.h"
#include "GNUstep.h"

#ifndef LONG_DELAY
  #define LONG_DELAY 86400.0
#endif

@implementation FileOperation

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];

  if (timer && [timer isValid]) {
    [timer invalidate];
  }

  RELEASE (operationInfo);
  DESTROY (opexecutor);
	DESTROY (conn);

	[super dealloc];
}

- (id)initWithOperationInfo:(NSDictionary *)info
                 forHandler:(id)hndl
{
  self = [super init];
  
  if (self) {
    unsigned long hnfladdr;
    NSString *cmd;
	  NSString *connName;
    NSTask *task;
    NSMutableArray *taskargs;

    handler = hndl;
    hnfladdr = (unsigned long)hndl;
    ASSIGN (operationInfo, info);
    ref = [[info objectForKey: @"ref"] intValue];
    opexecutor = nil;
    opdone = NO;
    
    if ([handler isKindOfClass: [SMBHandler class]]) {
      connName = [NSString stringWithFormat: @"smb_fileop_ref_%i_%i", hnfladdr, ref];
      cmd = @"smbfileop";
    } else {
      connName = [NSString stringWithFormat: @"ftp_fileop_ref_%i_%i", hnfladdr, ref];
      cmd = @"ftpfileop";
    }

    conn = [[NSConnection alloc] initWithReceivePort: (NSPort *)[NSPort port] 
																			      sendPort: nil];
    [conn enableMultipleThreads];
    [conn setRootObject: self];
    [conn registerName: connName];
    [conn setRequestTimeout: LONG_DELAY];
    [conn setReplyTimeout: LONG_DELAY];
    [conn setDelegate: self];

    [[NSNotificationCenter defaultCenter] addObserver: self
                      selector: @selector(connectionDidDie:)
                          name: NSConnectionDidDieNotification
                        object: conn];    
    
    taskargs = [NSMutableArray array];
    [taskargs insertObject: [NSString stringWithFormat: @"%i", ref] atIndex: 0];
    [taskargs insertObject: [NSString stringWithFormat: @"%i", hnfladdr] atIndex: 1];

    task = [NSTask launchedTaskWithLaunchPath: cmd arguments: taskargs];

    timer = [NSTimer scheduledTimerWithTimeInterval: 5.0 target: self 
          										    selector: @selector(checkExecutor:) 
                                                  userInfo: nil repeats: NO];                                             
  }  
  
  return self;
}

- (int)ref
{
  return ref;
}

- (void)checkExecutor:(id)sender
{
  if ((opexecutor == nil) && (opdone == NO)) {  
    NSLog(@"cannot launch the opexecutor task");
    [conn registerName: nil];
    [handler fileOperationTerminated: self];
  } 
}

- (void)connectionDidDie:(NSNotification *)notification
{
	id diedconn = [notification object];
	
  if (diedconn == conn) {
    [[NSNotificationCenter defaultCenter] removeObserver: self
	                name: NSConnectionDidDieNotification 
                object: diedconn];
    NSLog(@"the opexecutor connection has been destroyed!");
    [handler fileOperationTerminated: self];
	} 
}

- (void)stopOperation
{
  [opexecutor stopOperation];
}

- (void)registerFileOperation:(id)anObject
{
  NSData *data = [NSArchiver archivedDataWithRootObject: operationInfo];

  [anObject setProtocolForProxy: @protocol(FileOpExecutorProtocol)];
  opexecutor = (id <FileOpExecutorProtocol>)anObject;
  RETAIN (opexecutor);

  [opexecutor setOperation: data];
  [opexecutor performOperation];
}

- (void)fileOperationStarted:(NSData *)opinfo
{
  [[handler dispatcher] _fileOperationStarted: opinfo];
}

- (void)fileOperationUpdated:(NSData *)opinfo
{
  [[handler dispatcher] _fileOperationUpdated: opinfo];
}

- (void)fileTransferStarted:(NSData *)opinfo
{
  [[handler dispatcher] _fileTransferStarted: opinfo];
}

- (void)fileTransferUpdated:(NSData *)opinfo
{
  [[handler dispatcher] _fileTransferUpdated: opinfo];
}

- (BOOL)fileOperationError:(NSData *)opinfo
{
  return [[handler dispatcher] _fileOperationError: opinfo];
}

- (oneway void)fileOperationDone:(NSData *)opinfo
{
  opdone = YES;
  [conn registerName: nil];
  [[handler dispatcher] _fileOperationDone: opinfo];
  [handler fileOperationTerminated: self];
}

@end














