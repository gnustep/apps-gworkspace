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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <AppKit/AppKit.h>
#include <sys/types.h>
#include <sys/stat.h>
#include "ddbd.h"
#include "dbschema.h"
#include "config.h"

#define GWDebugLog(format, args...) \
  do { if (GW_DEBUG_LOG) \
    NSLog(format , ## args); } while (0)

#define EXECUTE_QUERY(q, r) \
do { \
  if ([qmanager executeQuery: q] == NO) { \
    NSLog(@"error at: %@", q); \
    return r; \
  } \
} while (0)

#define EXECUTE_OR_ROLLBACK(q, r) \
do { \
  if ([qmanager executeQuery: q] == NO) { \
    [qmanager executeQuery: @"ROLLBACK"]; \
    NSLog(@"error at: %@", q); \
    return r; \
  } \
} while (0)

#define STATEMENT_EXECUTE_QUERY(s, r) \
do { \
  if ([qmanager executeQueryWithStatement: s] == NO) { \
    NSLog(@"error at: %@", [s query]); \
    return r; \
  } \
} while (0)

#define STATEMENT_EXECUTE_OR_ROLLBACK(s, r) \
do { \
  if ([qmanager executeQueryWithStatement: s] == NO) { \
    [qmanager executeQuery: @"ROLLBACK"]; \
    NSLog(@"error at: %@", [s query]); \
    return r; \
  } \
} while (0)

#define SCHEDULE_UPDATE 3600

/*
60
3600
86400
*/        

    
enum {   
  DDBdInsertTreeUpdate,
  DDBdRemoveTreeUpdate,
  DDBdFileOperationUpdate,
  DDBdScheduledUpdate
};


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

  if (db != NULL) {
    closedb(db);
  }
  
  RELEASE (dbdir);
  RELEASE (dbpath);
  RELEASE (qmanager);

  DESTROY (updater);
  DESTROY (updaterconn);
              
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {   
    NSPort *port[2];
    NSArray *ports;
    BOOL isdir;    
    
    fm = [NSFileManager defaultManager]; 
    nc = [NSNotificationCenter defaultCenter];

    dbdir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    dbdir = [dbdir stringByAppendingPathComponent: @"gmds"];

    if (([fm fileExistsAtPath: dbdir isDirectory: &isdir] &isdir) == NO) {
      if ([fm createDirectoryAtPath: dbdir attributes: nil] == NO) { 
        NSLog(@"unable to create: %@", dbdir);
        DESTROY (self);
        return self;
      }
    }

    dbdir = [dbdir stringByAppendingPathComponent: @".db"];

    if (([fm fileExistsAtPath: dbdir isDirectory: &isdir] &isdir) == NO) {
      if ([fm createDirectoryAtPath: dbdir attributes: nil] == NO) { 
        NSLog(@"unable to create: %@", dbdir);
        DESTROY (self);
        return self;
      }
    }
    
    dbdir = [dbdir stringByAppendingPathComponent: @"v1"];

    if (([fm fileExistsAtPath: dbdir isDirectory: &isdir] &isdir) == NO) {
      if ([fm createDirectoryAtPath: dbdir attributes: nil] == NO) { 
        NSLog(@"unable to create: %@", dbdir);
        DESTROY (self);
        return self;
      }
    }

    RETAIN (dbdir);
    ASSIGN (dbpath, [dbdir stringByAppendingPathComponent: @"user.db"]);    
    
    db = NULL;

    if ([self opendb] == NO) {
      DESTROY (self);
      return self;    
    }

    conn = [NSConnection defaultConnection];
    [conn setRootObject: self];
    [conn setDelegate: self];

    if ([conn registerName: @"ddbd"] == NO) {
	    NSLog(@"unable to register with name server - quiting.");
	    DESTROY (self);
	    return self;
	  }
          
    [nc addObserver: self
           selector: @selector(connectionBecameInvalid:)
	             name: NSConnectionDidDieNotification
	           object: conn];
    
    [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                				  selector: @selector(fileSystemDidChange:) 
                					    name: @"GWFileSystemDidChangeNotification"
                					  object: nil];

    port[0] = (NSPort *)[NSPort port];
    port[1] = (NSPort *)[NSPort port];

    ports = [NSArray arrayWithObjects: port[1], port[0], nil];

    updaterconn = [[NSConnection alloc] initWithReceivePort: port[0]
				                                           sendPort: port[1]];
    [updaterconn setRootObject: self];
    [updaterconn setDelegate: self];
    RETAIN (updaterconn);

    [nc addObserver: self
           selector: @selector(connectionBecameInvalid:)
               name: NSConnectionDidDieNotification
             object: updaterconn];    
    
    updater = nil;
    
    NS_DURING
      {
        [NSThread detachNewThreadSelector: @selector(newUpdater:)
		                             toTarget: [DBUpdater class]
		                           withObject: ports];
      }
    NS_HANDLER
      {
        NSLog(@"A fatal error occured while detaching the updater thread! Exiting.");
        closedb(db);
        exit(EXIT_FAILURE);        
      }
    NS_ENDHANDLER

    NSLog(@"ddbd started");  
  }
  
  return self;    
}

- (void)registerUpdater:(id)anObject
{
  [anObject setProtocolForProxy: @protocol(DBUpdaterProtocol)];
  updater = (id <DBUpdaterProtocol>)[anObject retain];
  
  if ([updater openDbAtPath: dbpath] == NO) {
    NSLog(@"The updater thread is unable to open the db! Exiting.");
    closedb(db);
    exit(EXIT_FAILURE);        
  }
  
  [NSTimer scheduledTimerWithTimeInterval: SCHEDULE_UPDATE
                                   target: self
                                 selector: @selector(performScheduledUpdate:)
                                 userInfo: nil
                                  repeats: YES];
  
  NSLog(@"updater thread started");
}

- (oneway void)insertPath:(NSString *)path
{
  if ([qmanager executeQuery: @"BEGIN"] == NO) {      
    NSLog(@"error at insertPath: %@", path);  
    return;   
  }     
  if (insertPathIfNeeded(path, db, qmanager) != -1) {      
    [qmanager executeQuery: @"COMMIT"];    
  }   
}

- (oneway void)removePath:(NSString *)path
{
  if ([qmanager executeQuery: @"BEGIN"] == NO) {      
    NSLog(@"error at removePath: %@", path); 
    return;   
  }     
  if (removePath(path, qmanager)) {      
    [qmanager executeQuery: @"COMMIT"];    
  }   
}

- (oneway void)insertDirectoryTreesFromPaths:(NSData *)info
{
  GWDebugLog(@"starting db update");
  [updater insertTrees: info];
}

- (oneway void)removeTreesFromPaths:(NSData *)info
{
  GWDebugLog(@"starting db update");
  [updater removeTrees: info];
}

- (NSData *)directoryTreeFromPath:(NSString *)path
{  
  CREATE_AUTORELEASE_POOL (arp);
  NSString *qpath;
  NSString *query;
  SQLitePreparedStatement *statement;  
  NSArray *results;
  NSData *data = nil;

  if ([qmanager executeQuery: @"BEGIN"] == NO) {      
    NSLog(@"error at: %@", path); 
    RELEASE (arp);   
    return nil;
  }   

  query = @"SELECT path FROM user_paths WHERE path GLOB :path "
          @"AND is_directory = 1 "
          @"AND pathExists(path)";

  if ([path isEqual: pathsep()] == NO) {
    qpath = [stringForQuery(path) stringByAppendingFormat: @"%@*", pathsep()];
  } else {
    qpath = [stringForQuery(path) stringByAppendingString: @"*"];
  }
  
  statement = [qmanager statementForQuery: query 
                           withIdentifier: @"directory_tree_1"
                                 bindings: SQLITE_TEXT, @":path", qpath, 0];
    
  results = [qmanager resultsOfQueryWithStatement: statement];

  if (results && [results count]) {
    NSMutableArray *dirs = [NSMutableArray array];
    unsigned i;

    for (i = 0; i < [results count]; i++) {
      [dirs addObject: [[results objectAtIndex: i] objectForKey: @"path"]];
    }
    
    data = [NSArchiver archivedDataWithRootObject: dirs];
  }

  if ([qmanager executeQuery: @"COMMIT"] == NO) {      
    NSLog(@"error at: %@", path); 
  }   

  TEST_RETAIN (data);
  RELEASE (arp);
  
  return TEST_AUTORELEASE (data);
}

- (NSData *)attributeForKey:(NSString *)key
                     atPath:(NSString *)path
{
  if ([fm fileExistsAtPath: path]) {
    NSString *qpath = stringForQuery(path);
    NSString *query;
    SQLitePreparedStatement *statement;  

    query = @"SELECT attribute FROM user_attributes "
            @"WHERE path_id = (SELECT id FROM user_paths WHERE path = :path) "
            @"AND key = :key";

    statement = [qmanager statementForQuery: query 
                             withIdentifier: @"attribute_for_key_1"
                                   bindings: SQLITE_TEXT, @":path", qpath,
                                             SQLITE_TEXT, @":key", key, 0];

    return [qmanager getBlobEntryWithStatement: statement];
  }
  
  return nil;
}

- (BOOL)setAttribute:(NSData *)attribute
              forKey:(NSString *)key
              atPath:(NSString *)path
{
  if ([fm fileExistsAtPath: path]) {
    int path_id;
    
    EXECUTE_QUERY (@"BEGIN", NO);
    
    path_id = insertPathIfNeeded(path, db, qmanager);
        
    if (path_id != -1) {
      NSTimeInterval mdstamp = [[NSDate date] timeIntervalSinceReferenceDate];
      NSString *query;
      SQLitePreparedStatement *statement;  

      query = @"INSERT INTO user_attributes (path_id, key, attribute) "
              @"VALUES (:path_id, :key, :attribute)";

      statement = [qmanager statementForQuery: query 
                               withIdentifier: @"set_attribute_1"
                                     bindings: SQLITE_INTEGER, @":path_id", path_id,
                                               SQLITE_TEXT, @":key", key, 
                                               SQLITE_BLOB, 
                                               @":attribute", 
                                               attribute, 0];
      
      STATEMENT_EXECUTE_OR_ROLLBACK (statement, NO);
      
      query = @"UPDATE user_paths "
              @"SET md_moddate = :mdstamp "
              @"WHERE id = :path_id";
      
      statement = [qmanager statementForQuery: query 
                               withIdentifier: @"set_attribute_2"
                                     bindings: SQLITE_FLOAT, @":mdstamp", mdstamp,
                                               SQLITE_INTEGER, @":path_id", path_id, 0];
      
      STATEMENT_EXECUTE_OR_ROLLBACK (statement, NO);
      
      [qmanager executeQuery: @"COMMIT"]; 
    
      return YES;
    }
    
    [qmanager executeQuery: @"COMMIT"]; 
  }
  
  return NO;
}

- (NSTimeInterval)timestampOfPath:(NSString *)path
{
  if ([fm fileExistsAtPath: path]) {
    NSString *qpath = stringForQuery(path);
    NSString *query;
    SQLitePreparedStatement *statement;  
    
    query = @"SELECT md_moddate FROM user_paths "
            @"WHERE path = :path";

    statement = [qmanager statementForQuery: query 
                             withIdentifier: @"timestamp_of_path_1"
                                   bindings: SQLITE_TEXT, @":path", qpath, 0];
    
    return [qmanager getFloatEntryWithStatement: statement];
  }
    
  return 0.0;
}

- (NSString *)annotationsForPath:(NSString *)path
{
  NSData *data = [self attributeForKey: @"kMDItemFinderComment" atPath: path];
  
  if (data) {
    return [NSString stringWithUTF8String: [data bytes]];
  }

  return nil;
}

- (oneway void)setAnnotations:(NSString *)annotations
                      forPath:(NSString *)path
{
  const char *bytes = [annotations UTF8String];
  
  [self setAttribute: [NSData dataWithBytes: bytes length: strlen(bytes) + 1] 
              forKey: @"kMDItemFinderComment" 
              atPath: path];
}

- (void)fileSystemDidChange:(NSNotification *)notif
{
  NSData *info = [NSArchiver archivedDataWithRootObject: [notif userInfo]];
  
  GWDebugLog(@"starting db update");
  [updater fileSystemDidChange: info];
}

- (void)performScheduledUpdate:(id)sender
{
  GWDebugLog(@"starting db update");
  [updater scheduledUpdate];
}

- (BOOL)opendb
{
  if (db == NULL) {
    BOOL newdb = ([fm fileExistsAtPath: dbpath] == NO);
    char *err;
        
    db = opendbAtPath(dbpath);
        
    if (db != NULL) {
      qmanager = [[SQLiteQueryManager alloc] initForDb: db];
    
      if (newdb) {
        if (sqlite3_exec(db, [db_schema UTF8String], NULL, 0, &err) != SQLITE_OK) {
          NSLog(@"unable to create the database at %@", dbpath);
          sqlite3_free(err); 
          return NO;    
        } else {
          GWDebugLog(@"user database created");
        }
      }    
    } else {
      NSLog(@"unable to open the database at %@", dbpath);
      return NO;
    }    
    
    sqlite3_create_function(db, "pathExists", 1, 
                                SQLITE_UTF8, 0, path_exists, 0, 0);

    sqlite3_create_function(db, "pathMoved", 3, 
                                SQLITE_UTF8, 0, path_moved, 0, 0);

    sqlite3_create_function(db, "timeStamp", 0, 
                                SQLITE_UTF8, 0, time_stamp, 0, 0);

    [qmanager executeQuery: @"PRAGMA cache_size = 20000"];
    [qmanager executeQuery: @"PRAGMA count_changes = 0"];
    [qmanager executeQuery: @"PRAGMA synchronous = OFF"];
    [qmanager executeQuery: @"PRAGMA temp_store = MEMORY"];

    if (sqlite3_exec(db, [db_schema_tmp UTF8String], NULL, 0, &err) != SQLITE_OK) {
      NSLog(@"unable to create temp tables");
      sqlite3_free(err); 
      closedb(db);
      return NO;    
    }
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
    NSLog(@"argh - ddbd root connection has been destroyed.");
  } else if (connection == updaterconn) {
    NSLog(@"The updater connection died. Exiting now.");
  }
  
  if (db != NULL) {
    closedb(db);
  }
  
  exit(EXIT_FAILURE);
}

- (BOOL)connection:(NSConnection *)ancestor
            shouldMakeNewConnection:(NSConnection *)newConn
{
  [nc addObserver: self
         selector: @selector(connectionBecameInvalid:)
	           name: NSConnectionDidDieNotification
	         object: newConn];
           
  [newConn setDelegate: self];
  
  return YES;
}

@end


@implementation	DBUpdater

- (void)dealloc
{
  TEST_RELEASE (qmanager);
  
  if (db != NULL) {
    closedb(db);
  }
  
	[super dealloc];
}

+ (void)newUpdater:(NSArray *)ports
{
  CREATE_AUTORELEASE_POOL(pool);
  NSPort *port[2];
  NSConnection *conn;
  DBUpdater *updater;
                              
  port[0] = [ports objectAtIndex: 0];             
  port[1] = [ports objectAtIndex: 1];             

  conn = [NSConnection connectionWithReceivePort: (NSPort *)port[0]
                                        sendPort: (NSPort *)port[1]];
  
  updater = [[self alloc] init];
  
  [(id)[conn rootProxy] registerUpdater: updater];
  RELEASE (updater);
  
  [[NSRunLoop currentRunLoop] run];
  
  RELEASE (pool);
}

- (id)init
{
  self = [super init];
  
  if (self) {
    fm = [NSFileManager defaultManager];    
  }
  
  return self;
}

- (BOOL)openDbAtPath:(NSString *)dbpath
{
  db = opendbAtPath(dbpath);  
  
  if (db != NULL) {
    char *err;

    sqlite3_create_function(db, "pathExists", 1, 
                                SQLITE_UTF8, 0, path_exists, 0, 0);

    sqlite3_create_function(db, "pathMoved", 3, 
                                SQLITE_UTF8, 0, path_moved, 0, 0);

    sqlite3_create_function(db, "timeStamp", 0, 
                                SQLITE_UTF8, 0, time_stamp, 0, 0);

    [qmanager executeQuery: @"PRAGMA cache_size = 20000"];
    [qmanager executeQuery: @"PRAGMA count_changes = 0"];
    [qmanager executeQuery: @"PRAGMA synchronous = OFF"];
    [qmanager executeQuery: @"PRAGMA temp_store = MEMORY"];

    qmanager = [[SQLiteQueryManager alloc] initForDb: db];

    if (sqlite3_exec(db, [db_schema_tmp UTF8String], NULL, 0, &err) != SQLITE_OK) {
      NSLog(@"unable to create temp tables");
      sqlite3_free(err); 
      closedb(db);
      return NO;    
    }    
  } else {
    NSLog(@"unable to open db at %@", dbpath);
    return NO;
  }

  return YES;
}

- (oneway void)insertTrees:(NSData *)info
{
  CREATE_AUTORELEASE_POOL (arp);
  NSArray *paths = [NSUnarchiver unarchiveObjectWithData: info];
  unsigned i;

  if ([qmanager executeQuery: @"BEGIN"] == NO) {      
    NSLog(@"error at removeTrees");
    GWDebugLog(@"db update failed"); 
    return;   
  }     

  for (i = 0; i < [paths count]; i++) {
    NSString *path = [paths objectAtIndex: i];  
    NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];
    NSString *type = [attributes fileType];

    if (type == NSFileTypeDirectory) {
      NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath: path];
      NSString *part;    

      while ((part = [enumerator nextObject]) != nil) {
        CREATE_AUTORELEASE_POOL (arp1);
        NSString *subpath = [path stringByAppendingPathComponent: part];        

        if ([[enumerator fileAttributes] fileType] == NSFileTypeDirectory) {
          if (insertPathIfNeeded(subpath, db, qmanager) == -1) {      
            [qmanager executeQuery: @"COMMIT"]; 
            NSLog(@"insertTrees: error at %@", subpath);
            GWDebugLog(@"db update failed");
            RELEASE (arp1);
            RELEASE (arp);
            return;   
          }   
        }
        
        RELEASE (arp1);
      }
      
      if (insertPathIfNeeded(path, db, qmanager) == -1) {      
        NSLog(@"insertTrees: error at %@", path);
        break;   
      }   
    }
  }
  
  [qmanager executeQuery: @"COMMIT"]; 
      
  RELEASE (arp);
  
  GWDebugLog(@"db update done");
}

