/* mdfind.m
 *  
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@dtedu.net>
 * Date: October 2006
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
#include "sqlite.h"
#include <MDKit/MDKit.h>

#define MAX_RETRY 1000

enum {
  STRING,
  ARRAY,
  NUMBER,
  DATE,
  DATA
};

enum {
  NUM_INT,
  NUM_FLOAT,
  NUM_BOOL
};

static sqlite3 *db = NULL;


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

static void word_score(sqlite3_context *context, int argc, sqlite3_value **argv)
{
  int searchlen = strlen((const char *)sqlite3_value_text(argv[0]));
  int foundlen = strlen((const char *)sqlite3_value_text(argv[1]));
  int posting_wcount = sqlite3_value_int(argv[2]);
  int path_wcount = sqlite3_value_int(argv[3]);
  float score = (1.0 * posting_wcount / path_wcount);

  if (searchlen != foundlen) {
    /* TODO a better correction algorithm for score */
    score *= (1.0 * searchlen / foundlen);    
  } 

  sqlite3_result_double(context, score);
}

static void attribute_score(sqlite3_context *context, int argc, sqlite3_value **argv)
{
  const unsigned char *search_val = sqlite3_value_text(argv[0]);
  const unsigned char *found_val = sqlite3_value_text(argv[1]);
  int attribute_type = sqlite3_value_int(argv[2]);
  GMDOperatorType operator_type = sqlite3_value_int(argv[3]);
  float score = 1.0;

  if ((attribute_type == STRING) 
              || (attribute_type == ARRAY) 
                              || (attribute_type == DATA)) {
    if (operator_type == GMDEqualToOperatorType) {                          
      int searchlen = strlen((const char *)search_val);
      int foundlen = strlen((const char *)found_val);
    
      score *= (searchlen / foundlen); 
    }
  }

  sqlite3_result_double(context, score);
}

BOOL performSubquery(NSString *query)
{
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
        GSPrintf(stderr, @"mdfind: retry %i\n", retry);
        RELEASE (arp);

        if (retry++ > MAX_RETRY) {
          GSPrintf(stderr, @"mdfind: %s\n", sqlite3_errmsg(db));
		      break;
        }

      } else {
        GSPrintf(stderr, @"mdfind: %s\n", sqlite3_errmsg(db));
        break;
      }
    }
    
    sqlite3_finalize(stmt);
  }
  
  return (err == SQLITE_DONE);
}

BOOL performPreQueries(NSArray *queries)
{
  int i;
  
  if (performSubquery(@"BEGIN") == NO) {
    return NO;
  }
  
  for (i = 0; i < [queries count]; i++) {
    if (performSubquery([queries objectAtIndex: i]) == NO) {
      performSubquery(@"COMMIT");
      return NO;
    }
  }
  
  performSubquery(@"COMMIT");
   
  return YES;
}

void performPostQueries(NSArray *queries)
{
  int i;

  if (performSubquery(@"BEGIN") == NO) {
    return;
  }

  for (i = 0; i < [queries count]; i++) {
    performSubquery([queries objectAtIndex: i]);
  }

  performSubquery(@"COMMIT");
}

BOOL queryResults(NSString *qstr)
{
  const char *qbuff = [qstr UTF8String];
  struct sqlite3_stmt *stmt;
  int retry = 0;
  BOOL resok = YES;
  int err;
  int i;

  if (sqlite3_prepare(db, qbuff, strlen(qbuff), &stmt, NULL) == SQLITE_OK) {
    while (1) {
      err = sqlite3_step(stmt);
      
      if (err == SQLITE_ROW) {
        int count = sqlite3_data_count(stmt);

        // we use "<= count" because sqlite sends also 
        // the id of the entry with type = 0 
        for (i = 0; i <= count; i++) { 
          int type = sqlite3_column_type(stmt, i);
                    
          if (type == SQLITE_INTEGER) {
   //         GSPrintf(stdout, @"%i", sqlite3_column_int(stmt, i));

          } else if (type == SQLITE_FLOAT) {
   //         GSPrintf(stdout, @"%f", sqlite3_column_double(stmt, i));
            
          } else if (type == SQLITE_TEXT) {
            GSPrintf(stdout, @"%s", sqlite3_column_text(stmt, i));
          
          } else if (type == SQLITE_BLOB) {
    //        GSPrintf(stdout, @"%s", sqlite3_column_blob(stmt, i));
          }
        
          GSPrintf(stdout, @" ");
        }

        GSPrintf(stdout, @"\n");

      } else {
        if (err == SQLITE_DONE) {
          break;
        
        } else if (err == SQLITE_BUSY) {
          CREATE_AUTORELEASE_POOL(arp); 
          NSDate *when = [NSDate dateWithTimeIntervalSinceNow: 0.1];

          [NSThread sleepUntilDate: when];
          GSPrintf(stderr, @"mdfind: retry %i\n", retry);
          RELEASE (arp);

          if (retry++ > MAX_RETRY) {
            GSPrintf(stderr, @"mdfind: %s\n", sqlite3_errmsg(db));
            resok = NO;
		        break;
          }

        } else {
          GSPrintf(stderr, @"mdfind: %i %s\n", err, sqlite3_errmsg(db));
          resok = NO;
          break;
        }
      }
    }
     
    sqlite3_finalize(stmt);
    
  } else {
    GSPrintf(stderr, @"mdfind: %s\n", sqlite3_errmsg(db));
    resok = NO;
  }

  return resok;
}


