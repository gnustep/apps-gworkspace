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

static void user_mdata_key(sqlite3_context *context, int argc, sqlite3_value **argv)
{
#define KEYS 1
  const unsigned char *key = sqlite3_value_text(argv[0]);
  const static char *user_keys[KEYS] = { 
    "kMDItemFinderComment"
  };
  int contains = 0;
  unsigned i;

  for (i = 0; i < KEYS; i++) {
    if (strcmp((char *)key, user_keys[i]) == 0) {
      contains = 1;
      break;
    }
  }
     
  sqlite3_result_int(context, contains);
}


@implementation	GMDSExtractor

- (void)dealloc
{
  if (statusTimer && [statusTimer isValid]) {
    [statusTimer invalidate];
  }
  TEST_RELEASE (statusTimer);
  
  [dnc removeObserver: self];
  [nc removeObserver: self];
  
  RELEASE (indexablePaths);
  freeTree(excludedPathsTree);
  RELEASE (dbpath);
  RELEASE (indexedStatusPath);
  RELEASE (indexedStatusLock);
  RELEASE (extractors);  
  RELEASE (textExtractor);
  RELEASE (stemmer);  
  RELEASE (stopWords);
  
  //  
  // fswatcher_update  
  //
  if (fswatcher && [[(NSDistantObject *)fswatcher connectionForProxy] isValid]) {
    [fswatcher unregisterClient: (id <FSWClientProtocol>)self];
    DESTROY (fswatcher);
  }

  if (fswupdateTimer && [fswupdateTimer isValid]) {
    [fswupdateTimer invalidate];
  }
  TEST_RELEASE (fswupdateTimer);

  RELEASE (fswupdatePaths);
  RELEASE (fswupdateSkipBuff);

  if (userMdataTimer && [userMdataTimer isValid]) {
    [userMdataTimer invalidate];
  }
  TEST_RELEASE (userMdataTimer);

  RELEASE (lastRemovedUserMdata);
  
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
    unsigned i;
    
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
    
    defaults = [NSUserDefaults standardUserDefaults];
    [defaults synchronize];
    
    indexablePaths = [NSMutableArray new];
    excludedPathsTree = newTreeWithIdentifier(@"excluded");

    entry = [defaults arrayForKey: @"GSMetadataIndexablePaths"];

    if (entry) {
      for (i = 0; i < [entry count]; i++) {  
        NSString *path = [entry objectAtIndex: i];
        GMDSIndexablePath *indpath = [[GMDSIndexablePath alloc] initWithPath: path 
                                                                    ancestor: nil];
        [indexablePaths addObject: indpath];
        RELEASE (indpath);
      }
    }

    entry = [defaults arrayForKey: @"GSMetadataExcludedPaths"];
    if (entry) {
      for (i = 0; i < [entry count]; i++) {
        insertComponentsOfPath([entry objectAtIndex: i], excludedPathsTree);
      }
    }

    indexingEnabled = [defaults boolForKey: @"GSMetadataIndexingEnabled"];    
    
    extracting = NO;
    subpathsChanged = NO;
    statusTimer = nil;
    
    [self setupUpdaters];
    
    if ([self synchronizePathsStatus: YES] && indexingEnabled) {
      [self startExtracting];
    }
  }
  
  return self;
}