- (oneway void)removeTrees:(NSData *)info
{
  NSArray *paths = [NSUnarchiver unarchiveObjectWithData: info];
  unsigned i;

  if ([qmanager executeQuery: @"BEGIN"] == NO) {      
    NSLog(@"error at removeTrees"); 
    GWDebugLog(@"db update failed");
    return;   
  }     

  for (i = 0; i < [paths count]; i++) {
    if (removePath([paths objectAtIndex: i], qmanager) == NO) {
      NSLog(@"error at removeTrees"); 
      GWDebugLog(@"db update failed");
      return;   
    }
  }

  [qmanager executeQuery: @"COMMIT"]; 
  
  GWDebugLog(@"db update done");   
}

- (oneway void)fileSystemDidChange:(NSData *)info
{
  CREATE_AUTORELEASE_POOL (arp);
  NSDictionary *opdict = [NSUnarchiver unarchiveObjectWithData: info];
  NSString *operation = [opdict objectForKey: @"operation"];
  NSString *source = [opdict objectForKey: @"source"];
  NSString *destination = [opdict objectForKey: @"destination"];
  NSArray *files = [opdict objectForKey: @"files"];
  NSArray *origfiles = [opdict objectForKey: @"origfiles"];
  NSMutableArray *srcpaths = [NSMutableArray array];
  NSMutableArray *dstpaths = [NSMutableArray array];
  BOOL move, copy, remove; 
  int i;

  if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
    srcpaths = [NSArray arrayWithObject: source];
    dstpaths = [NSArray arrayWithObject: destination];
  } else {
    if ([operation isEqual: @"NSWorkspaceDuplicateOperation"]
            || [operation isEqual: @"NSWorkspaceRecycleOperation"]) { 
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

  remove = ([operation isEqual: @"NSWorkspaceDestroyOperation"]
				        || [operation isEqual: @"GWorkspaceEmptyRecyclerOperation"]);

  move = ([operation isEqual: @"NSWorkspaceMoveOperation"] 
            || [operation isEqual: @"GWorkspaceRenameOperation"]
            || [operation isEqual: @"NSWorkspaceRecycleOperation"]
            || [operation isEqual: @"GWorkspaceRecycleOutOperation"]);

  copy = ([operation isEqual: @"NSWorkspaceCopyOperation"]
             || [operation isEqual: @"NSWorkspaceDuplicateOperation"]); 
      

  if ([qmanager executeQuery: @"BEGIN"] == NO) {      
    NSLog(@"error at fileSystemDidChange"); 
    GWDebugLog(@"db update failed");
    RELEASE (arp);
    return;   
  }     

  if (remove) {    
    for (i = 0; i < [srcpaths count]; i++) {
      NSString *path = [srcpaths objectAtIndex: i];
      
      if (removePath(path, qmanager) == NO) { 
        NSLog(@"fileSystemDidChange: error removing %@", path);
        GWDebugLog(@"db update failed"); 
        RELEASE (arp);
        return;   
      }
    }
    
  } else if (move) {
    for (i = 0; i < [srcpaths count]; i++) {
      NSString *srcpath = [srcpaths objectAtIndex: i];
      NSString *dstpath = [dstpaths objectAtIndex: i];
            
      if (renamePath(dstpath, srcpath, qmanager) == NO) { 
        NSLog(@"fileSystemDidChange: error renaming %@", srcpath); 
        GWDebugLog(@"db update failed");
        RELEASE (arp);
        return;   
      }
    }
    
  } else if (copy) {
    for (i = 0; i < [srcpaths count]; i++) {
      NSString *srcpath = [srcpaths objectAtIndex: i];
      NSString *dstpath = [dstpaths objectAtIndex: i];
      
      if (removePath(dstpath, qmanager) == NO) {
        NSLog(@"fileSystemDidChange: error copying %@", srcpath); 
        RELEASE (arp);
        return;   
      }
      
      if (copyPath(srcpath, dstpath, qmanager) == NO) {
        NSLog(@"fileSystemDidChange: error copying %@", srcpath);
        GWDebugLog(@"db update failed"); 
        RELEASE (arp);
        return;   
      } 
    }    
  }

  [qmanager executeQuery: @"COMMIT"];    

  RELEASE (arp);

  GWDebugLog(@"db update done");
}

- (oneway void)scheduledUpdate
{
  CREATE_AUTORELEASE_POOL (arp);
  NSString *query;
  SQLitePreparedStatement *statement;  
  NSArray *results;

  if ([qmanager executeQuery: @"BEGIN"] == NO) {      
    NSLog(@"scheduledUpdate error"); 
    RELEASE (arp);   
    return;
  }   
  
  query = @"SELECT path FROM user_paths WHERE (pathExists(path) = 0)";

  statement = [qmanager statementForQuery: query 
                           withIdentifier: @"scheduled_update_1"
                                 bindings: 0];
                                 
  results = [qmanager resultsOfQueryWithStatement: statement];

  if (results && [results count]) {
    unsigned i;

    for (i = 0; i < [results count]; i++) {
      NSString *path = [[results objectAtIndex: i] objectForKey: @"path"];
      
      if (removePath(path, qmanager) == NO) {
        NSLog(@"scheduledUpdate error"); 
        GWDebugLog(@"db update failed");
        RELEASE (arp);
        return;   
      }    
    }
  }

  if ([qmanager executeQuery: @"COMMIT"] == NO) {      
    NSLog(@"scheduledUpdate error"); 
  }   

  RELEASE (arp);

  GWDebugLog(@"db update done");
}

@end


int insertPathIfNeeded(NSString *path, sqlite3 *db, SQLiteQueryManager *qmanager)
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];
  int path_id = -1;
  
  if (attributes) {
    NSString *qpath = stringForQuery(path);
    SQLitePreparedStatement *statement;
    NSString *query;
    
    query = @"SELECT id FROM user_paths WHERE path = :path";
    
    statement = [qmanager statementForQuery: query 
                             withIdentifier: @"insert_if_needed_1"
                                   bindings: SQLITE_TEXT, @":path", qpath, 0];
                             
    path_id = [qmanager getIntEntryWithStatement: statement];
  
    if (path_id == -1) {
      NSTimeInterval interval = [[attributes fileModificationDate] timeIntervalSinceReferenceDate];
      NSTimeInterval mdinterval = [[NSDate date] timeIntervalSinceReferenceDate];
      BOOL isdir = ([attributes fileType] == NSFileTypeDirectory);  

      query = @"INSERT INTO user_paths "
              @"(path, moddate, md_moddate, is_directory) "
              @"VALUES(:path, :moddate, :mdmoddate, :isdir)";

      statement = [qmanager statementForQuery: query 
                               withIdentifier: @"insert_if_needed_2"
                                     bindings: SQLITE_TEXT, @":path", qpath, 
                                               SQLITE_FLOAT, @":moddate", interval, 
                                               SQLITE_FLOAT, @":mdmoddate", mdinterval, 
                                               SQLITE_INTEGER, @":isdir", isdir, 0];

      STATEMENT_EXECUTE_OR_ROLLBACK (statement, -1);

      path_id = sqlite3_last_insert_rowid(db);
    }
  }

  return path_id;
}

