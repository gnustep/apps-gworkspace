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

#include <unistd.h>
#include <time.h>
#include <sys/ioctl.h>
#include <sys/sysctl.h>
#include <sys/stat.h>
#include <fcntl.h>
#include "fswatcher.h"
#include "fsevents.h"
#include "GNUstep.h"
#include "config.h"

#define GWDebugLog(format, args...) \
  do { if (GW_DEBUG_LOG) \
    NSLog(format , ## args); } while (0)

BOOL isDotFile(NSString *path)
{
  int len = ([path length] - 1);
  unichar c;
  int i;
  
  for (i = len; i >= 0; i--) {
    c = [path characterAtIndex: i];
    
    if (c == '.') {
      if ((i > 0) && ([path characterAtIndex: (i - 1)] == '/')) {
        return YES;
      }
    }
  }
  
  return NO;  
}

@implementation	FSWClientInfo

- (void)dealloc
{
	TEST_RELEASE (conn);
	TEST_RELEASE ((id)client);
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

  [nc removeObserver: self
		            name: NSConnectionDidDieNotification
		          object: devReadConn];
  DESTROY (devReadConn);

  [dnc removeObserver: self];
  
  RELEASE (clientsInfo);
  RELEASE (watchers);
  RELEASE (watchedPaths);

  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) { 
    NSPort *port[2];
    NSArray *ports;
     
    fm = [NSFileManager defaultManager];	
    nc = [NSNotificationCenter defaultCenter];
    dnc = [NSDistributedNotificationCenter defaultCenter];
    
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

    clientsInfo = [[NSMutableSet alloc] initWithCapacity: 1];
    watchers = [[NSMutableSet alloc] initWithCapacity: 1];
    watchedPaths = [[NSCountedSet alloc] initWithCapacity: 1];

    includePathsTree = newTreeWithIdentifier(@"incl_paths");
    excludePathsTree = newTreeWithIdentifier(@"excl_paths");
    [self setDefaultGlobalPaths];
    
    port[0] = (NSPort *)[NSPort port];
    port[1] = (NSPort *)[NSPort port];

    ports = [NSArray arrayWithObjects: port[1], port[0], nil];

    devReadConn = [[NSConnection alloc] initWithReceivePort: port[0]
				                                           sendPort: port[1]];
    [devReadConn setRootObject: self];
    [devReadConn setDelegate: self];

    [nc addObserver: self
           selector: @selector(connectionBecameInvalid:)
               name: NSConnectionDidDieNotification
             object: devReadConn];    

    NS_DURING
      {
        [NSThread detachNewThreadSelector: @selector(deviceReader:)
		                             toTarget: [FSWDeviceReader class]
		                           withObject: ports];
      }
    NS_HANDLER
      {
        NSLog(@"A fatal error occured while detaching the thread!");
        DESTROY (self);
        return self;
      }
    NS_ENDHANDLER
    
    [dnc addObserver: self
            selector: @selector(globalPathsChanged:)
	              name: @"GSMetadataIndexedDirectoriesChanged"
	            object: nil];
  }
  
  return self;    
}

- (BOOL)connection:(NSConnection *)ancestor
            shouldMakeNewConnection:(NSConnection *)newConn;
{
  if (ancestor == conn) {
    FSWClientInfo *info = [FSWClientInfo new];

    [info setConnection: newConn];
    [clientsInfo addObject: info];
    RELEASE (info);

    [nc addObserver: self
           selector: @selector(connectionBecameInvalid:)
	             name: NSConnectionDidDieNotification
	           object: newConn];

    [newConn setDelegate: self];
  }
    
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
      
        [watchedPaths removeObject: wpath];
      }
              
			[clientsInfo removeObject: info];
		}
	}
}

