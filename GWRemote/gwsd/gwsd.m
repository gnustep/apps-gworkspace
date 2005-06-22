/* gwsd.m
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
 *
 * This file is part of the GNUstep gwsd tool
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

#include <AppKit/AppKit.h>
#include "gwsd.h"
#include "FileOp.h"
#include "externs.h"
#include "Functions.h"

#define byname 0
#define bykind 1
#define bydate 2
#define bysize 3
#define byowner 4

#define MAX_FILE_SIZE 41200

#ifndef CACHED_MAX
  #define CACHED_MAX 20;
#endif

static GWSd *shared = nil;

@implementation GWSd

+ (void)initialize
{
  /*                                                           */
  /* only the thread that sends the first message to the class */
  /* will execute the initialize method.                       */
  /*                                                           */
  
  if ([self class] == [GWSd class]) {
	  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	  id entry = [defaults objectForKey: @"cachedmax"];
    if (entry) {
      cachedMax = [entry intValue];
    } else {  
      cachedMax = CACHED_MAX;
    }
    
    cachedContents = [NSMutableDictionary new];
    gwsdLock = [NSRecursiveLock new];  
    
    [GWSd sharedGWSd];              
  }
}

+ (GWSd *)sharedGWSd
{
  /*                                                         */
  /* we use this shared istance for notifications that must  */
  /* be received by all the others.                          */
  /*                                                         */

	if (shared == nil) {
		shared = [[GWSd alloc] init];
	}	
  return shared;
}

- (id)initWithRemote:(id)remote 
          connection:(NSConnection *)aConnection
{  
	self = [super init];

  if(self) {
	  NSUserDefaults *defaults;
	  id entry;
       
	  defaults = [NSUserDefaults standardUserDefaults];

	  entry = [defaults objectForKey: @"defaultsorttype"];	
	  if (entry == nil) { 
		  [defaults setObject: @"0" forKey: @"defaultsorttype"];
		  defSortType = byname;
	  } else {
		  defSortType = [entry intValue];
	  }

    entry = [defaults objectForKey: @"GSFileBrowserHideDotFiles"];
    if (entry) {
      hideSysFiles = [entry boolValue];
    } else {  
      NSDictionary *domain = [defaults persistentDomainForName: NSGlobalDomain];

      entry = [domain objectForKey: @"GSFileBrowserHideDotFiles"];
      if (entry) {
        hideSysFiles = [entry boolValue];
      } else {  
        hideSysFiles = NO;
      }
    }

	  entry = [defaults objectForKey: @"shellCommand"];	
	  if (entry == nil) { 
      NSLog(@"no shell defined.\nYou must set the default shell:");
      NSLog(@"\"defaults write gwsd shellCommand \"/bin/bash\"\", for example.");
      exit(0);
	  }
    ASSIGN (shellCommand, entry);
        
    gwsdClient = nil;
        
    if (remote) {
      /*                                                                 */
      /* We get here when a new GWSd istance is created for a new thread */
      /*                                                                 */

      watchers = [NSMutableArray new];	
	    watchTimers = [NSMutableArray new];	
      
      operations = [NSMutableArray new];	
      oprefnum = 0;

      shellTasks = [NSMutableArray new];	
    
		  nc = [NSNotificationCenter defaultCenter];
      dnc = [NSDistributedNotificationCenter defaultCenter];
      fm = [NSFileManager defaultManager];
      ws = [NSWorkspace sharedWorkspace];    
      
      sharedIstance = [GWSd sharedGWSd];

      [dnc addObserver: self
              selector: @selector(fileSystemDidChange:)
                  name: GWFileSystemDidChangeNotification
                object: nil];    
     
      conn = RETAIN (aConnection);
      [conn setIndependentConversationQueueing: YES];
      [conn setRootObject: self];
      [conn setDelegate: self];

      [nc addObserver: self
             selector: @selector(connectionDidDie:)
                 name: NSConnectionDidDieNotification
               object: conn];    

      [remote setProtocolForProxy: @protocol(GWSdClientProtocol)];
      gwsdClient = (id <GWSdClientProtocol>)remote;
      
      clientLock = [NSRecursiveLock new];
    } else {
      /*                                                                   */
      /* Here, only in the main thread, we create the connection that      */
      /* will be used by our clients to connect.                           */
      /* This connection will be substitudted with a not named connection, */
      /* that is, a new connection for each thread/client,                 */
      /* in +newThreadWithRemote:                                          */
      /*                                                                   */

      NSProcessInfo *proc = [NSProcessInfo processInfo];
      NSArray *args = [proc arguments];
      NSString *passwd;

      if ([args count] < 2) {
        NSLog(@"Missing password\nUsage: gwsd PASSWORD");
        exit(0);
      }

      passwd = [args objectAtIndex: 1];

      if ([passwd length] < 8) {
        NSLog(@"Invalid password\nThe password must have altmost 8 characters");
        exit(0);
      }

      ASSIGN (userPassword, passwd);
      ASSIGN (userName, NSUserName());

      firstConn = [[NSConnection alloc] initWithReceivePort: (NSPort *)[NSSocketPort port] 
																			             sendPort: nil];
      [firstConn enableMultipleThreads];
      [firstConn setRootObject: self];
      [firstConn registerName: @"gwsd"];
      [firstConn setDelegate: self];

      [[NSNotificationCenter defaultCenter] addObserver: self
             selector: @selector(connectionDidDie:)
                 name: NSConnectionDidDieNotification
               object: firstConn];    
    }
  }
    
	return self;
}

