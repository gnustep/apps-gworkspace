/* fswatcher-inotify.m
 *  
 * Copyright (C) 2007-2015 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@fibernet.ro>
 * Date: January 2007
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

#import "fswatcher-inotify.h"
#include "config.h"
#include <unistd.h>

#define GWDebugLog(format, args...) \
  do { if (GW_DEBUG_LOG) \
    NSLog(format , ## args); } while (0)

static BOOL	auto_stop = NO;		/* Should we shut down when unused? */

static NSString *GWWatchedPathDeleted = @"GWWatchedPathDeleted";
static NSString *GWFileDeletedInWatchedDirectory = @"GWFileDeletedInWatchedDirectory";
static NSString *GWFileCreatedInWatchedDirectory = @"GWFileCreatedInWatchedDirectory";
static NSString *GWWatchedFileModified = @"GWWatchedFileModified";
static NSString *GWWatchedPathRenamed = @"GWWatchedPathRenamed";


@implementation	FSWClientInfo

- (void)dealloc
{
  RELEASE (conn);
  RELEASE (client);
  RELEASE (wpaths);
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self)
    {
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
  NSUInteger i;

  for (i = 0; i < [clientsInfo count]; i++)
    {
      NSConnection *connection = [[clientsInfo objectAtIndex: i] connection];

      if (connection)
	{
	  [nc removeObserver: self
			name: NSConnectionDidDieNotification
		      object: connection];
	}
    }
  
  if (conn) {
    [nc removeObserver: self
		              name: NSConnectionDidDieNotification
		            object: conn];
  }

  [dnc removeObserver: self];
  
  RELEASE (clientsInfo);
  NSZoneFree (NSDefaultMallocZone(), (void *)watchers);
  NSZoneFree (NSDefaultMallocZone(), (void *)watchDescrMap);
  freeTree(includePathsTree);
  freeTree(excludePathsTree);
  RELEASE (excludedSuffixes);
  RELEASE (inotifyHandle);  
  RELEASE (lastMovedPath);
  
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self)
    {    
      int fd;

      fm = [NSFileManager defaultManager];	
      nc = [NSNotificationCenter defaultCenter];
      dnc = [NSDistributedNotificationCenter defaultCenter];
      
      conn = [NSConnection defaultConnection];
      [conn setRootObject: self];
      [conn setDelegate: self];
    
      if ([conn registerName: @"fswatcher"] == NO)
	{
	  NSLog(@"unable to register with name server.");
	  DESTROY (self);
	  return self;
	}

      fd = inotify_init();  
  
      if (fd == -1)
	{
	  NSLog(@"inotify_init() failed!");
	  DESTROY (self);
	  return self;  
	}
    
    inotifyHandle = [[NSFileHandle alloc] initWithFileDescriptor: fd 
                                                  closeOnDealloc: YES];  

    if (inotifyHandle == nil) {
      NSLog(@"unable to create the inotify handle.");
      close(fd);
      DESTROY (self);
      return self;  
    }

    dirmask = (IN_CREATE | IN_DELETE | IN_DELETE_SELF 
                | IN_MOVED_FROM | IN_MOVED_TO | IN_MOVE_SELF | IN_MODIFY);    
    filemask = (IN_CLOSE_WRITE | IN_MODIFY | IN_DELETE_SELF | IN_MOVE_SELF);    
    lastMovedPath = nil;
    moveCookie = 0;
  
    clientsInfo = [NSMutableArray new];    
    watchers = NSCreateMapTable(NSObjectMapKeyCallBacks,
	                                        NSObjectMapValueCallBacks, 0);
                                          
    watchDescrMap = NSCreateMapTable(NSIntMapKeyCallBacks,
	                                     NSNonOwnedPointerMapValueCallBacks, 0);
                                          
    includePathsTree = newTreeWithIdentifier(@"incl_paths");
    excludePathsTree = newTreeWithIdentifier(@"excl_paths");
    excludedSuffixes = [[NSMutableSet alloc] initWithCapacity: 1];
    
    [self setDefaultGlobalPaths];

    [nc addObserver: self
           selector: @selector(connectionBecameInvalid:)
	             name: NSConnectionDidDieNotification
	           object: conn];

    [dnc addObserver: self
            selector: @selector(globalPathsChanged:)
	              name: @"GSMetadataIndexedDirectoriesChanged"
	            object: nil];

    [nc addObserver: self
	         selector: @selector(inotifyDataReady:)
		           name: NSFileHandleReadCompletionNotification
		         object: inotifyHandle];
  
    [inotifyHandle readInBackgroundAndNotify];
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

  if (connection == conn)
    {
      NSLog(@"argh - fswatcher server root connection has been destroyed.");
      exit(EXIT_FAILURE);  
    }
  else
    {
      FSWClientInfo *info = [self clientInfoWithConnection: connection];
      
      if (info)
	{
	  NSSet *wpaths = [info watchedPaths];
	  NSEnumerator *enumerator = [wpaths objectEnumerator];
	  NSString *wpath;
	  
	  while ((wpath = [enumerator nextObject]))
	    {
	      Watcher *watcher = [self watcherForPath: wpath];
	      
	      if (watcher)
		[watcher removeListener];
	    }
	  
	  [clientsInfo removeObject: info];
	}
      
      if (auto_stop == YES && [clientsInfo count] <= 1)
	{
	  /* If there is nothing else using this process, and this is not
	   * a daemon, then we can quietly terminate.
	   */
	  NSLog(@"No more clients, shutting down.");
	  exit(EXIT_SUCCESS);
	}
    }
}

