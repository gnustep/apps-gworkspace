/* ddbd.m
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <AppKit/AppKit.h>
#include "ddbd.h"
#include "functions.h"
#include "config.h"

#ifdef HAVE_SQLITE
  #include "updater.h"
  #include "dbversion.h"
#endif

#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>

#ifdef __MINGW__
  #include "process.h"
#endif
#include <fcntl.h>
#ifdef HAVE_SYSLOG_H
  #include <syslog.h>
#endif
#include <signal.h>


@implementation	DDBd

- (void)dealloc
{
  [[NSDistributedNotificationCenter defaultCenter] removeObserver: self];

  if (conn) {
    [nc removeObserver: self
		              name: NSConnectionDidDieNotification
		            object: conn];
    DESTROY (conn);
  }
  
  RELEASE (lock);
  
#ifdef HAVE_SQLITE
  if (db != NULL) {
    closedb(db);
    RELEASE (dbpath);
  }
#endif

  RELEASE (skipSet);
  
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {    
    NSCharacterSet *set;  
  
    fm = [NSFileManager defaultManager];	
    nc = [NSNotificationCenter defaultCenter];

  #ifdef HAVE_SQLITE    
    db = NULL;
  #endif
    
    conn = [NSConnection defaultConnection];
    [conn setRootObject: self];
    [conn setDelegate: self];

    if ([conn registerName: @"ddbd"] == NO) {
	    NSLog(@"unable to register with name server - quiting.");
	    DESTROY (self);
	    return self;
	  }
    
    lock = [NSRecursiveLock new];
      
    [nc addObserver: self
           selector: @selector(connectionBecameInvalid:)
	             name: NSConnectionDidDieNotification
	           object: conn];
    
    [nc addObserver: self
       selector: @selector(threadWillExit:)
           name: NSThreadWillExitNotification
         object: nil];    

    [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                				  selector: @selector(fileSystemDidChange:) 
                					    name: @"GWFileSystemDidChangeNotification"
                					  object: nil];

    [NSTimer scheduledTimerWithTimeInterval: 3600.0
                                     target: self
                                   selector: @selector(performDaylyUpdate:)
                                   userInfo: nil
                                    repeats: YES];

    skipSet = [NSMutableCharacterSet new];
    set = [NSCharacterSet controlCharacterSet];
    [skipSet formUnionWithCharacterSet: set];
    set = [NSCharacterSet illegalCharacterSet];
    [skipSet formUnionWithCharacterSet: set];
    set = [NSCharacterSet punctuationCharacterSet];
    [skipSet formUnionWithCharacterSet: set];
    set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    [skipSet formUnionWithCharacterSet: set];
    set = [NSCharacterSet decimalDigitCharacterSet];
    [skipSet formUnionWithCharacterSet: set];

    set = [NSCharacterSet characterSetWithCharactersInString: @"+-=<>&@$*%#\"\'^`|~_"];
    [skipSet formUnionWithCharacterSet: set];  
    
  #ifdef HAVE_SQLITE  
    {
      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
      NSNumber *version = [defaults objectForKey: @"db_version"];
      NSString *db_path;
      BOOL newdb;
      
      db_path = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
      db_path = [db_path stringByAppendingPathComponent: @"Desktop.db"];
      
      ASSIGN (dbpath, db_path);
      
      if ((version == nil) || ([version intValue] != dbversion)) {
        [fm removeFileAtPath: dbpath handler: nil];
      }
      
      version = [NSNumber numberWithInt: dbversion];
      [defaults setObject: version forKey: @"db_version"];
      [defaults synchronize];
                                   
      newdb = ([fm fileExistsAtPath: dbpath] == NO);
    
      db = opendbAtPath(dbpath);
      
      if (db != NULL) {
        if (newdb) {
          if (addTablesToDb(db, dbschema) == NO) {
            NSLog(@"unable to create the Desktop database");
          } else {
            NSLog(@"Desktop database created");
          }
        }

      } else {
        NSLog(@"unable to open the Desktop database");
      }
    } 
  #endif
  
  }
  
  return self;    
}

- (BOOL)dbactive
{
#ifdef HAVE_SQLITE
  return (db != NULL);
#else
  return NO;
#endif
}

- (BOOL)insertPath:(NSString *)path
{
#ifdef HAVE_SQLITE
  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];

  if ((db != NULL) && attributes) {
    NSString *type = [attributes fileType];
    NSDate *date = [attributes fileModificationDate];
    NSString *query = [NSString stringWithFormat:
       @"INSERT INTO files (path, moddate, type) VALUES('%@', '%@', '%@')", 
                                        stringForQuery(path), 
                                        stringForQuery([date description]),
                                        stringForQuery(type)];

    if ([self performWriteQuery: query] == NO) {
      NSLog(@"error accessing the Desktop database (-insertPath:)");
      NSLog(@"error at path: %@", path);
      return NO;
    }
    
    return YES;
  }
#endif 

  return NO; 
}

- (BOOL)removePath:(NSString *)path
{
#ifdef HAVE_SQLITE
  if (db != NULL) {
    NSString *query = [NSString stringWithFormat:
                           @"DELETE FROM files WHERE path = '%@'", 
                                                    stringForQuery(path)];
    if ([self performWriteQuery: query] == NO) {
      NSLog(@"error accessing the Desktop database (-removePath:)");
      NSLog(@"error at path: %@", path);
      return NO;
    }
        
    return YES;
  }
#endif

  return NO; 
}

- (oneway void)removePaths:(NSArray *)paths
{
#ifdef HAVE_SQLITE
  NSMutableString *query = [NSMutableString string];
  int i;

  [query appendString: @"DELETE FROM files "];

  for (i = 0; i < [paths count]; i++) {
    NSString *path = stringForQuery([paths objectAtIndex: i]);  

    if (i == 0) {
      [query appendFormat: @"WHERE path = '%@' ", path];
    } else {
      [query appendFormat: @"OR path = '%@' ", path];
    }
  }

  if ([self performWriteQuery: query] == NO) {
    NSLog(@"error accessing the Desktop database (-removePaths:)");
  }  
  
#endif
}

- (void)insertDirectoryTreesFromPaths:(NSData *)info
{
#ifdef HAVE_SQLITE
  NSArray *paths = [NSUnarchiver unarchiveObjectWithData: info];
  NSMutableDictionary *updaterInfo = [NSMutableDictionary dictionary];
  NSDictionary *pathsdict = [NSDictionary dictionaryWithObject: paths 
                                                        forKey: @"paths"];
    
  [updaterInfo setObject: dbpath forKey: @"dbpath"];
  [updaterInfo setObject: [NSNumber numberWithInt: DDBdInsertTreeUpdate] 
                  forKey: @"type"];
  [updaterInfo setObject: pathsdict forKey: @"taskdict"];

  NS_DURING
    {
      [NSThread detachNewThreadSelector: @selector(updaterForTask:)
		                           toTarget: [DDBdUpdater class]
		                         withObject: updaterInfo];
    }
  NS_HANDLER
    {
      NSLog(@"A fatal error occured while detaching the thread!");
    }
  NS_ENDHANDLER
  
#endif
}

- (void)removeTreesFromPaths:(NSData *)info
{
#ifdef HAVE_SQLITE
  NSArray *paths = [NSUnarchiver unarchiveObjectWithData: info];
  NSMutableDictionary *updaterInfo = [NSMutableDictionary dictionary];
  NSDictionary *pathsdict = [NSDictionary dictionaryWithObject: paths 
                                                        forKey: @"paths"];

  [updaterInfo setObject: dbpath forKey: @"dbpath"];
  [updaterInfo setObject: [NSNumber numberWithInt: DDBdRemoveTreeUpdate] 
                  forKey: @"type"];
  [updaterInfo setObject: pathsdict forKey: @"taskdict"];

  NS_DURING
    {
      [NSThread detachNewThreadSelector: @selector(updaterForTask:)
		                           toTarget: [DDBdUpdater class]
		                         withObject: updaterInfo];
    }
  NS_HANDLER
    {
      NSLog(@"A fatal error occured while detaching the thread!");
    }
  NS_ENDHANDLER

#endif
}

- (NSData *)treeFromPath:(NSData *)pathinfo
{
#ifdef HAVE_SQLITE
  if (db != NULL) {
    NSDictionary *info = [NSUnarchiver unarchiveObjectWithData: pathinfo];
    NSString *path = [info objectForKey: @"path"];
    NSArray *columns = [info objectForKey: @"columns"];
    NSArray *criteria = [info objectForKey: @"criteria"];
    NSMutableString *query = [NSMutableString string];
    NSArray *results = nil;
    int i, count;
  
    [query appendString: @"SELECT "];
    
    count = [columns count];
    
    for (i = 0; i < count; i++) {
      [query appendFormat: @"%@ ", [columns objectAtIndex: i]];
      if (i < (count - 1)) {
        [query appendString: @", "];
      }
    }
    
    [query appendFormat: @"FROM files WHERE path > '%@", stringForQuery(path)];

    if ([path isEqual: path_separator()] == NO) {
      [query appendString: path_separator()];
    }
    [query appendString: @"' "];
    
    if ([path isEqual: path_separator()] == NO) {
      [query appendFormat: @"AND path < '%@0' ", stringForQuery(path)];
    } else {
      [query appendString: @"AND path < '0' "];
    }

    count = [criteria count];
    
    for (i = 0; i < count; i++) {
      NSDictionary *dict = [criteria objectAtIndex: i];
      NSString *type = [dict objectForKey: @"type"];
      NSString *operator = [dict objectForKey: @"operator"];
      NSString *arg = [dict objectForKey: @"arg"];
    
      [query appendFormat: @"AND %@ %@ '%@' ", type, operator, stringForQuery(arg)];
    }

    [query appendString: @"AND pathExists(path)"];
        
    results = performQueryOnDb(db, query);
    
    if (results && [results count]) {  
      return [NSArchiver archivedDataWithRootObject: results];    
    }
  }
#endif

  return nil;
}

- (NSData *)directoryTreeFromPath:(NSString *)path
{
#ifdef HAVE_SQLITE
  if (db != NULL) {
    CREATE_AUTORELEASE_POOL(pool);
    NSMutableArray *directories = [NSMutableArray array];  
    NSMutableString *query = [NSMutableString string];
    NSString *qpath = stringForQuery(path);
    NSArray *results = nil;
    NSData *data = nil;
    
    [query appendFormat: @"SELECT path FROM files WHERE path > '%@", qpath];

    if ([path isEqual: path_separator()] == NO) {
      [query appendString: path_separator()];
    }
    [query appendString: @"' "];
    
    if ([path isEqual: path_separator()] == NO) {
      [query appendFormat: @"AND path < '%@0' ", qpath];
    } else {
      [query appendString: @"AND path < '0' "];
    }

    [query appendFormat: @"AND type = 'NSFileTypeDirectory' "];
    [query appendString: @"AND pathExists(path)"];

    results = performQueryOnDb(db, query);

    if (results) { 
      int i;

      for (i = 0; i < [results count]; i++) {   
        NSDictionary *entry = [results objectAtIndex: i];
        NSData *pathdata = [entry objectForKey: @"path"];    
    
        [directories addObject: [NSString stringWithUTF8String: [pathdata bytes]]];
      }
      
      if ([directories count]) {  
        data = [NSArchiver archivedDataWithRootObject: directories]; 
      }
    }

    TEST_RETAIN (data);
    RELEASE (pool);
  
    return TEST_AUTORELEASE (data);
  }
#endif

  return nil;
}

- (NSString *)annotationsForPath:(NSString *)path
{
  NSData *data = [self infoOfType: @"annotations" forPath: path];
      
  if (data) {
    return [NSString stringWithUTF8String: [data bytes]];
  } 
  
  return nil;
}

- (oneway void)setAnnotations:(NSString *)annotations
                      forPath:(NSString *)path
{
  [self setInfo: annotations ofType: @"annotations" forPath: path];
}

- (NSString *)fileTypeForPath:(NSString *)path
{
  NSData *data = [self infoOfType: @"type" forPath: path];
      
  if (data) {
    return [NSString stringWithUTF8String: [data bytes]];
  } 
  
  return nil;
}

- (oneway void)setFileType:(NSString *)type
                   forPath:(NSString *)path
{
  [self setInfo: type ofType: @"type" forPath: path];
}

- (NSString *)modificationDateForPath:(NSString *)path
{
  NSData *data = [self infoOfType: @"moddate" forPath: path];

  if (data) {
    return [NSString stringWithUTF8String: [data bytes]];
  } 
  
  return nil;
}

- (oneway void)setModificationDate:(NSString *)datedescr
                           forPath:(NSString *)path
{
  [self setInfo: datedescr ofType: @"moddate" forPath: path];
}

- (NSData *)iconDataForPath:(NSString *)path
{
#ifdef HAVE_SQLITE
  NSData *data = [self infoOfType: @"icon" forPath: path];

  if (data) {
    return dataFromBlob([data bytes]);
  } 
#endif
  
  return nil;
}

- (oneway void)setIconData:(NSData *)data
                   forPath:(NSString *)path
{
#ifdef HAVE_SQLITE
  if (db != NULL) {
    [self setInfo: blobFromData(data)
           ofType: @"icon" 
          forPath: path];
  }
#endif
}

- (BOOL)setInfoOfPath:(NSString *)src
               toPath:(NSString *)dst
{
  CREATE_AUTORELEASE_POOL(pool);
  NSDictionary *attrs = [fm fileAttributesAtPath: dst traverseLink: NO];
  BOOL resok = NO;

#ifdef HAVE_SQLITE  
  if (attrs) {
    NSMutableString *query = [NSMutableString string];
    NSArray *results = nil;
    
    [query appendFormat: @"SELECT * FROM files WHERE path = '%@'", 
                                                  stringForQuery(src)];
    results = performQueryOnDb(db, query);

    if (results && [results count]) { 
      NSDictionary *dict = [results objectAtIndex: 0];
      NSMutableArray *keys = [NSMutableArray arrayWithArray: [dict allKeys]]; 
      int i, count;
      
      [keys removeObject: @"path"];
      count = [keys count];

      query = (NSMutableString *)[NSMutableString string];
      [query appendString: @"UPDATE files SET "];
  
      for (i = 0; i < count; i++) {
        NSString *key = [keys objectAtIndex: i];

        if ([key isEqual: @"moddate"]) {
          NSDate *date = [attrs fileModificationDate];
          [query appendFormat: @"%@ = '%@'", 
                stringForQuery(key), stringForQuery([date description])];
        } else {
          NSData *data = [dict objectForKey: key]; 
          [query appendFormat: @"%@ = '%s'", 
                      stringForQuery(key), [data bytes]];
        }

        if (i < (count -1)) {
          [query appendString: @", "];
        }
      }  
      
      [query appendFormat: @" WHERE path = '%@'", stringForQuery(dst)];
  
      if ([self checkPath: dst] == NO) {
        if ([self insertPath: dst] == NO) {
          RELEASE (pool);
          return NO;
        }      
      }
            
      resok = [self performWriteQuery: query];
    }
  }
#endif
  
  RELEASE (pool);
  
  return resok;
}

- (BOOL)performWriteQuery:(NSString *)query 
{
#ifdef HAVE_SQLITE
  [lock lock];
  if (performWriteQueryOnDb(db, query) == NO) {
    [lock unlock];
	  return NO;
  }
  [lock unlock];

  return YES;
#endif
}

- (NSData *)infoOfType:(NSString *)type
               forPath:(NSString *)path
{
#ifdef HAVE_SQLITE
  if ((db != NULL) && [fm fileExistsAtPath: path]) {
    NSArray *results = nil;
    NSString *query = [NSString stringWithFormat: 
                    @"SELECT %@ FROM files WHERE path = '%@'", 
                                                type, stringForQuery(path)];
                                                 
    results = performQueryOnDb(db, query);
    
    if (results && [results count]) {
      NSDictionary *dict = [results objectAtIndex: 0];
      return [dict objectForKey: type];
    }
  }
#endif
  
  return nil;
}

- (void)setInfo:(NSString *)info
         ofType:(NSString *)type
        forPath:(NSString *)path
{
#ifdef HAVE_SQLITE
  if (db != NULL) {
    NSString *query = [NSString stringWithFormat: 
              @"UPDATE files SET %@ = '%@' WHERE path = '%@'", 
          stringForQuery(type), stringForQuery(info), stringForQuery(path)]; 
    
    if ([self checkPath: path] == NO) {
      [self insertPath: path]; 
    }    
    
    if (performWriteQueryOnDb(db, query) == NO) {
      NSLog(@"error accessing the Desktop database (-setInfo:ofType:forPath:)");
      NSLog(@"error at path: %@", path);
    }
  }
#endif
}

- (BOOL)checkPath:(NSString *)path
{
#ifdef HAVE_SQLITE
  return ((db != NULL) && checkEntryInDb(db, @"files", @"path", path));
#else
  return NO;
#endif
}

- (void)connectionBecameInvalid:(NSNotification *)notification
{
  id connection = [notification object];

  [nc removeObserver: self
	              name: NSConnectionDidDieNotification
	            object: connection];

  if (connection == conn) {
    NSLog(@"argh - ddbd root connection has been destroyed.");
    exit(EXIT_FAILURE);
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

- (void)fileSystemDidChange:(NSNotification *)notif
{
#ifdef HAVE_SQLITE
  NSDictionary *info = [notif userInfo];
  NSMutableDictionary *updaterInfo = [NSMutableDictionary dictionary];
    
  [updaterInfo setObject: dbpath forKey: @"dbpath"];
  [updaterInfo setObject: [NSNumber numberWithInt: DDBdFileOperationUpdate] 
                  forKey: @"type"];
  [updaterInfo setObject: info forKey: @"taskdict"];

  NS_DURING
    {
      [NSThread detachNewThreadSelector: @selector(updaterForTask:)
		                           toTarget: [DDBdUpdater class]
		                         withObject: updaterInfo];
    }
  NS_HANDLER
    {
      NSLog(@"A fatal error occured while detaching the thread!");
    }
  NS_ENDHANDLER
  
#endif
}

- (void)performDaylyUpdate:(id)sender
{
#ifdef HAVE_SQLITE
  NSMutableDictionary *updaterInfo = [NSMutableDictionary dictionary];
    
  [updaterInfo setObject: dbpath forKey: @"dbpath"];
  [updaterInfo setObject: [NSNumber numberWithInt: DDBdDaylyUpdate] 
                  forKey: @"type"];
  [updaterInfo setObject: [NSDictionary dictionary] forKey: @"taskdict"];

  NS_DURING
    {
      [NSThread detachNewThreadSelector: @selector(updaterForTask:)
		                           toTarget: [DDBdUpdater class]
		                         withObject: updaterInfo];
    }
  NS_HANDLER
    {
      NSLog(@"A fatal error occured while detaching the thread!");
    }
  NS_ENDHANDLER
  
#endif
}

- (void)threadWillExit:(NSNotification *)notification
{
  NSLog(@"db update thread will exit");
}

@end


@implementation	DDBd (indexing)

- (void)indexContentsOfFile:(NSString *)path
{
#ifdef HAVE_SQLITE
#define DLENGTH 256
#define MAXFSIZE 600000
#define TRY_QUERY(q) \
if (performWriteQueryOnDb(db, q) == NO) { \
NSLog(@"error accessing the Desktop database (-indexContentsOfFile:)"); \
RELEASE (arp); \
return; \
}

  CREATE_AUTORELEASE_POOL(arp);  
  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];

  if (attributes 
          && ([attributes fileType] == NSFileTypeRegular)
                                    && ([attributes fileSize] < MAXFSIZE)) {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath: path];
    NSData *data = [handle readDataOfLength: DLENGTH];
    BOOL binary = NO;      
    int i;

    if (data) {
      const char *bytes = (const char *)[data bytes];
      unsigned length = [data length];

      for (i = 0; i < length; i++) {
        char c = bytes[i];

        if (c == 0x00) {
          binary = YES;
          break;
        } 
      }
    }

    [handle closeFile];

    if (binary == NO) {
      NSString *contents = [NSString stringWithContentsOfFile: path];
      
      if (contents && [contents length]) {
        NSScanner *scanner;
        SEL scanSel;
        IMP scanImp;
        NSString *word;
        NSString *query;
        
        query = [NSString stringWithFormat: 
                    @"INSERT INTO cpaths(path) VALUES('%@')", 
                                                  stringForQuery(path)];
        
        TRY_QUERY (@"BEGIN");
        TRY_QUERY (query);
        
        scanner = [NSScanner scannerWithString: contents];
        [scanner setCharactersToBeSkipped: skipSet];
        
        scanSel = @selector(scanUpToCharactersFromSet:intoString:);
        scanImp = [scanner methodForSelector: scanSel];

        while ([scanner isAtEnd] == NO) {
          (*scanImp)(scanner, scanSel, skipSet, &word);
          
          if ([word length] > 2) {
            word = stringForQuery([word lowercaseString]);
                      
            query = [NSString stringWithFormat: 
                          @"INSERT INTO words(word) VALUES('%@')", word];
            
            TRY_QUERY (query);
          }
        }
        
        TRY_QUERY (@"COMMIT")
      }
    }
  }

RELEASE (arp);
#endif
}

@end


int main(int argc, char** argv)
{
	DDBd *ddbd;

	switch (fork()) {
	  case -1:
	    fprintf(stderr, "ddbd - fork failed - bye.\n");
	    exit(1);

	  case 0:
	    setsid();
	    break;

	  default:
	    exit(0);
	}
  
  CREATE_AUTORELEASE_POOL (pool);
	ddbd = [[DDBd alloc] init];
  RELEASE (pool);
  
  if (ddbd != nil) {
	  CREATE_AUTORELEASE_POOL (pool);
    [[NSRunLoop currentRunLoop] run];
  	RELEASE (pool);
  }
  
  exit(0);
}
