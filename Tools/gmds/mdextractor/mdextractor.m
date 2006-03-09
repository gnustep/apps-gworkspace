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

BOOL isDotFile(NSString *path)
{
  int len = ([path length] - 1);
  unichar c;
  int i;
  
  for (i = len; i >= 0; i--) {
    c = [path characterAtIndex: i];
    
    if (c == '.') {
      if ((i > 0) && ([path characterAtIndex: (i - 1)] == '/')) {
        return YES;
      }
    }
  }
  
  return NO;  
}


@implementation	GMDSExtractor

- (void)dealloc
{
  if (statusTimer && [statusTimer isValid]) {
    [statusTimer invalidate];
  }
  DESTROY (statusTimer);
  
  [dnc removeObserver: self];
  [nc removeObserver: self];
  
  DESTROY (indexedPaths);
  freeTree(excludePathsTree);
  DESTROY (pathsStatus);
  DESTROY (dbpath);
  DESTROY (indexedStatusPath);
  DESTROY (indexedStatusLock);
  DESTROY (extractors);  
  DESTROY (textExtractor);
  DESTROY (stemmer);  
  DESTROY (stopWords);
  
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
    NSUserDefaults *defaults;
    id entry;
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
    ASSIGN (indexedStatusPath, [dbdir stringByAppendingPathComponent: @"status.plist"]);
    lockpath = [dbdir stringByAppendingPathComponent: @"extractors.lock"];
    indexedStatusLock = [[NSDistributedLock alloc] initWithPath: lockpath];
    
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

    textExtractor = nil;        
    [self loadExtractors];
    
    [self loadStemmer];
    [self setStemmingLanguage: nil];
        
    dnc = [NSDistributedNotificationCenter defaultCenter];
    
    [dnc addObserver: self
            selector: @selector(indexedDirectoriesChanged:)
	              name: @"GSMetadataIndexedDirectoriesChanged"
	            object: nil];
    
    ws = [NSWorkspace sharedWorkspace]; 
    
    indexedPaths = [NSMutableArray new];
    excludePathsTree = newTreeWithIdentifier(@"excluded");
    pathsStatus = [NSMutableDictionary new];
    
    defaults = [NSUserDefaults standardUserDefaults];
    [defaults synchronize];
    
    entry = [defaults arrayForKey: @"GSMetadataIndexedPaths"];
    if (entry) {
      [indexedPaths addObjectsFromArray: entry];
    }
    
    entry = [defaults arrayForKey: @"GSMetadataExcludedPaths"];
    if (entry) {
      unsigned i;
      
      for (i = 0; i < [entry count]; i++) {
        insertComponentsOfPath([entry objectAtIndex: i], excludePathsTree);
      }
    }
  
    indexingEnabled = [defaults boolForKey: @"GSMetadataIndexingEnabled"];    
    
    extracting = NO;
    statusTimer = nil;
    
    if ([self synchronizePathsStatus: YES] && indexingEnabled) {
      [self startExtracting];
    }
  }
  
  return self;
}

- (void)indexedDirectoriesChanged:(NSNotification *)notification
{
  NSDictionary *info = [notification userInfo];
  NSArray *indexed = [info objectForKey: @"GSMetadataIndexedPaths"];
  NSArray *excluded = [info objectForKey: @"GSMetadataExcludedPaths"];
  BOOL shouldExtract;
  unsigned i;

  [indexedPaths removeAllObjects];
  [indexedPaths addObjectsFromArray: indexed];

  // Controllare anche se ne e' stata tolta qualcuna e
  // toglierla dal database?
  // Fermare l'indexing se la path current e' stata tolta?
  
  emptyTreeWithBase(excludePathsTree);
  
  for (i = 0; i < [excluded count]; i++) {
    insertComponentsOfPath([excluded objectAtIndex: i], excludePathsTree);
  }

  indexingEnabled = [[info objectForKey: @"GSMetadataIndexingEnabled"] boolValue];
  
  shouldExtract = [self synchronizePathsStatus: NO];
  
  if (indexingEnabled) {
    if (shouldExtract && (extracting == NO)) {
      [self startExtracting];
    }
  
  } else if (extracting) {
    [self stopExtracting];
  }
}