+ (void)newThreadWithRemote:(id<GWSdClientProtocol>)remote
{
  /*                                                                      */
  /* Here, for each new client, we create a new connection and            */
  /* a new GWSd istance.                                                  */
  /* After calling -setServerConnection: on the client, we can release    */
  /* both the GWSd object and the NSConnection, because they ere retained */
  /* by the client.                                                       */
  /* This means that, when the client exits, these objects are released   */
  /* and the thread exits (I hope...).                                                */
  /*                                                                      */
  
  NSAutoreleasePool *pool;
  NSConnection *connection;
  GWSd *gwsd;
               
  pool = [[NSAutoreleasePool alloc] init];
  
  connection = [[NSConnection alloc] initWithReceivePort: (NSPort *)[NSSocketPort port] 
																			          sendPort: (NSPort *)[NSSocketPort port]];

  gwsd = [[GWSd alloc] initWithRemote: remote connection: connection];

  [remote setServerConnection: connection];
  
  RELEASE (gwsd);
  RELEASE (connection);
    
  [[NSRunLoop currentRunLoop] run];
  [pool release];
}

- (void)_registerRemoteClient:(id<GWSdClientProtocol>)remote 
{
  /*                                                                */
  /* This method is called, in the main thread, by each client that */
  /* wants to connect.                                              */
  /* A new thread is detached for each client.                      */
  /*                                                                */

  if (([userName isEqual: [remote userName]] == NO)
            || ([userPassword isEqual: [remote userPassword]] == NO)) {
    [remote connectionRefused];
    return;
  }
  
  NS_DURING
    {
      [NSThread detachNewThreadSelector: @selector(newThreadWithRemote:)
                               toTarget: [self class] 
                             withObject: remote];
    }
  NS_HANDLER
    {
      NSLog(@"Error! A fatal error occured while detaching the thread.\nRecompile your runtime with threads support.");
    }
  NS_ENDHANDLER
}

- (id<GWSdClientProtocol>)gwsdClient
{
  return gwsdClient;
}

- (NSRecursiveLock *)clientLock
{
  return clientLock;
}

- (void)connectionDidDie:(NSNotification *)notification
{
	id diedconn = [notification object];
	
  [[NSNotificationCenter defaultCenter] removeObserver: self
	                      name: NSConnectionDidDieNotification object: diedconn];

  if (diedconn == firstConn) {
		NSLog(@"argh - gwsd server root connection has been destroyed.");
		exit(1);
	} else if (diedconn == conn) {
    
      
  }
}


//
// Private methods
//
- (NSMutableDictionary *)cachedRepresentationForPath:(NSString *)path
{
  NSMutableDictionary *contents = [cachedContents objectForKey: path];
  
  if (contents) {
    NSDate *modDate = [contents objectForKey: @"moddate"];
    NSDate *date = [self modificationDateForPath: path];
  
    if ([modDate isEqualToDate: date]) {
      return contents;
    } else {
      [cachedContents removeObjectForKey: path];
    }
  }

  return nil;
}