- (void)setDefaultGlobalPaths
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  id paths;
  unsigned i;
  
  [defaults synchronize];

  paths = [defaults arrayForKey: @"GSMetadataIndexablePaths"];
  
  if (paths) {
    for (i = 0; i < [paths count]; i++) {
      insertComponentsOfPath([paths objectAtIndex: i], includePathsTree);
    }
  
  } else {
    insertComponentsOfPath(NSHomeDirectory(), includePathsTree);

    paths = NSSearchPathForDirectoriesInDomains(NSAllApplicationsDirectory, 
                                                        NSAllDomainsMask, YES);
    for (i = 0; i < [paths count]; i++) {
      insertComponentsOfPath([paths objectAtIndex: i], includePathsTree);
    }
    
    paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, 
                                                      NSAllDomainsMask, YES);
    for (i = 0; i < [paths count]; i++) {
      NSString *dir = [paths objectAtIndex: i];
      NSString *path = [dir stringByAppendingPathComponent: @"Headers"];

      if ([fm fileExistsAtPath: path]) {
        insertComponentsOfPath(path, includePathsTree);
      }
      
      path = [dir stringByAppendingPathComponent: @"Documentation"];
      
      if ([fm fileExistsAtPath: path]) {
        insertComponentsOfPath(path, includePathsTree);
      }
    }  
  }

  paths = [defaults arrayForKey: @"GSMetadataExcludedPaths"];

  if (paths) {
    for (i = 0; i < [paths count]; i++) {
      insertComponentsOfPath([paths objectAtIndex: i], excludePathsTree);
    }
  }
}