- (void)indexedDirectoriesChanged:(NSNotification *)notification
{
  CREATE_AUTORELEASE_POOL(arp);
  NSDictionary *info = [notification userInfo];
  NSArray *indexable = [info objectForKey: @"GSMetadataIndexablePaths"];
  NSArray *excluded = [info objectForKey: @"GSMetadataExcludedPaths"];
  NSArray *excludedPaths = pathsOfTreeWithBase(excludedPathsTree);
  BOOL shouldExtract;
  unsigned count;
  unsigned i;

  for (i = 0; i < [indexable count]; i++) {
    NSString *path = [indexable objectAtIndex: i];
    GMDSIndexablePath *indpath = [self indexablePathWithPath: path];   
    
    if (indpath == nil) {
      indpath = [[GMDSIndexablePath alloc] initWithPath: path ancestor: nil];
      [indexablePaths addObject: indpath];
      RELEASE (indpath);
    }
  }
  
  count = [indexablePaths count];
  
  for (i = 0; i < count; i++) {
    GMDSIndexablePath *indpath = [indexablePaths objectAtIndex: i];

    if ([indexable containsObject: [indpath path]] == NO) {
      [indexablePaths removeObject: indpath];
      count--;
      i--;
      
      /* FIXME 
      - remove the path from the db?
      - stop indexing if the current indexed path == indpath?
      */
    }
  }  

  emptyTreeWithBase(excludedPathsTree);

  for (i = 0; i < [excluded count]; i++) {
    NSString *path = [excluded objectAtIndex: i];
    
    insertComponentsOfPath(path, excludedPathsTree);
    
    if ([excludedPaths containsObject: path] == NO) {
      GMDSIndexablePath *ancestor = [self ancestorOfAddedPath: path];
    
      if (ancestor) {
        [ancestor removeSubpath: path];
                  
        /* FIXME 
        - remove the path from the db?
        - stop indexing if the current indexed path == path?
        */
      }
    }
  }

  for (i = 0; i < [excludedPaths count]; i++) {
    NSString *path = [excludedPaths objectAtIndex: i];
    
    if ([excluded containsObject: path] == NO) {
      GMDSIndexablePath *indpath = [self ancestorForAddingPath: path];
    
      if (indpath) {
        [indpath addSubpath: path];
        subpathsChanged = YES;
      }
    }
  }

  indexingEnabled = [[info objectForKey: @"GSMetadataIndexingEnabled"] boolValue];
  
  shouldExtract = [self synchronizePathsStatus: NO];
    
  if (indexingEnabled) {
    if (shouldExtract && (extracting == NO)) {
      subpathsChanged = NO;
      [self startExtracting];
    }
  
  } else if (extracting) {
    [self stopExtracting];
  }
    
  RELEASE (arp);    
}

- (BOOL)synchronizePathsStatus:(BOOL)onstart
{
  BOOL shouldExtract = NO;
  unsigned i;
    
  if (onstart) {
    NSArray *savedPaths = [self readPathsStatus];
    
    for (i = 0; i < [indexablePaths count]; i++) {
      GMDSIndexablePath *indPath = [indexablePaths objectAtIndex: i];
      NSDictionary *savedInfo = [self infoOfPath: [indPath path] inSavedStatus: savedPaths];
      id entry;
      
      if (savedInfo) {
        entry = [savedInfo objectForKey: @"subpaths"];
        
        if (entry) {
          unsigned j;
          
          for (j = 0; j < [entry count]; j++) {
            NSDictionary *subSaved = [entry objectAtIndex: j];
            id subentry = [subSaved objectForKey: @"path"];
            GMDSIndexablePath *subpath = [indPath addSubpath: subentry];
            
            subentry = [subSaved objectForKey: @"indexed"];
            [subpath setIndexed: [subentry boolValue]];
            
            if ([subpath indexed] == NO) {
              shouldExtract = YES;
            }
          }
        }
        
        entry = [savedInfo objectForKey: @"count"];
        
        if (entry) {
          [indPath setFilesCount: [entry unsignedLongValue]];
        }
        
        entry = [savedInfo objectForKey: @"indexed"];
        
        if (entry) {
          [indPath setIndexed: [entry boolValue]];
        
          if ([indPath indexed] == NO) {
            shouldExtract = YES;
          }
        }
        
      } else {
        shouldExtract = YES;
      }
    }    
  
  } else {
    for (i = 0; i < [indexablePaths count]; i++) {      
      GMDSIndexablePath *indPath = [indexablePaths objectAtIndex: i];
  
      if ([indPath indexed] == NO) {
        shouldExtract = YES;
      }
      
      if (shouldExtract == NO) {
        NSArray *subpaths = [indPath subpaths];
        unsigned j;
      
        for (j = 0; j < [subpaths count]; j++) {
          GMDSIndexablePath *subpath = [subpaths objectAtIndex: j];
          
          if ([subpath indexed] == NO) {
            shouldExtract = YES;
            break;
          }
        }
      }
      
      if (shouldExtract == YES) {
        break;
      }
    }
    
    [self writePathsStatus: nil];
  }
       
  return shouldExtract;
}