- (void)removeCachedRepresentation
{
  NSArray *keys = [cachedContents allKeys];
  
  if ([keys count]) {
    [cachedContents removeObjectForKey: [keys objectAtIndex: 0]];
  }
}

- (BOOL)hideSysFiles
{
  return hideSysFiles;
}

- (NSArray *)checkHiddenFiles:(NSArray *)files atPath:(NSString *)path
{
  NSArray *checkedFiles;
  NSArray *hiddenFiles;
  NSString *h; 
			
	h = [path stringByAppendingPathComponent: @".hidden"];
  if ([fm fileExistsAtPath: h]) {
	  h = [NSString stringWithContentsOfFile: h];
	  hiddenFiles = [h componentsSeparatedByString: @"\n"];
	} else {
    hiddenFiles = nil;
  }
	
	if (hiddenFiles != nil  ||  hideSysFiles) {	
		NSMutableArray *mutableFiles = AUTORELEASE ([files mutableCopy]);
	
		if (hiddenFiles != nil) {
	    [mutableFiles removeObjectsInArray: hiddenFiles];
	  }
	
		if (hideSysFiles) {
	    int j = [mutableFiles count] - 1;
	    
	    while (j >= 0) {
				NSString *file = (NSString *)[mutableFiles objectAtIndex: j];

				if ([file hasPrefix: @"."]) {
		    	[mutableFiles removeObjectAtIndex: j];
		  	}
				j--;
			}
	  }		
    
		checkedFiles = mutableFiles;
    
	} else {
    checkedFiles = files;
  }

  return checkedFiles;
}

- (BOOL)verifyFileAtPath:(NSString *)path
{
	if ([fm fileExistsAtPath: path] == NO) {
    NSString *fileName = [path lastPathComponent];
    NSString *message = [NSString stringWithFormat: @"%@: no such file or directory!", fileName];

    [gwsdClient showErrorAlertWithMessage: message];

		return NO;
	}
	
	return YES;
}

- (void)dealloc
{
  [nc removeObserver: self];
  [dnc removeObserver: self];
  
  TEST_RELEASE (userName);
  TEST_RELEASE (userPassword);

  TEST_RELEASE (watchers);
  TEST_RELEASE (watchTimers);
  
  TEST_RELEASE (operations);
  
  TEST_RELEASE (shellCommand);
  TEST_RELEASE (shellTasks);
  
  TEST_RELEASE (clientLock);
  
	DESTROY (firstConn);
  DESTROY (conn);
  
	[super dealloc];	
}


//
// GWSDProtocol
//
- (void)registerRemoteClient:(id<GWSdClientProtocol>)remote
{
  return [self _registerRemoteClient: remote];
}

- (NSString *)homeDirectory
{
  return NSHomeDirectory();
}

- (BOOL)existsFileAtPath:(NSString *)path
{
  return [fm fileExistsAtPath: path];
}

- (BOOL)existsAndIsDirectoryFileAtPath:(NSString *)path
{
  BOOL isDir;
  return ([fm fileExistsAtPath: path isDirectory: &isDir] && isDir);
}

- (NSString *)typeOfFileAt:(NSString *)path
{
  NSString *defApp, *type;
  
  [ws getInfoForFile: path application: &defApp type: &type];
  
  return type;
}

- (BOOL)isPakageAtPath:(NSString *)path
{
	NSString *defApp, *type;
		
	[ws getInfoForFile: path application: &defApp type: &type];  
	
	if (type == NSApplicationFileType) {
		return YES;
	} else if (type == NSPlainFileType) {
    return [self existsAndIsDirectoryFileAtPath: path];
  }
	
  return NO;
}

- (NSDictionary *)fileSystemAttributesAtPath:(NSString *)path
{
  return [fm fileSystemAttributesAtPath: path];
}

- (BOOL)isWritableFileAtPath:(NSString *)path
{
  return [fm isWritableFileAtPath: path];
}

- (NSDate *)modificationDateForPath:(NSString *)path
{
  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: YES];  

  return [attributes fileModificationDate];
}

