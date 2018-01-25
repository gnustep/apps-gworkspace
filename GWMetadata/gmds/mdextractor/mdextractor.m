/* mdextractor.m
 *  
 * Copyright (C) 2006-2018 Free Software Foundation, Inc.
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
#include <limits.h>
#include <float.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#import "mdextractor.h"
#import "dbschema.h"
#include "config.h"

#define DLENGTH 256
#define MAX_RETRY 1000
#define UPDATE_COUNT 100

#define GWDebugLog(format, args...) \
  do { if (GW_DEBUG_LOG) \
    NSLog(format , ## args); } while (0)

#define EXECUTE_QUERY(q, r) \
do { \
  if ([sqlite executeQuery: q] == NO) { \
    NSLog(@"error at: %@", q); \
    return r; \
  } \
} while (0)

#define STATEMENT_EXECUTE_QUERY(s, r) \
do { \
  if ([sqlite executeQueryWithStatement: s] == NO) { \
    NSLog(@"error at: %@", [s query]); \
    return r; \
  } \
} while (0)


static BOOL updating = NO;

static void check_updating(sqlite3_context *context, int argc, sqlite3_value **argv)
{
  sqlite3_result_int(context, (int)updating);
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
  // FIXME: This code also exists in GWMetadata/gmds/gmds/gmds.m.
  // It may be useful to move it to a library.

  // old dirname, and its length
  const unsigned char *oldbase = sqlite3_value_text(argv[0]);
  int oldblen = strlen((const char *)oldbase);

  // new dirname, and its length
  const unsigned char *newbase = sqlite3_value_text(argv[1]);
  int newblen = strlen((const char *)newbase);

  // old full path, and its length
  const unsigned char *oldpath = sqlite3_value_text(argv[2]);
  int oldplen = strlen((const char *)oldpath);

  // new full path, and its length
  char *newpath = NULL;
  int newplen = newblen + (oldplen - oldblen);

  int i = newblen;
  int j;

  /////

  // allocate space for new path + nul terminator
  newpath = malloc(newplen + 1);

  // copy the new dirname over, but restrict up to allocated space.
  // add a null terminator in case the newbase is exactly newplen
  // in size.
  strncpy(newpath, (const char *)newbase, newplen);
  newpath[newplen] = '\0';

  // concatenate the new pathname.
  // equivalent of: strncat(newpath, oldpath+oldblen, newplen),
  // which may be safer as it will also add a nul terminator at
  // newpath[newplen].
  for (j = oldblen; j < oldplen; j++) {
    newpath[i] = oldpath[j];
    i++;
  }
  newpath[i] = '\0';

  // return the path.
  sqlite3_result_text(context, newpath, strlen(newpath), SQLITE_TRANSIENT);

  free(newpath);
}

static void time_stamp(sqlite3_context *context, int argc, sqlite3_value **argv)
{
  NSTimeInterval interval = [[NSDate date] timeIntervalSinceReferenceDate];

  sqlite3_result_double(context, interval);
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
  freeTree(includePathsTree);
  freeTree(excludedPathsTree);
  RELEASE (excludedSuffixes);
  RELEASE (dbpath);
  RELEASE (sqlite);
  RELEASE (indexedStatusPath);
  RELEASE (indexedStatusLock);
  TEST_RELEASE (errHandle);
  RELEASE (extractors);  
  RELEASE (textExtractor);
  
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
  RELEASE (lostPaths);
  
  if (lostPathsTimer && [lostPathsTimer isValid]) {
    [lostPathsTimer invalidate];
  }
  TEST_RELEASE (lostPathsTimer);

  //
  // ddbd_update
  //
  DESTROY (ddbd);
    
  //  
  // scheduled_update  
  //
  if (schedupdateTimer && [schedupdateTimer isValid]) {
    [schedupdateTimer invalidate];
  }
  TEST_RELEASE (schedupdateTimer);  
  RELEASE (directories);
  
  //
  // update_notifications
  //
  if (notificationsTimer && [notificationsTimer isValid]) {
    [notificationsTimer invalidate];
  }
  TEST_RELEASE (notificationsTimer);
  RELEASE (notifDate);
    
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
    NSUserDefaults *defaults;
    id entry;
    NSString *lockpath;
    NSString *errpath;
    unsigned i;
    
    fm = [NSFileManager defaultManager]; 

    dbdir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    dbdir = [dbdir stringByAppendingPathComponent: @"gmds"];
    dbdir = [dbdir stringByAppendingPathComponent: @".db"];

    ASSIGN (indexedStatusPath, [dbdir stringByAppendingPathComponent: @"status.plist"]);
    lockpath = [dbdir stringByAppendingPathComponent: @"extractors.lock"];    

    errpath = [dbdir stringByAppendingPathComponent: @"error.log"];
        
    dbdir = [dbdir stringByAppendingPathComponent: db_version];
    RETAIN (dbdir);
    ASSIGN (dbpath, [dbdir stringByAppendingPathComponent: @"contents.db"]);    
    
    sqlite = [SQLite new];

    if ([self opendb] == NO) {
      DESTROY (self);
      return self;    
    }

    indexedStatusLock = [[NSDistributedLock alloc] initWithPath: lockpath];

    if (indexedStatusLock == nil) {
      DESTROY (self);
      return self;    
    }

    if ([fm fileExistsAtPath: errpath] == NO) {
      [fm createFileAtPath: errpath contents: nil attributes: nil];
    }
    errHandle = [NSFileHandle fileHandleForWritingAtPath: errpath];
    RETAIN (errHandle);


    conn = [NSConnection defaultConnection];
    [conn setRootObject: self];
    [conn setDelegate: self];

    if ([conn registerName: @"mdextractor"] == NO) {
	    NSLog(@"unable to register with name server - quitting.");
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
                    
    dnc = [NSDistributedNotificationCenter defaultCenter];
    
    [dnc addObserver: self
            selector: @selector(indexedDirectoriesChanged:)
	              name: @"GSMetadataIndexedDirectoriesChanged"
	            object: nil];
    
    ws = [NSWorkspace sharedWorkspace]; 
    
    defaults = [NSUserDefaults standardUserDefaults];
    [defaults synchronize];
    
    indexablePaths = [NSMutableArray new];
    
    includePathsTree = newTreeWithIdentifier(@"included");
    excludedPathsTree = newTreeWithIdentifier(@"excluded");
    excludedSuffixes = [[NSMutableSet alloc] initWithCapacity: 1];
    
    entry = [defaults arrayForKey: @"GSMetadataIndexablePaths"];

    if (entry) {
      for (i = 0; i < [entry count]; i++) {  
        NSString *path = [entry objectAtIndex: i];
        GMDSIndexablePath *indpath = [[GMDSIndexablePath alloc] initWithPath: path 
                                                                    ancestor: nil];
        [indexablePaths addObject: indpath];
        RELEASE (indpath);
        
        insertComponentsOfPath(path, includePathsTree);
      }
    }

    entry = [defaults arrayForKey: @"GSMetadataExcludedPaths"];
    if (entry) {
      for (i = 0; i < [entry count]; i++) {
        insertComponentsOfPath([entry objectAtIndex: i], excludedPathsTree);
      }
    }

    entry = [defaults arrayForKey: @"GSMetadataExcludedSuffixes"];
    if (entry == nil) {
      entry = [NSArray arrayWithObjects: @"a", @"d", @"dylib", @"er1", 
                                         @"err", @"extinfo", @"frag", @"la", 
                                         @"log", @"o", @"out", @"part", 
                                         @"sed", @"so", @"status", @"temp",
                                         @"tmp",  
                                         nil];
    } 

    [excludedSuffixes addObjectsFromArray: entry];

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
  NSArray *suffixes = [info objectForKey: @"GSMetadataExcludedSuffixes"];
  NSArray *excludedPaths = pathsOfTreeWithBase(excludedPathsTree);
  BOOL shouldExtract;
  unsigned count;
  unsigned i;

  emptyTreeWithBase(includePathsTree);

  for (i = 0; i < [indexable count]; i++) {
    NSString *path = [indexable objectAtIndex: i];
    GMDSIndexablePath *indpath = [self indexablePathWithPath: path];   
    
    if (indpath == nil) {
      indpath = [[GMDSIndexablePath alloc] initWithPath: path ancestor: nil];
      [indexablePaths addObject: indpath];
      RELEASE (indpath);
    }
    
    insertComponentsOfPath(path, includePathsTree);
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

  [excludedSuffixes removeAllObjects];
  [excludedSuffixes addObjectsFromArray: suffixes];

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
        return [NSArray array];
      }
    }

    status = [NSArray arrayWithContentsOfFile: indexedStatusPath];
    [indexedStatusLock unlock];
  }
  
  if (status != nil) {
    return status;
  }
  
  return [NSArray array];
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

- (BOOL)extractFromPath:(GMDSIndexablePath *)indpath
{
  NSString *path = [NSString stringWithString: [indpath path]];
  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];
  
  if (attributes) {
    NSString *app = nil;
    NSString *type = nil;
    NSDirectoryEnumerator *enumerator;
    id extractor = nil;
    unsigned long fcount = 0;  
    int path_id;
    
    [self updateStatusOfPath: indpath
                   startTime: [NSDate date]
                     endTime: nil
                  filesCount: fcount
                 indexedDone: NO];
    
    EXECUTE_QUERY (@"BEGIN", NO);
    
    [ws getInfoForFile: path application: &app type: &type];  
    
    path_id = [self insertOrUpdatePath: path 
                                ofType: type
                        withAttributes: attributes];
    
    if (path_id == -1) {
      [sqlite executeQuery: @"ROLLBACK"];
      return NO;
    }

    extractor = [self extractorForPath: path 
                                ofType: type
                        withAttributes: attributes];

    if (extractor) {
      if ([extractor extractMetadataAtPath: path
                                    withID: path_id
                                attributes: attributes] == NO) {
        [sqlite executeQuery: @"ROLLBACK"];
        return NO;
      }
    }
    
    [sqlite executeQuery: @"COMMIT"];
    
    GWDebugLog(@"%@", path);
    
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
        NSString *ext = [[subpath pathExtension] lowercaseString];

        skip = ([excludedSuffixes containsObject: ext]
                    || isDotFile(subpath) 
                    || inTreeFirstPartOfPath(subpath, excludedPathsTree));

        attributes = [fm fileAttributesAtPath: subpath traverseLink: NO];

        if (attributes) {
          BOOL failed = NO;
          BOOL hasextractor = NO;
        
          if (skip == NO) {
            NSString *app = nil;
            NSString *type = nil;        
                                
            [sqlite executeQuery: @"BEGIN"];
            
            [ws getInfoForFile: subpath application: &app type: &type];
            
            path_id = [self insertOrUpdatePath: subpath 
                                        ofType: type
                                withAttributes: attributes];
                    
            if (path_id != -1) {
              extractor = [self extractorForPath: subpath 
                                          ofType: type
                                  withAttributes: attributes];

              if (extractor) {
                hasextractor = YES;
                
                if ([extractor extractMetadataAtPath: subpath
                                              withID: path_id
                                          attributes: attributes] == NO) {
                  failed = YES;                         
                }
              }
          
            } else {
              failed = YES;
            }
                        
            [sqlite executeQuery: (failed ? @"ROLLBACK" : @"COMMIT")];
            
            if ((failed == NO) && (skip == NO)) {
              fcount++;
            }
            
            if ((fcount % UPDATE_COUNT) == 0) {
              [self updateStatusOfPath: indpath
                             startTime: nil
                               endTime: nil
                            filesCount: fcount
                           indexedDone: NO];
                           
              GWDebugLog(@"updating %lu", fcount);             
            }
          }
          
          if (skip) {
            GWDebugLog(@"skipping %@", subpath);
            
            if ([attributes fileType] == NSFileTypeDirectory) {
              [enumerator skipDescendents];
            }

          } else {
            if (failed) {
              [self logError: [NSString stringWithFormat: @"EXTRACT %@", subpath]];
              GWDebugLog(@"error extracting at: %@", subpath);
            } else if (hasextractor == NO) {
              GWDebugLog(@"no extractor for: %@", subpath);
            } else {
              GWDebugLog(@"extracted: %@", subpath);
            }
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

- (int)insertOrUpdatePath:(NSString *)path
                   ofType:(NSString *)type
           withAttributes:(NSDictionary *)attributes
{
  NSTimeInterval interval = [[attributes fileModificationDate] timeIntervalSinceReferenceDate];
  NSMutableArray *mdattributes = [NSMutableArray array];  
  NSString *qpath = stringForQuery(path);
  NSString *qname = stringForQuery([path lastPathComponent]);
  NSString *qext = stringForQuery([[path pathExtension] lowercaseString]);  
  SQLitePreparedStatement *statement;
  NSString *query;
  int path_id;
  BOOL didexist;
  unsigned i;

#define KEY_AND_ATTRIBUTE(k, a) \
do { \
  if (a) { \
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys: \
                                        k, @"key", a, @"attribute", nil]; \
    [mdattributes addObject: dict]; \
  } \
} while (0)
    
  query = @"SELECT id FROM paths WHERE path = :path";
    
  statement = [sqlite statementForQuery: query 
                         withIdentifier: @"insert_or_update_1"
                               bindings: SQLITE_TEXT, @":path", qpath, 0];
                             
  path_id = [sqlite getIntEntryWithStatement: statement];
  
  didexist = (path_id != INT_MAX);
     
  if (didexist == NO) {
    BOOL isdir = ([attributes fileType] == NSFileTypeDirectory);  

    if (isdir && ([directories containsObject: path] == NO)) {
      [directories addObject: path];
    }

    query = @"INSERT INTO paths "
            @"(path, words_count, moddate, is_directory) "
            @"VALUES(:path, 0, :moddate, :isdir)";

    statement = [sqlite statementForQuery: query 
                           withIdentifier: @"insert_or_update_2"
                                 bindings: SQLITE_TEXT, @":path", qpath, 
                                           SQLITE_FLOAT, @":moddate", interval, 
                                           SQLITE_INTEGER, @":isdir", isdir, 0];

    STATEMENT_EXECUTE_QUERY (statement, -1);

    path_id = [sqlite lastInsertRowId];

  } else {
    query = @"UPDATE paths "
            @"SET words_count = 0, moddate = :moddate "
            @"WHERE id = :pathid";
  
    statement = [sqlite statementForQuery: query 
                           withIdentifier: @"insert_or_update_3"
                                 bindings: SQLITE_FLOAT, @":moddate", interval, 
                                           SQLITE_INTEGER, @":pathid", path_id, 0];
  
    STATEMENT_EXECUTE_QUERY (statement, -1);
  
    query = @"DELETE FROM attributes WHERE path_id = :pathid";

    statement = [sqlite statementForQuery: query 
                           withIdentifier: @"insert_or_update_4"
                                 bindings: SQLITE_INTEGER, @":pathid", path_id, 0];

    STATEMENT_EXECUTE_QUERY (statement, -1);

    query = @"DELETE FROM postings WHERE path_id = :pathid";

    statement = [sqlite statementForQuery: query 
                           withIdentifier: @"insert_or_update_5"
                                 bindings: SQLITE_INTEGER, @":pathid", path_id, 0];

    STATEMENT_EXECUTE_QUERY (statement, -1);
  }

  KEY_AND_ATTRIBUTE (@"GSMDItemFSName", qname);  
  KEY_AND_ATTRIBUTE (@"GSMDItemFSExtension", qext);  
  KEY_AND_ATTRIBUTE (@"GSMDItemFSType", type);  
  
  if (ddbd) {
    NSArray *usermdata = [ddbd userMetadataForPath: path];
    
    if (usermdata) {
      [mdattributes addObjectsFromArray: usermdata];
    }
  }
  
  for (i = 0; i < [mdattributes count]; i++) {
    NSDictionary *dict = [mdattributes objectAtIndex: i];      
    NSString *key = [dict objectForKey: @"key"];  
    NSString *attribute = [dict objectForKey: @"attribute"];  

    query = @"INSERT INTO attributes (path_id, key, attribute) "
            @"VALUES(:pathid, :key, :attribute)"; 

    statement = [sqlite statementForQuery: query 
                           withIdentifier: @"insert_or_update_6"
                                 bindings: SQLITE_INTEGER, @":pathid", path_id, 
                                           SQLITE_TEXT, @":key", key, 
                                       SQLITE_TEXT, @":attribute", attribute, 0];

    STATEMENT_EXECUTE_QUERY (statement, -1);
  }
  
  return path_id;
}

- (BOOL)setMetadata:(NSDictionary *)mddict
            forPath:(NSString *)path
             withID:(int)path_id
{
  NSDictionary *wordsdict;
  NSDictionary *attrsdict;
  SQLitePreparedStatement *statement;
  NSString *query;
        
  wordsdict = [mddict objectForKey: @"words"];

  if (wordsdict) {
    NSCountedSet *wordset = [wordsdict objectForKey: @"wset"];
    NSEnumerator *enumerator = [wordset objectEnumerator];  
    unsigned wcount = [[wordsdict objectForKey: @"wcount"] unsignedLongValue];
    NSString *word;

    query = @"UPDATE paths "
            @"SET words_count = :wcount "
            @"WHERE id = :pathid";
  
    statement = [sqlite statementForQuery: query 
                           withIdentifier: @"set_metadata_1"
                                 bindings: SQLITE_INTEGER, @":wcount", wcount, 
                                           SQLITE_INTEGER, @":pathid", path_id, 0];

    STATEMENT_EXECUTE_QUERY (statement, NO);

    while ((word = [enumerator nextObject])) {
      NSString *qword = stringForQuery(word);
      unsigned word_count = [wordset countForObject: word];
      int word_id;
      
      query = @"SELECT id FROM words WHERE word = :word";

      statement = [sqlite statementForQuery: query 
                             withIdentifier: @"set_metadata_2"
                                   bindings: SQLITE_TEXT, @":word", qword, 0];
      
      word_id = [sqlite getIntEntryWithStatement: statement];
      
      if (word_id == INT_MAX) {
        query = @"INSERT INTO words (word) VALUES(:word)";

        statement = [sqlite statementForQuery: query 
                               withIdentifier: @"set_metadata_3"
                                     bindings: SQLITE_TEXT, @":word", qword, 0];
      
        STATEMENT_EXECUTE_QUERY (statement, NO);
      
        word_id = [sqlite lastInsertRowId];
      }
      
      query = @"INSERT INTO postings (word_id, path_id, word_count) "
              @"VALUES(:wordid, :pathid, :wordcount)";
              
      statement = [sqlite statementForQuery: query 
                             withIdentifier: @"set_metadata_4"
                                   bindings: SQLITE_INTEGER, @":wordid", word_id,
                                             SQLITE_INTEGER, @":pathid", path_id, 
                                             SQLITE_INTEGER, @":wordcount", word_count, 0];
              
      STATEMENT_EXECUTE_QUERY (statement, NO);
    }
  }

  attrsdict = [mddict objectForKey: @"attributes"];

  if (attrsdict) {
    NSArray *keys = [attrsdict allKeys];
    unsigned i;

    for (i = 0; i < [keys count]; i++) {
      NSString *key = [keys objectAtIndex: i];
      id mdvalue = [attrsdict objectForKey: key];

      query = @"INSERT INTO attributes "
              @"(path_id, key, attribute) "
              @"VALUES(:pathid, :key, :mdvalue)";

      if ([mdvalue isKindOfClass: [NSString class]]) {      
        statement = [sqlite statementForQuery: query 
                               withIdentifier: @"set_metadata_5"
                                     bindings: SQLITE_INTEGER, @":pathid", path_id, 
                                               SQLITE_TEXT, @":key", key,        
                                               SQLITE_TEXT, @":mdvalue", mdvalue, 0];

      } else if ([mdvalue isKindOfClass: [NSArray class]]) {     
        statement = [sqlite statementForQuery: query 
                               withIdentifier: @"set_metadata_5"
                                     bindings: SQLITE_INTEGER, @":pathid", path_id, 
                                               SQLITE_TEXT, @":key", key,        
                                               SQLITE_TEXT, @":mdvalue", [mdvalue description], 0];
 
      } else if ([mdvalue isKindOfClass: [NSNumber class]]) {
        statement = [sqlite statementForQuery: query 
                               withIdentifier: @"set_metadata_5"
                                     bindings: SQLITE_INTEGER, @":pathid", path_id, 
                                               SQLITE_TEXT, @":key", key,        
                                               SQLITE_TEXT, @":mdvalue", [mdvalue description], 0];

      } else if ([mdvalue isKindOfClass: [NSData class]]) {      
        statement = [sqlite statementForQuery: query 
                               withIdentifier: @"set_metadata_5"
                                     bindings: SQLITE_INTEGER, @":pathid", path_id, 
                                               SQLITE_TEXT, @":key", key,        
                                               SQLITE_BLOB, @":mdvalue", mdvalue, 0];
      } else {
        return NO;
      }
      
      STATEMENT_EXECUTE_QUERY (statement, NO);
    }
  }

  return YES;
}

- (id)extractorForPath:(NSString *)path
                ofType:(NSString *)type
        withAttributes:(NSDictionary *)attributes
{
  NSString *ext = [[path pathExtension] lowercaseString];
  NSData *data = nil;
  id extractor = nil;  
  
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

  extractor = [extractors objectForKey: ext];
  
  if (extractor) {
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
  NSEnumerator *e1;
  NSEnumerator *enumerator;
  NSString *dir;
  int i;
   
  bundlesPaths = [NSMutableArray array];
  e1 = [NSSearchPathForDirectoriesInDomains
    (NSLibraryDirectory, NSAllDomainsMask, YES) objectEnumerator];
  while ((bundlesDir = [e1 nextObject]) != nil)
    {
      bundlesDir = [bundlesDir stringByAppendingPathComponent: @"Bundles"];
      enumerator = [[fm directoryContentsAtPath: bundlesDir] objectEnumerator];

      while ((dir = [enumerator nextObject])) {
	if ([[dir pathExtension] isEqual: @"extr"]) {
	  [bundlesPaths addObject:
	    [bundlesDir stringByAppendingPathComponent: dir]];
	}
      }
    }

  extractors = [NSMutableDictionary new];
  
  for (i = 0; i < [bundlesPaths count]; i++) {
    NSString *bpath = [bundlesPaths objectAtIndex: i];
    NSBundle *bundle = [NSBundle bundleWithPath: bpath]; 

    if (bundle) {
			Class principalClass = [bundle principalClass];  
  
			if ([principalClass conformsToProtocol: @protocol(ExtractorsProtocol)]) {	
        id extractor = [[principalClass alloc] initForExtractor: self];
        
        if (extractor) {
          NSArray *extensions = [extractor pathExtensions];

          if ([extensions containsObject: @"txt"]) {
            ASSIGN (textExtractor, extractor);

          } else {
            unsigned j;

            for (j = 0; j < [extensions count]; j++) {
              [extractors setObject: extractor 
                             forKey: [[extensions objectAtIndex: j] lowercaseString]];
            }

            RELEASE ((id)extractor);
          }
        }
      }
    }
  }
}

- (BOOL)opendb
{
  BOOL newdb;

  if ([sqlite opendbAtPath: dbpath isNew: &newdb]) {    
    if (newdb) {
      if ([sqlite executeSimpleQuery: db_schema] == NO) {
        NSLog(@"unable to create the database at %@", dbpath);
        return NO;
      } else {
        GWDebugLog(@"contents database created");
      }
    } 
  } else {
    NSLog(@"unable to open the database at %@", dbpath);
    return NO;
  }    

  [sqlite createFunctionWithName: @"checkUpdating"
                  argumentsCount: 0
                    userFunction: check_updating];

  [sqlite createFunctionWithName: @"pathExists"
                  argumentsCount: 1
                    userFunction: path_exists];

  [sqlite createFunctionWithName: @"pathMoved"
                  argumentsCount: 3
                    userFunction: path_moved];

  [sqlite createFunctionWithName: @"timeStamp"
                  argumentsCount: 0
                    userFunction: time_stamp];

  [sqlite executeQuery: @"PRAGMA cache_size = 20000"];
  [sqlite executeQuery: @"PRAGMA count_changes = 0"];
  [sqlite executeQuery: @"PRAGMA synchronous = OFF"];
  [sqlite executeQuery: @"PRAGMA temp_store = MEMORY"];

  if ([sqlite executeSimpleQuery: db_schema_tmp] == NO) {
    NSLog(@"unable to create temp tables");
    [sqlite closeDb];
    return NO;    
  }

  /* only to avoid a compiler warning */
  if (0) {
    NSLog(@"%@", user_db_schema);
    NSLog(@"%@", user_db_schema_tmp);
  }

  return YES;
}