- (void)setDefaultGlobalPaths
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  id entry;
  NSUInteger i;
  
  [defaults synchronize];

  entry = [defaults arrayForKey: @"GSMetadataIndexablePaths"];
  
  if (entry) {
    for (i = 0; i < [entry count]; i++) {
      insertComponentsOfPath([entry objectAtIndex: i], includePathsTree);
    }
  
  } else {
    insertComponentsOfPath(NSHomeDirectory(), includePathsTree);

    entry = NSSearchPathForDirectoriesInDomains(NSAllApplicationsDirectory, 
                                                        NSAllDomainsMask, YES);
    for (i = 0; i < [entry count]; i++) {
      insertComponentsOfPath([entry objectAtIndex: i], includePathsTree);
    }
    
    entry = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, 
                                                      NSAllDomainsMask, YES);
    for (i = 0; i < [entry count]; i++) {
      NSString *dir = [entry objectAtIndex: i];
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

  entry = [defaults arrayForKey: @"GSMetadataExcludedPaths"];

  if (entry) {
    for (i = 0; i < [entry count]; i++) {
      insertComponentsOfPath([entry objectAtIndex: i], excludePathsTree);
    }
  }
  
  entry = [defaults arrayForKey: @"GSMetadataExcludedSuffixes"];
  
  if (entry == nil) {
    entry = [NSArray arrayWithObjects: @"a", @"d", @"dylib", @"er1", 
                                       @"err", @"extinfo", @"frag", @"la", 
                                       @"log", @"o", @"out", @"part", 
                                       @"sed", @"so", @"status", @"temp",
                                       @"tmp",  
                                       nil];
  } 
  
  [excludedSuffixes addObjectsFromArray: entry];
}

- (void)globalPathsChanged:(NSNotification *)notification
{
  NSDictionary *info = [notification userInfo];
  NSArray *indexable = [info objectForKey: @"GSMetadataIndexablePaths"];
  NSArray *excluded = [info objectForKey: @"GSMetadataExcludedPaths"];
  NSArray *suffixes = [info objectForKey: @"GSMetadataExcludedSuffixes"];
  
  NSUInteger i;

  emptyTreeWithBase(includePathsTree);
  
  for (i = 0; i < [indexable count]; i++) {
    insertComponentsOfPath([indexable objectAtIndex: i], includePathsTree);
  }

  emptyTreeWithBase(excludePathsTree);
  
  for (i = 0; i < [excluded count]; i++) {
    insertComponentsOfPath([excluded objectAtIndex: i], excludePathsTree);
  }
  
  [excludedSuffixes removeAllObjects];
  [excludedSuffixes addObjectsFromArray: suffixes];
}