- (BOOL)synchronizePathsStatus:(BOOL)onstart
{
  CREATE_AUTORELEASE_POOL(arp);
  BOOL shouldExtract = NO;
  unsigned i;
    
  if (onstart) {
    NSDictionary *savedStatus = [self readPathsStatus];
    
    for (i = 0; i < [indexedPaths count]; i++) {
      NSString *path = [indexedPaths objectAtIndex: i];
      NSDictionary *savedDict = [savedStatus objectForKey: path];
      NSMutableDictionary *dict;
        
      if (savedDict != nil) {
        dict = [savedDict mutableCopy];
      } else {
        dict = [NSMutableDictionary new];
        [dict setObject: [NSNumber numberWithBool: NO] forKey: @"indexed"];
        [dict setObject: [NSNumber numberWithUnsignedLong: 0L] forKey: @"files"];
      }
      
      [pathsStatus setObject: dict forKey: path];
      
      RELEASE (dict);
    }
  
  } else {
    NSArray *paths = [[pathsStatus allKeys] copy];
        
    for (i = 0; i < [paths count]; i++) {
      NSString *path = [paths objectAtIndex: i];  
      
      if ([indexedPaths containsObject: path] == NO) {
        [pathsStatus removeObjectForKey: path];
      }
    }
    
    RELEASE (paths);
    
    for (i = 0; i < [indexedPaths count]; i++) {
      NSString *path = [indexedPaths objectAtIndex: i];
      NSMutableDictionary *dict = [pathsStatus objectForKey: path];
      
      if (dict == nil) {
        dict = [NSMutableDictionary dictionary];
    
        [dict setObject: [NSNumber numberWithBool: NO] forKey: @"indexed"];
        [dict setObject: [NSNumber numberWithUnsignedLong: 0L] forKey: @"files"];
        
        [pathsStatus setObject: dict forKey: path];
      }
    }
  
    [self writePathsStatus: nil];
  }
  
  {  
    NSArray *pathsInfo = [pathsStatus allValues]; 
  
    for (i = 0; i < [pathsInfo count]; i++) {
      NSDictionary *dict = [pathsInfo objectAtIndex: i];
    
      if ([[dict objectForKey: @"indexed"] boolValue] == NO) {
        shouldExtract = YES;
        break; 
      }
    }
  }
     
  RELEASE (arp);  
  
  return shouldExtract;
}