- (int)sortTypeForDirectoryAtPath:(NSString *)aPath
{
  if ([fm isWritableFileAtPath: aPath]) {
    NSString *dictPath = [aPath stringByAppendingPathComponent: @".gwsort"];
    
    if ([fm fileExistsAtPath: dictPath]) {
      NSDictionary *sortDict = [NSDictionary dictionaryWithContentsOfFile: dictPath];
       
      if (sortDict) {
        return [[sortDict objectForKey: @"sort"] intValue];
      }   
    }
  } 
  
	return defSortType;
}

- (void)setSortType:(int)type forDirectoryAtPath:(NSString *)aPath
{
  if ([fm isWritableFileAtPath: aPath]) {
    NSString *sortstr = [NSString stringWithFormat: @"%i", type];
    NSDictionary *dict = [NSDictionary dictionaryWithObject: sortstr 
                                                     forKey: @"sort"];
    [dict writeToFile: [aPath stringByAppendingPathComponent: @".gwsort"] 
           atomically: YES];
  }
  
//	[[NSNotificationCenter defaultCenter]
// 				 postNotificationName: GWSortTypeDidChangeNotification
//	 								     object: (id)aPath];  
}

- (NSDictionary *)directoryContentsAtPath:(NSString *)path 
{
  NSMutableDictionary *contentsDict;
  NSArray *files;
  NSMutableArray *sortfiles;
  NSMutableArray *paths; 
  NSString *s; 
  int i, count;
  int stype;
  
  if ([self existsAndIsDirectoryFileAtPath: path] == NO) {	
    return nil;
  } 

  [gwsdLock lock];
  contentsDict = [self cachedRepresentationForPath: path];
  [gwsdLock unlock];
  if (contentsDict) {
    return contentsDict;
  }

  files = [self checkHiddenFiles: [fm directoryContentsAtPath: path] 
                          atPath: path];

  count = [files count];
  if (count == 0) {
		return nil;
	}

  paths = [NSMutableArray arrayWithCapacity: count];

  for (i = 0; i < count; ++i) {
    s = [path stringByAppendingPathComponent: [files objectAtIndex: i]];
    [paths addObject: s];
  }

	stype = [self sortTypeForDirectoryAtPath: path]; 

  paths = AUTORELEASE ([[paths sortedArrayUsingFunction: (int (*)(id, id, void*))comparePaths
                                      context: (void *)stype] mutableCopy]);

  sortfiles = [NSMutableArray arrayWithCapacity: 1];
  for (i = 0; i < count; ++i) {
    [sortfiles addObject: [[paths objectAtIndex: i] lastPathComponent]];
  }  

  contentsDict = [NSMutableDictionary dictionary];
  [contentsDict setObject: [NSDate date] forKey: @"datestamp"];
  [contentsDict setObject: [self modificationDateForPath: path] forKey: @"moddate"];
  [contentsDict setObject: sortfiles forKey: @"files"];

  [gwsdLock lock];
  if ([cachedContents count] <= cachedMax) {
    [self removeCachedRepresentation];
  }

  [cachedContents setObject: contentsDict forKey: path];
  [gwsdLock unlock];
    
  return contentsDict;
}

- (NSString *)contentsOfFileAt:(NSString *)path
{
  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: YES];
  long fsize = [[attributes objectForKey: @"NSFileSize"] longValue];

  if (fsize >= MAX_FILE_SIZE) {
    return nil;
  } else {
    return [NSString stringWithContentsOfFile: path];
  }  
}

- (BOOL)saveString:(NSString *)str atPath:(NSString *)path
{
  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: YES];

  if ([str writeToFile: path atomically: YES]) {
    if (attributes) {
      [fm changeFileAttributes: attributes atPath: path];
    }
    return YES;
  }
  
  return NO;
}

- (void)addWatcherForPath:(NSString *)path
{
  [self _addWatcherForPath: path];
}

- (void)removeWatcherForPath:(NSString *)path
{
  [self _removeWatcherForPath: path];
}

- (oneway void)performLocalFileOperationWithDictionary:(id)opdict
{
  LocalFileOp *op = [[LocalFileOp alloc] initWithOperationDescription: opdict
                                        forGWSd: self withClient: gwsdClient];
  [operations addObject: op];
  RELEASE (op);
}