- (oneway void)registerClient:(id <FSWClientProtocol>)client
              isGlobalWatcher:(BOOL)global
{
  NSConnection *connection = [(NSDistantObject *)client connectionForProxy];
  FSWClientInfo *info = [self clientInfoWithConnection: connection];

  if (info == nil)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"registration with unknown connection"];
    }

  if ([info client] != nil)
    { 
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
  
  if (auto_stop == YES && [clientsInfo count] <= 1)
    {
      /* If there is nothing else using this process, and this is not
       * a daemon, then we can quietly terminate.
       */
      exit(EXIT_SUCCESS);
    }
}

- (FSWClientInfo *)clientInfoWithConnection:(NSConnection *)connection
{
  NSUInteger i;

  for (i = 0; i < [clientsInfo count]; i++) {
    FSWClientInfo *info = [clientsInfo objectAtIndex: i];
  
		if ([info connection] == connection) {
			return info;
		}  
  }

	return nil;
}

- (FSWClientInfo *)clientInfoWithRemote:(id)remote
{
  NSUInteger i;

  for (i = 0; i < [clientsInfo count]; i++)
    {
      FSWClientInfo *info = [clientsInfo objectAtIndex: i];
      
      if ([info client] == remote)
	return info;
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
  
  if (watcher) {
    GWDebugLog(@"watcher found; adding listener for: %@", path);
    [info addWatchedPath: path];
    [watcher addListener]; 
        
  } else {
    BOOL isdir;
  
    if ([fm fileExistsAtPath: path isDirectory: &isdir]) {
      uint32_t mask = (isdir ? dirmask : filemask);
      int wd = inotify_add_watch([inotifyHandle fileDescriptor], 
                                                  [path UTF8String], mask);
      
      if (wd != -1) { 
        GWDebugLog(@"add watcher for: %@", path);      
        [info addWatchedPath: path];
  	    watcher = [[Watcher alloc] initWithWatchedPath: path 
                                       watchDescriptor: wd
                                             fswatcher: self];      
        NSMapInsert (watchers, path, watcher);
        NSMapInsert (watchDescrMap, (void *)wd, (void *)watcher);      
        RELEASE (watcher);       
        
      } else {
        NSLog(@"Invalid watch descriptor returned by inotify_add_watch(). "
                                                @"No watcher for: %@", path);  
      }    
    }
  }
  
  GWDebugLog(@"watchers: %i", NSCountMapTable(watchers));
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
  
  if (watcher) {
    GWDebugLog(@"remove listener for: %@", path);
    [info removeWatchedPath: path];    
  	[watcher removeListener];  
  }
  
  GWDebugLog(@"watchers: %i", NSCountMapTable(watchers));
}

- (Watcher *)watcherForPath:(NSString *)path
{
  return (Watcher *)NSMapGet(watchers, path);
}

- (Watcher *)watcherWithWatchDescriptor:(int)wd
{
  return (Watcher *)NSMapGet(watchDescrMap, (void *)wd);
}

- (void)removeWatcher:(Watcher *)watcher
{
  NSString *path = [watcher watchedPath];
  int wd = [watcher watchDescriptor];
  
  if (wd != -1) {      
    if (inotify_rm_watch([inotifyHandle fileDescriptor], wd) != 0) {
      NSLog(@"error removing watch descriptor for: %@", path);
    }    
    NSMapRemove(watchDescrMap, (void *)wd);      
  }

  GWDebugLog(@"removed watcher for: %@", path); 
  
  RETAIN (path);
  NSMapRemove(watchers, path);  
  RELEASE (path);
}

- (void)notifyClients:(NSDictionary *)info
{
  CREATE_AUTORELEASE_POOL(pool);
  NSString *path = [info objectForKey: @"path"];
  NSData *data = [NSArchiver archivedDataWithRootObject: info];
  NSUInteger i;

  for (i = 0; i < [clientsInfo count]; i++) {
    FSWClientInfo *clinfo = [clientsInfo objectAtIndex: i];
  
		if ([clinfo isWathchingPath: path]) {
			[[clinfo client] watchedPathDidChange: data];
		}
  }

  RELEASE (pool);  
}

- (void)notifyGlobalWatchingClients:(NSDictionary *)info
{
  NSUInteger i;

  for (i = 0; i < [clientsInfo count]; i++) {
    FSWClientInfo *clinfo = [clientsInfo objectAtIndex: i];

    if ([clinfo isGlobal]) {
      [[clinfo client] globalWatchedPathDidChange: info];
    }
  }
}

- (void)checkLastMovedPath:(id)sender
{
  if (lastMovedPath != nil) {  
    NSMutableDictionary *notifdict = [NSMutableDictionary dictionary];
    
    [notifdict setObject: lastMovedPath forKey: @"path"];        
    [notifdict setObject: GWWatchedPathDeleted forKey: @"event"];
    
    [self notifyGlobalWatchingClients: notifdict];   
    
    GWDebugLog(@"%@ MOVED to not indexable path", lastMovedPath);         
  }
}

static inline uint32_t eventType(uint32_t mask)
{
  uint32_t type = IN_IGNORED;

  if ((mask & IN_CREATE) == IN_CREATE) {
    type = IN_CREATE;
  } else if ((mask & IN_DELETE) == IN_DELETE) {
    type = IN_DELETE;  
  } else if ((mask & IN_DELETE_SELF) == IN_DELETE_SELF) {
    type = IN_DELETE_SELF;
  } else if ((mask & IN_MOVED_FROM) == IN_MOVED_FROM) {
    type = IN_MOVED_FROM;
  } else if ((mask & IN_MOVED_TO) == IN_MOVED_TO) {
    type = IN_MOVED_TO;
  } else if ((mask & IN_MOVE_SELF) == IN_MOVE_SELF) {
    type = IN_MOVE_SELF;
  } else if ((mask & IN_CLOSE_WRITE) == IN_CLOSE_WRITE) {
    type = IN_CLOSE_WRITE;
  } else if ((mask & IN_MODIFY) == IN_MODIFY) {
    type = IN_MODIFY;
  }
  
  return type;  
}

static inline BOOL isDotFile(NSString *path)
{
  int len = ([path length] - 1);
  static unichar sep = 0;  
  unichar c;
  int i;
  
  if (sep == 0) {
    #if defined(__MINGW32__)
      sep = '\\';	
    #else
      sep = '/';	
    #endif
  }
  
  for (i = len; i >= 0; i--) {
    c = [path characterAtIndex: i];
    
    if (c == '.') {
      if ((i > 0) && ([path characterAtIndex: (i - 1)] == sep)) {
        return YES;
      }
    }
  }
  
  return NO;  
}


/*
#define EV_GRAIN (0.2)
#define EV_TIMEOUT (0.5)

- (void)queueEvent:(NSString *)event
            atPath:(NSString *)path
           forFile:(NSString *)fname
{
  NSMutableDictionary *dict = nil;
  NSString *fullpath = path;
  NSDate *now = [NSDate date];
  BOOL exists = (event == GWFileCreatedInWatchedDirectory
                            || event == GWWatchedFileModified 
                              || event == GWWatchedPathRenamed);
  
  if (event == GWFileCreatedInWatchedDirectory
          || event == GWFileDeletedInWatchedDirectory) {
    fullpath = [path stringByAppendingPathComponent: fname];
  }
  
  dict = [eventsQueue objectForKey: fullpath];
  
  if (dict) {
    NSDate *stamp = [dict objectForKey: @"stamp"];
    NSTimeInterval interval = [now timeIntervalSinceDate: stamp];
    NSString *lastevent = [dict objectForKey: @"event"];
    BOOL didexist = (lastevent == GWFileCreatedInWatchedDirectory
                              || lastevent == GWWatchedFileModified 
                                  || lastevent == GWWatchedPathRenamed);
    
    if (exists == didexist) {
      [dict setObject: event forKey: @"event"];
    } else {
      if (interval < EV_GRAIN) {
        [eventsQueue removeObjectForKey: fullpath];
      } else {
        [dict setObject: event forKey: @"event"];
        [dict setObject: now forKey: @"stamp"];
      }
    }  
      
  } else {
    dict = [NSMutableDictionary dictionary];
    
    [dict setObject: event forKey: @"event"];
    [dict setObject: now forKey: @"stamp"];
    
    [eventsQueue setObject: dict forKey: fullpath];
  }
}

- (void)queueGlobalEvent:(NSString *)event
                 forPath:(NSString *)path
                 oldPath:(NSString *)oldpath
{
  NSMutableDictionary *dict = [globalEventsQueue objectForKey: path];
  NSDate *now = [NSDate date];
  BOOL exists = (event == GWFileCreatedInWatchedDirectory
                            || event == GWWatchedFileModified 
                              || event == GWWatchedPathRenamed);
  
  if (dict) {
    NSDate *stamp = [dict objectForKey: @"stamp"];
    NSTimeInterval interval = [now timeIntervalSinceDate: stamp];
    NSString *lastevent = [dict objectForKey: @"event"];
    BOOL didexist = (lastevent == GWFileCreatedInWatchedDirectory
                              || lastevent == GWWatchedFileModified 
                                  || lastevent == GWWatchedPathRenamed);
  
    if (exists == didexist) {
      [dict setObject: event forKey: @"event"];
    } else {
      if (interval < EV_GRAIN) {
        [eventsQueue removeObjectForKey: fullpath];
      } else {
        [dict setObject: event forKey: @"event"];
        [dict setObject: now forKey: @"stamp"];
      }
    }  
  
  } else {
    dict = [NSMutableDictionary dictionary];
    
    [dict setObject: event forKey: @"event"];
    [dict setObject: now forKey: @"stamp"];    
    if (event == GWWatchedPathRenamed) {
      [dict setObject: oldpath forKey: @"oldpath"]; 
    }
    
    [globalEventsQueue setObject: dict forKey: fullpath];
  }
}

- (void)processPendingEvents:(id)sender
{
  NSArray *paths = [eventsQueue allKeys];
  NSDate *now = [NSDate date];
  int i;
  
  RETAIN (paths);
  
  for (i = 0; i < [paths count]; i++) {
    NSString *path = [paths objectAtIndex: i];
    NSDictionary *dict = [eventsQueue objectForKey: path];
    NSDate *stamp = [dict objectForKey: @"stamp"];

    if ([now timeIntervalSinceDate: stamp] >= EV_TIMEOUT) {
      NSMutableDictionary *notifdict = [NSMutableDictionary dictionary];
      NSString *event = [dict objectForKey: @"event"];
      NSString *basepath = path;
      
      [notifdict setObject: event forKey: @"event"];
      
      if (event == GWFileCreatedInWatchedDirectory
          || event == GWFileDeletedInWatchedDirectory) {
        NSString *fname = [path lastPathComponent];    
        
        [notifdict setObject: [NSArray arrayWithObject: fname] 
                      forKey: @"files"];
        
        basepath = [path stringByDeletingLastPathComponent];          
      }
      
      [notifdict setObject: basepath forKey: @"path"];
      
      [self notifyClients: notifdict];
      
      [eventsQueue removeObjectForKey: path];
    }
  }

  RELEASE (paths);

  paths = [globalEventsQueue allKeys];
  
  for (i = 0; i < [paths count]; i++) {
    NSString *path = [paths objectAtIndex: i];
    NSDictionary *dict = [eventsQueue objectForKey: path];
    NSDate *stamp = [dict objectForKey: @"stamp"];

    if ([now timeIntervalSinceDate: stamp] >= EV_TIMEOUT) {
      NSMutableDictionary *notifdict = [NSMutableDictionary dictionary];
      NSString *event = [dict objectForKey: @"event"];
      
      [notifdict setObject: event forKey: @"event"];
      [notifdict setObject: path forKey: @"path"];
  
      if (event == GWWatchedPathRenamed) {
        [notifdict setObject: [dict objectForKey: @"oldpath"] 
                      forKey: @"oldpath"]; 
      }
    
      [self notifyGlobalWatchingClients: notifdict];
      
      [globalEventsQueue removeObjectForKey: path];
    }
  }
  
  RELEASE (paths);
}

*/


- (void)inotifyDataReady:(NSNotification *)notif
{
  NSDictionary *info = [notif userInfo];
  NSData *data = [info objectForKey: NSFileHandleNotificationDataItem];
  const void *bytes = [data bytes];
  void *limit = ((void *)bytes + [data length]);  
  unsigned evsize = sizeof(struct inotify_event);
  
  while (bytes < limit) {  
    struct inotify_event *eventp = (struct inotify_event *)bytes;
    uint32_t type = eventType(eventp->mask);
    
    if (type != IN_IGNORED && eventp->len) {
      Watcher *watcher = [self watcherWithWatchDescriptor: eventp->wd];
      
      if (watcher) {
        CREATE_AUTORELEASE_POOL(arp);
        NSMutableDictionary *notifdict = [NSMutableDictionary dictionary];
        NSString *basepath = [watcher watchedPath];
        NSString *fullpath = basepath;
        NSString *fname = [NSString stringWithUTF8String: eventp->name];         
        NSString *ext = [[fname pathExtension] lowercaseString];
        BOOL dirwatch = [watcher isDirWatcher];
        BOOL notify = YES;
        
        [notifdict setObject: basepath forKey: @"path"];
            
        if (dirwatch) {    
          if (type == IN_DELETE_SELF || type == IN_MOVE_SELF) {     
            [notifdict setObject: GWWatchedPathDeleted forKey: @"event"];
            
          } else if (type == IN_DELETE || type == IN_MOVED_FROM) {
            [notifdict setObject: [NSArray arrayWithObject: fname] 
                          forKey: @"files"];            
            [notifdict setObject: GWFileDeletedInWatchedDirectory 
                          forKey: @"event"];
            fullpath = [basepath stringByAppendingPathComponent: fname];
                           
          } else if (type == IN_CREATE || type == IN_MOVED_TO) {
            [notifdict setObject: [NSArray arrayWithObject: fname] 
                          forKey: @"files"];            
            [notifdict setObject: GWFileCreatedInWatchedDirectory 
                          forKey: @"event"];
            fullpath = [basepath stringByAppendingPathComponent: fname];
              
          } else if (type == IN_MODIFY) {
            [notifdict setObject: GWWatchedFileModified forKey: @"event"];
            fullpath = [basepath stringByAppendingPathComponent: fname];
            
            if ([self watcherForPath: fullpath] != nil) { 
              [notifdict setObject: fullpath forKey: @"path"];
            } else {
              fullpath = basepath;
              notify = NO;               
            }
            
          } else {
            notify = NO;
          }
          
        } else {
          if (type == IN_MODIFY || type == IN_CLOSE_WRITE) {
            [notifdict setObject: GWWatchedFileModified forKey: @"event"];
          } else if (type == IN_DELETE_SELF || type == IN_MOVE_SELF) {
            [notifdict setObject: GWWatchedPathDeleted forKey: @"event"];          
          } else {
            notify = NO;
          }
        }   
        
        if (notify) {
          [self notifyClients: notifdict];
        }         
                
        notify = (notify && ([excludedSuffixes containsObject: ext] == NO)
                   && (isDotFile(fullpath) == NO) 
                   && inTreeFirstPartOfPath(fullpath, includePathsTree)
                   && (inTreeFirstPartOfPath(fullpath, excludePathsTree) == NO));
        
        if (notify) {
          [notifdict removeAllObjects]; 
          
          [notifdict setObject: fullpath forKey: @"path"];
          
          if (type == IN_DELETE || type == IN_DELETE_SELF 
                                        || type == IN_MOVE_SELF) {       
            [notifdict setObject: GWWatchedPathDeleted forKey: @"event"];
            GWDebugLog(@"DELETE %@", fullpath); 
            
          } else if (type == IN_CREATE) {
            [notifdict setObject: GWFileCreatedInWatchedDirectory 
                          forKey: @"event"];        
            GWDebugLog(@"CREATED %@", fullpath); 
                     
          } else if (type == IN_MODIFY 
                        || ((dirwatch == NO) && type == IN_CLOSE_WRITE)) {
            [notifdict setObject: GWWatchedFileModified forKey: @"event"];        
            GWDebugLog(@"MODIFIED %@", fullpath); 
                 
          } else if (type == IN_MOVED_FROM) {  
            ASSIGN (lastMovedPath, fullpath);
            moveCookie = eventp->cookie;          
            notify = NO;
            GWDebugLog(@"MOVE from indexable path: %@", fullpath);
            
            [NSTimer scheduledTimerWithTimeInterval: 0.1 
                                 target: self 
          										 selector: @selector(checkLastMovedPath:) 
                               userInfo: nil 
                                repeats: NO];
            
          } else if (type == IN_MOVED_TO) {              
            if ((eventp->cookie == moveCookie) && (lastMovedPath != nil)) {
              [notifdict setObject: lastMovedPath forKey: @"oldpath"];
              [notifdict setObject: GWWatchedPathRenamed forKey: @"event"];
              GWDebugLog(@"MOVED from: %@ to: %@", lastMovedPath, fullpath);
            
            } else {
              [notifdict setObject: GWFileCreatedInWatchedDirectory 
                            forKey: @"event"];             
              GWDebugLog(@"MOVED from not indexable path: %@", fullpath); 
            }
            
            DESTROY (lastMovedPath);
            moveCookie = 0;
          
          } else {
            notify = NO;
          }
          
          if (notify) {
            [self notifyGlobalWatchingClients: notifdict];
          }                   
        } 
        
        RELEASE (arp);
      }    
    }
    
    bytes += (evsize + eventp->len);
  }
      
  [inotifyHandle readInBackgroundAndNotify];
}

@end


@implementation Watcher

- (void)dealloc
{ 
  RELEASE (watchedPath);  
  [super dealloc];
}

- (id)initWithWatchedPath:(NSString *)path
          watchDescriptor:(int)wdesc
                fswatcher:(id)fsw
{
  self = [super init];
  
  if (self) { 
    NSFileManager *fm = [NSFileManager defaultManager];
		NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: YES];
    		
    ASSIGN (watchedPath, path); 
    watchDescriptor = wdesc;    
    isdir = ([attributes fileType] == NSFileTypeDirectory);        
    listeners = 1;
    fswatcher = fsw;
  }
  
  return self;
}

- (void)addListener
{
  listeners++;
}

- (void)removeListener
{ 
  listeners--;
  if (listeners <= 0) {     
    [fswatcher removeWatcher: self];
  } 
}

- (BOOL)isWathcingPath:(NSString *)apath
{
  return ([watchedPath isEqual: apath]);
}

- (NSString *)watchedPath
{
	return watchedPath;
}

- (int)watchDescriptor
{
  return watchDescriptor;
}

- (BOOL)isDirWatcher
{
  return isdir;
}

@end


int main(int argc, char** argv)
{
  CREATE_AUTORELEASE_POOL(pool);
  NSProcessInfo *info = [NSProcessInfo processInfo];
  NSMutableArray *args = AUTORELEASE ([[info arguments] mutableCopy]);
  BOOL subtask = YES;

  if ([[info arguments] containsObject: @"--auto"] == YES)
  {
    auto_stop = YES;
  }
    
  if ([[info arguments] containsObject: @"--daemon"])
  {
    subtask = NO;
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