- (void)globalPathsChanged:(NSNotification *)notification
{
  NSDictionary *info = [notification userInfo];
  NSArray *indexable = [info objectForKey: @"GSMetadataIndexablePaths"];
  NSArray *excluded = [info objectForKey: @"GSMetadataExcludedPaths"];
  unsigned i;

  emptyTreeWithBase(includePathsTree);
  
  for (i = 0; i < [indexable count]; i++) {
    insertComponentsOfPath([indexable objectAtIndex: i], includePathsTree);
  }

  emptyTreeWithBase(excludePathsTree);
  
  for (i = 0; i < [excluded count]; i++) {
    insertComponentsOfPath([excluded objectAtIndex: i], excludePathsTree);
  }
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

    [watchedPaths removeObject: wpath];
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

  GWDebugLog(@"addWatcherForPath %@", path);
  
  if ([fm fileExistsAtPath: path]) {
    if (watcher) {
      [info addWatchedPath: path];
      [watcher addListener]; 
    } else {
      [info addWatchedPath: path];
  	  watcher = [[Watcher alloc] initWithWatchedPath: path fswatcher: self];      
  	  [watchers addObject: watcher];
  	  RELEASE (watcher);  
    }
    
    [watchedPaths addObject: path];
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
  
  GWDebugLog(@"removeWatcherForPath %@", path);

  if (watcher && ([watcher isOld] == NO)) {
    [info removeWatchedPath: path];
  	[watcher removeListener];  
  }
  
  [watchedPaths removeObject: path];
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

- (void)watcherTimeOut:(NSTimer *)sender
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

- (void)notifyGlobalWatchingClients:(NSDictionary *)info
{
  NSEnumerator *enumerator = [clientsInfo objectEnumerator];
  FSWClientInfo *clinfo;
  
  while ((clinfo = [enumerator nextObject])) {
    if ([clinfo isGlobal]) {
      [[clinfo client] globalWatchedPathDidChange: info];
    }
  }
}

- (oneway void)deviceDataReadyForPath:(char *)path
                        operationType:(int)type
{
  CREATE_AUTORELEASE_POOL(pool);
  NSString *fullPath = [NSString stringWithUTF8String: path];
  NSString *basePath = [fullPath stringByDeletingLastPathComponent];
  BOOL notify = [watchedPaths containsObject: fullPath];
  BOOL globnotify = ((isDotFile(fullPath) == NO) 
                      && inTreeFirstPartOfPath(fullPath, includePathsTree)
                && ((inTreeFirstPartOfPath(fullPath, excludePathsTree) == NO)
                                || fullPathInTree(fullPath, includePathsTree)));
  
  if (notify || globnotify) {
    NSMutableDictionary *notifdict = [NSMutableDictionary dictionary];
    BOOL glob = globnotify;
    
    [notifdict setObject: fullPath forKey: @"path"];
  
    switch (type) { 
      case FSE_CONTENT_MODIFIED:
        [notifdict setObject: @"GWWatchedFileModified" forKey: @"event"];
        GWDebugLog(@"MODIFIED %@", fullPath);
        break;
  
      case FSE_DELETE:
        [notifdict setObject: @"GWWatchedPathDeleted" forKey: @"event"];
        glob = NO;
        GWDebugLog(@"DELETE %@", fullPath);
        break;
  
      case FSE_RENAME:
        if ([fm fileExistsAtPath: fullPath] == NO) {
          [notifdict setObject: @"GWWatchedPathDeleted" forKey: @"event"];
          GWDebugLog(@"RENAME %@", fullPath);
        } else {
          notify = NO; 
        }
        glob = NO;
        break;
  
      default:
        notify = NO;
        glob = NO;
        break;
    }
    
    if (notify) {
      [self notifyClients: notifdict];
    }  
    
    if (glob) {
      [self notifyGlobalWatchingClients: notifdict];
    }  
  }

  notify = [watchedPaths containsObject: basePath];
  
  if (notify || globnotify) {
    NSMutableDictionary *notifdict = [NSMutableDictionary dictionary];
    
    [notifdict setObject: basePath forKey: @"path"];
      
    switch (type) { 
      case FSE_CREATE_FILE:
      case FSE_CREATE_DIR:
        [notifdict setObject: @"GWFileCreatedInWatchedDirectory" forKey: @"event"];
        [notifdict setObject: [NSArray arrayWithObject: [fullPath lastPathComponent]] 
                      forKey: @"files"];
        GWDebugLog(@"CREATE %@", fullPath);
        break;
        
      case FSE_DELETE:
        [notifdict setObject: @"GWFileDeletedInWatchedDirectory" forKey: @"event"];
        [notifdict setObject: [NSArray arrayWithObject: [fullPath lastPathComponent]] 
                      forKey: @"files"];
        GWDebugLog(@"DELETE %@", fullPath);
        break;

      case FSE_RENAME:
        if ([fm fileExistsAtPath: fullPath]) {
          [notifdict setObject: @"GWFileCreatedInWatchedDirectory" forKey: @"event"];
          [notifdict setObject: [NSArray arrayWithObject: [fullPath lastPathComponent]] 
                        forKey: @"files"];
          GWDebugLog(@"RENAME %@", fullPath);
        } else {
          [notifdict setObject: @"GWFileDeletedInWatchedDirectory" forKey: @"event"];
          [notifdict setObject: [NSArray arrayWithObject: [fullPath lastPathComponent]] 
                        forKey: @"files"];
          GWDebugLog(@"RENAME %@", fullPath);
        }
        break;

      default:
        notify = NO;
        globnotify = NO;
        break;
    }

    if (notify) {
      [self notifyClients: notifdict];
    }    

    if (globnotify) {
      [self notifyGlobalWatchingClients: notifdict];
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
  GWDebugLog(@"adding listener for: %@", watchedPath);
  listeners++;
}

- (void)removeListener
{ 
  GWDebugLog(@"removing listener for: %@", watchedPath);
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


char large_buf[0x2000];

@implementation	FSWDeviceReader

+ (void)deviceReader:(NSArray *)ports
{
  CREATE_AUTORELEASE_POOL(arp);
  FSWDeviceReader *reader = [[FSWDeviceReader alloc] initWithPorts: ports];

  [reader readDeviceData];
  
  RELEASE (reader);
  RELEASE (arp);
}

- (void)dealloc
{
  [super dealloc];
}

- (id)initWithPorts:(NSArray *)ports
{
  self = [super init];
  
  if (self) {    
    NSPort *port[2];
    NSConnection *conn;
    id anObject;
      
    port[0] = [ports objectAtIndex: 0];             
    port[1] = [ports objectAtIndex: 1];             

    conn = [NSConnection connectionWithReceivePort: (NSPort *)port[0]
                                          sendPort: (NSPort *)port[1]];

    anObject = (id)[conn rootProxy];
    [anObject setProtocolForProxy: @protocol(FSWatcherProtocol)];
    fsw = (id <FSWatcherProtocol>)anObject;
    
    if (fsw) {
      signed char event_list[FSE_MAX_EVENTS];
      fsevent_clone_args retrieve_ioctl;    
      int fd;
    
      event_list[FSE_CREATE_FILE] = FSE_REPORT;
      event_list[FSE_DELETE] = FSE_REPORT;
      event_list[FSE_STAT_CHANGED] = FSE_IGNORE;
      event_list[FSE_RENAME] = FSE_REPORT;
      event_list[FSE_CONTENT_MODIFIED] = FSE_REPORT;
      event_list[FSE_EXCHANGE] = FSE_IGNORE;
      event_list[FSE_FINDER_INFO_CHANGED] = FSE_IGNORE;
      event_list[FSE_CREATE_DIR] = FSE_REPORT;
      event_list[FSE_CHOWN] = FSE_IGNORE;
    
      fd = open("/dev/fsevents", 0, 2);

      if (fd < 0) {
        DESTROY (self);
        return self;
      }

      retrieve_ioctl.event_list = event_list;
      retrieve_ioctl.num_events = sizeof(event_list);
      retrieve_ioctl.event_queue_depth = 0x400;
      retrieve_ioctl.fd = &fsevents_fd;

      if (ioctl(fd, FSEVENTS_CLONE, &retrieve_ioctl) < 0) {
        DESTROY (self);
        return self;
      }
      close(fd);

      fprintf(stderr, "fswatcher fslogger thread running...\n");
    
    } else {
      DESTROY (self);
      return self;
    }
  }
  
  return self;    
}

- (void)readDeviceData
{
  int n;

  while ((n = read(fsevents_fd, large_buf, sizeof(large_buf))) > 0) { 
    CREATE_AUTORELEASE_POOL(pool);
    void *data = (void *)large_buf;
    int pos = 0;
    pid_t pid;
    u_int16_t argtype;
    u_int16_t arglen;
    
    do {
	    int32_t type = *((int32_t *)(data + pos));

      if (type == FSE_INVALID) {
        return;
      }

      pos += 4;

      pid = *((pid_t *)(data + pos));	
      pos += sizeof(pid_t);

      while (1) {
        BOOL valid = NO;
        
        argtype = *((u_int16_t *)(data + pos));
        pos += 2;

        if (argtype == FSE_ARG_DONE) {
	        break;
        }

        arglen = *((u_int16_t *)(data + pos));
        pos += 2;

        switch(argtype) {
          case FSE_ARG_VNODE:
            valid = YES;
	          break;

          case FSE_ARG_STRING:
            valid = YES;
	          break;

          case FSE_ARG_PATH: 
            valid = YES;
	          break;

          case FSE_ARG_INT32:
          case FSE_ARG_INT64:
          case FSE_ARG_RAW: 
          case FSE_ARG_INO:
          case FSE_ARG_UID:
          case FSE_ARG_DEV:
          case FSE_ARG_MODE:
          case FSE_ARG_GID:
            break;
            
          default:   // invalid!
            pos = n; // to break also the do cycle
	          break;   
        }

        if (valid) {
          char *path = data + pos;
          
          if ((path[0] != 0) && (path[0] == '/')) {
            [fsw deviceDataReadyForPath: path operationType: (int)type];
	        }
        }
        
        pos += arglen;
      }

    } while (pos < n);
    
    RELEASE (pool);
  }
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
