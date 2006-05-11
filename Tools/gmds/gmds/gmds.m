/* gmsd.m
 *  
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@dtedu.net>
 * Date: February 2006
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

#include <sys/types.h>
#include <sys/stat.h>
#include "gmds.h"
#include "dbschema.h"
#include "config.h"

#define GWDebugLog(format, args...) \
  do { if (GW_DEBUG_LOG) \
    NSLog(format , ## args); } while (0)

#define MAX_RETRY 1000
#define MAX_RES 100

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


@implementation	GMDS

- (void)dealloc
{
  NSConnection *connection = [clientInfo objectForKey: @"connection"];
  
  if (connection) {
    [nc removeObserver: self
		              name: NSConnectionDidDieNotification
		            object: connection];
  }

  RELEASE (clientInfo);
  
  [nc removeObserver: self
		            name: NSConnectionDidDieNotification
		          object: conn];
  DESTROY (conn);
  RELEASE (connectionName);
  
  if (db != NULL) {
    sqlite3_close(db);
  }
  
  RELEASE (dbpath);
  RELEASE (dbdir);
  
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {    
    BOOL isdir;

    fm = [NSFileManager defaultManager];
  
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
    ASSIGN (dbpath, [dbdir stringByAppendingPathComponent: @"contents.db"]);    
    db = NULL;

    if ([self opendb] == NO) {
      DESTROY (self);
      return self;    
    }
    
    conn = [NSConnection defaultConnection];
    [conn setRootObject: self];
    [conn setDelegate: self];
    
    if ([conn registerName: @"gmds"] == NO) {
	    NSLog(@"unable to register with name server - quiting.");
	    DESTROY (self);
	    return self;
	  }
    
    nc = [NSNotificationCenter defaultCenter];
      
    [nc addObserver: self
           selector: @selector(connectionDidDie:)
	             name: NSConnectionDidDieNotification
	           object: conn];
             
    clientInfo = [NSMutableDictionary new];
  }
  
  return self;    
}

- (BOOL)connection:(NSConnection *)parentConnection
            shouldMakeNewConnection:(NSConnection *)newConnnection
{
  if ([clientInfo objectForKey: @"connection"] == nil) {
    CREATE_AUTORELEASE_POOL(pool); 
    NSProcessInfo *info = [NSProcessInfo processInfo];
    NSMutableArray *args = [[info arguments] mutableCopy];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id connum = [defaults objectForKey: @"gmds_connection_number"]; 
    unsigned long ln;
    NSTask *task; 

    if (connum == nil) {
      connum = [NSNumber numberWithUnsignedLong: 0L];
    }

    ln = [connum unsignedLongValue];
    ASSIGN (connectionName, ([NSString stringWithFormat: @"gmds_%i", ln]));

    if ([conn registerName: connectionName] == NO) {
      NSLog(@"unable to register with name server - quiting.");
      exit(EXIT_FAILURE);
    }

    GWDebugLog(@"connection name changed to %@", connectionName);

    ln++;
    connum = [NSNumber numberWithUnsignedLong: ln];
    [defaults setObject: connum forKey: @"gmds_connection_number"];
    [defaults synchronize];

    task = [NSTask new];
	  [task setLaunchPath: [[NSBundle mainBundle] executablePath]];
    [args addObject: @"--from-gmds"];
    [task setArguments: args];
    RELEASE (args);
    [task setEnvironment: [info environment]];
	  [task launch];
	  RELEASE (task);

    RELEASE (pool);
    
    [clientInfo setObject: newConnnection forKey: @"connection"];
    
    [newConnnection setDelegate: self];
    
    [nc addObserver: self
           selector: @selector(connectionDidDie:)
	             name: NSConnectionDidDieNotification
	           object: newConnnection];

    GWDebugLog(@"new client connection");

    return YES;
  } 
  
  NSLog(@"client connection already exists!");
  
  return NO;
}

- (void)connectionDidDie:(NSNotification *)notification
{
  id connection = [notification object];

  [nc removeObserver: self
	              name: NSConnectionDidDieNotification
	            object: connection];
  
  if (connection == conn) {
    NSLog(@"argh - gmds server root connection has been destroyed.");
    exit(EXIT_FAILURE);
  }
  
  [self terminate]; 
}

- (oneway void)registerClient:(id)remote
{
	NSConnection *connection = [(NSDistantObject *)remote connectionForProxy];
  NSConnection *clientConn = [clientInfo objectForKey: @"connection"];  
  
	if ((clientConn == nil) || (clientConn != connection)) {
    [NSException raise: NSInternalInconsistencyException
		            format: @"registration with unknown connection"];
  }

  if ([clientInfo objectForKey: @"client"] != nil) { 
    [NSException raise: NSInternalInconsistencyException
		            format: @"registration with registered client"];
  }

  [(id)remote setProtocolForProxy: @protocol(GMDSClientProtocol)];    
  [clientInfo setObject: remote forKey: @"client"];
  
  GWDebugLog(@"new client registered");
}

- (oneway void)unregisterClient:(id)remote
{
  NSConnection *clientConn = [clientInfo objectForKey: @"connection"];  
  id client = [clientInfo objectForKey: @"client"];  
    
	if (clientConn == nil) {
    [NSException raise: NSInternalInconsistencyException
		            format: @"unregistration with unknown connection"];
  }

  if ((client == nil) || (client != remote)) { 
    [NSException raise: NSInternalInconsistencyException
                format: @"unregistration with unregistered client"];
  }
    
  GWDebugLog(@"client unregistered");

  [self terminate]; 
}

- (BOOL)performSubquery:(NSString *)query
{
  CREATE_AUTORELEASE_POOL(pool); 
  const char *qbuff = [query UTF8String];
  struct sqlite3_stmt *stmt;
  int err;

  if ((err = sqlite3_prepare(db, qbuff, strlen(qbuff), &stmt, NULL)) == SQLITE_OK) {  
    int retry = 0;
    
    while (1) {
      err = sqlite3_step(stmt);

      if (err == SQLITE_DONE) {
        break;

      } else if (err == SQLITE_BUSY) {
        CREATE_AUTORELEASE_POOL(arp); 
        NSDate *when = [NSDate dateWithTimeIntervalSinceNow: 0.1];

        [NSThread sleepUntilDate: when];
        GWDebugLog(@"retry %i", retry);
        RELEASE (arp);

        if (retry++ > MAX_RETRY) {
          NSLog(@"%s", sqlite3_errmsg(db));
		      break;
        }

      } else {
        NSLog(@"%s", sqlite3_errmsg(db));
        break;
      }
    }
    
    sqlite3_finalize(stmt);
  }
  
  RELEASE (pool);
    
  return (err == SQLITE_DONE);
}

- (BOOL)performPreQueries:(NSArray *)queries
{
  int i;
  
  for (i = 0; i < [queries count]; i++) {
    if ([self performSubquery: [queries objectAtIndex: i]] == NO) {
      return NO;
    }
  }
   
  return YES;
}

- (void)performPostQueries:(NSArray *)queries
{
  if (queries) {
    int i;

    for (i = 0; i < [queries count]; i++) {
      [self performSubquery: [queries objectAtIndex: i]];
    }
  }
}

- (oneway void)performQuery:(NSData *)queryInfo
{
  CREATE_AUTORELEASE_POOL(pool); 
  NSDictionary *dict = [NSUnarchiver unarchiveObjectWithData: queryInfo];  
  NSArray *prequeries = [dict objectForKey: @"pre_queries"];
  BOOL prepared = YES;
  NSString *query = [dict objectForKey: @"query"];
  NSArray *postqueries = [dict objectForKey: @"post_queries"];  
  NSNumber *queryNumber = [dict objectForKey: @"query_number"];  
  const char *qbuff = [query UTF8String];
  NSMutableArray *reslines = [NSMutableArray array];
  struct sqlite3_stmt *stmt;
  int retry = 0;
  int err;
  int i;
  
  if (prequeries) {
    prepared = [self performPreQueries: prequeries];
  }
  
  if (prepared && (sqlite3_prepare(db, qbuff, strlen(qbuff), &stmt, NULL) == SQLITE_OK)) {
    while (1) {
      err = sqlite3_step(stmt);

      if (err == SQLITE_ROW) {
        NSMutableArray *line = [NSMutableArray array];
        int count = sqlite3_data_count(stmt);

        // we use "<= count" because sqlite sends also 
        // the id of the entry with type = 0 
        for (i = 0; i <= count; i++) { 
          int type = sqlite3_column_type(stmt, i);
                    
          if (type == SQLITE_INTEGER) {
            [line addObject: [NSNumber numberWithInt: sqlite3_column_int(stmt, i)]];
          
          } else if (type == SQLITE_FLOAT) {
            [line addObject: [NSNumber numberWithDouble: sqlite3_column_double(stmt, i)]];
          
          } else if (type == SQLITE_TEXT) {
            [line addObject: [NSString stringWithUTF8String: (const char *)sqlite3_column_text(stmt, i)]];
          
          } else if (type == SQLITE_BLOB) {
            const char *bytes = sqlite3_column_blob(stmt, i);
            int length = sqlite3_column_bytes(stmt, i); 

            [line addObject: [NSData dataWithBytes: bytes length: length]];
          }
        }

        [reslines addObject: line];

        if ([reslines count] == MAX_RES) {

          GWDebugLog(@"SENDING");

          if ([self sendResults: reslines forQueryWithNumber: queryNumber]) {
            GWDebugLog(@"SENT");
            [reslines removeAllObjects];
          } else {
            GWDebugLog(@"INVALID!");
            break;
          }
        }

      } else {
        if (err == SQLITE_DONE) {

          GWDebugLog(@"SENDING (last)");

          if ([reslines count]) {
            if ([self sendResults: reslines forQueryWithNumber: queryNumber]) {
              GWDebugLog(@"SENT");
            } else {
              GWDebugLog(@"INVALID!");
            }
          } else {
            GWDebugLog(@"0 RESULTS");
          }

          break;

        } else if (err == SQLITE_BUSY) {
          CREATE_AUTORELEASE_POOL(arp); 
          NSDate *when = [NSDate dateWithTimeIntervalSinceNow: 0.1];

          [NSThread sleepUntilDate: when];
          GWDebugLog(@"retry %i", retry);
          RELEASE (arp);

          if (retry++ > MAX_RETRY) {
            NSLog(@"%s", sqlite3_errmsg(db));
		        break;
          }

        } else {
          NSLog(@"%i %s", err, sqlite3_errmsg(db));
          break;
        }
      }
    }
  
    sqlite3_finalize(stmt);
    
  } else {
    NSLog(@"%s", sqlite3_errmsg(db));
  }
  
  [self performPostQueries: postqueries];
  
  [[clientInfo objectForKey: @"client"] endOfQuery];
  
  RELEASE (pool);
}

- (BOOL)sendResults:(NSArray *)lines
           forQueryWithNumber:(NSNumber *)qnum
{
  CREATE_AUTORELEASE_POOL(arp); 
  id client = [clientInfo objectForKey: @"client"];
  NSMutableDictionary *results = [NSMutableDictionary dictionary];
  BOOL accepted;
  
  [results setObject: qnum forKey: @"query_number"];  
  [results setObject: lines forKey: @"lines"];
  accepted = [client queryResults: [NSArchiver archivedDataWithRootObject: results]];    
  RELEASE (arp);
  
  return accepted;
}

- (BOOL)opendb
{
  if (db == NULL) {
    BOOL newdb = ([fm fileExistsAtPath: dbpath] == NO);
    char *err;
        
    db = opendbAtPath(dbpath);
        
    if (db != NULL) {
      if (newdb) {
        if (sqlite3_exec(db, [db_schema UTF8String], NULL, 0, &err) != SQLITE_OK) {
          NSLog(@"unable to create the database at %@", dbpath);
          sqlite3_free(err); 
          return NO;    
        } else {
          GWDebugLog(@"contents database created");
        }
      }    
    } else {
      NSLog(@"unable to open the database at %@", dbpath);
      return NO;
    }    
    
    sqlite3_create_function(db, "pathExists", 1, 
                                SQLITE_UTF8, 0, path_exists, 0, 0);

    performWriteQuery(db, @"PRAGMA cache_size = 20000");
    performWriteQuery(db, @"PRAGMA count_changes = 0");
    performWriteQuery(db, @"PRAGMA synchronous = OFF");
    performWriteQuery(db, @"PRAGMA temp_store = MEMORY");
  }

  /* only to avoid a compiler warning */
  if (0) {
    NSLog(db_schema_tmp);
    NSLog(user_db_schema);
    NSLog(user_db_schema_tmp);
  }

  return YES;
}

