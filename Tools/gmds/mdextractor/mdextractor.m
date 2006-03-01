/* mdextractor.m
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <sys/types.h>
#include <sys/stat.h>
#include "mdextractor.h"
#include "dbschema.h"
#include "config.h"

#define DLENGTH 256

#define GWDebugLog(format, args...) \
  do { if (GW_DEBUG_LOG) \
    NSLog(format , ## args); } while (0)

#define PERFORM_OR_EXIT(d, q) \
do { \
  if (performWriteQuery(d, q) == NO) { \
    NSLog(@"error at: %@", q); \
    exit(EXIT_FAILURE); \
  } \
} while (0)


static void path_Exists(sqlite3_context *context, int argc, sqlite3_value **argv)
{
  const unsigned char *path = sqlite3_value_text(argv[0]);
  int exists = 0;
  
  if (path) {
    struct stat statbuf;  
    exists = (stat((const char *)path, &statbuf) == 0);
  }
     
  sqlite3_result_int(context, exists);
}


@implementation	GMDSExtractor

- (void)dealloc
{
  [nc removeObserver: self];

  RELEASE (dbpath);
  TEST_RELEASE (extractorInfoPath);
  TEST_RELEASE (extractorInfoLock);
  RELEASE (extractors);  
  RELEASE (textExtractor);
  RELEASE (stemmer);  
  TEST_RELEASE (stopWords);
  
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
    NSString *dbdir;
    NSString *lockpath;
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

    ASSIGN (dbpath, [dbdir stringByAppendingPathComponent: @"contents.db"]);    
    ASSIGN (extractorInfoPath, [dbdir stringByAppendingPathComponent: @"extractors.plist"]);
    lockpath = [dbdir stringByAppendingPathComponent: @"extractors.lock"];
    extractorInfoLock = [[NSDistributedLock alloc] initWithPath: lockpath];
    
    db = NULL;

    if ([self opendb] == NO) {
      DESTROY (self);
      return self;    
    }

    conn = [NSConnection defaultConnection];
    [conn setRootObject: self];
    [conn setDelegate: self];

    if ([conn registerName: @"mdextractor"] == NO) {
	    NSLog(@"unable to register with name server - quiting.");
	    DESTROY (self);
	    return self;
	  }

    nc = [NSNotificationCenter defaultCenter];

    [nc addObserver: self
           selector: @selector(connectionDidDie:)
	             name: NSConnectionDidDieNotification
	           object: conn];

    ws = [NSWorkspace sharedWorkspace];   

    textExtractor = nil;        
    [self loadExtractors];
    
    [self loadStemmer];
    [self setStemmingLanguage: nil];
  }
  
  return self;
}

- (BOOL)connection:(NSConnection *)ancestor
            shouldMakeNewConnection:(NSConnection *)newConn;
{
  [nc addObserver: self
         selector: @selector(connectionDidDie:)
	           name: NSConnectionDidDieNotification
	         object: newConn];
           
  [newConn setDelegate: self];
  
  return YES;
}

- (void)connectionDidDie:(NSNotification *)notification
{
  id connection = [notification object];

  [nc removeObserver: self
	              name: NSConnectionDidDieNotification
	            object: connection];

  if (connection == conn) {
    NSLog(@"mdextractor connection has been destroyed. Exiting.");
    exit(EXIT_FAILURE);
  }
}

- (oneway void)startExtracting
{

}

- (void)setMetadata:(NSDictionary *)mddict
            forPath:(NSString *)path
     withAttributes:(NSDictionary *)attributes
{

}

- (void)setFileSystemMetadataForPath:(NSString *)path
                      withAttributes:(NSDictionary *)attributes
{

}

- (id)extractorForPath:(NSString *)path
        withAttributes:(NSDictionary *)attributes
{
  
  return nil;
}

- (void)loadExtractors
{
  NSString *bundlesDir;
  NSMutableArray *bundlesPaths;
  NSEnumerator *enumerator;
  NSString *dir;
  int i;
   
  bundlesDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSSystemDomainMask, YES) lastObject];
  bundlesDir = [bundlesDir stringByAppendingPathComponent: @"Bundles"];

  bundlesPaths = [NSMutableArray array];

  enumerator = [[fm directoryContentsAtPath: bundlesDir] objectEnumerator];

  while ((dir = [enumerator nextObject])) {
    if ([[dir pathExtension] isEqual: @"extr"]) {
			[bundlesPaths addObject: [bundlesDir stringByAppendingPathComponent: dir]];
		}
  }

  extractors = [NSMutableArray new];
  
  for (i = 0; i < [bundlesPaths count]; i++) {
    NSString *bpath = [bundlesPaths objectAtIndex: i];
    NSBundle *bundle = [NSBundle bundleWithPath: bpath]; 

    if (bundle) {
			Class principalClass = [bundle principalClass];  
  
			if ([principalClass conformsToProtocol: @protocol(ExtractorsProtocol)]) {	
        id extractor = [[principalClass alloc] initForExtractor: self];
        
        if ([[extractor pathExtensions] containsObject: @"txt"]) {
          ASSIGN (textExtractor, extractor);
        } else {
          [extractors addObject: extractor];
          RELEASE ((id)extractor);
        }
      }
    }
  }
}

- (void)setStemmingLanguage:(NSString *)language
{
  NSString *lang = (language == nil) ? @"English" : language;

  if ([stemmer setLanguage: lang] == NO) {
    [stemmer setLanguage: @"English"];
  }
  
  ASSIGN (stopWords, [NSSet setWithArray: [stemmer stopWords]]);
}

- (void)loadStemmer
{
  NSString *bundlePath;

  bundlePath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSSystemDomainMask, YES) lastObject];
  bundlePath = [bundlePath stringByAppendingPathComponent: @"Bundles"];
  bundlePath = [bundlePath stringByAppendingPathComponent: @"Stemmer.bundle"];

  if ([fm fileExistsAtPath: bundlePath]) {
    NSBundle *bundle = [NSBundle bundleWithPath: bundlePath];

    if (bundle) {
      stemmer = [[bundle principalClass] new];
    } 
  }
  
  if (stemmer == nil) {
    [NSException raise: NSInternalInconsistencyException
		            format: @"unable to load stemmer"];   
    exit(EXIT_FAILURE);
  }
}

- (BOOL)opendb
{
  if (db == NULL) {
    BOOL newdb = ([fm fileExistsAtPath: dbpath] == NO);
  
    db = opendbAtPath(dbpath);

    if (db != NULL) {
      if (newdb) {
        if (performQuery(db, dbschema) == nil) {
          NSLog(@"unable to create the database at %@", dbpath);
          return NO;    
        } else {
          GWDebugLog(@"database created");
        }
      }    
    } else {
      NSLog(@"unable to open the database at %@", dbpath);
      return NO;
    }    
    
    sqlite3_create_function(db, "pathExists", 1, 
                                SQLITE_UTF8, 0, path_Exists, 0, 0);

    performWriteQuery(db, @"PRAGMA cache_size = 20000");
    performWriteQuery(db, @"PRAGMA count_changes = 0");
    performWriteQuery(db, @"PRAGMA synchronous = OFF");
    performWriteQuery(db, @"PRAGMA temp_store = MEMORY");
  }

  return YES;
}

- (NSDictionary *)extractorInfo
{
  if (extractorInfoPath && [fm isReadableFileAtPath: extractorInfoPath]) {
    NSDictionary *info;

    if ([extractorInfoLock tryLock] == NO) {
      unsigned sleeps = 0;

      if ([[extractorInfoLock lockDate] timeIntervalSinceNow] < -20.0) {
	      NS_DURING
	        {
	      [extractorInfoLock breakLock];
	        }
	      NS_HANDLER
	        {
        NSLog(@"Unable to break lock %@ ... %@", extractorInfoLock, localException);
	        }
	      NS_ENDHANDLER
      }

      for (sleeps = 0; sleeps < 10; sleeps++) {
	      if ([extractorInfoLock tryLock]) {
	        break;
	      }

        sleeps++;
	      [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
	    }

      if (sleeps >= 10) {
        NSLog(@"Unable to obtain lock %@", extractorInfoLock);
        return nil;
	    }
    }

    info = [NSDictionary dictionaryWithContentsOfFile: extractorInfoPath];
    [extractorInfoLock unlock];

    return info;
  }
  
  return nil;
}

- (void)writeExtractorInfo
{
  if (extractorInfoPath) {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];







    if ([extractorInfoLock tryLock] == NO) {
      unsigned sleeps = 0;

      if ([[extractorInfoLock lockDate] timeIntervalSinceNow] < -20.0) {
	      NS_DURING
	        {
	      [extractorInfoLock breakLock];
	        }
	      NS_HANDLER
	        {
        NSLog(@"Unable to break lock %@ ... %@", extractorInfoLock, localException);
	        }
	      NS_ENDHANDLER
      }

      for (sleeps = 0; sleeps < 10; sleeps++) {
	      if ([extractorInfoLock tryLock]) {
	        break;
	      }

        sleeps++;
	      [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
	    }

      if (sleeps >= 10) {
        NSLog(@"Unable to obtain lock %@", extractorInfoLock);
        return;
	    }
    }

    [info writeToFile: extractorInfoPath atomically: YES];
    [extractorInfoLock unlock];
  }
}

- (void)terminate
{
  [nc removeObserver: self];
  
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
	      fprintf (stderr, "unable to launch the mdextractor task. exiting.\n");
	      DESTROY (task);
	    }
    NS_ENDHANDLER
      
    exit(EXIT_FAILURE);
  }
  
  RELEASE(pool);

  {
    CREATE_AUTORELEASE_POOL (pool);
	  GMDSExtractor *extractor = [[GMDSExtractor alloc] init];
    RELEASE (pool);

    if (extractor != nil) {
	    CREATE_AUTORELEASE_POOL (pool);
      [[NSRunLoop currentRunLoop] run];
  	  RELEASE (pool);
    }
  }
    
  exit(EXIT_SUCCESS);
}