- (void)logError:(NSString *)err
{
  NSString *errbuf = [NSString stringWithFormat: @"%@\n", err];
  NSData *data = [errbuf dataUsingEncoding: [NSString defaultCStringEncoding]];

  if (data == nil) {
    data = [errbuf dataUsingEncoding: NSUnicodeStringEncoding];
  }

  [errHandle seekToEndOfFile];
  [errHandle writeData: data];
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
    [sqlite closeDb];
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
  BOOL subtask = YES;

  if ([[info arguments] containsObject: @"--daemon"]) {
    subtask = NO;
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
	  GMDSExtractor *extractor;
    
    [NSApplication sharedApplication];
    extractor = [GMDSExtractor new];
    RELEASE (pool);

    if (extractor != nil) {
	    CREATE_AUTORELEASE_POOL (pool);
      [[NSRunLoop currentRunLoop] run];
  	  RELEASE (pool);
    }
  }
    
  exit(EXIT_SUCCESS);
}


void setUpdating(BOOL value)
{
  updating = value;
}

BOOL isDotFile(NSString *path)
{
  NSArray *components;
  NSEnumerator *e;
  NSString *c;
  BOOL found;

  if (path == nil)
    return NO;

  found = NO;
  components = [path pathComponents];
  e = [components objectEnumerator];
  while ((c = [e nextObject]) && !found)
    {
      if (([c length] > 0) && ([c characterAtIndex:0] == '.'))
	found = YES;
    }

  return found;  
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

NSString *path_separator(void)
{
  static NSString *separator = nil;

  if (separator == nil) {
    #if defined(__MINGW32__)
      separator = @"\\";	
    #else
      separator = @"/";	
    #endif

    RETAIN (separator);
  }

  return separator;
}