- (NSArray *)readPathsStatus
{
  NSArray *status = nil;

  if (indexedStatusPath && [fm isReadableFileAtPath: indexedStatusPath]) {
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

    status = [NSArray arrayWithContentsOfFile: indexedStatusPath];
    [indexedStatusLock unlock];
  }
  
  return ((status != nil) ? status : [NSArray array]);
}

- (void)writePathsStatus:(id)sender
{
  if (indexedStatusPath) {
    CREATE_AUTORELEASE_POOL(arp);
    NSMutableArray *status = [NSMutableArray array];
    unsigned i;
    
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
        RELEASE (arp);
        return;
	    }
    }

    for (i = 0; i < [indexablePaths count]; i++) {
      [status addObject: [[indexablePaths objectAtIndex: i] info]];
    }

    [status writeToFile: indexedStatusPath atomically: YES];
    [indexedStatusLock unlock];
    
    GWDebugLog(@"paths status updated"); 
    
    RELEASE (arp);
  }
}

- (NSDictionary *)infoOfPath:(NSString *)path 
               inSavedStatus:(NSArray *)status
{
  unsigned i;

  for (i = 0; i < [status count]; i++) {
    NSDictionary *info = [status objectAtIndex: i];
  
    if ([[info objectForKey: @"path"] isEqual: path]) {
      return info;
    }
  }

  return nil;
}

- (void)updateStatusOfPath:(GMDSIndexablePath *)indpath
                 startTime:(NSDate *)stime
                   endTime:(NSDate *)etime
                filesCount:(unsigned long)count
               indexedDone:(BOOL)indexed
{
  if ([indexablePaths containsObject: indpath]) {
    if (stime) {
      [indpath setStartTime: stime];  
    } 
    if (etime) {
      [indpath setEndTime: etime];  
    }     
    [indpath setFilesCount: count];
    [indpath setIndexed: indexed];

  } else {
    GMDSIndexablePath *ancestor = [indpath ancestor];
  
    if (ancestor) {
      if (stime) {
        [indpath setStartTime: stime];  
      } 
      if (etime) {
        [indpath setEndTime: etime];  
      }     
      [indpath setFilesCount: count];
      [indpath setIndexed: indexed];
      
      if (indexed) {
        [ancestor checkIndexingDone];
      }
    }
  }
}

- (GMDSIndexablePath *)indexablePathWithPath:(NSString *)path
{
  unsigned i;

  for (i = 0; i < [indexablePaths count]; i++) {
    GMDSIndexablePath *indpath = [indexablePaths objectAtIndex: i];

    if ([[indpath path] isEqual: path]) {
      return indpath;
    }
  }
  
  return nil;
}

- (GMDSIndexablePath *)ancestorForAddingPath:(NSString *)path 
{
  unsigned i;

  for (i = 0; i < [indexablePaths count]; i++) {
    GMDSIndexablePath *indpath = [indexablePaths objectAtIndex: i];
  
    if ([indpath acceptsSubpath: path]) {
      return indpath;
    }
  }
  
  return nil;
}

- (GMDSIndexablePath *)ancestorOfAddedPath:(NSString *)path
{
  unsigned i;

  for (i = 0; i < [indexablePaths count]; i++) {
    GMDSIndexablePath *indpath = [indexablePaths objectAtIndex: i];

    if ([indpath subpathWithPath: path] != nil) {
      return indpath;
    }
  }
  
  return nil;
}

