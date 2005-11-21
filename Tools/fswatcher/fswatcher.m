/* fswatcher.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: February 2004
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

#include "fswatcher.h"
#include "GNUstep.h"

@implementation	FSWClientInfo

- (void)dealloc
{
	TEST_RELEASE (conn);
	TEST_RELEASE (client);
  RELEASE (wpaths);
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
		client = nil;
		conn = nil;
    wpaths = [[NSCountedSet alloc] initWithCapacity: 1];
    global = NO;
  }
  
  return self;
}

- (void)setConnection:(NSConnection *)connection
{
	ASSIGN (conn, connection);
}

- (NSConnection *)connection
{
	return conn;
}

- (void)setClient:(id <FSWClientProtocol>)clnt
{
	ASSIGN (client, clnt);
}

- (id <FSWClientProtocol>)client
{
	return client;
}

- (void)addWatchedPath:(NSString *)path
{
  [wpaths addObject: path];
}

- (void)removeWatchedPath:(NSString *)path
{
  [wpaths removeObject: path];
}

- (BOOL)isWathchingPath:(NSString *)path
{
  return [wpaths containsObject: path];
}

- (NSSet *)watchedPaths
{
  return wpaths;
}

- (void)setGlobal:(BOOL)value
{
  global = value;
}

- (BOOL)isGlobal
{
  return global;
}

@end


@implementation	FSWatcher

- (void)dealloc
{
  NSEnumerator *enumerator = [clientsInfo objectEnumerator];
  FSWClientInfo *info;
  
  while ((info = [enumerator nextObject])) {
    NSConnection *connection = [info connection];

		if (connection) {
      [nc removeObserver: self
		                name: NSConnectionDidDieNotification
		              object: connection];
		}
  }
  
  if (conn) {
    [nc removeObserver: self
		              name: NSConnectionDidDieNotification
		            object: conn];
    DESTROY (conn);
  }
  
  RELEASE (clientsInfo);
  RELEASE (watchers);

  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {    
    fm = [NSFileManager defaultManager];	
    nc = [NSNotificationCenter defaultCenter];
    
    clientsInfo = [[NSMutableSet alloc] initWithCapacity: 1];
    
    watchers = [[NSMutableSet alloc] initWithCapacity: 1];

    conn = [NSConnection defaultConnection];
    [conn setRootObject: self];
    [conn setDelegate: self];

    if ([conn registerName: @"fswatcher"] == NO) {
	    NSLog(@"unable to register with name server - quiting.");
	    DESTROY (self);
	    return self;
	  }
      
    [nc addObserver: self
           selector: @selector(connectionBecameInvalid:)
	             name: NSConnectionDidDieNotification
	           object: conn];
  }
  
  return self;    
}

- (BOOL)connection:(NSConnection *)ancestor
            shouldMakeNewConnection:(NSConnection *)newConn;
{
  FSWClientInfo *info = [FSWClientInfo new];
	      
  [info setConnection: newConn];
  [clientsInfo addObject: info];
  RELEASE (info);

  [nc addObserver: self
         selector: @selector(connectionBecameInvalid:)
	           name: NSConnectionDidDieNotification
	         object: newConn];
           
  [newConn setDelegate: self];
  
  return YES;
}

- (void)connectionBecameInvalid:(NSNotification *)notification
{
  id connection = [notification object];

  [nc removeObserver: self
	              name: NSConnectionDidDieNotification
	            object: connection];

  if (connection == conn) {
    NSLog(@"argh - fswatcher server root connection has been destroyed.");
    exit(EXIT_FAILURE);
    
  } else {
		FSWClientInfo *info = [self clientInfoWithConnection: connection];
	
		if (info) {
      NSSet *wpaths = [info watchedPaths];
      NSEnumerator *enumerator = [wpaths objectEnumerator];
      NSString *wpath;
      
      while ((wpath = [enumerator nextObject])) {
        Watcher *watcher = [self watcherForPath: wpath];
      
        if (watcher) {
          [watcher removeListener];
        }      
      }
          
			[clientsInfo removeObject: info];
		}
	}
}

- (oneway void)setGlobalIncludePaths:(NSArray *)ipaths
                        excludePaths:(NSArray *)epaths
{
}

- (oneway void)addGlobalIncludePath:(NSString *)path
{
}

- (oneway void)removeGlobalIncludePath:(NSString *)path
{
}

- (NSArray *)globalIncludePaths
{
  return nil;
}

- (oneway void)addGlobalExcludePath:(NSString *)path
{
}

- (oneway void)removeGlobalExcludePath:(NSString *)path
{
}

- (NSArray *)globalExcludePaths
{
  return nil;
}

- (oneway void)registerClient:(id <FSWClientProtocol>)client
              isGlobalWatcher:(BOOL)global
{
	NSConnection *connection = [(NSDistantObject *)client connectionForProxy];
  FSWClientInfo *info = [self clientInfoWithConnection: connection];

	if (info == nil) {
    [NSException raise: NSInternalInconsistencyException
		            format: @"registration with unknown connection"];
  }

  if ([info client] != nil) { 
    [NSException raise: NSInternalInconsistencyException
		            format: @"registration with registered client"];
  }

  if ([(id)client isProxy] == YES) {
    [(id)client setProtocolForProxy: @protocol(FSWClientProtocol)];
    [info setClient: client];  
    [info setGlobal: global];
  }
}

- (oneway void)unregisterClient:(id <FSWClientProtocol>)client
{
	NSConnection *connection = [(NSDistantObject *)client connectionForProxy];
  FSWClientInfo *info = [self clientInfoWithConnection: connection];
  NSSet *wpaths;
  NSEnumerator *enumerator;
  NSString *wpath;

	if (info == nil) {
    [NSException raise: NSInternalInconsistencyException
		            format: @"unregistration with unknown connection"];
  }

  if ([info client] == nil) { 
    [NSException raise: NSInternalInconsistencyException
                format: @"unregistration with unregistered client"];
  }

  wpaths = [info watchedPaths];
  enumerator = [wpaths objectEnumerator];
  
  while ((wpath = [enumerator nextObject])) {
    Watcher *watcher = [self watcherForPath: wpath];
  
    if (watcher) {
      [watcher removeListener];
    }  
  }
  
  [nc removeObserver: self
	              name: NSConnectionDidDieNotification
	            object: connection];

  [clientsInfo removeObject: info];  
}

- (FSWClientInfo *)clientInfoWithConnection:(NSConnection *)connection
{
  NSEnumerator *enumerator = [clientsInfo objectEnumerator];
  FSWClientInfo *info;

  while ((info = [enumerator nextObject])) {
		if ([info connection] == connection) {
			return info;
		}
  }

	return nil;
}

- (FSWClientInfo *)clientInfoWithRemote:(id)remote
{
  NSEnumerator *enumerator = [clientsInfo objectEnumerator];
  FSWClientInfo *info;

  while ((info = [enumerator nextObject])) {
		if ([info client] == remote) {
			return info;
		}
	}

	return nil;
}

- (oneway void)client:(id <FSWClientProtocol>)client
                              addWatcherForPath:(NSString *)path
{
	NSConnection *connection = [(NSDistantObject *)client connectionForProxy];
  FSWClientInfo *info = [self clientInfoWithConnection: connection];
  Watcher *watcher = [self watcherForPath: path];

	if (info == nil) {
    [NSException raise: NSInternalInconsistencyException
		            format: @"adding watcher from unknown connection"];
  }

  if ([info client] == nil) { 
    [NSException raise: NSInternalInconsistencyException
                format: @"adding watcher for unregistered client"];
  }

//  NSLog(@"addWatcherForPath %@", path);
  
  if (watcher) {
    [info addWatchedPath: path];
    [watcher addListener]; 
        
  } else {
    if ([fm fileExistsAtPath: path]) {
      [info addWatchedPath: path];
  	  watcher = [[Watcher alloc] initWithWatchedPath: path fswatcher: self];      
  	  [watchers addObject: watcher];
  	  RELEASE (watcher);  
    }
  }
}

- (oneway void)client:(id <FSWClientProtocol>)client
                                removeWatcherForPath:(NSString *)path
{
	NSConnection *connection = [(NSDistantObject *)client connectionForProxy];
  FSWClientInfo *info = [self clientInfoWithConnection: connection];
  Watcher *watcher = [self watcherForPath: path];
  
	if (info == nil) {
    [NSException raise: NSInternalInconsistencyException
		            format: @"removing watcher from unknown connection"];
  }

  if ([info client] == nil) { 
    [NSException raise: NSInternalInconsistencyException
                format: @"removing watcher for unregistered client"];
  }  
  
//  NSLog(@"removeWatcherForPath %@", path);
  
  if (watcher && ([watcher isOld] == NO)) {
    [info removeWatchedPath: path];
  	[watcher removeListener];  
  }
}

- (Watcher *)watcherForPath:(NSString *)path
{
  NSEnumerator *enumerator = [watchers objectEnumerator];
  Watcher *watcher;
  
  while ((watcher = [enumerator nextObject])) {
    if ([watcher isWathcingPath: path] && ([watcher isOld] == NO)) { 
      return watcher;
    }
  }
  
  return nil;
}

- (void)watcherTimeOut:(id)sender
{
  Watcher *watcher = (Watcher *)[sender userInfo];

  if ([watcher isOld]) {
    [self removeWatcher: watcher];
  } else {
    [watcher watchFile];
  }
}

- (void)removeWatcher:(Watcher *)watcher
{
	NSTimer *timer = [watcher timer];

	if (timer && [timer isValid]) {
		[timer invalidate];
	}
  
  [watchers removeObject: watcher];
}

- (void)notifyClients:(NSDictionary *)info
{
  CREATE_AUTORELEASE_POOL(pool);
  NSString *path = [info objectForKey: @"path"];
  NSData *data = [NSArchiver archivedDataWithRootObject: info];
  NSEnumerator *enumerator = [clientsInfo objectEnumerator];
  FSWClientInfo *clinfo;

  while ((clinfo = [enumerator nextObject])) {
		if ([clinfo isWathchingPath: path]) {
			[[clinfo client] watchedPathDidChange: data];
		}
  }

  RELEASE (pool);  
}

@end


@implementation Watcher

- (void)dealloc
{ 
	if (timer && [timer isValid]) {
		[timer invalidate];
	}
  RELEASE (watchedPath);  
  TEST_RELEASE (pathContents);
  RELEASE (date);  
  [super dealloc];
}

- (id)initWithWatchedPath:(NSString *)path
                fswatcher:(id)fsw
{
  self = [super init];
  
  if (self) { 
		NSDictionary *attributes;
		NSString *type;
    		
    ASSIGN (watchedPath, path);    
		fm = [NSFileManager defaultManager];	
    attributes = [fm fileAttributesAtPath: path traverseLink: YES];
    type = [attributes fileType];
		ASSIGN (date, [attributes fileModificationDate]);		
    
    if (type == NSFileTypeDirectory) {
		  ASSIGN (pathContents, ([fm directoryContentsAtPath: watchedPath]));
      isdir = YES;
    } else {
      isdir = NO;
    }
    
    listeners = 1;
		isOld = NO;
    fswatcher = fsw;
    timer = [NSTimer scheduledTimerWithTimeInterval: 1.0 
												                     target: fswatcher 
                                           selector: @selector(watcherTimeOut:) 
										                       userInfo: self 
                                            repeats: YES];
  }
  
  return self;
}

- (void)watchFile
{
  CREATE_AUTORELEASE_POOL(pool);
  NSDictionary *attributes;
  NSDate *moddate;
  NSMutableDictionary *notifdict;

	if (isOld) {
    RELEASE (pool);  
		return;
	}
	
	attributes = [fm fileAttributesAtPath: watchedPath traverseLink: YES];

  if (attributes == nil) {
    notifdict = [NSMutableDictionary dictionary];
    [notifdict setObject: watchedPath forKey: @"path"];
    [notifdict setObject: @"GWWatchedPathDeleted" forKey: @"event"];
    [fswatcher notifyClients: notifdict];              
		isOld = YES;
    RELEASE (pool);  
    return;
  }
  	
  moddate = [attributes fileModificationDate];

  if ([date isEqualToDate: moddate] == NO) {
    if (isdir) {
      NSArray *oldconts = [pathContents copy];
      NSArray *newconts = [fm directoryContentsAtPath: watchedPath];	
      NSMutableArray *diffFiles = [NSMutableArray array];
      BOOL contentsChanged = NO;
      int i;

      ASSIGN (date, moddate);	
      ASSIGN (pathContents, newconts);

      notifdict = [NSMutableDictionary dictionary];
      [notifdict setObject: watchedPath forKey: @"path"];

		  /* if there is an error in fileAttributesAtPath */
		  /* or watchedPath doesn't exist anymore         */
		  if (newconts == nil) {	
        [notifdict setObject: @"GWWatchedPathDeleted" forKey: @"event"];
        [fswatcher notifyClients: notifdict];
        RELEASE (oldconts);
			  isOld = YES;
        RELEASE (pool);  
    	  return;
		  }

      for (i = 0; i < [oldconts count]; i++) {
        NSString *fname = [oldconts objectAtIndex: i];
        if ([newconts containsObject: fname] == NO) {
          [diffFiles addObject: fname];
        }
      }

      if ([diffFiles count] > 0) {
        contentsChanged = YES;
        [notifdict setObject: @"GWFileDeletedInWatchedDirectory" forKey: @"event"];
        [notifdict setObject: diffFiles forKey: @"files"];
        [fswatcher notifyClients: notifdict];
      }

      [diffFiles removeAllObjects];

      for (i = 0; i < [newconts count]; i++) {
        NSString *fname = [newconts objectAtIndex: i];
        if ([oldconts containsObject: fname] == NO) {   
          [diffFiles addObject: fname];
        }
      }

      if ([diffFiles count] > 0) {
        contentsChanged = YES;
        [notifdict setObject: watchedPath forKey: @"path"];
        [notifdict setObject: @"GWFileCreatedInWatchedDirectory" forKey: @"event"];
        [notifdict setObject: diffFiles forKey: @"files"];
        [fswatcher notifyClients: notifdict];
      }

      TEST_RELEASE (oldconts);	

      if (contentsChanged == NO) {
        [notifdict setObject: @"GWWatchedFileModified" forKey: @"event"];
        [fswatcher notifyClients: notifdict];
      }
      	
	  } else {  // isdir == NO
      ASSIGN (date, moddate);	
      
      notifdict = [NSMutableDictionary dictionary];
      
      [notifdict setObject: watchedPath forKey: @"path"];
      [notifdict setObject: @"GWWatchedFileModified" forKey: @"event"];
                    
      [fswatcher notifyClients: notifdict];
    }
  }

  RELEASE (pool);   
}