- (BOOL)pauseFileOpeRationWithRef:(int)ref
{
  LocalFileOp *op = [self fileOpWithRef: ref];
  return (op && [op pauseOperation]);
}

- (BOOL)continueFileOpeRationWithRef:(int)ref
{
  LocalFileOp *op = [self fileOpWithRef: ref];
  return (op && [op continueOperation]);
}

- (BOOL)stopFileOpeRationWithRef:(int)ref
{
  LocalFileOp *op = [self fileOpWithRef: ref];
  return (op && [op stopOperation]);
}

- (oneway void)renamePath:(NSString *)oldname toNewName:(NSString *)newname
{
  NSString *basepath = [oldname stringByDeletingLastPathComponent];
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  NSString *message;
  
  if ([fm isWritableFileAtPath: oldname] == NO) {
    message = [NSString stringWithFormat: 
                    @"You do not have write permission\nfor \"%@\"!", 
                                          [oldname lastPathComponent]];
    [gwsdClient showErrorAlertWithMessage: message];
    return;
    
  } else if ([fm isWritableFileAtPath: basepath] == NO) {	
    message = [NSString stringWithFormat: 
                    @"You do not have write permission\nfor \"%@\"!", 
                                          [basepath lastPathComponent]];
    [gwsdClient showErrorAlertWithMessage: message];
    return;
    
  } else {  
    NSCharacterSet *notAllowSet = [NSCharacterSet characterSetWithCharactersInString: @"/\\*$|~\'\"`^!?\33"];
    NSRange range = [[newname lastPathComponent] rangeOfCharacterFromSet: notAllowSet];
    NSArray *dirContents = [fm directoryContentsAtPath: basepath];
    
    if (range.length > 0) {    
      [gwsdClient showErrorAlertWithMessage: @"Invalid char in name"];
      return;
    }	
        
    if ([dirContents containsObject: newname]) {
      if ([newname isEqualToString: oldname]) {
        return;
      } else {
        message = [NSString stringWithFormat: 
              @"The name %@ is already in use!", [newname lastPathComponent]];
        [gwsdClient showErrorAlertWithMessage: message];
        return;
      }
    }
    
    [self suspendWatchingForPath: basepath]; 

    [fm movePath: oldname toPath: newname handler: self];
    
    [dict setObject: basepath forKey: @"path"];            
    [dict setObject: GWFileDeletedInWatchedDirectory forKey: @"event"];        
    [dict setObject: [NSArray arrayWithObject: [oldname lastPathComponent]] 
             forKey: @"files"];        

    [gwsdClient server: self fileSystemDidChange: dict];  

    [[NSRunLoop currentRunLoop] 
        runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.5]];
    
    [dict setObject: basepath forKey: @"path"];            
    [dict setObject: GWFileCreatedInWatchedDirectory forKey: @"event"];        
    [dict setObject: [NSArray arrayWithObject: [newname lastPathComponent]] 
             forKey: @"files"];        
    
    [self restartWatchingForPath: basepath]; 
  }
}

- (oneway void)newObjectAtPath:(NSString *)basePath isDirectory:(BOOL)directory
{      
  NSString *fullPath;
	NSString *fileName;
  NSMutableDictionary *dict;  
  int suff;
    
	if ([self verifyFileAtPath: basePath] == NO) {
		return;
	}
	
	if ([fm isWritableFileAtPath: basePath] == NO) {
    NSString *message = [NSString stringWithFormat: 
                @"You do not have write permission for %@!", basePath];
                
    [gwsdClient showErrorAlertWithMessage: message];
		return;
	}

  if (directory == YES) {
    fileName = @"NewFolder";
  } else {
    fileName = @"NewFile";
  }

  fullPath = [basePath stringByAppendingPathComponent: fileName];
  	
  if ([fm fileExistsAtPath: fullPath] == YES) {    
    suff = 1;
    while (1) {    
      NSString *s = [fileName stringByAppendingFormat: @"%i", suff];
      fullPath = [basePath stringByAppendingPathComponent: s];
      if ([fm fileExistsAtPath: fullPath] == NO) {
        fileName = [NSString stringWithString: s];
        break;      
      }      
      suff++;
    }     
  }
    
  [self suspendWatchingForPath: basePath]; 
  
  if (directory == YES) {
    [fm createDirectoryAtPath: fullPath attributes: nil];
  } else {
	  [fm createFileAtPath: fullPath contents: nil attributes: nil];
  }
  
  dict = [NSMutableDictionary dictionary];  
  [dict setObject: basePath forKey: @"path"];            
  [dict setObject: GWFileCreatedInWatchedDirectory forKey: @"event"];        
  [dict setObject: [NSArray arrayWithObject: [fullPath lastPathComponent]] 
           forKey: @"files"];        
  
  [gwsdClient server: self fileSystemDidChange: dict];  
  
  [self restartWatchingForPath: basePath]; 
}
       