BOOL removePath(NSString *path, SQLiteQueryManager *qmanager)
{
  NSString *qpath = stringForQuery(path);
  SQLitePreparedStatement *statement;
  NSString *query;
        
  statement = [qmanager statementForQuery: @"DELETE FROM user_paths_removed_id" 
                           withIdentifier: @"remove_path_1"
                                 bindings: 0];
  
  STATEMENT_EXECUTE_OR_ROLLBACK (statement, NO);
    
  query = @"INSERT INTO user_paths_removed_id (id) "
          @"SELECT id FROM user_paths "
          @"WHERE path = :path "
          @"OR path GLOB :minpath";
          
  statement = [qmanager statementForQuery: query 
                           withIdentifier: @"remove_path_2"
                                 bindings: SQLITE_TEXT, @":path", qpath,
                                       SQLITE_TEXT, @":minpath", 
                [NSString stringWithFormat: @"%@%@*", qpath, pathsep()], 0];
      
  STATEMENT_EXECUTE_OR_ROLLBACK (statement, NO);
      
  query = @"DELETE FROM user_attributes "
          @"WHERE path_id IN (SELECT id FROM user_paths_removed_id)";

  statement = [qmanager statementForQuery: query 
                           withIdentifier: @"remove_path_3"
                                 bindings: 0];

  STATEMENT_EXECUTE_OR_ROLLBACK (statement, NO);

  query = @"DELETE FROM user_paths WHERE id IN (SELECT id FROM user_paths_removed_id)";

  statement = [qmanager statementForQuery: query 
                           withIdentifier: @"remove_path_4"
                                 bindings: 0];

  STATEMENT_EXECUTE_OR_ROLLBACK (statement, NO);

  return YES;
}

