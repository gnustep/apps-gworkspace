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
  #include "SQLite.h"
  #include "updater.h"
  #include "dbversion.h"
#endif

#include <stdio.h>
#include <unistd.h>
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
  if (sqlite) {
    [sqlite closedb];
    RELEASE (sqlite);
    RELEASE (dbpath);
  }
#endif
  
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {    
    fm = [NSFileManager defaultManager];	
    nc = [NSNotificationCenter defaultCenter];
    
    sqlite = nil;
    
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

/*
60
3600
86400
*/


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
            
            
      // !!!!!!!!!!!!!!!!!!!! TEST 1 !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  //    [self testCreateDB];          
      // !!!!!!!!!!!!!!!!!!!! TEST 1 !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            
            
      newdb = ([fm fileExistsAtPath: dbpath] == NO);
    
      sqlite = [[SQLite alloc] initWithDatabasePath: dbpath];
      
      if ([sqlite opendb]) {
        if (newdb) {
          NSDictionary *table = [deftable propertyList];
          
          if ([sqlite createDatabaseWithTable: table] == NO) {
            DESTROY (sqlite);
            NSLog(@"unable to create the Desktop database");
          } else {
            NSLog(@"Desktop database created");
          }
        }


        // !!!!!!!!!!!!!!!!!!!! TEST 2 !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    //    [self testWriteImage];        
        // !!!!!!!!!!!!!!!!!!!! TEST 2 !!!!!!!!!!!!!!!!!!!!!!!!!!!!!

         
         
         
      } else {
        DESTROY (sqlite);
        NSLog(@"unable to open the Desktop database");
      }
    } 
  #endif
  
  }
  
  return self;    
}

- (BOOL)dbactive
{
  return (sqlite != nil);
}

- (BOOL)insertPath:(NSString *)path
{
#ifdef HAVE_SQLITE
  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];

  if (sqlite && attributes) {
    NSString *type = [attributes fileType];
    NSDate *date = [attributes fileModificationDate];
    NSString *query = [NSString stringWithFormat:
       @"REPLACE INTO files (path, moddate, type) VALUES('%@', '%@', '%@')", 
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
  if (sqlite) {
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

- (void)insertTreesFromPaths:(NSData *)info
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
  if (sqlite) {
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
    
    [query appendFormat: @"FROM files WHERE path = '%@' ", stringForQuery(path)];
    [query appendFormat: @"OR path GLOB '%@", stringForQuery(path)];

    if ([path isEqual: path_separator()] == NO) {
      [query appendFormat: @"%@*' ", path_separator()];
    } else {
      [query appendString: @"*' "];
    }
    
    count = [criteria count];
    
    for (i = 0; i < count; i++) {
      NSDictionary *dict = [criteria objectAtIndex: i];
      NSString *type = [dict objectForKey: @"type"];
      NSString *operator = [dict objectForKey: @"operator"];
      NSString *arg = [dict objectForKey: @"arg"];
    
      [query appendFormat: @"AND %@ %@ '%@' ", type, operator, stringForQuery(arg)];
    }
    
    results = [sqlite performQuery: query];
    
    if (results && [results count]) {  
      return [NSArchiver archivedDataWithRootObject: results];    
    }
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
    return [sqlite dataFromBlob: [data bytes]];
  } 
#endif
  
  return nil;
}

- (oneway void)setIconData:(NSData *)data
                   forPath:(NSString *)path
{
#ifdef HAVE_SQLITE
  if (sqlite) {
    [self setInfo: [sqlite blobFromData: data] 
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
  
  if (attrs) {
    NSMutableString *query = [NSMutableString string];
    NSArray *results = nil;
    
    [query appendFormat: @"SELECT * FROM files WHERE path = '%@'", 
                                                  stringForQuery(src)];
    results = [sqlite performQuery: query];

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
  
  RELEASE (pool);
  
  return resok;
}

- (BOOL)performWriteQuery:(NSString *)query 
{
#ifdef HAVE_SQLITE
  [lock lock];
  if ([sqlite performWriteQuery: query] == NO) {
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
  if (sqlite && [fm fileExistsAtPath: path]) {
    NSArray *results = nil;
    NSString *query = [NSString stringWithFormat: 
                          @"SELECT %@ FROM files WHERE path = '%@'", 
                                              type, stringForQuery(path)];
    results = [sqlite performQuery: query];
    
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
  if (sqlite) {
    NSString *query = [NSString stringWithFormat: 
              @"UPDATE files SET %@ = '%@' WHERE path = '%@'", 
          stringForQuery(type), stringForQuery(info), stringForQuery(path)]; 
    
    if ([self checkPath: path] == NO) {
      [self insertPath: path]; 
    }
    
    if ([self performWriteQuery: query] == NO) {
      NSLog(@"error accessing the Desktop database (-setInfo:ofType:forPath:)");
      NSLog(@"error at path: %@", path);
    }
  }
#endif
}

- (BOOL)checkPath:(NSString *)path
{
  return (sqlite && [self infoOfType: @"path" forPath: path]);
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








- (void)testCreateDB
{
  NSString *dbPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
  NSString *testpath = @"/home/enrico/Butt/GNUstep/CopyPix";
  NSString *imgpath = @"/home/enrico/Butt/GNUstep/CopyPix/Calculator.tiff";
  NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath: testpath];
  NSImage *image;
  NSData *imdata;  
  NSDictionary *attributes;
  NSString *type;
  NSDate *date;
  NSString *path;
        
  dbPath = [dbPath stringByAppendingPathComponent: @"Desktop.db"];
  [fm removeFileAtPath: dbPath handler: nil];
  
  sqlite = [[SQLite alloc] initWithDatabasePath: dbPath];
  
  if ([sqlite opendb]) {
    NSDictionary *table = [deftable propertyList];

    if ([sqlite createDatabaseWithTable: table] == NO) {
      DESTROY (sqlite);
      NSLog(@"unable to create the Desktop database");
      exit(0);
    } else {
      NSLog(@"Desktop database created");
    }
  } else {
    DESTROY (sqlite);
    NSLog(@"unable to open the Desktop database");
    exit(0);
  }

  image = [[NSImage alloc] initWithContentsOfFile: imgpath];
  imdata = [image TIFFRepresentation];

  while ((path = [enumerator nextObject])) {
    attributes = [enumerator fileAttributes];
    type = [attributes fileType];
    date = [attributes fileModificationDate];
    path = [testpath stringByAppendingPathComponent: path];
    
    [self setFileType: type forPath: path];
    [self setModificationDate: [date description] forPath: path];
    [self setAnnotations: @"testo di test" forPath: path];
    [self setIconData: imdata forPath: path];
  }
  
  RELEASE (image);
  [sqlite closedb];
  RELEASE (sqlite);
  
  NSLog(@"DONE");
  exit(0);
}

- (void)testWriteImage
{      
  NSString *imgoutpath = @"/home/enrico/Butt/GNUstep/CopyPix/Calculator2.tiff";
  NSString *path = @"/home/enrico/Butt/GNUstep/Pixmaps/AA";
  NSData *imdata = [self iconDataForPath: path];
  NSImage *image;
  NSData *data;

  [fm removeFileAtPath: imgoutpath handler: nil];
  image = [[NSImage alloc] initWithData: imdata];
  data = [image TIFFRepresentation];
  [data writeToFile: imgoutpath atomically: NO];
  RELEASE (image);
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