- (void)startExtracting
{
  unsigned index = 0;
    
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
    if (index < [indexablePaths count]) {
      GMDSIndexablePath *indpath = [indexablePaths objectAtIndex: index]; 
      NSArray *subpaths = [indpath subpaths];
      BOOL indexed = [indpath indexed];
      
      RETAIN (indpath);
      
      if (indexed == NO) {
        if ([self extractFromPath: indpath] == NO) {
          NSLog(@"An error occurred while processing %@", [indpath path]);
          RELEASE (indpath);
          break;
        }
      }
      
      if (subpaths) {
        unsigned i;
      
        for (i = 0; i < [subpaths count]; i++) {
          GMDSIndexablePath *subpath = [subpaths objectAtIndex: i];
          
          RETAIN (subpath);
          
          if ([subpath indexed] == NO) {
            if ([self extractFromPath: subpath] == NO) {
              NSLog(@"An error occurred while processing %@", [subpath path]);
              RELEASE (subpath);
              break;
            }
          }
          
          TEST_RELEASE (subpath);
        }      
      }
      
      TEST_RELEASE (indpath);
      
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
  
  if (subpathsChanged) {
    subpathsChanged = NO;
    [self startExtracting];
  }
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

- (BOOL)extractFromPath:(GMDSIndexablePath *)indpath
{
  NSString *path = [NSString stringWithString: [indpath path]];
  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];
  
  if (attributes) {
    NSDirectoryEnumerator *enumerator;
    id extractor = nil;
    unsigned long fcount = 0;  
  
    [self updateStatusOfPath: indpath
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
                    || inTreeFirstPartOfPath(subpath, excludedPathsTree));

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
              [self updateStatusOfPath: indpath
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

      TEST_RELEASE (arp); 
    }
    
    [self updateStatusOfPath: indpath
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
  NSMutableArray *mdattributes = [NSMutableArray array];
  NSString *query;
  int path_id;
  BOOL didexist;
  unsigned i;

#define KEY_AND_ATTRIBUTE(k, a) \
do { \
  NSMutableDictionary *dict = [NSMutableDictionary dictionary]; \
  [dict setObject: [NSData dataWithBytes: [k UTF8String] length: [k length] + 1] \
           forKey: @"key"]; \
  [dict setObject: [NSData dataWithBytes: [a UTF8String] length: [a length] + 1] \
           forKey: @"attribute"]; \
\
  [mdattributes addObject: dict]; \
} while (0)
    
  PERFORM_QUERY (db, @"BEGIN");

  query = [NSString stringWithFormat: @"SELECT id FROM paths "
                                      @"WHERE path = '%@'",
                                       stringForQuery(path)];
  path_id = getIntEntry(db, query);
  didexist = (path_id != -1);
     
  if (didexist == NO) {  
    NSDictionary *userMdata;

    query = [NSString stringWithFormat: @"INSERT INTO paths (path, words_count, moddate) "
                                        @"VALUES('%@', 0, %f)", 
                                        stringForQuery(path), interval];
    PERFORM_QUERY (db, query);
  
    path_id = sqlite3_last_insert_rowid(db);

    userMdata = [lastRemovedUserMdata objectForKey: path];
    
    if (userMdata != nil) {
      [mdattributes addObjectsFromArray: [userMdata objectForKey: @"attributes"]];
    }
        
  } else {
    query = [NSString stringWithFormat: @"UPDATE paths "
                                        @"SET words_count = 0, moddate = %f "
                                        @"WHERE id = %i",
                                        interval, path_id];
    PERFORM_QUERY (db, query);

    query = [NSString stringWithFormat: @"SELECT key, attribute FROM attributes "
                                        @"WHERE attributes.path_id = %i "
                                        @"AND isUserMdataKey(key)",
                                        path_id];
    [mdattributes addObjectsFromArray: performQuery(db, query)];

    query = [NSString stringWithFormat: @"DELETE FROM attributes "
                                        @"WHERE path_id = %i", 
                                        path_id];
    PERFORM_QUERY (db, query);

    query = [NSString stringWithFormat: @"DELETE FROM postings "
                                        @"WHERE path_id = %i", 
                                        path_id];
    PERFORM_QUERY (db, query);
  }

  KEY_AND_ATTRIBUTE (@"kMDItemFSName", stringForQuery([path lastPathComponent]));  
  
  for (i = 0; i < [mdattributes count]; i++) {
    NSDictionary *dict = [mdattributes objectAtIndex: i];      
    const char *key = [[dict objectForKey: @"key"] bytes];  
    const char *attribute = [[dict objectForKey: @"attribute"] bytes];  

    
    NSLog(@"didexist = %i - SETTING %s FOR %s", didexist, attribute, key);


    query = [NSString stringWithFormat: @"INSERT INTO attributes (path_id, key, attribute) "
                                        @"VALUES(%i, '%s', '%s')", 
                                        path_id, key, attribute];
    PERFORM_QUERY (db, query);
  }
  
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
  
  query = [NSString stringWithFormat: @"SELECT id FROM paths "
                                      @"WHERE path = '%@'", 
                                      stringForQuery(path)];
  path_id = getIntEntry(db, query);
  
  wordsdict = [mddict objectForKey: @"words"];

  if (wordsdict) {
    NSCountedSet *wordset = [wordsdict objectForKey: @"wset"];
    NSEnumerator *enumerator = [wordset objectEnumerator];  
    unsigned wcount = [[wordsdict objectForKey: @"wcount"] unsignedLongValue];
    NSString *word;

    query = [NSString stringWithFormat: @"UPDATE paths "
                                        @"SET words_count = %i "
                                        @"WHERE id = %i", 
                                        wcount, path_id];
    PERFORM_QUERY (db, query);

    while ((word = [enumerator nextObject])) {
      unsigned count = [wordset countForObject: word];
      int word_id;

      query = [NSString stringWithFormat: @"SELECT id FROM words "
                                          @"WHERE word = '%@'",
                                          stringForQuery(word)];
      word_id = getIntEntry(db, query);

      if (word_id == -1) {
        query = [NSString stringWithFormat: @"INSERT INTO words (word) "
                                            @"VALUES('%@')", 
                                            stringForQuery(word)];
        PERFORM_QUERY (db, query);

        word_id = sqlite3_last_insert_rowid(db);
      }
            
      query = [NSString stringWithFormat: @"INSERT INTO postings (word_id, path_id, score) "
                                          @"VALUES(%i, %i, %f)", 
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
     
      query = [NSString stringWithFormat: @"INSERT INTO attributes (path_id, key, attribute) "
                                          @"VALUES(%i, '%@', %@)", 
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
                                SQLITE_UTF8, 0, path_exists, 0, 0);

    sqlite3_create_function(db, "pathMoved", 3, 
                                SQLITE_UTF8, 0, path_moved, 0, 0);

    sqlite3_create_function(db, "isUserMdataKey", 1, 
                                SQLITE_UTF8, 0, user_mdata_key, 0, 0);

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

@end


@implementation	GMDSIndexablePath

- (void)dealloc
{
  RELEASE (path);
  TEST_RELEASE (startTime);
  TEST_RELEASE (endTime);
  RELEASE (subpaths);
  TEST_RELEASE (ancestor);
  
  [super dealloc];
}

- (id)initWithPath:(NSString *)apath
          ancestor:(GMDSIndexablePath *)prepath
{
  self = [super init];
  
  if (self) {
    ASSIGN (path, apath);
    subpaths = [NSMutableArray new];
    ancestor = nil;
    if (prepath) {
      ASSIGN (ancestor, prepath);
    }
    startTime = nil;
    endTime = nil;
    filescount = 0L;
    indexed = NO;
  }
  
  return self;
}

- (NSString *)path
{
  return path;
}

- (NSArray *)subpaths
{
  return subpaths;
}

- (GMDSIndexablePath *)subpathWithPath:(NSString *)apath
{
  unsigned i;
  
  for (i = 0; i < [subpaths count]; i++) {  
    GMDSIndexablePath *subpath = [subpaths objectAtIndex: i];
    
    if ([[subpath path] isEqual: apath]) {
      return subpath;
    }
  }
  
  return nil;
}

- (BOOL)acceptsSubpath:(NSString *)subpath
{
  if (subPathOfPath(path, subpath)) {
    return ([self subpathWithPath: subpath] == nil);
  }
  
  return NO;
}

- (GMDSIndexablePath *)addSubpath:(NSString *)apath
{
  if ([self acceptsSubpath: apath]) {
    GMDSIndexablePath *subpath = [[GMDSIndexablePath alloc] initWithPath: apath ancestor: self];

    [subpaths addObject: subpath];
    RELEASE (subpath);
    
    return subpath;
  }
  
  return nil;
}

- (void)removeSubpath:(NSString *)apath
{
  GMDSIndexablePath *subpath = [self subpathWithPath: apath];
  
  if (subpath) {
    [subpaths removeObject: subpath];
  }
}

- (BOOL)isSubpath
{
  return (ancestor != nil);
}

- (GMDSIndexablePath *)ancestor
{
  return ancestor;
}

- (unsigned long)filescount
{
  return filescount;
}

- (void)setFilesCount:(unsigned long)count
{
  filescount = count;
}

- (NSDate *)startTime
{
  return startTime;
}

- (void)setStartTime:(NSDate *)date
{
  ASSIGN (startTime, date);
}

- (NSDate *)endTime
{
  return endTime;
}

- (void)setEndTime:(NSDate *)date
{
  ASSIGN (endTime, date);
}

- (BOOL)indexed
{
  return indexed;
}

- (void)setIndexed:(BOOL)value
{
  indexed = value;
}

- (void)checkIndexingDone
{
  unsigned count = [subpaths count];
  unsigned i;

  for (i = 0; i < count; i++) {  
    GMDSIndexablePath *subpath = [subpaths objectAtIndex: i];

    [self setFilesCount: (filescount + [subpath filescount])];

    if ([subpath indexed]) {
      [self setEndTime: [subpath endTime]];
      [subpaths removeObject: subpath];
      count--;
      i--;
    }
  }
}

- (NSDictionary *)info
{
  NSMutableDictionary *info = [NSMutableDictionary dictionary];
  NSMutableArray *subinfo = [NSMutableArray array];
  unsigned i;
  
  [info setObject: path forKey: @"path"];
  
  if (startTime) {
    [info setObject: startTime forKey: @"start_time"];
  }

  if (endTime) {
    [info setObject: endTime forKey: @"end_time"];
  }
  
  [info setObject: [NSNumber numberWithBool: indexed] forKey: @"indexed"];
  
  [info setObject: [NSNumber numberWithUnsignedLong: filescount] forKey: @"count"];
  
  for (i = 0; i < [subpaths count]; i++) {
    [subinfo addObject: [[subpaths objectAtIndex: i] info]];
  }
  [info setObject: [subinfo makeImmutableCopyOnFail: NO]
           forKey: @"subpaths"];

  return [info makeImmutableCopyOnFail: NO];
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

BOOL subPathOfPath(NSString *p1, NSString *p2)
{
  int l1 = [p1 length];
  int l2 = [p2 length];  

  if ((l1 > l2) || ([p1 isEqual: p2])) {
    return NO;
  } else if ([[p2 substringToIndex: l1] isEqual: p1]) {
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

NSString *path_separator(void)
{
  static NSString *separator = nil;

  if (separator == nil) {
    separator = fixpath(@"/", 0);
    RETAIN (separator);
  }

  return separator;
}