BOOL renamePath(NSString *path, NSString *oldpath, SQLiteQueryManager *qmanager)
{
  NSString *qpath = stringForQuery(path);
  NSString *qoldpath = stringForQuery(oldpath);
  SQLitePreparedStatement *statement;
  NSString *query;

  GWDebugLog(@"srcpath = %@", qoldpath);
  GWDebugLog(@"dstpath = %@", qpath);
          
  statement = [qmanager statementForQuery: @"DELETE FROM user_renamed_paths" 
                           withIdentifier: @"rename_path_1"
                                 bindings: 0];

  STATEMENT_EXECUTE_OR_ROLLBACK (statement, NO);

  statement = [qmanager statementForQuery: @"DELETE FROM user_renamed_paths_base" 
                           withIdentifier: @"rename_path_2"
                                 bindings: 0];

  STATEMENT_EXECUTE_OR_ROLLBACK (statement, NO);

  query = @"INSERT INTO user_renamed_paths_base "
          @"(base, oldbase) "
          @"VALUES(:path, :oldpath)";

  statement = [qmanager statementForQuery: query 
                           withIdentifier: @"rename_path_3"
                                 bindings: SQLITE_TEXT, @":path", qpath, 
                                       SQLITE_TEXT, @":oldpath", qoldpath, 0];

  STATEMENT_EXECUTE_OR_ROLLBACK (statement, NO);

  query = @"INSERT INTO user_renamed_paths "
          @"(id, path, base, oldbase) "
          @"SELECT user_paths.id, user_paths.path, "
          @"user_renamed_paths_base.base, user_renamed_paths_base.oldbase "
          @"FROM user_paths, user_renamed_paths_base "
          @"WHERE user_paths.path = :oldpath "
          @"OR user_paths.path GLOB :minpath ";
          
  statement = [qmanager statementForQuery: query 
                           withIdentifier: @"rename_path_4"
                                 bindings: SQLITE_TEXT, @":oldpath", qoldpath,
                                            SQLITE_TEXT, @":minpath", 
            [NSString stringWithFormat: @"%@%@*", qoldpath, pathsep()], 0];

  STATEMENT_EXECUTE_OR_ROLLBACK (statement, NO);
  
  return YES;
}

