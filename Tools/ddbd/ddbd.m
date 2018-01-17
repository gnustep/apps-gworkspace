/* ddbd.m
 *  
 * Copyright (C) 2004-2018 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 *         Riccardo Mottola <rm@gnu.org>
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

#import <AppKit/AppKit.h>
#import "DBKBTreeNode.h"
#import "DBKVarLenRecordsFile.h"
#import "ddbd.h"
#import "DDBPathsManager.h"
#import "DDBDirsManager.h"
#include "config.h"

#define GWDebugLog(format, args...) \
  do { if (GW_DEBUG_LOG) \
    NSLog(format , ## args); } while (0)
    
enum {   
  DDBdInsertTreeUpdate,
  DDBdRemoveTreeUpdate,
  DDBdFileOperationUpdate
};

static DDBPathsManager *pathsManager = nil; 
static NSRecursiveLock *pathslock = nil; 
static DDBDirsManager *dirsManager = nil; 
static NSRecursiveLock *dirslock = nil; 

static NSFileManager *fm = nil;

static BOOL	auto_stop = NO;		/* Should we shut down when unused? */


@implementation	DDBd

- (void)dealloc
{
  if (conn)
    {
      [nc removeObserver: self
                    name: NSConnectionDidDieNotification
                  object: conn];
    }

  RELEASE (dbdir);
            
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {   
    NSString *basepath;
    BOOL isdir;
    
    fm = [NSFileManager defaultManager];
    
    basepath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    ASSIGN (dbdir, [basepath stringByAppendingPathComponent: @"ddbd"]);

    if (([fm fileExistsAtPath: dbdir isDirectory: &isdir] &isdir) == NO) {
      if ([fm createDirectoryAtPath: dbdir attributes: nil] == NO) { 
        NSLog(@"unable to create: %@", dbdir);
        DESTROY (self);
        return self;
      }
    }

    nc = [NSNotificationCenter defaultCenter];
               
    conn = [NSConnection defaultConnection];
    [conn setRootObject: self];
    [conn setDelegate: self];

    if ([conn registerName: @"ddbd"] == NO) {
	    NSLog(@"unable to register with name server - quitting.");
	    DESTROY (self);
	    return self;
	  }
          
    [nc addObserver: self
           selector: @selector(connectionBecameInvalid:)
	             name: NSConnectionDidDieNotification
	           object: conn];

    [nc addObserver: self
       selector: @selector(threadWillExit:)
           name: NSThreadWillExitNotification
         object: nil];    
    
    pathsManager = [[DDBPathsManager alloc] initWithBasePath: dbdir];
    pathslock = [NSRecursiveLock new];
    dirsManager = [[DDBDirsManager alloc] initWithBasePath: dbdir];
    dirslock = [NSRecursiveLock new];
        
    NSLog(@"ddbd started");    
  }
  
  return self;    
}

- (BOOL)dbactive
{
  return YES;
}

- (oneway void)insertPath:(NSString *)path
{
  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];

  if (attributes) {
    [pathslock lock];
    [pathsManager addPath: path];
    [pathslock unlock];
    
    if ([attributes fileType] == NSFileTypeDirectory) {
      [dirslock lock];
      [dirsManager addDirectory: path];
      [dirslock unlock];
    }
  }
}

- (oneway void)removePath:(NSString *)path
{
  [pathslock lock];
  [pathsManager removePath: path];
  [pathslock unlock];
  
  [dirslock lock];
  [dirsManager removeDirectory: path];
  [dirslock unlock];
}

- (void)insertDirectoryTreesFromPaths:(NSData *)info
{
  NSArray *paths = [NSUnarchiver unarchiveObjectWithData: info];
  NSMutableDictionary *updaterInfo = [NSMutableDictionary dictionary];
  NSDictionary *dict = [NSDictionary dictionaryWithObject: paths 
                                                   forKey: @"paths"];
    
  [updaterInfo setObject: [NSNumber numberWithInt: DDBdInsertTreeUpdate] 
                  forKey: @"type"];
  [updaterInfo setObject: dict forKey: @"taskdict"];

  NS_DURING
    {
      [NSThread detachNewThreadSelector: @selector(updaterForTask:)
		                           toTarget: [DBUpdater class]
		                         withObject: updaterInfo];
    }
  NS_HANDLER
    {
      NSLog(@"A fatal error occurred while detaching the thread!");
    }
  NS_ENDHANDLER
}