- (oneway void)duplicateFiles:(NSArray *)files inDirectory:(NSString *)basePath
{
  NSMutableDictionary *opDict = [NSMutableDictionary dictionary];

	if ([fm isWritableFileAtPath: basePath] == NO) {  
    NSString *message = [NSString stringWithFormat: 
                @"You do not have write permission for %@!", basePath];
                
    [gwsdClient showErrorAlertWithMessage: message];
		return;
	}

	[opDict setObject: NSWorkspaceDuplicateOperation forKey: @"operation"];
	[opDict setObject: basePath forKey: @"source"];
	[opDict setObject: basePath forKey: @"destination"];
	[opDict setObject: files forKey: @"files"];

  [self performLocalFileOperationWithDictionary: opDict];
}

- (oneway void)deleteFiles:(NSArray *)files inDirectory:(NSString *)basePath
{
  NSMutableDictionary *opDict = [NSMutableDictionary dictionary];

	if ([fm isWritableFileAtPath: basePath] == NO) {  
    NSString *message = [NSString stringWithFormat: 
                @"You do not have write permission for %@!", basePath];
                
    [gwsdClient showErrorAlertWithMessage: message];
		return;
	}

	[opDict setObject: NSWorkspaceDestroyOperation forKey: @"operation"];
	[opDict setObject: basePath forKey: @"source"];
	[opDict setObject: basePath forKey: @"destination"];
	[opDict setObject: files forKey: @"files"];

  [self performLocalFileOperationWithDictionary: opDict];
}

- (BOOL)fileManager:(NSFileManager *)manager 
              shouldProceedAfterError:(NSDictionary *)errorDict
{
  NSString *path = [errorDict objectForKey: @"Path"];
  NSString *msg = [NSString stringWithFormat: 
                  @"File operation error: %@\nwith file: %@\n",
                          [errorDict objectForKey: @"Error"], path];

  return [gwsdClient requestUserConfirmationWithMessage: msg 
                                                  title: @"error"];
}

- (void)fileManager:(NSFileManager *)manager willProcessPath:(NSString *)path
{
}

- (oneway void)openShellOnPath:(NSString *)path refNumber:(NSNumber *)ref
{
  [self _openShellOnPath: path refNumber: ref];
}

- (oneway void)remoteShellWithRef:(NSNumber *)ref 
                   newCommandLine:(NSString *)line
{
  [self _remoteShellWithRef: ref newCommandLine: line];
}

- (oneway void)closedRemoteTerminalWithRefNumber:(NSNumber *)ref
{
  [self _closedRemoteTerminalWithRefNumber: ref];
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
    GWSd *gwsd = [[GWSd alloc] initWithRemote: nil connection: nil];
    RELEASE (pool);
  
    if (gwsd != nil) {
	    CREATE_AUTORELEASE_POOL (pool);
      [[NSRunLoop currentRunLoop] run];
  	  RELEASE (pool);
    }
  }
    
  exit(EXIT_SUCCESS);


/*
	GWSd *gwsd;

	switch (fork()) {
	  case -1:
	    fprintf(stderr, "gwsd - fork failed - bye.\n");
	    exit(1);

	  case 0:
	    setsid();
	    break;

	  default:
	    exit(0);
	}
  
  CREATE_AUTORELEASE_POOL (pool);
	gwsd = [[GWSd alloc] initWithRemote: nil connection: nil];

  RELEASE (pool);
  
  if (gwsd != nil) {
	  CREATE_AUTORELEASE_POOL (pool);
    [[NSRunLoop currentRunLoop] run];
  	RELEASE (pool);
  }
  
  exit(0);
*/
}