BOOL copyPath(NSString *srcpath, NSString *dstpath, SQLiteQueryManager *qmanager)
{
  NSString *qsrcpath = stringForQuery(srcpath);
  NSString *qdstpath = stringForQuery(dstpath);
  SQLitePreparedStatement *statement;
  NSString *query;
  
  GWDebugLog(@"srcpath = %@", qsrcpath);
  GWDebugLog(@"dstpath = %@", qdstpath);
        
  statement = [qmanager statementForQuery: @"DELETE FROM user_copied_paths" 
                           withIdentifier: @"copy_path_1"
                                 bindings: 0];

  STATEMENT_EXECUTE_OR_ROLLBACK (statement, NO);

  statement = [qmanager statementForQuery: @"DELETE FROM user_copied_paths_base" 
                           withIdentifier: @"copy_path_2"
                                 bindings: 0];

  STATEMENT_EXECUTE_OR_ROLLBACK (statement, NO);

  query = @"INSERT INTO user_copied_paths_base "
          @"(srcbase, dstbase) "
          @"VALUES(:srcbase, :dstbase)";

  statement = [qmanager statementForQuery: query 
                           withIdentifier: @"copy_path_4"
                                 bindings: SQLITE_TEXT, @":srcbase", qsrcpath, 
                                    SQLITE_TEXT, @":dstbase", qdstpath, 0];

  STATEMENT_EXECUTE_OR_ROLLBACK (statement, NO);

  query = @"INSERT INTO user_copied_paths "
          @"(src_id, srcpath, is_directory, srcbase, dstbase) "
          @"SELECT user_paths.id, user_paths.path, user_paths.is_directory, "
          @"user_copied_paths_base.srcbase, user_copied_paths_base.dstbase "
          @"FROM user_paths, user_copied_paths_base "
          @"WHERE user_paths.path = :srcbase " 
          @"OR user_paths.path GLOB :minpath";

  statement = [qmanager statementForQuery: query 
                           withIdentifier: @"copy_path_5"
                                 bindings: SQLITE_TEXT, @":srcbase", qsrcpath,
                                            SQLITE_TEXT, @":minpath", 
            [NSString stringWithFormat: @"%@%@*", qsrcpath, pathsep()], 0];

  STATEMENT_EXECUTE_OR_ROLLBACK (statement, NO);
  
  return YES;
}