- (void)removeTreesFromPaths:(NSData *)info
{
  NSArray *paths = [NSUnarchiver unarchiveObjectWithData: info];
  NSMutableDictionary *updaterInfo = [NSMutableDictionary dictionary];
  NSDictionary *dict = [NSDictionary dictionaryWithObject: paths 
                                                   forKey: @"paths"];

  [updaterInfo setObject: [NSNumber numberWithInt: DDBdRemoveTreeUpdate] 
                  forKey: @"type"];
  [updaterInfo setObject: dict forKey: @"taskdict"];

  NS_DURING
    {
      [NSThread detachNewThreadSelector: @selector(updaterForTask:)
		                           toTarget: [DBUpdater class]
		                         withObject: updaterInfo];
    }
  NS_HANDLER
    {
      NSLog(@"A fatal error occurred while detaching the thread!");
    }
  NS_ENDHANDLER
}

- (NSData *)directoryTreeFromPath:(NSString *)apath
{  
  NSArray *directories;  
  NSData *data = nil;
  
  [dirslock lock];
  directories = [dirsManager dirsFromPath: apath];
  [dirslock unlock];
    
  if ([directories count]) { 
    data = [NSArchiver archivedDataWithRootObject: directories]; 
  } 
  
  return data;
}

- (NSArray *)userMetadataForPath:(NSString *)apath
{
  NSArray *usrdata = nil;
  
  [pathslock lock];
  usrdata = [pathsManager metadataForPath: apath];
  [pathslock unlock];

  return usrdata;
}

- (NSString *)annotationsForPath:(NSString *)path
{
  NSString *annotations = nil;
  
  [pathslock lock];
  annotations = [pathsManager metadataOfType: @"GSMDItemFinderComment" 
                                     forPath: path];
  [pathslock unlock];

  return annotations;
}

- (oneway void)setAnnotations:(NSString *)annotations
                      forPath:(NSString *)path
{
  [pathslock lock];
  [pathsManager setMetadata: annotations 
                     ofType: @"GSMDItemFinderComment" 
                    forPath: path];
  [pathslock unlock];                    
}

- (NSTimeInterval)timestampOfPath:(NSString *)path
{
  NSTimeInterval interval;

  [pathslock lock];
  interval = [pathsManager timestampOfPath: path];
  [pathslock unlock];
  
  return interval;
}

- (oneway void)fileSystemDidChange:(NSData *)info
{
  NSDictionary *dict = [NSUnarchiver unarchiveObjectWithData: info];
  NSMutableDictionary *updaterInfo = [NSMutableDictionary dictionary];
    
  [updaterInfo setObject: [NSNumber numberWithInt: DDBdFileOperationUpdate] 
                  forKey: @"type"];
  [updaterInfo setObject: dict forKey: @"taskdict"];

  NS_DURING
    {
      [NSThread detachNewThreadSelector: @selector(updaterForTask:)
		                           toTarget: [DBUpdater class]
		                         withObject: updaterInfo];
    }
  NS_HANDLER
    {
      NSLog(@"A fatal error occurred while detaching the thread!");
    }
  NS_ENDHANDLER
}

- (oneway void)synchronize
{
  [pathslock lock];
  [pathsManager synchronize];
  [pathslock unlock];
  
  [dirslock lock];
  [dirsManager synchronize];
  [dirslock unlock];
}

- (void)connectionBecameInvalid:(NSNotification *)notification
{
  id connection = [notification object];

  [nc removeObserver: self
		name: NSConnectionDidDieNotification
	      object: connection];

  if (connection == conn)
    {
      NSLog(@"argh - ddbd root connection has been destroyed.");
      exit(EXIT_FAILURE);
    }
  else if (auto_stop == YES)
    {
      NSLog(@"ddbd: connection became invalid, shutting down");
      exit(EXIT_SUCCESS);
    }
}

- (BOOL)connection:(NSConnection *)ancestor
            shouldMakeNewConnection:(NSConnection *)newConn;
{
  [nc addObserver: self
         selector: @selector(connectionBecameInvalid:)
	           name: NSConnectionDidDieNotification
	         object: newConn];
           
  [newConn setDelegate: self];
  
  return YES;
}

- (void)threadWillExit:(NSNotification *)notification
{
  GWDebugLog(@"db update done");
}

@end


@implementation	DBUpdater

- (void)dealloc
{
  RELEASE (updinfo);
  [super dealloc];
}

+ (void)updaterForTask:(NSDictionary *)info
{
  CREATE_AUTORELEASE_POOL(arp);
  DBUpdater *updater = [[DBUpdater alloc] init];
  
  [updater setUpdaterTask: info];

  RELEASE (updater);
  RELEASE (arp);
}

