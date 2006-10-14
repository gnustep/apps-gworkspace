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
#include <string.h>
#include "sqlite.h"
#include "MDKQuery.h"
#include "SQLite.h"

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
static BOOL repscore = NO;
static BOOL onlycount = NO;

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

static void contains_substr(sqlite3_context *context, int argc, sqlite3_value **argv)
{
  const char *buff = (const char *)sqlite3_value_text(argv[0]);
  const char *substr = (const char *)sqlite3_value_text(argv[1]);
  int contains = (strstr(buff, substr) != NULL);
  
  printf("buff = %s - substr = %s contains = %d\n", buff, substr, contains);
  
  sqlite3_result_int(context, contains);
}

static void append_unique_string(sqlite3_context *context, int argc, sqlite3_value **argv)
{
  const char *buff = (const char *)sqlite3_value_text(argv[0]);
  const char *str = (const char *)sqlite3_value_text(argv[1]);

  if (strstr(buff, str) == NULL) {
    char newbuff[2048] = "";
  
    sprintf(newbuff, "%s %s", buff, str);
    newbuff[strlen(newbuff)] = '\0';
    sqlite3_result_text(context, newbuff, strlen(newbuff), SQLITE_TRANSIENT);
    
    return;
  } 
  
  sqlite3_result_text(context, buff, strlen(buff), SQLITE_TRANSIENT);  
}

