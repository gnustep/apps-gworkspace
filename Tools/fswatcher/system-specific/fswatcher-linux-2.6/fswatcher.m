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

#include <libaudit.h>
#include <sys/select.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <time.h>
#include <syscall.h>
#include "fswatcher.h"
#include "config.h"
#include "GNUstep.h"

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
		          object: recReadConn];
  DESTROY (recReadConn);

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

    recReadConn = [[NSConnection alloc] initWithReceivePort: port[0]
				                                           sendPort: port[1]];
    [recReadConn setRootObject: self];
    [recReadConn setDelegate: self];

    [nc addObserver: self
           selector: @selector(connectionBecameInvalid:)
               name: NSConnectionDidDieNotification
             object: recReadConn];    
  
    NS_DURING
      {
        [NSThread detachNewThreadSelector: @selector(recordsReader:)
		                             toTarget: [FSWRecordsReader class]
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

- (oneway void)logDataReady:(NSData *)data
{
  CREATE_AUTORELEASE_POOL(pool);
  audit_record *rec = (audit_record *)[data bytes];
  NSString *path = nil;
  NSString *basePath = nil;    
  NSString *destPath = nil;
  NSString *destBasePath = nil;
  BOOL notify;
  BOOL globnotify;

  path = [NSString stringWithUTF8String: rec->fullpath];
  path = [path stringByStandardizingPath];
  basePath = [path stringByDeletingLastPathComponent];

  if (rec->syscall == __NR_rename) {
    destPath = [NSString stringWithUTF8String: rec->destpath];
    destPath = [destPath stringByStandardizingPath];
    destBasePath = [destPath stringByDeletingLastPathComponent];
  }

  notify = [watchedPaths containsObject: path];
  globnotify = ((isDotFile(path) == NO) 
                      && inTreeFirstPartOfPath(path, includePathsTree)
                  && ((inTreeFirstPartOfPath(path, excludePathsTree) == NO)
                                    || fullPathInTree(path, includePathsTree)));

  if (notify || globnotify) {
    NSMutableDictionary *notifdict = [NSMutableDictionary dictionary];
    BOOL glob = globnotify;

    [notifdict setObject: path forKey: @"path"];

    switch (rec->syscall) { 
      case __NR_open:
      case __NR_creat:
      case __NR_mkdir:
        [notifdict setObject: @"GWWatchedFileModified" forKey: @"event"];
        GWDebugLog(@"MODIFIED %@", path);        
        break;

      case __NR_unlink:
      case __NR_rmdir:
      case __NR_rename:
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

    switch (rec->syscall) { 
      case __NR_open:
      case __NR_creat:
      case __NR_mkdir:
        [notifdict setObject: @"GWFileCreatedInWatchedDirectory" forKey: @"event"];
        [notifdict setObject: [NSArray arrayWithObject: [path lastPathComponent]] 
                      forKey: @"files"];
        GWDebugLog(@"CREATE %@", path);
        break;

      case __NR_unlink:
      case __NR_rmdir:
        [notifdict setObject: @"GWFileDeletedInWatchedDirectory" forKey: @"event"];
        [notifdict setObject: [NSArray arrayWithObject: [path lastPathComponent]] 
                      forKey: @"files"];
        GWDebugLog(@"DELETE %@", path);
        break;

      case __NR_rename:
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
                      && (isDotFile(path) == NO)
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

  
  if (isDotFile(path) == NO) {
    printf("sec %ld\n", rec->sec); 
    printf("milli %ld\n", rec->milli); 
    printf("serial %ld\n", rec->serial); 
    printf("syscall %ld\n", rec->syscall); 

    printf("basepath %s\n", rec->basepath);
    printf("fullpath %s\n", rec->fullpath);
    if (rec->syscall == __NR_rename) {
      printf("destpath %s\n", rec->destpath);
    }

    printf("\n"); 
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


audit_record record;
unsigned long reclen;

enum {
  OTHER,
  SYSCALL,
  CWD,
  PATH
};

static BOOL parseAuditLine(char *line);

static BOOL checkSyscall(unsigned call);

static BOOL checkRecordId(unsigned long serial, 
                                unsigned long sec, unsigned long milli);
                                
static BOOL recordIsComplete(void);                               
                                
static void resetRecord(void);

static BOOL reservedPath(char *path);                               

static BOOL plainAndModifiedPath(char *path);                               

                                
@implementation	FSWRecordsReader

+ (void)recordsReader:(NSArray *)ports
{
  CREATE_AUTORELEASE_POOL(arp);
  FSWRecordsReader *reader = [[FSWRecordsReader alloc] initWithPorts: ports];

  [reader readLoop];

  RELEASE (reader);  
  RELEASE (arp);
}

- (void)dealloc
{
  RELEASE (logPath);
  RELEASE (logDir);
  
  [super dealloc];
}

- (id)initWithPorts:(NSArray *)ports
{
  self = [super init];
  
  if (self) {    
    NSPort *port[2];
    NSConnection *conn;
    id anObject;
    
    fm = [NSFileManager defaultManager];
    
    ASSIGN (logPath, [NSString stringWithString: @"/var/log/audit/audit.log"]);
    ASSIGN (logDir, [logPath stringByDeletingLastPathComponent]);
    
    port[0] = [ports objectAtIndex: 0];             
    port[1] = [ports objectAtIndex: 1];             

    conn = [NSConnection connectionWithReceivePort: (NSPort *)port[0]
                                          sendPort: (NSPort *)port[1]];

    anObject = (id)[conn rootProxy];
    [anObject setProtocolForProxy: @protocol(FSWatcherProtocol)];
    fsw = (id <FSWatcherProtocol>)anObject;
    
    reclen = sizeof(audit_record);    
    resetRecord();    
  }
  
  return self;    
}

- (void)readLoop
{  
  while (1) {
    stream = fopen([logPath UTF8String], "r");

	  if (stream == NULL) {
		  fprintf(stderr, "Error opening the log file\n");
		  exit(0);
	  }
    
    fseek(stream, 0, SEEK_END);

    [self readRecords];

    fclose(stream);
  }
}

- (void)readRecords
{
  const char *basedir = [logDir UTF8String];
  struct stat dirstat;
  time_t modtime;
	char *buff;
	char *rc;
  struct timespec request;
  
  stat(basedir, &dirstat);
  modtime = dirstat.st_mtime;
  
  buff = malloc(MAX_AUDIT_MESSAGE_LENGTH);
  if (buff == NULL) {
		exit(0);
  }

  while (1) {    
    stat(basedir, &dirstat);
    
    if (dirstat.st_mtime != modtime) {
      free(buff);
      return;
    }
    
    rc = fgets(buff, MAX_AUDIT_MESSAGE_LENGTH, stream);
    
    if (rc) {
      if (parseAuditLine(buff) && recordIsComplete()) {
        BOOL sendfsw = YES;

        if (record.syscall == __NR_open) {
          sendfsw = plainAndModifiedPath(record.fullpath);
        }

        if (sendfsw) {
          CREATE_AUTORELEASE_POOL(pool);
          NSData *data = [NSData dataWithBytes: &record length: reclen];

          [fsw logDataReady: data];
          resetRecord();

          RELEASE (pool);
        }  
      }
                
    } else { 
      request.tv_sec = (time_t)0;
      request.tv_nsec = (long)0;      
      nanosleep(&request, 0);
    }
  }
      
  free(buff);
}

@end


static BOOL parseAuditLine(char *line)
{
  char *buff = strdup(line);
  char *ptr;
  char *eptr;
  unsigned type;
  unsigned long serial;
  unsigned long sec;
  unsigned long milli;
  BOOL success;
      
#define CHKPTR(p) \
do { \
if (p == NULL) { \
free(buff); \
resetRecord(); \
return NO; \
} \
} while (0)

#define RESET_RETURN \
resetRecord(); \
free(buff); \
return NO

  /* type */
  ptr = strtok(buff, "=");
  CHKPTR (ptr);
  
  ptr = strtok(NULL, " ");
  CHKPTR (ptr);
    
  if (strcmp(ptr, "SYSCALL") == 0) {
    type = SYSCALL;
  } else if (strcmp(ptr, "CWD") == 0) {
    type = CWD;
  } else if (strcmp(ptr, "PATH") == 0) {
    type = PATH;
  } else {
    type = OTHER;
  }
      
  if (type != OTHER) {  
    /* event id */
    ptr = strtok(NULL, ")");
    CHKPTR (ptr);
    
    eptr = strchr(ptr, '(');
    CHKPTR (eptr);
    eptr++;
    CHKPTR (eptr);
    
    errno = 0;
    ptr = strchr(eptr, ':');
    CHKPTR (ptr);
    serial = strtoul(ptr+1, NULL, 10);
    *ptr = 0;
    
    ptr = strchr(eptr, '.');
    CHKPTR (ptr);
    milli = strtoul(ptr+1, NULL, 10);
    *ptr = 0;
    
    sec = strtoul(eptr, NULL, 10);

    if (checkRecordId(serial, sec, milli) == NO) {
      resetRecord();
      record.serial = serial;
      record.sec = sec;
      record.milli = milli;    
    }
        
    if ((type == SYSCALL) && (!record.has_syscall)) {
      /* syscall number */
      ptr = strtok(NULL, "=");
      CHKPTR (ptr);
      ptr = strtok(NULL, " ");
      CHKPTR (ptr);
      ptr = strtok(NULL, "=");
      CHKPTR (ptr);
      ptr = strtok(NULL, " ");
      CHKPTR (ptr);       
      record.syscall = strtoul(ptr, NULL, 10); 
      record.has_syscall = 1;
   
      if (checkSyscall(record.syscall) == NO) {
        RESET_RETURN;
      }
      
      /* success */
      ptr = strtok(NULL, "=");
      CHKPTR (ptr);    
      ptr = strtok(NULL, " ");
      CHKPTR (ptr);    
      success = (strcmp(ptr, "yes") == 0);
      if (success == NO) {
        RESET_RETURN;
      }

    } else if ((type == CWD) && record.has_syscall && !record.has_cwd) {
      ptr = strtok(NULL, "=");
      CHKPTR (ptr);
      ptr = strtok(NULL, "\"");
      CHKPTR (ptr);
      strcpy(record.basepath, ptr);
      record.has_cwd = 1;
      
    } else if ((type == PATH) && record.has_syscall && record.has_cwd
                                              && (!record.has_path 
                 || (record.has_path && (!record.has_second_path 
                                      && (record.syscall == __NR_rename))))) {
      ptr = strtok(NULL, "=");
      CHKPTR (ptr);
      ptr = strtok(NULL, " ");
      CHKPTR (ptr);
      ptr = strtok(NULL, "\"");
      CHKPTR (ptr);
      ptr = strtok(NULL, "\"");
      CHKPTR (ptr);
      
      if (!record.has_path) {
        if (ptr[0] == '/') {
          strcpy(record.fullpath, ptr);
        } else {
          sprintf(record.fullpath, "%s/%s", record.basepath, ptr);
        }
        
        if (reservedPath(record.fullpath)) {
          RESET_RETURN;
        }
        
        record.has_path = 1;
        
      } else if (!record.has_second_path && (record.syscall == __NR_rename)) {
        if (ptr[0] == '/') {
          strcpy(record.destpath, ptr);
        } else {
          sprintf(record.destpath, "%s/%s", record.basepath, ptr);
        }
      
        record.has_second_path = 1;

      } else {   
        RESET_RETURN;
      }
      
    } else {
      RESET_RETURN;
    }
    
  } else {
    RESET_RETURN;
  }
  
  free(buff);
  
  return YES;
}

static BOOL checkSyscall(unsigned call)
{
  // touch = __NR_open __NR_utime
  // da nedit se il file non c'e': __NR_open __NR_creat 
  // save da nedit __NR_open 
  // rm = __NR_lstat64 __NR_access __NR_unlink

/*
auditctl -a exit,always -S open
auditctl -a exit,always -S creat
auditctl -a exit,always -S mkdir
auditctl -a exit,always -S rmdir
auditctl -a exit,always -S unlink
auditctl -a exit,always -S rename




auditctl -a exit,always -S open -w /root
auditctl -a exit,always -S creat -w /root
auditctl -a exit,always -S mkdir -w /root
auditctl -a exit,always -S rmdir -w /root
auditctl -a exit,always -S unlink -w /root
auditctl -a exit,always -S rename -w /root


auditctl -a watch,always -S open 
auditctl -a watch,always -S creat 
auditctl -a watch,always -S mkdir 
auditctl -a watch,always -S rmdir 
auditctl -a watch,always -S unlink
auditctl -a watch,always -S rename

*/

  return ((call == __NR_open) || (call == __NR_creat)
          || (call == __NR_mkdir) || (call == __NR_rmdir)
          || (call == __NR_unlink) || (call == __NR_rename));
}

static BOOL checkRecordId(unsigned long serial,
                                unsigned long sec, unsigned long milli)
{
  return ((record.serial == serial) 
                  && (record.sec == sec) && (record.milli == milli));
}

static BOOL recordIsComplete()
{
  BOOL complete = (record.has_syscall && record.has_cwd && record.has_path);  

  if (complete && (record.syscall == __NR_rename)) {
    complete = (record.has_second_path);
  }
  
  return complete;
}

static void resetRecord()
{
  memset(&record, 0, reclen);
}

static BOOL reservedPath(char *path)
{
  const char *reserved[3] = { "/proc", "/dev", "/tmp" };
  unsigned count = 3;
  unsigned i;
  
  for (i = 0; i < count; i++) {
    unsigned c = 0;

    while (path[c] == reserved[i][c]) {
      c++;
    }
    
    if (c == strlen(reserved[i])) {
      return YES;
    }  
  }
    
  return NO;
}

static BOOL plainAndModifiedPath(char *path)
{
  struct stat ptstat;

  if ((lstat(path, &ptstat) == 0) && S_ISREG(ptstat.st_mode)) {
    time_t now = time(&now);
    
    return ((difftime(now, ptstat.st_ctime) < 5.0)
                      || difftime(now, ptstat.st_mtime) < 5.0);
  } 
  
  return NO;
}

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