- (void)terminate
{
  NSConnection *connection = [clientInfo objectForKey: @"connection"];
  
  if (connection) {
    [nc removeObserver: self
		              name: NSConnectionDidDieNotification
		            object: connection];
  }

  RELEASE (clientInfo);
  
  if (db != NULL) {
    sqlite3_close(db);
  }
  
  NSLog(@"exiting");
  
  exit(EXIT_SUCCESS);
}

@end


int main(int argc, char** argv)
{
  CREATE_AUTORELEASE_POOL(pool);
  NSProcessInfo *info = [NSProcessInfo processInfo];
  NSMutableArray *args = AUTORELEASE ([[info arguments] mutableCopy]);

  if ([args containsObject: @"--from-gmds"] == NO) {  
    static BOOL	is_daemon = NO;
    BOOL subtask = YES;

    if ([args containsObject: @"--daemon"]) {
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
	        fprintf (stderr, "unable to launch the gmds task. exiting.\n");
	        DESTROY (task);
	      }
      NS_ENDHANDLER

      exit(EXIT_FAILURE);
    }
  }
    
  RELEASE(pool);

  {
    CREATE_AUTORELEASE_POOL (pool);
    GMDS *gmds = [[GMDS alloc] init];
    RELEASE (pool);
  
    if (gmds != nil) {
	    CREATE_AUTORELEASE_POOL (pool);
      [[NSRunLoop currentRunLoop] run];
  	  RELEASE (pool);
    }
  }
    
  exit(EXIT_SUCCESS);
}