int main(int argc, char **argv, char **env)
{
  NSAutoreleasePool	*pool;
  NSProcessInfo *proc;
  NSArray *args;

#ifdef GS_PASS_ARGUMENTS
  [NSProcessInfo initializeWithArguments: argv count: argc environment: env];
#endif

  pool = [NSAutoreleasePool new];
  proc = [NSProcessInfo processInfo];
  
  if (proc == nil) {
    GSPrintf(stderr, @"mdfind: unable to get process information!\n");
    RELEASE (pool);
    return 1;
  }

  args = [proc arguments];

  if ([args count] > 1) {
    NSArray *queryargs = [args subarrayWithRange: NSMakeRange(1, [args count] - 1)];
    NSMutableString *qstr = [[queryargs componentsJoinedByString: @" "] mutableCopy];
    NSString *dbpath;

    dbpath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    dbpath = [dbpath stringByAppendingPathComponent: @"gmds"];    
    dbpath = [dbpath stringByAppendingPathComponent: @".db"];
    dbpath = [dbpath stringByAppendingPathComponent: @"v3"];
    dbpath = [dbpath stringByAppendingPathComponent: @"contents.db"];    
    
    db = opendbAtPath(dbpath);
    
    if (db == NULL) {
      GSPrintf(stderr, @"mdfind: unable to open the db!\n");
      RELEASE (pool);
      return 1;
    }
    
    sqlite3_create_function(db, "pathExists", 1, 
                                SQLITE_UTF8, 0, path_exists, 0, 0);
    sqlite3_create_function(db, "wordScore", 4, 
                                SQLITE_UTF8, 0, word_score, 0, 0);
    sqlite3_create_function(db, "attributeScore", 4, 
                                SQLITE_UTF8, 0, attribute_score, 0, 0);

    performWriteQuery(db, @"PRAGMA cache_size = 20000");
    performWriteQuery(db, @"PRAGMA count_changes = 0");
    performWriteQuery(db, @"PRAGMA synchronous = OFF");
    performWriteQuery(db, @"PRAGMA temp_store = MEMORY");

    [qstr replaceOccurrencesOfString: @"(" 
                          withString: @" ( " 
                             options: NSLiteralSearch
                               range: NSMakeRange(0, [qstr length])];

    [qstr replaceOccurrencesOfString: @")" 
                          withString: @" ) " 
                             options: NSLiteralSearch
                               range: NSMakeRange(0, [qstr length])];
    
	  NS_DURING
	    {
    MDKQuery *query = [MDKQuery queryFromString: qstr];
    NSDictionary *dict = [query sqldescription];
    NSArray *prequeries = [dict objectForKey: @"pre"];
    NSArray *postqueries = [dict objectForKey: @"post"];
    NSString *joinstr = [dict objectForKey: @"join"];    

    if (prequeries && (performPreQueries(prequeries) == NO)) {
      GSPrintf(stderr, @"mdfind: error in: %@", [prequeries description]);
      closedb(db);
      RELEASE (pool);
      return 1;    
    }
      
    if (queryResults(joinstr) == NO) {
      GSPrintf(stderr, @"mdfind: error in: %@", joinstr);
    }
    
    if (postqueries) {
      performPostQueries(postqueries);
    }


 //   GSPrintf(stdout, @"%@\n", [[query sqldescription] description]);
 //   GSPrintf(stdout, @"%@\n", [query description]);


      }
	  NS_HANDLER
	    {
    GSPrintf(stderr, @"mdfind: %@\n", localException);
    closedb(db);
    RELEASE (pool);
    return 1;
	    }
	  NS_ENDHANDLER
    
    closedb(db);

    RELEASE (qstr);
    RELEASE (pool);
	  
    return 0;
  }

/*
  GSPrintf(stderr,
@"The 'gspath' utility prints out various items of path/directory\n"
@"information (one item at a time).\n"
@"The program always takes a single argument ... selecting the information\n"
@"to be printed.\n\n"
@"The arguments and their meanings are -\n\n"
@"defaults\n"
@"  The GNUstep defaults directory of the current user\n\n"
@"libpath\n"
@"  A path specification which may be used to add all the standard GNUstep\n"
@"  directories where dynamic libraries are normally stored.\n\n"
@"  you might do 'LD_LIBRARY_PATH=$LD_LIBRARY_PATH:`gspath libpath`' to make\n"
@"  use of this.\n\n"
@"path\n"
@"  A path specification which may be used to add all the standard GNUstep\n"
@"  directories where command-line programs are normally stored.\n"
@"  you might do 'PATH=$PATH:`gspath path`' to make use of this.\n\n"
@"user\n"
@"  The GNUstep home directory of the current user\n\n"
);
*/

  RELEASE (pool);

  return 1;
}