static void word_score(sqlite3_context *context, int argc, sqlite3_value **argv)
{
  int searchlen = strlen((const char *)sqlite3_value_text(argv[0]));
  int foundlen = strlen((const char *)sqlite3_value_text(argv[1]));
  int posting_wcount = sqlite3_value_int(argv[2]);
  int path_wcount = sqlite3_value_int(argv[3]);
  float score = (1.0 * posting_wcount / path_wcount);

  if (searchlen != foundlen) {
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
  float score = 0.0;

  if ((attribute_type == STRING) 
              || (attribute_type == ARRAY) 
                              || (attribute_type == DATA)) {
    if (operator_type == GMDEqualToOperatorType) {                          
      int searchlen = strlen((const char *)search_val);
      int foundlen = strlen((const char *)found_val);
    
      score = (1.0 * searchlen / foundlen); 
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
  int linescount = 0;
  int retry = 0;
  BOOL resok = YES;
  int err;
  int i;

  if (sqlite3_prepare(db, qbuff, strlen(qbuff), &stmt, NULL) == SQLITE_OK) {
    while (1) {
      err = sqlite3_step(stmt);
      
      if (err == SQLITE_ROW) {
        if (onlycount == NO) {
          int count = sqlite3_data_count(stmt);

          /* we use "<= count" because sqlite sends 
             also the id of the entry with type = 0 */
          for (i = 0; i <= count; i++) { 
            int type = sqlite3_column_type(stmt, i);

            /* mdfind reports only the path and (optionally) the score */          
            if (type == SQLITE_TEXT) {
              /* only if i == 0 to not print also the attribute name */  
           //   if (i == 0) {
                GSPrintf(stdout, @" %s", sqlite3_column_text(stmt, i));          
           //   }
           
            //
            // TOGLIERE ANCHE IL printf() IN contains_substr()
            //
           
            } else if (repscore && type == SQLITE_FLOAT) {
              GSPrintf(stdout, @" %f", sqlite3_column_double(stmt, i));          
            }
          }

          GSPrintf(stdout, @"\n");
        
        } else {
          linescount++;
        }

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
    
    if (onlycount) {
      GSPrintf(stdout, @"%i\n", linescount);
    }
    
  } else {
    GSPrintf(stderr, @"mdfind: %s\n", sqlite3_errmsg(db));
    resok = NO;
  }

  return resok;
}

void printAttributesList()
{
  NSArray *attributes = [MDKQuery attributesNames];
  unsigned i;
  
  for (i = 0; i < [attributes count]; i++) {
    GSPrintf(stderr, @"%@\n", [attributes objectAtIndex: i]);
  }
}

void printAttributeDescription(NSString *attribute)
{
  NSString *description = [MDKQuery attributeDescription: attribute];

  if (description) {
    GSPrintf(stderr, @"%@\n", description);
  } else {
    GSPrintf(stderr, @"%@: invalid attribute name!\n", attribute);
  }
}

void printHelp()
{
  GSPrintf(stderr,
      @"\n"
      @"The 'mdfind' tool finds files matching a given query\n"
      @"\n"
      @"usage: mdfind [arguments] query\n"
      @"\n"
      @"Arguments:\n"
      @"  -onlyin 'directory'    limits the the search to 'directory'.\n"
      @"  -s                     reports also the score for each found path.\n"
      @"  -c                     reports only the count of the found paths.\n"
      @"  -a [attribute]         if 'attribute' is supplied, prints the attribute\n"
      @"                         description, else prints the attributes list.\n"
      @"  -h                     shows this help and exit.\n"
      @"\n"
      @"The query have the format: attribute  operator  value\n"
      @"where 'attribute' is one of the attributes used by the mdextractor\n"
      @"tool when indexing (type 'mdfind -a' for the attribute list),\n"
      @"and 'operator' is one of the following:\n"
      @"  ==   equal\n"
      @"  !=   not equal\n"
      @"  <    less than (only for numeric values and dates)\n"
      @"  <=   less than or equal (only for numeric values and dates)\n"
      @"  >    greater than (only for numeric values and dates)\n"
      @"  >=   greater than or equal (only for numeric values and dates)\n"
      @"\n"
      @"Value comparision modifiers for string values:\n"
      @"Appending the 'c' character to the search value (ex. \"value\"c),\n"
      @"makes the query case insensitive.\n"      
      @"You can use the '*' wildcard to match substrings anywhere in the\n"
      @"search value.\n"
      @"\n"
      @"Combining queries:\n"
      @"Queries can be combined using '&&' for AND and '||' for OR and\n"
      @"parenthesis to define nesting criteria.\n"
      @"\n"
  );
}


int main(int argc, char **argv, char **env)
{
  NSAutoreleasePool	*pool;
  NSProcessInfo *proc;
  NSArray *args;
  NSString *arg; 
  NSString *searchdir = nil;
  unsigned count;
  unsigned pos;
  unsigned i;
  
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
  count = [args count];
  
  if (count <= 1) {
    GSPrintf(stderr, @"mdfind: too few arguments supplied!\n");
    RELEASE (pool);
    return 1;
  }
  
  pos = 1;
  
  for (i = 1; i < count; i++) {
    arg = [args objectAtIndex: i];
  
    if ([arg isEqual: @"-h"]) {
      printHelp();
      RELEASE (pool);
      return 0;
    
    } else if ([arg isEqual: @"-a"]) {
      if ((i + 1) < count) {
        printAttributeDescription([args objectAtIndex: (i + 1)]);
      } else {
        printAttributesList();
      }
      
      RELEASE (pool);
      return 0;            
    
    } else if ([arg isEqual: @"-s"]) {
      repscore = YES; 
      pos++;

    } else if ([arg isEqual: @"-c"]) {
      onlycount = YES; 
      pos++;
      
    } else if ([arg isEqual: @"-onlyin"]) {
      BOOL pathok = YES;
      
      if (i++ < count) {
        arg = [args objectAtIndex: i];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath: arg]) {
          ASSIGN (searchdir, arg);
          pos += 2;
        } else {
          pathok = NO;
        }
      } else {
        pathok = NO;
      }
      
      if (pathok == NO) {
        GSPrintf(stderr, @"mdfind: no search path or invalid path supplied!\n");
        RELEASE (pool);
        return 0;            
      }
    }   
  }
  
  if (pos < count) {
    NSArray *queryargs = [args subarrayWithRange: NSMakeRange(pos, count - pos)];
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
    sqlite3_create_function(db, "containsSubstr", 2, 
                                SQLITE_UTF8, 0, contains_substr, 0, 0);
    sqlite3_create_function(db, "appendUniqueString", 2, 
                                SQLITE_UTF8, 0, append_unique_string, 0, 0);
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
    NSArray *dirs = (searchdir ? [NSArray arrayWithObject: searchdir] : nil);  
    MDKQuery *query = [MDKQuery queryFromString: qstr inDirectories: dirs];
    NSDictionary *dict;
    NSArray *prequeries;
    NSArray *postqueries;
    NSString *joinstr;    

    dict = [query sqldescription];
    prequeries = [dict objectForKey: @"pre"];
    postqueries = [dict objectForKey: @"post"];
    joinstr = [dict objectForKey: @"join"];    
    
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
  
  printHelp();

  RELEASE (pool);

  return 1;
}
