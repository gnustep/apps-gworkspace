/* Dispatcher.m
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

#include "Dispatcher.h"
#include "GNUstep.h"

@implementation Dispatcher

- (void)dealloc
{
  [nc removeObserver: self];  

  DESTROY (viewerConn);
  DESTROY (handler);
  DESTROY (handlerConn);
  
	[super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
    nc = [NSNotificationCenter defaultCenter];
  }
  
  return self;
}

- (void)handlerConnectionDidDie:(NSNotification *)notification
{
	id diedconn = [notification object];

  if (diedconn == handlerConn) {
    [nc removeObserver: self
	                name: NSConnectionDidDieNotification 
                object: handlerConn];
    NSLog(@"handler connection died", @"");
  }
}


//
// methods for the viewer
//
- (void)setViewer:(id)aViewer 
     handlerClass:(Class)aClass
       connection:(NSConnection *)aConnection
{
  NSPort *port[2];  
  NSArray *portArray;

  [aViewer setProtocolForProxy: @protocol(ViewerProtocol)];
  viewer = (id <ViewerProtocol>)aViewer;
  
  handler = nil;

  port[0] = (NSPort *)[NSPort port];
  port[1] = (NSPort *)[NSPort port];
  portArray = [NSArray arrayWithObjects: port[1], port[0], nil];

  handlerConn = [[NSConnection alloc] initWithReceivePort: (NSPort *)port[0]
                                                 sendPort: (NSPort *)port[1]];
  [handlerConn setRootObject: self];
  [handlerConn setDelegate: self];
  [handlerConn enableMultipleThreads];

  [nc addObserver: self 
				 selector: @selector(handlerConnectionDidDie:)
	    			 name: NSConnectionDidDieNotification 
           object: handlerConn];

  NS_DURING
  {
    [NSThread detachNewThreadSelector: @selector(connectWithPorts:)
                             toTarget: aClass
                           withObject: portArray];
  }
  NS_HANDLER
  {
    NSLog(@"Error! A fatal error occured while detaching the thread.");
  }
  NS_ENDHANDLER
}

- (oneway void)nextCommand:(NSData *)cmdinfo
{
  [handler _nextCommand: cmdinfo];
}

- (oneway void)startFileOperation:(NSData *)opinfo
{
  [handler _startFileOperation: opinfo];
}

- (oneway void)stopFileOperation:(NSData *)opinfo
{
  [handler _stopFileOperation: opinfo];
}

- (oneway void)unregister
{
  [handler _unregister];
  [NSThread exit];
}


//
// methods for the handler
//
- (void)_setHandler:(id)anObject
{
  [anObject setProtocolForProxy: @protocol(HandlerProtocol)];
  handler = (id <HandlerProtocol>)anObject;
  RETAIN (handler);
  [viewer setDispatcher: self];
  RELEASE (self);
}

- (oneway void)_replyToViewer:(NSData *)reply
{
  [viewer commandReplyReady: reply];  
}

- (oneway void)_fileOperationStarted:(NSData *)opinfo
{
  [viewer fileOperationStarted: opinfo];
}

- (oneway void)_fileOperationUpdated:(NSData *)opinfo
{
  [viewer fileOperationUpdated: opinfo];
}

- (oneway void)_fileTransferStarted:(NSData *)opinfo
{
  [viewer fileTransferStarted: opinfo];
}

- (oneway void)_fileTransferUpdated:(NSData *)opinfo
{
  [viewer fileTransferUpdated: opinfo];
}

- (BOOL)_fileOperationError:(NSData *)opinfo
{
  return [viewer fileOperationError: opinfo];
}

- (oneway void)_fileOperationDone:(NSData *)opinfo
{
  [viewer fileOperationDone: opinfo];
}

@end



