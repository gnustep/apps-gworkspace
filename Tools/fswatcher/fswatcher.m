/* fswatcher.m
 *  
 * Copyright (C) 2004-2018 Free Software Foundation, Inc.
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

#import "fswatcher.h"
#include "config.h"

#define GWDebugLog(format, args...) \
  do { if (GW_DEBUG_LOG) \
    NSLog(format , ## args); } while (0)

static BOOL	is_daemon = NO;		/* Currently running as daemon.	 */
static BOOL	auto_stop = NO;		/* Should we shut down when unused? */

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

- (BOOL)isWatchingPath:(NSString *)path
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
    DESTROY (conn);
  }
  
  [dnc removeObserver: self];
  
  RELEASE (clientsInfo);
  NSZoneFree (NSDefaultMallocZone(), (void *)watchers);
  freeTree(includePathsTree);
  freeTree(excludePathsTree);
  RELEASE (excludedSuffixes);

  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self)
  {    
    fm = [NSFileManager defaultManager];	
    nc = [NSNotificationCenter defaultCenter];
    dnc = [NSDistributedNotificationCenter defaultCenter];

    conn = [NSConnection defaultConnection];
    [conn setRootObject: self];
    [conn setDelegate: self];

    if ([conn registerName: @"fswatcher"] == NO)
    {
      NSLog(@"unable to register with name server - quitting.");
      DESTROY (self);
      return self;
    }
    
    clientsInfo = [NSMutableArray new]; 

    watchers = NSCreateMapTable(NSObjectMapKeyCallBacks,
	                                        NSObjectMapValueCallBacks, 0);
      
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

  NSLog(@"Connection became invalid");
  if (connection == conn)
  {
    NSLog(@"argh - fswatcher server root connection has been destroyed.");
    exit(EXIT_FAILURE);
    
  } else
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
	{
          [watcher removeListener];
        }      
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

  if ([(id)client isProxy] == YES)
  {
    [(id)client setProtocolForProxy: @protocol(FSWClientProtocol)];
    [info setClient: client];  
    [info setGlobal: global];
  }
  NSLog(@"register client %lu", (unsigned long)[clientsInfo count]);
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

  for (i = 0; i < [clientsInfo count]; i++)
    {
      FSWClientInfo *info = [clientsInfo objectAtIndex: i];
  
      if ([info connection] == connection)
	return info;
		
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
    if ([fm fileExistsAtPath: path]) {
      GWDebugLog(@"add watcher for: %@", path);     
      [info addWatchedPath: path];
  	  watcher = [[Watcher alloc] initWithWatchedPath: path fswatcher: self];      
      NSMapInsert (watchers, path, watcher);
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
    
  if (watcher && ([watcher isOld] == NO)) {
    GWDebugLog(@"remove listener for: %@", path);
    [info removeWatchedPath: path];
  	[watcher removeListener];  
  }
}

- (Watcher *)watcherForPath:(NSString *)path
{
  return (Watcher *)NSMapGet(watchers, path);
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
  NSString *path = [watcher watchedPath];
	NSTimer *timer = [watcher timer];

	if (timer && [timer isValid]) {
		[timer invalidate];
	}
  
  GWDebugLog(@"removed watcher for: %@", path);
  
  RETAIN (path);
  NSMapRemove(watchers, path);  
  RELEASE (path);
}

- (pcomp *)includePathsTree
{
  return includePathsTree;
}

- (pcomp *)excludePathsTree
{
  return excludePathsTree;
}

- (NSSet *)excludedSuffixes
{
  return excludedSuffixes;
}

static inline BOOL isDotFile(NSString *path)
{
  NSArray *components;
  NSEnumerator *e;
  NSString *c;
  BOOL found;

  if (path == nil)
    return NO;

  found = NO;
  components = [path pathComponents];
  e = [components objectEnumerator];
  while ((c = [e nextObject]) && !found)
    {
      if (([c length] > 0) && ([c characterAtIndex:0] == '.'))
	found = YES;
    }

  return found;  
}

- (BOOL)isGlobalValidPath:(NSString *)path
{
  NSString *ext = [[path pathExtension] lowercaseString];

  return (([excludedSuffixes containsObject: ext] == NO)
                   && (isDotFile(path) == NO) 
                   && inTreeFirstPartOfPath(path, includePathsTree)
                   && (inTreeFirstPartOfPath(path, excludePathsTree) == NO));
}

- (void)notifyClients:(NSDictionary *)info
{
  CREATE_AUTORELEASE_POOL(pool);
  NSString *path = [info objectForKey: @"path"];
  NSString *event = [info objectForKey: @"event"];
  NSData *data = [NSArchiver archivedDataWithRootObject: info];
  NSUInteger i;

  for (i = 0; i < [clientsInfo count]; i++)
    {
      FSWClientInfo *clinfo = [clientsInfo objectAtIndex: i];
  
      if ([clinfo isWatchingPath: path])
	{
	  [[clinfo client] watchedPathDidChange: data];
	}
    }
  
  if ([event isEqual: @"GWWatchedPathDeleted"] 
      && [self isGlobalValidPath: path])
    {
      GWDebugLog(@"DELETE %@", path);
      [self notifyGlobalWatchingClients: info];
    
    }
  else if ([event isEqual: @"GWWatchedFileModified"] 
	   && [self isGlobalValidPath: path])
    {
      GWDebugLog(@"MODIFIED %@", path);
      [self notifyGlobalWatchingClients: info];    
    
    } 
  else if ([event isEqual: @"GWFileDeletedInWatchedDirectory"])
    {
      NSArray *files = [info objectForKey: @"files"];
    
      for (i = 0; i < [files count]; i++)
	{
	  NSString *fname = [files objectAtIndex: i];
	  NSString *fullpath = [path stringByAppendingPathComponent: fname];
      
	  if ([self isGlobalValidPath: fullpath])
	    {
	      NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	      
	      [dict setObject: fullpath forKey: @"path"];
	      [dict setObject: @"GWWatchedPathDeleted" forKey: @"event"];
      
	      [self notifyGlobalWatchingClients: dict];
	    }      
	}  
  
  }
  else if ([event isEqual: @"GWFileCreatedInWatchedDirectory"])
    {
      NSArray *files = [info objectForKey: @"files"];
      
      for (i = 0; i < [files count]; i++)
	{
	  NSString *fname = [files objectAtIndex: i];
	  NSString *fullpath = [path stringByAppendingPathComponent: fname];
	  
	  if ([self isGlobalValidPath: fullpath]) {
	    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	    
	    [dict setObject: fullpath forKey: @"path"];
	    [dict setObject: @"GWFileCreatedInWatchedDirectory" forKey: @"event"];
	    
	    [self notifyGlobalWatchingClients: dict];
	  }      
	}      
    }
  
  RELEASE (pool);  
}

- (void)notifyGlobalWatchingClients:(NSDictionary *)info
{
  NSUInteger i;

  for (i = 0; i < [clientsInfo count]; i++)
    {
      FSWClientInfo *clinfo = [clientsInfo objectAtIndex: i];
      
      if ([clinfo isGlobal])
	[[clinfo client] globalWatchedPathDidChange: info];
    }
}

@end


@implementation Watcher

- (void)dealloc
{ 
  if (timer && [timer isValid])
    [timer invalidate];
 
  RELEASE (watchedPath);  
  RELEASE (pathContents);
  RELEASE (date);  
  [super dealloc];
}

- (id)initWithWatchedPath:(NSString *)path
                fswatcher:(id)fsw
{
  self = [super init];
  
  if (self)
    { 
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
        
    fswatcher = fsw;    
    listeners = 1;
		isOld = NO;
        
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

  if (isOld)
    {
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

      RELEASE (oldconts);	

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
  listeners++;
}

- (void)removeListener
{ 
  listeners--;
  if (listeners <= 0) { 
		isOld = YES;
  } 
}

- (BOOL)isWatchingPath:(NSString *)apath
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
  BOOL subtask = YES;

  if ([[info arguments] containsObject: @"--auto"] == YES)
  {
    auto_stop = YES;
  }
    
  if ([[info arguments] containsObject: @"--daemon"])
  {
    subtask = NO;
    is_daemon = YES;
  }

  if (subtask)
  {
    NSTask *task;
    
    
    task = [NSTask new];
    
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
  
    if (fsw != nil)
    {
      CREATE_AUTORELEASE_POOL (pool);
      [[NSRunLoop currentRunLoop] run];
      RELEASE (pool);
    }
  }
    
  exit(EXIT_SUCCESS);
}