- (void)setUpdaterTask:(NSDictionary *)info
{
  NSDictionary *dict = [info objectForKey: @"taskdict"];
  int type = [[info objectForKey: @"type"] intValue];
  
  ASSIGN (updinfo, dict);
    
  GWDebugLog(@"starting db update");

  switch(type) {
    case DDBdInsertTreeUpdate:
      [self insertTrees];
      break;

    case DDBdRemoveTreeUpdate:
      [self removeTrees];
      break;

    case DDBdFileOperationUpdate:
      [self fileSystemDidChange];
      break;

    default:
      break;
  }
}

- (void)insertTrees
{
  NSArray *paths = [updinfo objectForKey: @"paths"];
  
  [dirslock lock];
  [dirsManager insertDirsFromPaths: paths];
  [dirslock unlock];
}

- (void)removeTrees
{
  NSArray *paths = [updinfo objectForKey: @"paths"];
  
  [dirslock lock];
  [dirsManager removeDirsFromPaths: paths];
  [dirslock unlock];
}

- (void)fileSystemDidChange
{
  NSString *operation = [updinfo objectForKey: @"operation"];

  if ([operation isEqual: NSWorkspaceMoveOperation] 
                || [operation isEqual: NSWorkspaceCopyOperation]
                || [operation isEqual: NSWorkspaceDuplicateOperation]
                || [operation isEqual: @"GWorkspaceRenameOperation"]) {
    CREATE_AUTORELEASE_POOL(arp);
    NSString *source = [updinfo objectForKey: @"source"];
    NSString *destination = [updinfo objectForKey: @"destination"];
    NSArray *files = [updinfo objectForKey: @"files"];
    NSArray *origfiles = [updinfo objectForKey: @"origfiles"];
    NSMutableArray *srcpaths = [NSMutableArray array];
    NSMutableArray *dstpaths = [NSMutableArray array];
    NSUInteger i;
    
    if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
      srcpaths = [NSMutableArray arrayWithObject: source];
      dstpaths = [NSMutableArray arrayWithObject: destination];
    } else {
      if ([operation isEqual: NSWorkspaceDuplicateOperation]) { 
        for (i = 0; i < [files count]; i++) {
          NSString *fname = [origfiles objectAtIndex: i];
          [srcpaths addObject: [source stringByAppendingPathComponent: fname]];
          fname = [files objectAtIndex: i];
          [dstpaths addObject: [destination stringByAppendingPathComponent: fname]];
        }
      } else {  
        for (i = 0; i < [files count]; i++) {
          NSString *fname = [files objectAtIndex: i];
          [srcpaths addObject: [source stringByAppendingPathComponent: fname]];
          [dstpaths addObject: [destination stringByAppendingPathComponent: fname]];
        }
      }
    }
    
    [pathslock lock];
    [pathsManager duplicateDataOfPaths: srcpaths forPaths: dstpaths];
    [pathslock unlock];
    
    RELEASE (arp);
  }
}

@end


BOOL subpath(NSString *p1, NSString *p2)
{
  NSUInteger l1 = [p1 length];
  NSUInteger l2 = [p2 length];  

  if ((l1 > l2) || ([p1 isEqualToString: p2])) {
    return NO;
  } else if ([[p2 substringToIndex: l1] isEqualToString: p1]) {
    if ([[p2 pathComponents] containsObject: [p1 lastPathComponent]]) {
      return YES;
    }
  }

  return NO;
}

NSString *pathsep(void)
{
  static NSString *separator = nil;

  if (separator == nil) {
    #if defined(__MINGW32__)
      separator = @"\\";	
    #else
      separator = @"/";	
    #endif

    RETAIN (separator);
  }

  return separator;
}

NSString *removePrefix(NSString *path, NSString *prefix)
{
  if ([path hasPrefix: prefix]) {
	  return [path substringFromIndex: [path rangeOfString: prefix].length + 1];
  }

  return path;  	
}


int main(int argc, char** argv)
{
  CREATE_AUTORELEASE_POOL(pool);
  NSProcessInfo *info = [NSProcessInfo processInfo];
  NSMutableArray *args = AUTORELEASE ([[info arguments] mutableCopy]);
  BOOL subtask = YES;

  if ([args containsObject: @"--auto"] == YES)
    {
      auto_stop = YES;
    }

  if ([args containsObject: @"--daemon"])
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
	      fprintf (stderr, "unable to launch the ddbd task. exiting.\n");
	      DESTROY (task);
	    }
    NS_ENDHANDLER
      
    exit(EXIT_FAILURE);
  }
  
  RELEASE(pool);

  {
    CREATE_AUTORELEASE_POOL (pool);
	  DDBd *ddbd = [[DDBd alloc] init];
    RELEASE (pool);

    if (ddbd != nil) {
	    CREATE_AUTORELEASE_POOL (pool);
      [[NSRunLoop currentRunLoop] run];
  	  RELEASE (pool);
    }
  }
    
  exit(EXIT_SUCCESS);
}