BOOL subpath(NSString *p1, NSString *p2)
{
  int l1 = [p1 length];
  int l2 = [p2 length];  

  if ((l1 > l2) || ([p1 isEqualToString: p2])) {
    return NO;
  } else if ([[p2 substringToIndex: l1] isEqualToString: p1]) {
    if ([[p2 pathComponents] containsObject: [p1 lastPathComponent]]) {
      return YES;
    }
  }

  return NO;
}

static NSString *fixpath(NSString *s, const char *c)
{
  static NSFileManager *mgr = nil;
  const char *ptr = c;
  unsigned len;

  if (mgr == nil) {
    mgr = [NSFileManager defaultManager];
    RETAIN (mgr);
  }
  
  if (ptr == 0) {
    if (s == nil) {
	    return nil;
	  }
    ptr = [s cString];
  }
  
  len = strlen(ptr);

  return [mgr stringWithFileSystemRepresentation: ptr length: len]; 
}

static NSString *path_sep(void)
{
  static NSString *separator = nil;

  if (separator == nil) {
    separator = fixpath(@"/", 0);
    RETAIN (separator);
  }

  return separator;
}

NSString *pathsep(void)
{
  return path_sep();
}

NSString *removePrefix(NSString *path, NSString *prefix)
{
  if ([path hasPrefix: prefix]) {
	  return [path substringFromIndex: [path rangeOfString: prefix].length + 1];
  }

  return path;  	
}

