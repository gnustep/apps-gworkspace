/* SQLite.m
 *  
 * Copyright (C) 2006-2013 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: May 2006
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

#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <limits.h>
#include <float.h>
#include "config.h"

#import "SQLite.h"

#define GWDebugLog(format, args...) \
  do { if (GW_DEBUG_LOG) \
    NSLog(format , ## args); } while (0)

#define MAX_RETRY 1000

@implementation SQLite

- (void)dealloc
{
  if (db != NULL) {
    sqlite3_close(db);
  }
  RELEASE (preparedStatements);
  
  [super dealloc];
}

+ (id)handlerForDbAtPath:(NSString *)path
                   isNew:(BOOL *)isnew
{
  return TEST_AUTORELEASE ([[self alloc] initForDbAtPath: path isNew: isnew]);
}

- (id)initForDbAtPath:(NSString *)path
                isNew:(BOOL *)isnew
{
  self = [super init];
  
  if (self) {
    preparedStatements = [NSMutableDictionary new];
    db = NULL;
    fm = [NSFileManager defaultManager];

    if ([self opendbAtPath: path isNew: isnew] == NO) {
      DESTROY (self);
      return self;
    }
  }
  
  return self;
}

- (id)init
{
  self = [super init];
  
  if (self) {
    preparedStatements = [NSMutableDictionary new];
    db = NULL;
    fm = [NSFileManager defaultManager];
  }

  return self;
}

- (BOOL)opendbAtPath:(NSString *)path
               isNew:(BOOL *)isnew
{
  *isnew = ([fm fileExistsAtPath: path] == NO);

  if (db == NULL) {
    NSArray *components = [path pathComponents];
    unsigned count = [components count];
    NSString *dbname = [components objectAtIndex: count - 1];
    NSString *dbpath = [NSString string];
    unsigned i;

    for (i = 0; i < (count - 1); i++) {
      NSString *dir = [components objectAtIndex: i];
      BOOL isdir;    
      
      dbpath = [dbpath stringByAppendingPathComponent: dir];
      
      if (([fm fileExistsAtPath: dbpath isDirectory: &isdir] &isdir) == NO) {
        if ([fm createDirectoryAtPath: dbpath attributes: nil] == NO) { 
          NSLog(@"unable to create: %@", dbpath);
          return NO;
        }
      }
    }

    dbpath = [dbpath stringByAppendingPathComponent: dbname];
    
    if (sqlite3_open([dbpath fileSystemRepresentation], &db) != SQLITE_OK) {
      NSLog(@"%s", sqlite3_errmsg(db));
		  return NO;	    
    }
  
    return YES;
  }
  
  return NO;
}

- (BOOL)attachDbAtPath:(NSString *)path
              withName:(NSString *)name
                 isNew:(BOOL *)isnew
{
  *isnew = ([fm fileExistsAtPath: path] == NO);

  if (db != NULL) {
    NSArray *components = [path pathComponents];
    unsigned count = [components count];
    NSString *dbname = [components objectAtIndex: count - 1];
    NSString *dbpath = [NSString string];
    NSString *query;
    unsigned i;

    for (i = 0; i < (count - 1); i++) {
      NSString *dir = [components objectAtIndex: i];
      BOOL isdir;    
      
      dbpath = [dbpath stringByAppendingPathComponent: dir];
      
      if (([fm fileExistsAtPath: dbpath isDirectory: &isdir] &isdir) == NO) {
        if ([fm createDirectoryAtPath: dbpath attributes: nil] == NO) { 
          NSLog(@"unable to create: %@", dbpath);
          return NO;
        }
      }
    }

    dbpath = [dbpath stringByAppendingPathComponent: dbname];
    query = [NSString stringWithFormat: @"ATTACH DATABASE '%@' AS %@", dbpath, name]; 
    
    return [self executeSimpleQuery: query];
  }
  
  return NO;
}

- (void)closeDb
{
  if (db != NULL) {
    sqlite3_close(db);
    db = NULL;
  }
}

- (sqlite3 *)db
{
  return db;
}

- (BOOL)executeSimpleQuery:(NSString *)query
{
  char *err;

  if (sqlite3_exec(db, [query UTF8String], NULL, 0, &err) != SQLITE_OK) {
    NSLog(@"error at %@", query);
    
    if (err != NULL) {
      NSLog(@"%s", err);
      sqlite3_free(err); 
    }
      
    return NO;    
  }

  return YES;
}

- (BOOL)executeQuery:(NSString *)query
{
  const char *qbuff = [query UTF8String];
  struct sqlite3_stmt *stmt;
  int retry = 0;
  int err;
  
  err = sqlite3_prepare(db, qbuff, strlen(qbuff), &stmt, NULL);
  
  if (err != SQLITE_OK) {
    NSLog(@"%s", sqlite3_errmsg(db));
    return NO;
  }
  
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

      if (retry++ >= MAX_RETRY) {
        NSLog(@"timeout for query: %@", query);
        NSLog(@"%s", sqlite3_errmsg(db));
        sqlite3_finalize(stmt);
		    return NO;
      }

    } else {
      NSLog(@"error at: %@", query);
      NSLog(@"%s", sqlite3_errmsg(db));
      sqlite3_finalize(stmt);
      return NO;
    }
  }

  sqlite3_finalize(stmt);
  
  return YES;
}

- (NSArray *)resultsOfQuery:(NSString *)query
{
  const char *qbuff = [query UTF8String];
  NSMutableArray *lines = [NSMutableArray array];
  struct sqlite3_stmt *stmt;
  int retry = 0;
  int err;
  int i;
    
  if (sqlite3_prepare(db, qbuff, strlen(qbuff), &stmt, NULL) == SQLITE_OK) {
    while (1) {
      err = sqlite3_step(stmt);

      if (err == SQLITE_ROW) {
        NSMutableDictionary *line = [NSMutableDictionary dictionary];
        int count = sqlite3_data_count(stmt);

        // we use "<= count" because sqlite sends also 
        // the id of the entry with type = 0 
        for (i = 0; i <= count; i++) { 
          const char *name = sqlite3_column_name(stmt, i); 
          
          if (name != NULL) {
            int type = sqlite3_column_type(stmt, i);

            if (type == SQLITE_INTEGER) {
              [line setObject: [NSNumber numberWithInt: sqlite3_column_int(stmt, i)]
                       forKey: [NSString stringWithUTF8String: name]];    
            
            } else if (type == SQLITE_FLOAT) {
              [line setObject: [NSNumber numberWithDouble: sqlite3_column_double(stmt, i)]
                       forKey: [NSString stringWithUTF8String: name]];    
            
            } else if (type == SQLITE_TEXT) {
              [line setObject: [NSString stringWithUTF8String: (const char *)sqlite3_column_text(stmt, i)]
                       forKey: [NSString stringWithUTF8String: name]];    

            } else if (type == SQLITE_BLOB) {
              const void *bytes = sqlite3_column_blob(stmt, i);
              int length = sqlite3_column_bytes(stmt, i); 
              
              [line setObject: [NSData dataWithBytes: bytes length: length]
                       forKey: [NSString stringWithUTF8String: name]];    
            }
          }
        }

        [lines addObject: line];

      } else {
        if (err == SQLITE_DONE) {
          break;

        } else if (err == SQLITE_BUSY) {
          CREATE_AUTORELEASE_POOL(arp); 
          NSDate *when = [NSDate dateWithTimeIntervalSinceNow: 0.1];

          [NSThread sleepUntilDate: when];
          GWDebugLog(@"retry %i", retry);
          RELEASE (arp);

          if (retry++ >= MAX_RETRY) {
            NSLog(@"timeout for query: %@", query);
            NSLog(@"%s", sqlite3_errmsg(db));
		        break;
          }

        } else {
          NSLog(@"error at: %@", query);
          NSLog(@"%i %s", err, sqlite3_errmsg(db));
          break;
        }
      }
    }
  
    sqlite3_finalize(stmt);
    
  } else {
    NSLog(@"error at: %@", query);
    NSLog(@"%s", sqlite3_errmsg(db));
  }
  
  return lines;
}

- (int)getIntEntry:(NSString *)query
{
  NSArray *result = [self resultsOfQuery: query];

  if ([result count]) {
    return [[[[result objectAtIndex: 0] allValues] objectAtIndex: 0] intValue];
  }

  return INT_MAX;
}

- (float)getFloatEntry:(NSString *)query
{
  NSArray *result = [self resultsOfQuery: query];

  if ([result count]) {
    return [[[[result objectAtIndex: 0] allValues] objectAtIndex: 0] floatValue];
  }

  return FLT_MAX;
}

- (NSString *)getStringEntry:(NSString *)query
{
  NSArray *result = [self resultsOfQuery: query];

  if ([result count]) {
    return [[[result objectAtIndex: 0] allValues] objectAtIndex: 0];
  }

  return nil;
}

- (NSData *)getBlobEntry:(NSString *)query
{
  NSArray *result = [self resultsOfQuery: query];

  if ([result count]) {
    return [[[result objectAtIndex: 0] allValues] objectAtIndex: 0];
  }

  return nil;
}

- (BOOL)createFunctionWithName:(NSString *)fname
                argumentsCount:(int)nargs
                  userFunction:(void *)funct
{
  return (sqlite3_create_function(db, [fname UTF8String], nargs, 
                              SQLITE_UTF8, 0, funct, 0, 0) == SQLITE_OK);
}

- (int)lastInsertRowId
{
  return sqlite3_last_insert_rowid(db);
}

@end


@implementation SQLite (PreparedStatements)

- (id)statementForQuery:(NSString *)query
         withIdentifier:(id)identifier
               bindings:(int)firstTipe, ...
{
  SQLitePreparedStatement *statement = [preparedStatements objectForKey: identifier];

  if (statement == nil) {
    statement = [SQLitePreparedStatement statementWithQuery: query onDb: db];
    
    if (statement == nil) {
      return nil;
    }
    
    [preparedStatements setObject: statement forKey: identifier];
  }
  
  if ([statement expired] && ([statement prepare] == NO)) {
    [preparedStatements removeObjectForKey: identifier];
    return nil;
  }
  
  if (firstTipe != 0) {  
    int type = firstTipe;
    id name;
    va_list	ap;
    
    va_start(ap, firstTipe);   
  
    while (type != 0) {    
      name = va_arg(ap, id); 
      
      if (type == SQLITE_INTEGER) {
        if ([statement bindIntValue: va_arg(ap, int) forName: name] == NO) {
          va_end(ap);  
          [preparedStatements removeObjectForKey: identifier];
          return nil;
        }
      
      } else if (type == SQLITE_FLOAT) {
        if ([statement bindDoubleValue: va_arg(ap, double) forName: name] == NO) {
          va_end(ap);  
          [preparedStatements removeObjectForKey: identifier];
          return nil;
        }
      
      } else if (type == SQLITE_TEXT) {
        if ([statement bindTextValue: va_arg(ap, id) forName: name] == NO) {
          va_end(ap);  
          [preparedStatements removeObjectForKey: identifier];
          return nil;
        }

      } else if (type == SQLITE_BLOB) {
        if ([statement bindBlobValue: va_arg(ap, id) forName: name] == NO) {
          va_end(ap);  
          [preparedStatements removeObjectForKey: identifier];
          return nil;
        }
      
      } else {
        va_end(ap);  
        [preparedStatements removeObjectForKey: identifier];
        return nil;
      }
      
      type = va_arg(ap, int); 
    }
    
    va_end(ap); 
  }
  
  return statement;
}

- (BOOL)executeQueryWithStatement:(SQLitePreparedStatement *)statement
{
  if (statement) {
    sqlite3_stmt *handle = [statement handle];
    int retry = 0;
    int err;

    while (1) {
      err = sqlite3_step(handle);

      if (err == SQLITE_DONE) {
        break;

      } else if (err == SQLITE_BUSY) {
        CREATE_AUTORELEASE_POOL(arp); 
        NSDate *when = [NSDate dateWithTimeIntervalSinceNow: 0.1];

        [NSThread sleepUntilDate: when];
        GWDebugLog(@"retry %i", retry);
        RELEASE (arp);

        if (retry++ > MAX_RETRY) {
          NSLog(@"timeout for query: %@", [statement query]);
          NSLog(@"%s", sqlite3_errmsg(db));
          [statement reset];
		      return NO;
        }

      } else {
        NSLog(@"error at: %@", [statement query]);
        NSLog(@"%s", sqlite3_errmsg(db));
        [statement reset];
        return NO;
      }
    }

    [statement reset];

    return YES;
  }
  
  return NO;
}

- (NSArray *)resultsOfQueryWithStatement:(SQLitePreparedStatement *)statement
{
  NSMutableArray *lines = [NSMutableArray array];
  
  if (statement) {
    sqlite3_stmt *handle = [statement handle];
    int retry = 0;
    int err;
    int i;

    while (1) {
      err = sqlite3_step(handle);

      if (err == SQLITE_ROW) {
        NSMutableDictionary *line = [NSMutableDictionary dictionary];
        int count = sqlite3_data_count(handle);

        // we use "<= count" because sqlite sends also 
        // the id of the entry with type = 0 
        for (i = 0; i <= count; i++) { 
          const char *name = sqlite3_column_name(handle, i); 

          if (name != NULL) {
            int type = sqlite3_column_type(handle, i);

            if (type == SQLITE_INTEGER) {
              [line setObject: [NSNumber numberWithInt: sqlite3_column_int(handle, i)]
                       forKey: [NSString stringWithUTF8String: name]];    

            } else if (type == SQLITE_FLOAT) {
              [line setObject: [NSNumber numberWithDouble: sqlite3_column_double(handle, i)]
                       forKey: [NSString stringWithUTF8String: name]];    

            } else if (type == SQLITE_TEXT) {
              [line setObject: [NSString stringWithUTF8String: (const char *)sqlite3_column_text(handle, i)]
                       forKey: [NSString stringWithUTF8String: name]];    

            } else if (type == SQLITE_BLOB) {
              const void *bytes = sqlite3_column_blob(handle, i);
              int length = sqlite3_column_bytes(handle, i); 

              [line setObject: [NSData dataWithBytes: bytes length: length]
                       forKey: [NSString stringWithUTF8String: name]];    
            }
          }
        }

        [lines addObject: line];

      } else {
        if (err == SQLITE_DONE) {
          break;

        } else if (err == SQLITE_BUSY) {
          CREATE_AUTORELEASE_POOL(arp); 
          NSDate *when = [NSDate dateWithTimeIntervalSinceNow: 0.1];

          [NSThread sleepUntilDate: when];
          GWDebugLog(@"retry %i", retry);
          RELEASE (arp);

          if (retry++ > MAX_RETRY) {
            NSLog(@"timeout for query: %@", [statement query]);
            NSLog(@"%s", sqlite3_errmsg(db));
		        break;
          }

        } else {
          NSLog(@"error at: %@", [statement query]);
          NSLog(@"%i %s", err, sqlite3_errmsg(db));
          break;
        }
      }
    }

    [statement reset];
  }
      
  return lines;
}

- (int)getIntEntryWithStatement:(SQLitePreparedStatement *)statement
{
  NSArray *result = [self resultsOfQueryWithStatement: statement];

  if ([result count]) {
    return [[[[result objectAtIndex: 0] allValues] objectAtIndex: 0] intValue];
  }

  return INT_MAX;
}

- (float)getFloatEntryWithStatement:(SQLitePreparedStatement *)statement
{
  NSArray *result = [self resultsOfQueryWithStatement: statement];

  if ([result count]) {
    return [[[[result objectAtIndex: 0] allValues] objectAtIndex: 0] floatValue];
  }

  return FLT_MAX;
}

- (NSString *)getStringEntryWithStatement:(SQLitePreparedStatement *)statement
{
  NSArray *result = [self resultsOfQueryWithStatement: statement];

  if ([result count]) {
    return [[[result objectAtIndex: 0] allValues] objectAtIndex: 0];
  }

  return nil;
}

- (NSData *)getBlobEntryWithStatement:(SQLitePreparedStatement *)statement
{
  NSArray *result = [self resultsOfQueryWithStatement: statement];

  if ([result count]) {
    return [[[result objectAtIndex: 0] allValues] objectAtIndex: 0];
  }

  return nil;
}

@end


@implementation SQLitePreparedStatement

- (void)dealloc
{
  if (handle != NULL) {
    sqlite3_finalize(handle);
  }
  RELEASE (query);
  [super dealloc];
}

+ (id)statementWithQuery:(NSString *)aquery
                    onDb:(sqlite3 *)dbptr
{
  return TEST_AUTORELEASE ([[self alloc] initWithQuery: aquery onDb: dbptr]);
}
                    
- (id)initWithQuery:(NSString *)aquery 
               onDb:(sqlite3 *)dbptr
{
  self = [super init];

  if (self) {
    ASSIGN (query, stringForQuery(aquery));
    db = dbptr;
    handle = NULL;
    
    if (sqlite3_prepare(db, [query UTF8String], -1, &handle, NULL) != SQLITE_OK) {
      NSLog(@"%s", sqlite3_errmsg(db));
      DESTROY (self);
    }
  }
  
  return self;
}

- (BOOL)bindIntValue:(int)value 
             forName:(NSString *)name
{
  int index = sqlite3_bind_parameter_index(handle, [name UTF8String]);

  if (index != 0) {
    return (sqlite3_bind_int(handle, index, value) == SQLITE_OK);
  }
  
  return NO;
}

- (BOOL)bindDoubleValue:(double)value 
                forName:(NSString *)name
{
  int index = sqlite3_bind_parameter_index(handle, [name UTF8String]);

  if (index != 0) {
    return (sqlite3_bind_double(handle, index, value) == SQLITE_OK);
  }
  
  return NO;
}

- (BOOL)bindTextValue:(NSString *)value 
              forName:(NSString *)name
{
  int index = sqlite3_bind_parameter_index(handle, [name UTF8String]);

  if (index != 0) {
    return (sqlite3_bind_text(handle, index, [value UTF8String], -1, SQLITE_TRANSIENT) == SQLITE_OK);
  }

  return NO;
}

- (BOOL)bindBlobValue:(NSData *)value 
              forName:(NSString *)name
{
  int index = sqlite3_bind_parameter_index(handle, [name UTF8String]);

  if (index != 0) {
    const void *bytes = [value bytes];
    return (sqlite3_bind_blob(handle, index, bytes, [value length], SQLITE_TRANSIENT) == SQLITE_OK);
  }

  return NO;
}

- (BOOL)expired
{
  return (sqlite3_expired(handle) != 0);
}

- (BOOL)prepare
{
  if (sqlite3_prepare(db, [query UTF8String], -1, &handle, NULL) != SQLITE_OK) {
    NSLog(@"%s", sqlite3_errmsg(db));
    return NO;
  }

  return YES;
}

- (BOOL)reset
{
  return (sqlite3_reset(handle) == SQLITE_OK);
}

- (BOOL)finalizeStatement
{
  int err = sqlite3_finalize(handle);

  if (err == SQLITE_OK) {
    handle = NULL;
    return YES;
  }
  
  return NO;
}

- (NSString *)query
{
  return query;
}

- (sqlite3_stmt *)handle
{
  return handle;
}

@end


NSString *stringForQuery(NSString *str)
{
	NSRange range, subRange;
	NSMutableString *querystr;

  range = NSMakeRange(0, [str length]);
	subRange = [str rangeOfString: @"'" options: NSLiteralSearch range: range];
	
  if (subRange.location == NSNotFound) {
		return str;
	}
  
	querystr = [NSMutableString stringWithString: str];
  
	while ((subRange.location != NSNotFound) && (range.length > 0)) {
		subRange = [querystr rangeOfString: @"'" 
                               options: NSLiteralSearch 
                                 range: range];
		
    if (subRange.location != NSNotFound) {
			[querystr replaceCharactersInRange: subRange withString: @"''"];
		}
    
		range.location = subRange.location + 2;
	  
    if ([querystr length] < range.location) {
      range.length = 0;
    } else {
      range.length = [querystr length] - range.location;
    }
  }
  
	return querystr;
}











