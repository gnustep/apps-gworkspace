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
#include "fswatcher.h"
#include "config.h"
#include "GNUstep.h"

#define GWDebugLog(format, args...) \
  do { if (GW_DEBUG_LOG) \
    NSLog(format , ## args); } while (0)

#define OPENW 0
#define RMDIR 2
#define MKDIR 3
#define UNLINK 6
#define CREATE 7
#define RENAME 9 

#define MAX_PATH_LEN 512
#define MAX_LINE_LEN (MAX_PATH_LEN * 2)

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

- (oneway void)deviceDataReady:(NSData *)data
{
  CREATE_AUTORELEASE_POOL(pool);
  const char *bytes = [data bytes];
  char *p = (char *)bytes;
  char buf[MAX_LINE_LEN];
  unsigned i = 0;
  NSString *line = nil;
  NSString *separator = @" ]]]----->> ";
  int operation;
  NSString *path = nil;
  NSString *basePath = nil;    
  NSString *destPath = nil;
  NSString *destBasePath = nil;
  NSRange range = NSMakeRange(0, 1);
  BOOL notify;
  BOOL globnotify;

  while (*p != '\0') {
    buf[i] = *p;
    i++;
    p++;
  }

  buf[i++] = '\0';

  line = [NSString stringWithUTF8String: buf];

  range = NSMakeRange(0, 1);
  operation = [[line substringWithRange: range] intValue];

  if ([line length] < 2) {
    return;
  }

  range.location += 2;
  range.length = ([line length] - 2);
  line = [line substringWithRange: range];

  range = [line rangeOfString: separator];

  if (range.location != NSNotFound) {
    NSRange destrange;

    path = [line substringWithRange: NSMakeRange(0, range.location)];
    
    destrange.location = (range.location + range.length);
    destrange.length = ([line length] - destrange.location);
    destPath = [line substringWithRange: destrange];
    destPath = [destPath stringByStandardizingPath];
    
    destBasePath = [destPath stringByDeletingLastPathComponent];

  } else {
    path = line;
  }
  
  path = [path stringByStandardizingPath];
  
  basePath = [path stringByDeletingLastPathComponent];
    
  notify = [watchedPaths containsObject: path];
  globnotify = ((isDotFile(path) == NO) 
                      && inTreeFirstPartOfPath(path, includePathsTree)
                  && ((inTreeFirstPartOfPath(path, excludePathsTree) == NO)
                                  || fullPathInTree(path, includePathsTree)));
    
  if (notify || globnotify) {
    NSMutableDictionary *notifdict = [NSMutableDictionary dictionary];
    BOOL glob = globnotify;

    [notifdict setObject: path forKey: @"path"];

    switch (operation) { 
      case OPENW:
      case CREATE:
      case MKDIR:
        if (pathModified(path)) {
          [notifdict setObject: @"GWWatchedFileModified" forKey: @"event"];
          GWDebugLog(@"MODIFIED %@", path);
        } else {
          notify = NO;
          globnotify = NO;
        }
        break;

      case UNLINK:
      case RMDIR:
      case RENAME:
        [notifdict setObject: @"GWWatchedPathDeleted" forKey: @"event"];
        GWDebugLog(@"DELETE %@", path); 
        glob = NO;
        break;

      default:
        notify = NO;
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
    BOOL notify = YES;

    [notifdict setObject: basePath forKey: @"path"];

    switch (operation) {   
      case OPENW:
      case CREATE:
      case MKDIR:
        [notifdict setObject: @"GWFileCreatedInWatchedDirectory" forKey: @"event"];
        [notifdict setObject: [NSArray arrayWithObject: [path lastPathComponent]] 
                      forKey: @"files"];
        GWDebugLog(@"CREATE %@", path);
        break;

      case UNLINK:
      case RMDIR:
        [notifdict setObject: @"GWFileDeletedInWatchedDirectory" forKey: @"event"];
        [notifdict setObject: [NSArray arrayWithObject: [path lastPathComponent]] 
                      forKey: @"files"];
        GWDebugLog(@"DELETE %@", path);
        break;

      case RENAME:
        [notifdict setObject: @"GWFileDeletedInWatchedDirectory" forKey: @"event"];
        [notifdict setObject: [NSArray arrayWithObject: [path lastPathComponent]] 
                      forKey: @"files"];
        [self notifyClients: notifdict];
        if (globnotify) {
          [self notifyGlobalWatchingClients: notifdict];
        }  

        notifdict = [NSMutableDictionary dictionary];

        [notifdict setObject: destBasePath forKey: @"path"];
        [notifdict setObject: @"GWFileCreatedInWatchedDirectory" forKey: @"event"];
        [notifdict setObject: [NSArray arrayWithObject: [destPath lastPathComponent]]
                      forKey: @"files"];

        notify = ([watchedPaths containsObject: destBasePath]);
        globnotify = ((isDotFile(destBasePath) == NO) 
                      && inTreeFirstPartOfPath(destBasePath, includePathsTree)
                  && ((inTreeFirstPartOfPath(destBasePath, excludePathsTree) == NO)
                                || fullPathInTree(destBasePath, includePathsTree)));
        GWDebugLog(@"RENAME %@ to %@", path, destPath);
        break;

      default:
        notify = NO;
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

      if ([diffFiles count]) {
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

      if ([diffFiles count]) {
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
  TEST_RELEASE (devHandle);
  [super dealloc];
}

- (id)initWithPorts:(NSArray *)ports
{
  self = [super init];
  
  if (self) {    
    NSPort *port[2];
    NSConnection *conn;
    id anObject;

    devHandle = [NSFileHandle fileHandleForReadingAtPath: @"/dev/fswatcher"];  
  
    if (devHandle == nil) {
      DESTROY (self);
      return self;
    }
    
    RETAIN (devHandle);
    
    port[0] = [ports objectAtIndex: 0];             
    port[1] = [ports objectAtIndex: 1];             

    conn = [NSConnection connectionWithReceivePort: (NSPort *)port[0]
                                          sendPort: (NSPort *)port[1]];

    anObject = (id)[conn rootProxy];
    [anObject setProtocolForProxy: @protocol(FSWatcherProtocol)];
    fsw = (id <FSWatcherProtocol>)anObject;
  }
  
  return self;    
}

- (void)readDeviceData
{
  struct timespec request;

  while (1) {
    CREATE_AUTORELEASE_POOL(pool);
    NSData *data = [devHandle availableData];

    if (data && [data length]) {
      [fsw deviceDataReady: data];            
    } else {
      request.tv_sec = (time_t)0;
      request.tv_nsec = (long)0;      
      nanosleep(&request, 0);
    }
  
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