static void path_exists(sqlite3_context *context, int argc, sqlite3_value **argv)
{
  const unsigned char *path = sqlite3_value_text(argv[0]);
  int exists = 0;
  
  if (path) {
    struct stat statbuf;  
    exists = (stat((const char *)path, &statbuf) == 0);
  }
     
  sqlite3_result_int(context, exists);
}

static void path_moved(sqlite3_context *context, int argc, sqlite3_value **argv)
{
  const unsigned char *oldbase = sqlite3_value_text(argv[0]);
  int oldblen = strlen((const char *)oldbase);
  const unsigned char *newbase = sqlite3_value_text(argv[1]);
  int newblen = strlen((const char *)newbase);
  const unsigned char *oldpath = sqlite3_value_text(argv[2]);
  int oldplen = strlen((const char *)oldpath);
  char newpath[PATH_MAX] = "";
  int i = newblen;
  int j;
  
  strncpy(newpath, (const char *)newbase, newblen);  
  
  for (j = oldblen; j < oldplen; j++) {
    newpath[i] = oldpath[j];
    i++;
  }
  
  newpath[i] = '\0';
    
  sqlite3_result_text(context, newpath, strlen(newpath), SQLITE_TRANSIENT);
}

static void time_stamp(sqlite3_context *context, int argc, sqlite3_value **argv)
{
  NSTimeInterval interval = [[NSDate date] timeIntervalSinceReferenceDate];

  sqlite3_result_double(context, interval);
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

