/* updater.m
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
#include <limits.h>
#include <float.h>
#include "mdextractor.h"
#include "config.h"

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

#define EXECUTE_OR_ROLLBACK(q, r) \
do { \
  if ([sqlite executeQuery: q] == NO) { \
    [sqlite executeQuery: @"ROLLBACK"]; \
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

#define STATEMENT_EXECUTE_OR_ROLLBACK(s, r) \
do { \
  if ([sqlite executeQueryWithStatement: s] == NO) { \
    [sqlite executeQuery: @"ROLLBACK"]; \
    NSLog(@"error at: %@", [s query]); \
    return r; \
  } \
} while (0)


#define SKIP_EXPIRE (1.0)
#define LOST_PATHS_EXPIRE (60.0)
#define LOST_PATHS_CHECK (30.0)
#define SCHED_TIME (1.0)


@implementation GMDSExtractor (updater)

- (void)setupUpdaters
{
  [self setupFswatcherUpdater];
  [self setupScheduledUpdater];
}

- (BOOL)addPath:(NSString *)path
{
  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];
      
  if (attributes) {
    id extractor = nil;
    int path_id;
    
    EXECUTE_QUERY (@"BEGIN", NO);
    
    path_id = [self insertOrUpdatePath: path withAttributes: attributes];
    
    if (path_id == -1) {
      [sqlite executeQuery: @"ROLLBACK"];
      return NO;
    }

    extractor = [self extractorForPath: path withAttributes: attributes];

    if (extractor) {
      if ([extractor extractMetadataAtPath: path
                                    withID: path_id
                                attributes: attributes
                              usingStemmer: stemmer
                                 stopWords: stopWords] == NO) {
        [sqlite executeQuery: @"ROLLBACK"];
        return NO;
      }
    }
    
    [sqlite executeQuery: @"COMMIT"];
    
    if ([attributes fileType] == NSFileTypeDirectory) {
      NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath: path];
      
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
            if (skip == NO) {
              [sqlite executeQuery: @"BEGIN"];
              
              path_id = [self insertOrUpdatePath: subpath withAttributes: attributes];
    
              if (path_id == -1) {
                RELEASE (arp);
                [sqlite executeQuery: @"ROLLBACK"];
                return NO;
              }

              extractor = [self extractorForPath: subpath withAttributes: attributes];
                  
              if (extractor) {
                if ([extractor extractMetadataAtPath: subpath
                                              withID: path_id
                                          attributes: attributes
                                        usingStemmer: stemmer
                                           stopWords: stopWords] == NO) {
                  [sqlite executeQuery: @"ROLLBACK"];
                  RELEASE (arp);
                  return NO;
                }
              }
              
              [sqlite executeQuery: @"COMMIT"];
            }
          
            if ([attributes fileType] == NSFileTypeDirectory) {
              if (skip) {
                GWDebugLog(@"skipping %@", subpath); 
                [enumerator skipDescendents];
              }
            }
          }
          
        } else {
          RELEASE (arp);
          break;
        }
        
        TEST_RELEASE (arp);
      }
    }
  }
  
  return YES;
}

- (BOOL)updatePath:(NSString *)path
{
  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];
      
  if (attributes) {
    id extractor;
    int path_id;
    
    EXECUTE_QUERY (@"BEGIN", NO);
    
    path_id = [self insertOrUpdatePath: path withAttributes: attributes];
    
    if (path_id == -1) {
      [sqlite executeQuery: @"ROLLBACK"];
      return NO;
    }

    extractor = [self extractorForPath: path withAttributes: attributes];

    if (extractor) {
      if ([extractor extractMetadataAtPath: path
                                    withID: path_id
                                attributes: attributes
                              usingStemmer: stemmer
                                 stopWords: stopWords] == NO) {
        [sqlite executeQuery: @"ROLLBACK"];
        return NO;
      }
    }
    
    [sqlite executeQuery: @"COMMIT"];
  }
  
  return YES;
}

- (BOOL)updateRenamedPath:(NSString *)path 
                  oldPath:(NSString *)oldpath
              isDirectory:(BOOL)isdir
{
  NSString *qpath = stringForQuery(path);
  NSString *qoldpath = stringForQuery(oldpath);
  SQLitePreparedStatement *statement;
  NSString *query;
        
  EXECUTE_QUERY (@"BEGIN", NO);

  statement = [sqlite statementForQuery: @"DELETE FROM renamed_paths" 
                         withIdentifier: @"update_renamed_1"
                               bindings: 0];

  STATEMENT_EXECUTE_OR_ROLLBACK (statement, NO);

  statement = [sqlite statementForQuery: @"DELETE FROM renamed_paths_base" 
                         withIdentifier: @"update_renamed_2"
                               bindings: 0];

  STATEMENT_EXECUTE_OR_ROLLBACK (statement, NO);

  query = @"INSERT INTO renamed_paths_base "
          @"(base, oldbase) "
          @"VALUES(:path, :oldpath)";

  statement = [sqlite statementForQuery: query 
                         withIdentifier: @"update_renamed_3"
                               bindings: SQLITE_TEXT, @":path", qpath, 
                                         SQLITE_TEXT, @":oldpath", qoldpath, 0];

  STATEMENT_EXECUTE_OR_ROLLBACK (statement, NO);
  
  if (isdir) {
    query = @"INSERT INTO renamed_paths "
            @"(id, path, base, oldbase) "
            @"SELECT paths.id, paths.path, "
            @"renamed_paths_base.base, renamed_paths_base.oldbase "
            @"FROM paths, renamed_paths_base "
            @"WHERE paths.path = :oldpath "
            @"OR paths.path GLOB :minpath ";

    statement = [sqlite statementForQuery: query 
                           withIdentifier: @"update_renamed_4"
                                 bindings: SQLITE_TEXT, @":oldpath", qoldpath,
                                           SQLITE_TEXT, @":minpath", 
          [NSString stringWithFormat: @"%@%@*", qoldpath, path_separator()], 0];
  } else {
    query = @"INSERT INTO renamed_paths "
            @"(id, path, base, oldbase) "
            @"SELECT paths.id, paths.path, "
            @"renamed_paths_base.base, renamed_paths_base.oldbase "
            @"FROM paths, renamed_paths_base "
            @"WHERE paths.path = :oldpath";

    statement = [sqlite statementForQuery: query 
                           withIdentifier: @"update_renamed_5"
                                 bindings: SQLITE_TEXT, @":oldpath", qoldpath, 0];
  }
  
  STATEMENT_EXECUTE_OR_ROLLBACK (statement, NO);

  EXECUTE_QUERY (@"COMMIT", NO);
  
  return YES;
}

- (BOOL)removePath:(NSString *)path
{
  NSString *qpath = stringForQuery(path);
  SQLitePreparedStatement *statement;
  NSString *query;
      
  EXECUTE_QUERY (@"BEGIN", NO);

  statement = [sqlite statementForQuery: @"DELETE FROM removed_id" 
                         withIdentifier: @"remove_path_1"
                               bindings: 0];
                             
  STATEMENT_EXECUTE_OR_ROLLBACK (statement, NO);
    
  query = @"INSERT INTO removed_id (id) "
          @"SELECT id FROM paths "
          @"WHERE path = :path "
          @"OR path GLOB :minpath";
          
  statement = [sqlite statementForQuery: query 
                         withIdentifier: @"remove_path_2"
                               bindings: SQLITE_TEXT, @":path", qpath,
                                         SQLITE_TEXT, @":minpath", 
          [NSString stringWithFormat: @"%@%@*", qpath, path_separator()], 0];
      
  STATEMENT_EXECUTE_OR_ROLLBACK (statement, NO);

  query = @"DELETE FROM attributes WHERE path_id IN (SELECT id FROM removed_id)";

  statement = [sqlite statementForQuery: query 
                         withIdentifier: @"remove_path_3"
                               bindings: 0];

  STATEMENT_EXECUTE_OR_ROLLBACK (statement, NO);

  query = @"DELETE FROM postings WHERE path_id IN (SELECT id FROM removed_id)";

  statement = [sqlite statementForQuery: query 
                         withIdentifier: @"remove_path_4"
                               bindings: 0];

  STATEMENT_EXECUTE_OR_ROLLBACK (statement, NO);

  query = @"DELETE FROM paths WHERE id IN (SELECT id FROM removed_id)";

  statement = [sqlite statementForQuery: query 
                         withIdentifier: @"remove_path_5"
                               bindings: 0];

  STATEMENT_EXECUTE_OR_ROLLBACK (statement, NO);

  EXECUTE_QUERY (@"COMMIT", NO);

  return YES;
}

- (void)checkLostPaths:(id)sender
{
  NSDate *now = [NSDate date];
  unsigned count = [lostPaths count];
  unsigned i;
  
  for (i = 0; i < count; i++) {
    NSDictionary *d = [lostPaths objectAtIndex: i];
    NSDate *stamp = [d objectForKey: @"stamp"];
    
    if ([stamp timeIntervalSinceDate: now] > LOST_PATHS_EXPIRE) {
      GWDebugLog(@"removing expired lost path: %@ ", [d objectForKey: @"path"]);
      [lostPaths removeObjectAtIndex: i];
      count--;
      i--;
    }
  }  
}

- (NSArray *)filteredDirectoryContentsAtPath:(NSString *)path
                               escapeEntries:(BOOL)escape
{
  NSMutableArray *contents = [NSMutableArray array];
  NSEnumerator *enumerator = [[fm directoryContentsAtPath: path] objectEnumerator];
  NSString *fname;

  while ((fname = [enumerator nextObject])) {
    NSString *subpath = [path stringByAppendingPathComponent: fname];
    NSString *ext = [[subpath pathExtension] lowercaseString];
    
    if (([excludedSuffixes containsObject: ext] == NO)
            && (isDotFile(subpath) == NO)
            && (inTreeFirstPartOfPath(subpath, excludedPathsTree) == NO)) {
      [contents addObject: (escape ? stringForQuery(subpath) : subpath)];
    }
  }

  return [contents makeImmutableCopyOnFail: NO];
}

@end


@implementation GMDSExtractor (fswatcher_update)

- (void)setupFswatcherUpdater
{
  fswupdatePaths = [NSMutableArray new];
  fswupdateSkipBuff = [NSMutableDictionary new];
  lostPaths = [NSMutableArray new];
     
  fswupdateTimer = [NSTimer scheduledTimerWithTimeInterval: 1.0 
						                         target: self 
                                   selector: @selector(processPendingChanges:) 
																   userInfo: nil 
                                    repeats: YES];
  RETAIN (fswupdateTimer);     
          
  lostPathsTimer = [NSTimer scheduledTimerWithTimeInterval: LOST_PATHS_CHECK
						                         target: self 
                                   selector: @selector(checkLostPaths:) 
																   userInfo: nil 
                                    repeats: YES];
  RETAIN (lostPathsTimer);     
     
  fswatcher = nil;
  [self connectFSWatcher];
}

- (oneway void)globalWatchedPathDidChange:(NSDictionary *)info
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];  
  NSString *path = [info objectForKey: @"path"];
  NSString *event = [info objectForKey: @"event"];
  NSNumber *exists;
    
  if ([event isEqual: @"GWWatchedPathDeleted"]) {
    exists = [NSNumber numberWithBool: NO];
    
  } else if ([event isEqual: @"GWWatchedFileModified"]) {
    exists = [NSNumber numberWithBool: YES];
  
  } else if ([event isEqual: @"GWWatchedPathRenamed"]) {
    NSString *oldpath = [info objectForKey: @"oldpath"];
 
    if (oldpath != nil) {    
      [dict setObject: oldpath forKey: @"oldpath"];   
    }
    
    exists = [NSNumber numberWithBool: YES];
  } 

  [dict setObject: path forKey: @"path"];
  [dict setObject: event forKey: @"event"];
  [dict setObject: exists forKey: @"exists"];

  if ([fswupdatePaths containsObject: dict] == NO) {
    NSDictionary *skipInfo = [fswupdateSkipBuff objectForKey: path];
    BOOL caninsert = YES;
    
    if (skipInfo != nil) {
      NSNumber *didexists = [skipInfo objectForKey: @"exists"];
      NSDate *stamp = [skipInfo objectForKey: @"stamp"];
      NSDate *now = [NSDate date];
            
      if ([exists isEqual: didexists]
             && ([now timeIntervalSinceDate: stamp] < SKIP_EXPIRE)) {
        caninsert = NO;
      } else {
        skipInfo = [NSDictionary dictionaryWithObjectsAndKeys: event, @"event", 
                                                  exists, @"exists",
                                                  now, @"stamp", nil];     
        [fswupdateSkipBuff setObject: skipInfo forKey: path];
      }
    } else {
      skipInfo = [NSDictionary dictionaryWithObjectsAndKeys: event, @"event",
                                                 exists, @"exists",
                                                 [NSDate date], @"stamp", nil];     
      [fswupdateSkipBuff setObject: skipInfo forKey: path];
    }
  
    if (caninsert) {
      [fswupdatePaths insertObject: dict atIndex: 0];
      GWDebugLog(@"queueing: %@ - %@", path, event);
    }
  }
     
  RELEASE (arp);                       
}

- (void)processPendingChanges:(id)sender
{
  CREATE_AUTORELEASE_POOL(arp);
  
  while ([fswupdatePaths count] > 0) {
    NSDictionary *dict = [fswupdatePaths lastObject];
    NSString *path = [dict objectForKey: @"path"];    
    NSString *event = [dict objectForKey: @"event"];
    NSDate *date = [NSDate dateWithTimeIntervalSinceNow: 0.001];
        
    [[NSRunLoop currentRunLoop] runUntilDate: date]; 
    
    if ([event isEqual: @"GWWatchedFileModified"]) {
      if ([fm fileExistsAtPath: path]) {
        GWDebugLog(@"db update: %@", path);

        if ([self updatePath: path] == NO) {      
          NSLog(@"An error occurred while processing %@", path);
        }        
      } else {
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        
        [d setObject: path forKey: @"path"];
        [d setObject: [NSDate date] forKey: @"stamp"];
        
        GWDebugLog(@"add lost path: %@", path);
        [lostPaths addObject: d];
      }
       
    } else if ([event isEqual: @"GWWatchedPathDeleted"]) {
      if ([fm fileExistsAtPath: path] == NO) {
        GWDebugLog(@"db remove: %@", path);
        [self removePath: path];
      }

    } else if ([event isEqual: @"GWWatchedPathRenamed"]) {
      BOOL isdir;
      
      if ([fm fileExistsAtPath: path isDirectory: &isdir]) {
        NSString *oldpath = [dict objectForKey: @"oldpath"];
      
        if (oldpath != nil) {
          unsigned count = [lostPaths count];
          unsigned i;

          for (i = 0; i < count; i++) {
            NSMutableDictionary *d = [lostPaths objectAtIndex: i];
            NSString *lost = [d objectForKey: @"path"];

            if (subPathOfPath(oldpath, lost)) {
              unsigned pos = [lost rangeOfString: oldpath].length +1;
              NSString *part = [lost substringFromIndex: pos];
              NSString *newpath = [path stringByAppendingPathComponent: part];          

              GWDebugLog(@"found lost path: %@", lost);          

              [self removePath: lost];
              
              if ([fm fileExistsAtPath: newpath]) {
                [self updatePath: newpath]; 
                [lostPaths removeObjectAtIndex: i];
                count--;
                i--;
              } else {
                [d setObject: newpath forKey: @"path"];
                [d setObject: [NSDate date] forKey: @"stamp"];
                GWDebugLog(@"changed lost path: %@ to: %@", lost, newpath);    
              }
            }
          }
        
          GWDebugLog(@"db rename: %@ -> %@", oldpath, path);

          if ([self updateRenamedPath: path 
                              oldPath: oldpath 
                          isDirectory: isdir] == NO) { 
            NSLog(@"An error occurred while processing %@", path);
          }

        } else {
          GWDebugLog(@"db update renamed: %@", path);

          if ([self addPath: path] == NO) {      
            NSLog(@"An error occurred while processing %@", path);
          }
        }
        
      } else {
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        
        [d setObject: path forKey: @"path"];
        [d setObject: [NSDate date] forKey: @"stamp"];
        [lostPaths addObject: d];
        GWDebugLog(@"add lost path: %@", path);
      }
    }
       
    [fswupdatePaths removeLastObject];    
  }
  
  {
    NSArray *skipPaths = [fswupdateSkipBuff allKeys];
    NSDate *now = [NSDate date];
    unsigned i;
    
    RETAIN (skipPaths);
    
    for (i = 0; i < [skipPaths count]; i++) {
      NSString *path = [skipPaths objectAtIndex: i];
      NSDictionary *skipInfo = [fswupdateSkipBuff objectForKey: path];
      NSDate *stamp = [skipInfo objectForKey: @"stamp"];
      
      if ([now timeIntervalSinceDate: stamp] > SKIP_EXPIRE) {
        [fswupdateSkipBuff removeObjectForKey: path];
   //     GWDebugLog(@"expired skip-info %@", path);
      }
    }
    
    RELEASE (skipPaths);
  }  
    
  RELEASE (arp);  
}

- (void)connectFSWatcher
{
  if (fswatcher == nil) {
    id fsw = [NSConnection rootProxyForConnectionWithRegisteredName: @"fswatcher" 
                                                               host: @""];

    if (fsw) {
      NSConnection *c = [fsw connectionForProxy];

	    [nc addObserver: self
	           selector: @selector(fswatcherConnectionDidDie:)
		             name: NSConnectionDidDieNotification
		           object: c];
      
      fswatcher = fsw;
	    [fswatcher setProtocolForProxy: @protocol(FSWatcherProtocol)];
      RETAIN (fswatcher);
                                   
	    [fswatcher registerClient: (id <FSWClientProtocol>)self 
                isGlobalWatcher: YES];
      
      NSLog(@"fswatcher connected!");
      
	  } else {
	    static BOOL recursion = NO;
	    static NSString	*cmd = nil;

	    if (recursion == NO) {
        if (cmd == nil) {
          cmd = RETAIN ([[NSSearchPathForDirectoriesInDomains(
                      GSToolsDirectory, NSSystemDomainMask, YES) objectAtIndex: 0]
                            stringByAppendingPathComponent: @"fswatcher"]);
		    }
      }
	  
      if (recursion == NO && cmd != nil) {
        int i;
        
	      [NSTask launchedTaskWithLaunchPath: cmd arguments: nil];
        DESTROY (cmd);
        
        for (i = 1; i <= 40; i++) {
	        [[NSRunLoop currentRunLoop] runUntilDate:
		                       [NSDate dateWithTimeIntervalSinceNow: 0.1]];
                           
          fsw = [NSConnection rootProxyForConnectionWithRegisteredName: @"fswatcher" 
                                                                  host: @""];                  
          if (fsw) {
            break;
          }
        }
        
	      recursion = YES;
	      [self connectFSWatcher];
	      recursion = NO;
        
	    } else { 
        DESTROY (cmd);
	      recursion = NO;
        NSLog(@"unable to contact fswatcher!");  
      }
	  }
  }
}

- (void)fswatcherConnectionDidDie:(NSNotification *)notif
{
  id connection = [notif object];

  [nc removeObserver: self
	              name: NSConnectionDidDieNotification
	            object: connection];

  NSAssert(connection == [fswatcher connectionForProxy],
		                                  NSInternalInconsistencyException);
  RELEASE (fswatcher);
  fswatcher = nil;

  NSLog(@"The fswatcher connection died!");

  [self connectFSWatcher];                
}

@end


@implementation GMDSExtractor (scheduled_update)

- (void)setupScheduledUpdater
{
  CREATE_AUTORELEASE_POOL(arp);
  NSString *query = @"SELECT path FROM paths WHERE is_directory = 1";
  NSArray *lines = [sqlite resultsOfQuery: query];
  unsigned i;
    
  directories = [NSMutableArray new];
                                       
  for (i = 0; i < [lines count]; i++) {
    [directories addObject: [[lines objectAtIndex: i] objectForKey: @"path"]];
  }
  
  dirpos = 0;

  schedupdateTimer = [NSTimer scheduledTimerWithTimeInterval: SCHED_TIME
						                                 target: self 
                                           selector: @selector(checkNextDir:) 
																           userInfo: nil 
                                            repeats: YES];
  RETAIN (schedupdateTimer);     
  
  RELEASE (arp);
}

- (void)checkNextDir:(id)sender
{
  CREATE_AUTORELEASE_POOL(arp);
  unsigned count = [directories count];

  if (dirpos < count) {
    NSString *dir = [directories objectAtIndex: dirpos];
    NSDictionary *attributes = [fm fileAttributesAtPath: dir traverseLink: NO];
    BOOL dirok = (attributes && ([attributes fileType] == NSFileTypeDirectory));
    unsigned i;
    
    if (dirok) {
      NSArray *contents = [self filteredDirectoryContentsAtPath: dir escapeEntries: YES];
      NSMutableDictionary *dbcontents = [NSMutableDictionary dictionary];
      NSArray *dbpaths = nil;
      NSString *qdir = stringForQuery(dir);
      NSString *sep = path_separator();
      NSString *query;
      SQLitePreparedStatement *statement;
      NSArray *results;
      unsigned i;
      
      query = @"SELECT path, moddate FROM paths "
              @"WHERE path > :minpath "
              @"AND path < :maxpath "
              @"AND path NOT GLOB :limit";
               
      statement = [sqlite statementForQuery: query 
                             withIdentifier: @"check_next_dir"
                                   bindings: SQLITE_TEXT,
                                             @":minpath",
                      [NSString stringWithFormat: @"%@%@", qdir, sep],                   
                                             SQLITE_TEXT,
                                             @":maxpath",                             
                      [NSString stringWithFormat: @"%@0", qdir],
                                             SQLITE_TEXT,
                                             @":limit",                             
                [NSString stringWithFormat: @"%@%@*%@*", qdir, sep, sep], 0];
      
      results = [sqlite resultsOfQueryWithStatement: statement];

      for (i = 0; i < [results count]; i++) {
        NSDictionary *dict = [results objectAtIndex: i];
        
        [dbcontents setObject: [dict objectForKey: @"moddate"]
                       forKey: [dict objectForKey: @"path"]];
      }
          
      for (i = 0; i < [contents count]; i++) {
        NSString *path = [contents objectAtIndex: i];
        NSNumber *dbdate = [dbcontents objectForKey: path];
        
        if (dbdate == nil) {
          GWDebugLog(@"schedule-add %@", path);
          [self addPath: path];
        
        } else {
          NSDictionary *attrs = [fm fileAttributesAtPath: path traverseLink: NO];
          NSTimeInterval date = [[attrs fileModificationDate] timeIntervalSinceReferenceDate];
   
          if ((date - [dbdate floatValue]) > 10) {
            GWDebugLog(@"schedule-update %@ ---- %f - %f", path, date, [dbdate floatValue]);
            [self updatePath: path];
          }
        }
      }    
    
      dbpaths = [dbcontents allKeys];
    
      for (i = 0; i < [dbpaths count]; i++) {    
        NSString *path = [dbpaths objectAtIndex: i];
    
        if ([contents containsObject: path] == NO) {
          GWDebugLog(@"schedule-remove %@", path);
          [self removePath: path];
        }
      }
        
    } else {  
      [self removePath: dir];
      
      RETAIN (dir);
      GWDebugLog(@"schedule-remove %@", dir);
      [directories removeObjectAtIndex: dirpos];
      count--;
      dirpos--;
        
      for (i = 0; i < count; i++) {
        if (subPathOfPath(dir, [directories objectAtIndex: i])) {
          GWDebugLog(@"schedule-remove %@", [directories objectAtIndex: i]);
          [directories removeObjectAtIndex: i];
          count--;
          if (dirpos >= i) {
            dirpos--;
          }
          i--;
        }
      }
      
      if (attributes) {
        [self addPath: dir];
        GWDebugLog(@"schedule-remove->add %@", dir);
      }
      
      RELEASE (dir);
    }

    dirpos++;
  
    if ((dirpos >= count) || (dirpos < 0)) {
      dirpos = 0;
    }
  }
  
  RELEASE (arp);
}

@end