- (void)addListener
{
//  NSLog(@"adding listener for: %@", watchedPath);
  listeners++;
}

- (void)removeListener
{ 
//  NSLog(@"removing listener for: %@", watchedPath);
  listeners--;
  if (listeners <= 0) { 
		isOld = YES;
  } 
}

- (BOOL)isWathcingPath:(NSString *)apath
{
  return ([apath isEqualToString: watchedPath]);
}

- (NSString *)watchedPath
{
	return watchedPath;
}

- (BOOL)isOld
{
	return isOld;
}

- (NSTimer *)timer
{
  return timer;
}

@end


int main(int argc, char** argv)
{
  CREATE_AUTORELEASE_POOL(pool);
  NSProcessInfo *info = [NSProcessInfo processInfo];
  NSMutableArray *args = AUTORELEASE ([[info arguments] mutableCopy]);
  static BOOL	is_daemon = NO;
  BOOL subtask = YES;

  if ([[info arguments] containsObject: @"--daemon"]) {
    subtask = NO;
    is_daemon = YES;
  }

  if (subtask) {
    NSTask *task = [NSTask new];
    
    NS_DURING
	    {
	      [args removeObjectAtIndex: 0];
	      [args addObject: @"--daemon"];
	      [task setLaunchPath: [[NSBundle mainBundle] executablePath]];
	      [task setArguments: args];
	      [task setEnvironment: [info environment]];
	      [task launch];
	      DESTROY (task);
	    }
    NS_HANDLER
	    {
	      fprintf (stderr, "unable to launch the fswatcher task. exiting.\n");
	      DESTROY (task);
	    }
    NS_ENDHANDLER
      
    exit(EXIT_FAILURE);
  }
  
  RELEASE(pool);

  {
    CREATE_AUTORELEASE_POOL (pool);
    FSWatcher *fsw = [[FSWatcher alloc] init];
    RELEASE (pool);
  
    if (fsw != nil) {
	    CREATE_AUTORELEASE_POOL (pool);
      [[NSRunLoop currentRunLoop] run];
  	  RELEASE (pool);
    }
  }
    
  exit(EXIT_SUCCESS);
}