- (NSDictionary *)readPathsStatus
{
  if (indexedStatusPath && [fm isReadableFileAtPath: indexedStatusPath]) {
    NSDictionary *info;

    if ([indexedStatusLock tryLock] == NO) {
      unsigned sleeps = 0;

      if ([[indexedStatusLock lockDate] timeIntervalSinceNow] < -20.0) {
	      NS_DURING
	        {
	      [indexedStatusLock breakLock];
	        }
	      NS_HANDLER
	        {
        NSLog(@"Unable to break lock %@ ... %@", indexedStatusLock, localException);
	        }
	      NS_ENDHANDLER
      }

      for (sleeps = 0; sleeps < 10; sleeps++) {
	      if ([indexedStatusLock tryLock]) {
	        break;
	      }

        sleeps++;
	      [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
	    }

      if (sleeps >= 10) {
        NSLog(@"Unable to obtain lock %@", indexedStatusLock);
        return [NSDictionary dictionary];
	    }
    }

    info = [NSDictionary dictionaryWithContentsOfFile: indexedStatusPath];
    [indexedStatusLock unlock];

    return info;
  }
  
  return [NSDictionary dictionary];
}

- (void)writePathsStatus:(id)sender
{
  if (indexedStatusPath) {
    if ([indexedStatusLock tryLock] == NO) {
      unsigned sleeps = 0;

      if ([[indexedStatusLock lockDate] timeIntervalSinceNow] < -20.0) {
	      NS_DURING
	        {
	      [indexedStatusLock breakLock];
	        }
	      NS_HANDLER
	        {
        NSLog(@"Unable to break lock %@ ... %@", indexedStatusLock, localException);
	        }
	      NS_ENDHANDLER
      }

      for (sleeps = 0; sleeps < 10; sleeps++) {
	      if ([indexedStatusLock tryLock]) {
	        break;
	      }

        sleeps++;
	      [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
	    }

      if (sleeps >= 10) {
        NSLog(@"Unable to obtain lock %@", indexedStatusLock);
        return;
	    }
    }

    [pathsStatus writeToFile: indexedStatusPath atomically: YES];
    [indexedStatusLock unlock];
    
    GWDebugLog(@"paths status updated"); 
  }
}

- (void)updateStatusOfPath:(NSString *)path
                 startTime:(NSDate *)stime
                   endTime:(NSDate *)etime
                filesCount:(unsigned long)count
               indexedDone:(BOOL)indexed
{
  NSMutableDictionary *dict = [pathsStatus objectForKey: path];

  if (dict) {
    if (stime) {
      [dict setObject: stime forKey: @"start_time"];  
    } 
    if (etime) {
      [dict setObject: etime forKey: @"end_time"];  
    }     
    [dict setObject: [NSNumber numberWithUnsignedLong: count] forKey: @"files"];    
    [dict setObject: [NSNumber numberWithBool: indexed] forKey: @"indexed"];
  }
}

- (void)startExtracting
{
  unsigned index = 0;
  NSString *path;
  NSDictionary *dict;
    
  GWDebugLog(@"start extracting");
  extracting = YES;

  if (statusTimer && [statusTimer isValid]) {
    [statusTimer invalidate];
  }
  DESTROY (statusTimer);
  
  statusTimer = [NSTimer scheduledTimerWithTimeInterval: 5.0 
						                         target: self 
                                   selector: @selector(writePathsStatus:) 
																   userInfo: nil 
                                    repeats: YES];
  RETAIN (statusTimer);
    
  while (1) {  
    if (index < ([indexedPaths count] -1)) {
      path = [indexedPaths objectAtIndex: index];
      RETAIN (path);
      dict = [pathsStatus objectForKey: path];
      
      if ([[dict objectForKey: @"indexed"] boolValue] == NO) {
        if ([self extractFromPath: path] == NO) {
          NSLog(@"An error occurred while processing %@", path);
          RELEASE (path);
          break;
        }
      }
      
      RELEASE (path);
      
    } else {
      break;
    }
      
    if (extracting == NO) {
      break;
    }
    
    index++;
  }
  
  if (statusTimer && [statusTimer isValid]) {
    [statusTimer invalidate];
  }
  DESTROY (statusTimer);
  
  [self writePathsStatus: nil];
  extracting = NO;

  GWDebugLog(@"extracting done!");
}

- (void)stopExtracting
{
  extracting = NO;  
}

#define PERFORM_QUERY(d, q) \
do { \
  if (performWriteQuery(d, q) == NO) { \
    NSLog(@"error at: %@", q); \
    RELEASE (path); \
    return NO; \
  } \
} while (0)

#define UPDATE_COUNT 100

- (BOOL)extractFromPath:(NSString *)path
{
  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];
  
  if (attributes) {
    NSDirectoryEnumerator *enumerator;
    id extractor = nil;
    unsigned long fcount = 0;  
  
    [self updateStatusOfPath: path
                   startTime: [NSDate date]
                     endTime: nil
                  filesCount: fcount
                 indexedDone: NO];

    if ([self insertOrUpdatePath: path withAttributes: attributes] == NO) {
      return NO;
    }

    extractor = [self extractorForPath: path withAttributes: attributes];

    if (extractor) {
      if ([extractor extractMetadataAtPath: path
                            withAttributes: attributes
                              usingStemmer: stemmer
                                 stopWords: stopWords] == NO) {
        return NO;
      }
    }
    
    fcount++;

    enumerator = [fm enumeratorAtPath: path];

    while (1) {
      CREATE_AUTORELEASE_POOL(arp); 
      NSString *entry = [enumerator nextObject];
      NSDate *date = [NSDate dateWithTimeIntervalSinceNow: 0.001];
      BOOL skip = NO;

      [[NSRunLoop currentRunLoop] runUntilDate: date];

      if (entry) {
        NSString *subpath = [path stringByAppendingPathComponent: entry];

        skip = (isDotFile(subpath) 
                    || inTreeFirstPartOfPath(subpath, excludePathsTree));

        attributes = [fm fileAttributesAtPath: subpath traverseLink: NO];

        if (attributes) {
          if (skip == NO) {
            if ([self insertOrUpdatePath: subpath withAttributes: attributes] == NO) {
              RELEASE (arp);
              return NO;
            }

            extractor = [self extractorForPath: subpath withAttributes: attributes];

            if (extractor) {
              if ([extractor extractMetadataAtPath: subpath
                                    withAttributes: attributes
                                      usingStemmer: stemmer
                                         stopWords: stopWords] == NO) {
                RELEASE (arp);
                return NO;
              }
            }
            
            fcount++;
            
            if ((fcount % UPDATE_COUNT) == 0) {
              [self updateStatusOfPath: path
                             startTime: nil
                               endTime: nil
                            filesCount: fcount
                           indexedDone: NO];
              GWDebugLog(@"updating %i", fcount);             
            }
          }

          if (([attributes fileType] == NSFileTypeDirectory) && skip) {
            GWDebugLog(@"skipping %@", subpath); 
            [enumerator skipDescendents];
          }
        }

      } else {
        RELEASE (arp);
        break;
      }

      if (extracting == NO) {
        GWDebugLog(@"stopped"); 
        RELEASE (arp);
        break;
      }

      RELEASE (arp); 
    }
    
    [self updateStatusOfPath: path
                   startTime: nil
                     endTime: [NSDate date]
                  filesCount: fcount
                 indexedDone: extracting];
        
    [self writePathsStatus: nil];
    
    GWDebugLog(@"done %@", path); 
  }
  
  return YES;
}

- (BOOL)insertOrUpdatePath:(NSString *)path
            withAttributes:(NSDictionary *)attributes
{
  NSTimeInterval interval = [[attributes fileModificationDate] timeIntervalSinceReferenceDate];
  NSString *query;
  int path_id;
    
  PERFORM_QUERY (db, @"BEGIN");

  query = [NSString stringWithFormat: 
                    @"SELECT id FROM paths WHERE path = '%@'",
                                              stringForQuery(path)];
  path_id = getIntEntry(db, query);
    
  if (path_id == -1) { 
    query = [NSString stringWithFormat:
        @"INSERT INTO paths (path, words_count, moddate) VALUES('%@', 0, %f)", 
                                                 stringForQuery(path), interval];
    PERFORM_QUERY (db, query);
  
    path_id = sqlite3_last_insert_rowid(db);
  
  } else {
    query = [NSString stringWithFormat:
        @"UPDATE paths SET words_count = 0, moddate = %f WHERE id = %i",
                                                          interval, path_id];
    PERFORM_QUERY (db, query);
  }

  query = [NSString stringWithFormat:
                      @"DELETE FROM attributes WHERE path_id = %i", path_id];
  PERFORM_QUERY (db, query);
  
  PERFORM_QUERY (db, @"COMMIT");

  return YES;
}

- (BOOL)setMetadata:(NSDictionary *)mddict
            forPath:(NSString *)path
     withAttributes:(NSDictionary *)attributes
{
  NSDictionary *wordsdict;
  NSDictionary *attrsdict;
  NSString *query;
  int path_id;
  
//  NSLog(path);
  
  PERFORM_QUERY (db, @"BEGIN");
  
  query = [NSString stringWithFormat: 
             @"SELECT id FROM paths WHERE path = '%@'", stringForQuery(path)];
  path_id = getIntEntry(db, query);

  query = [NSString stringWithFormat:
                      @"DELETE FROM postings WHERE path_id = %i", path_id];
  PERFORM_QUERY (db, query);
  
  wordsdict = [mddict objectForKey: @"words"];

  if (wordsdict) {
    NSCountedSet *wordset = [wordsdict objectForKey: @"wset"];
    NSEnumerator *enumerator = [wordset objectEnumerator];  
    unsigned wcount = [[wordsdict objectForKey: @"wcount"] unsignedLongValue];
    NSString *word;

    query = [NSString stringWithFormat:
                  @"UPDATE paths SET words_count = %i WHERE id = %i", 
                                                              wcount, path_id];
    PERFORM_QUERY (db, query);

    while ((word = [enumerator nextObject])) {
      unsigned count = [wordset countForObject: word];
      int word_id;

      query = [NSString stringWithFormat: 
                      @"SELECT id FROM words WHERE word = '%@'",
                                                  stringForQuery(word)];
      word_id = getIntEntry(db, query);

      if (word_id == -1) {
        query = [NSString stringWithFormat:
             @"INSERT INTO words (word) VALUES('%@')", stringForQuery(word)];
        PERFORM_QUERY (db, query);

        word_id = sqlite3_last_insert_rowid(db);
      }
            
      query = [NSString stringWithFormat:
          @"INSERT INTO postings (word_id, path_id, score) VALUES(%i, %i, %f)", 
                    word_id, path_id, (1.0 * count / wcount)];
      PERFORM_QUERY (db, query);
    }
  }

  attrsdict = [mddict objectForKey: @"attributes"];

  if (attrsdict) {
    NSArray *keys = [attrsdict allKeys];
    unsigned i;

    for (i = 0; i < [keys count]; i++) {
      NSString *key = [keys objectAtIndex: i];
      id mdvalue = [attrsdict objectForKey: key];
      NSString *attributeStr;

      if ([mdvalue isKindOfClass: [NSString class]]) {
        attributeStr = [NSString stringWithFormat: @"'%@'", mdvalue];

      } else if ([mdvalue isKindOfClass: [NSArray class]]) {
        attributeStr = [NSString stringWithFormat: @"'%@'", [mdvalue description]];      
      
      } else if ([mdvalue isKindOfClass: [NSNumber class]]) {
        attributeStr = [NSString stringWithFormat: @"%@", [mdvalue description]];      
      
      } else if ([mdvalue isKindOfClass: [NSData class]]) {
        attributeStr = [NSString stringWithFormat: @"%@", blobFromData(mdvalue)];      
      }
     
      query = [NSString stringWithFormat:
        @"INSERT INTO attributes (path_id, key, attribute) VALUES(%i, '%@', %@)", 
                                                  path_id, key, attributeStr];
      PERFORM_QUERY (db, query);
    }
  }

  PERFORM_QUERY (db, @"COMMIT");

  return YES;
}

- (id)extractorForPath:(NSString *)path
        withAttributes:(NSDictionary *)attributes
{
  NSString *ext = [[path pathExtension] lowercaseString];
  NSString *app = nil, *type = nil;
  NSData *data = nil;
  int i;
  
  [ws getInfoForFile: path application: &app type: &type]; 
  
  if ([attributes fileType] == NSFileTypeRegular) {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath: path];

    if (handle) {
      NS_DURING
        {
          data = [handle readDataOfLength: DLENGTH];
        }
      NS_HANDLER
        {
          data = nil;
        }
      NS_ENDHANDLER

      [handle closeFile];
    }
  }
  
  for (i = 0; i < [extractors count]; i++) {
    id extractor = [extractors objectAtIndex: i];

    if ([extractor canExtractFromFileType: type
                            withExtension: ext 
                               attributes: attributes
                                 testData: data]) {
      return extractor;
    }
  }
  
  if ([textExtractor canExtractFromFileType: type 
                              withExtension: ext
                                 attributes: attributes
                                   testData: data]) {
    return textExtractor;
  }
  
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

- (BOOL)connection:(NSConnection *)ancestor
            shouldMakeNewConnection:(NSConnection *)newConn;
{
  [nc addObserver: self
         selector: @selector(connectionDidDie:)
	           name: NSConnectionDidDieNotification
	         object: newConn];
           
  [newConn setDelegate: self];
  
  GWDebugLog(@"new connection");
  
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
  } else {
    GWDebugLog(@"connection closed");
  }
}

- (void)terminate
{
  if (statusTimer && [statusTimer isValid]) {
    [statusTimer invalidate];
  }

  [dnc removeObserver: self];
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



