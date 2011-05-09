/* updater.m
 *  
 * Copyright (C) 2006-2011 Free Software Foundation, Inc.
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

#include "config.h"

#include <sys/types.h>
#include <sys/stat.h>
#include <limits.h>
#include <float.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#import "mdextractor.h"


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

#define STATEMENT_EXECUTE_OR_ROLLBACK(s, u, r) \
do { \
  if ([sqlite executeQueryWithStatement: s] == NO) { \
    if (u) { \
      setUpdating(NO); \
    } \
    [sqlite executeQuery: @"ROLLBACK"]; \
    NSLog(@"error at: %@", [s query]); \
    return r; \
  } \
} while (0)


#define SKIP_EXPIRE (1.0)
#define LOST_PATHS_EXPIRE (60.0)
#define LOST_PATHS_CHECK (30.0)
#define SCHED_TIME (1.0)
#define NOTIF_TIME (60.0)


@implementation GMDSExtractor (updater)

- (void)setupUpdaters
{
  [self setupFswatcherUpdater];
  [self setupDDBdUpdater];
  [self setupScheduledUpdater];
  [self setupUpdateNotifications];
}

- (BOOL)addPath:(NSString *)path
{
  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];
      
  if (attributes) {
    NSString *app = nil;
    NSString *type = nil;
    id extractor = nil;
    BOOL failed = NO;
    BOOL hasextractor = NO;
    int path_id;
    
    EXECUTE_QUERY (@"BEGIN", NO); 
    setUpdating(YES);
     
    [ws getInfoForFile: path application: &app type: &type];  
    
    path_id = [self insertOrUpdatePath: path 
                                ofType: type
                        withAttributes: attributes];
    
    if (path_id != -1) {
      extractor = [self extractorForPath: path 
                                  ofType: type
                          withAttributes: attributes];    
    
      if (extractor) {
        hasextractor = YES;
      
        if ([extractor extractMetadataAtPath: path
                                      withID: path_id
                                  attributes: attributes] == NO) {
          failed = YES;                         
        }
      }
    
    } else {
      failed = YES;
    }
    
    if (failed == NO) {
      setUpdating(NO);
      [sqlite executeQuery: @"COMMIT"];
      
      if (hasextractor) {
        GWDebugLog(@"updated: %@", path);
      } else {
        GWDebugLog(@"no extractor for: %@", path);
      }
      
    } else {
      setUpdating(NO);
      [sqlite executeQuery: @"ROLLBACK"];
      [self logError: [NSString stringWithFormat: @"UPDATE %@", path]];
      GWDebugLog(@"error updating at: %@", path);
      
      return NO;
    }
    
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
            failed = NO;
            hasextractor = NO;
            
            if (skip == NO) {
              NSString *app = nil;
              NSString *type = nil;
              
              [sqlite executeQuery: @"BEGIN"];
              setUpdating(YES);
              
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
              
              setUpdating(NO);
              [sqlite executeQuery: @"COMMIT"];
            }
            
            if (skip) { 
              GWDebugLog(@"skipping (update) %@", subpath);

              if ([attributes fileType] == NSFileTypeDirectory) {
                [enumerator skipDescendents];
              }
            
            } else {
              if (failed) {
                [self logError: [NSString stringWithFormat: @"UPDATE %@", subpath]];
                GWDebugLog(@"error updating: %@", subpath);
              } else if (hasextractor == NO) {
                GWDebugLog(@"no extractor for: %@", subpath);
              } else {
                GWDebugLog(@"updated: %@", subpath);
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
    NSString *app = nil;
    NSString *type = nil;  
    id extractor;
    int path_id;
    
    EXECUTE_QUERY (@"BEGIN", NO);
    setUpdating(YES);
    
    [ws getInfoForFile: path application: &app type: &type];  
    
    path_id = [self insertOrUpdatePath: path 
                                ofType: type
                        withAttributes: attributes];
    
    if (path_id == -1) {
      setUpdating(NO);
      [sqlite executeQuery: @"COMMIT"];
      return NO;
    }

    extractor = [self extractorForPath: path 
                                ofType: type
                        withAttributes: attributes];

    if (extractor) {
      if ([extractor extractMetadataAtPath: path
                                    withID: path_id
                                attributes: attributes] == NO) {
        setUpdating(NO);                         
        [sqlite executeQuery: @"COMMIT"];
        return NO;
      }
    }
    
    setUpdating(NO);
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
  setUpdating(YES);

  statement = [sqlite statementForQuery: @"DELETE FROM renamed_paths" 
                         withIdentifier: @"update_renamed_1"
                               bindings: 0];

  STATEMENT_EXECUTE_OR_ROLLBACK (statement, YES, NO);

  statement = [sqlite statementForQuery: @"DELETE FROM renamed_paths_base" 
                         withIdentifier: @"update_renamed_2"
                               bindings: 0];

  STATEMENT_EXECUTE_OR_ROLLBACK (statement, YES, NO);

  query = @"INSERT INTO renamed_paths_base "
          @"(base, oldbase) "
          @"VALUES(:path, :oldpath)";

  statement = [sqlite statementForQuery: query 
                         withIdentifier: @"update_renamed_3"
                               bindings: SQLITE_TEXT, @":path", qpath, 
                                         SQLITE_TEXT, @":oldpath", qoldpath, 0];

  STATEMENT_EXECUTE_OR_ROLLBACK (statement, YES, NO);
  
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
  
  STATEMENT_EXECUTE_OR_ROLLBACK (statement, YES, NO);

  setUpdating(NO);
  EXECUTE_QUERY (@"COMMIT", NO);
  
  return YES;
}

- (BOOL)removePath:(NSString *)path
{
  NSString *qpath = stringForQuery(path);
  SQLitePreparedStatement *statement;
  NSString *query;
      
  EXECUTE_QUERY (@"BEGIN", NO);
  setUpdating(YES);

  statement = [sqlite statementForQuery: @"DELETE FROM removed_id" 
                         withIdentifier: @"remove_path_1"
                               bindings: 0];
                             
  STATEMENT_EXECUTE_OR_ROLLBACK (statement, YES, NO);
    
  query = @"INSERT INTO removed_id (id) "
          @"SELECT id FROM paths "
          @"WHERE path = :path "
          @"OR path GLOB :minpath";
          
  statement = [sqlite statementForQuery: query 
                         withIdentifier: @"remove_path_2"
                               bindings: SQLITE_TEXT, @":path", qpath,
                                         SQLITE_TEXT, @":minpath", 
          [NSString stringWithFormat: @"%@%@*", qpath, path_separator()], 0];
      
  STATEMENT_EXECUTE_OR_ROLLBACK (statement, YES, NO);

  query = @"DELETE FROM attributes WHERE path_id IN (SELECT id FROM removed_id)";

  statement = [sqlite statementForQuery: query 
                         withIdentifier: @"remove_path_3"
                               bindings: 0];

  STATEMENT_EXECUTE_OR_ROLLBACK (statement, YES, NO);

  query = @"DELETE FROM postings WHERE path_id IN (SELECT id FROM removed_id)";

  statement = [sqlite statementForQuery: query 
                         withIdentifier: @"remove_path_4"
                               bindings: 0];

  STATEMENT_EXECUTE_OR_ROLLBACK (statement, YES, NO);

  query = @"DELETE FROM paths WHERE id IN (SELECT id FROM removed_id)";

  statement = [sqlite statementForQuery: query 
                         withIdentifier: @"remove_path_5"
                               bindings: 0];

  STATEMENT_EXECUTE_OR_ROLLBACK (statement, YES, NO);

  setUpdating(NO);
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
  [self connectFSWatcher: nil];
}

- (oneway void)globalWatchedPathDidChange:(NSDictionary *)info
{
  if (extracting == NO) {
    CREATE_AUTORELEASE_POOL(arp);
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];  
    NSString *path = [info objectForKey: @"path"];
    NSString *event = [info objectForKey: @"event"];
    NSNumber *exists = nil;

    if ([event isEqual: @"GWWatchedPathDeleted"]) {
      exists = [NSNumber numberWithBool: NO];

    } else if ([event isEqual: @"GWWatchedFileModified"]
                  || [event isEqual: @"GWFileCreatedInWatchedDirectory"]) {
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
}

- (void)processPendingChanges:(id)sender
{
  if (extracting == NO) {
    CREATE_AUTORELEASE_POOL(arp);

    while ([fswupdatePaths count] > 0) {
      NSDictionary *dict = [fswupdatePaths lastObject];
      NSString *path = [dict objectForKey: @"path"];    
      NSString *event = [dict objectForKey: @"event"];
      NSDate *date = [NSDate dateWithTimeIntervalSinceNow: 0.001];

      [[NSRunLoop currentRunLoop] runUntilDate: date]; 

      if ([event isEqual: @"GWWatchedFileModified"]
            || [event isEqual: @"GWFileCreatedInWatchedDirectory"]) {
        if ([fm fileExistsAtPath: path]) {
          GWDebugLog(@"db update: %@", path);

          if ([event isEqual: @"GWFileCreatedInWatchedDirectory"]) {
            /* 
               "GWFileCreatedInWatchedDirectory" is reported only by 
               fswatcher-inotify.
               In this case, if "path" is a directory, we must add 
               also its contents.
            */
            if ([self addPath: path] == NO) {
              NSLog(@"An error occurred while processing %@", path);
            }                  
          } else {
            if ([self updatePath: path] == NO) {      
              NSLog(@"An error occurred while processing %@", path);
            }        
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
            [self addPath: path];      
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
        }
      }

      RELEASE (skipPaths);
    }  

    RELEASE (arp);  
  }
}

- (void)connectFSWatcher:(id)sender
{
  if (fswatcher == nil) {
    fswatcher = [NSConnection rootProxyForConnectionWithRegisteredName: @"fswatcher" 
                                                                  host: @""];

    if (fswatcher == nil)
    {
      NSString *cmd;
      NSMutableArray *arguments;
      int i;
    
      cmd = [NSTask launchPathForTool: @"fswatcher"];    
      
      arguments = [NSMutableArray arrayWithCapacity:2];
      [arguments addObject:@"--daemon"];
      [arguments addObject:@"--auto"];  
      [NSTask launchedTaskWithLaunchPath: cmd arguments: arguments];
   
      for (i = 0; i < 40; i++)
      {	
        [[NSRunLoop currentRunLoop] runUntilDate:
            [NSDate dateWithTimeIntervalSinceNow: 0.1]];

        fswatcher = [NSConnection rootProxyForConnectionWithRegisteredName: @"fswatcher" 
                                                                      host: @""];                  
        if (fswatcher)
          break;
      }
    }
    
    if (fswatcher)
    {
      RETAIN (fswatcher);
      [fswatcher setProtocolForProxy: @protocol(FSWatcherProtocol)];
    
	    [[NSNotificationCenter defaultCenter] addObserver: self
	                   selector: @selector(fswatcherConnectionDidDie:)
		                     name: NSConnectionDidDieNotification
		                   object: [fswatcher connectionForProxy]];
                       
	    [fswatcher registerClient: (id <FSWClientProtocol>)self 
                isGlobalWatcher: YES];

      NSLog(@"fswatcher connected!");                
    } else {
      NSLog(@"unable to contact fswatcher!");  
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

  [NSTimer scheduledTimerWithTimeInterval: 5.0
						                       target: self 
                                 selector: @selector(connectFSWatcher:) 
															   userInfo: nil 
                                  repeats: NO];
}

@end


@implementation GMDSExtractor (ddbd_update)

- (void)setupDDBdUpdater
{
  ddbd = nil;
  [self connectDDBd];

  [dnc addObserver: self
          selector: @selector(userAttributeModified:)
	            name: @"GSMetadataUserAttributeModifiedNotification"
	          object: nil];
}

- (void)connectDDBd
{
  if (ddbd == nil) {
    ddbd = [NSConnection rootProxyForConnectionWithRegisteredName: @"ddbd" 
                                                             host: @""];

    if (ddbd == nil) {
	    NSString *cmd;
      int i;
    
      cmd = [NSTask launchPathForTool: @"ddbd"];    
                
     [NSTask launchedTaskWithLaunchPath: cmd arguments: nil];
   
      for (i = 0; i < 40; i++) {
	      [[NSRunLoop currentRunLoop] runUntilDate:
		                     [NSDate dateWithTimeIntervalSinceNow: 0.1]];

        ddbd = [NSConnection rootProxyForConnectionWithRegisteredName: @"ddbd" 
                                                                 host: @""];                  
        if (ddbd) {
          break;
        }
      }
    }
    
    if (ddbd) {
      RETAIN (ddbd);
      [ddbd setProtocolForProxy: @protocol(DDBdProtocol)];
    
	    [[NSNotificationCenter defaultCenter] addObserver: self
	                   selector: @selector(ddbdConnectionDidDie:)
		                     name: NSConnectionDidDieNotification
		                   object: [ddbd connectionForProxy]];
    
      NSLog(@"ddbd connected!");    
    } else {
      NSLog(@"unable to contact ddbd!");  
    }
  }
}

- (void)ddbdConnectionDidDie:(NSNotification *)notif
{
  id connection = [notif object];

  [nc removeObserver: self
	              name: NSConnectionDidDieNotification
	            object: connection];

  NSAssert(connection == [ddbd connectionForProxy],
		                                  NSInternalInconsistencyException);
  RELEASE (ddbd);
  ddbd = nil;

  NSLog(@"The ddbd connection died!");

  [self connectDDBd];                
}

- (void)userAttributeModified:(NSNotification *)notif
{
  if (extracting == NO) {
    NSString *path = [notif object];
    NSString *ext = [[path pathExtension] lowercaseString];

    if (([excludedSuffixes containsObject: ext] == NO)
              && (isDotFile(path) == NO)
              && inTreeFirstPartOfPath(path, includePathsTree)
              && (inTreeFirstPartOfPath(path, excludedPathsTree) == NO)) {
      GWDebugLog(@"ddbd_update: %@", path);        
      [self updatePath: path];
    }
  }
}

@end


@implementation GMDSExtractor (scheduled_update)

- (void)setupScheduledUpdater
{
  NSString *query;
  NSArray *lines;
  NSUInteger i;

  CREATE_AUTORELEASE_POOL(arp);
  query = @"SELECT path FROM paths WHERE is_directory = 1";
  lines = [sqlite resultsOfQuery: query];

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
  if (extracting == NO) {
    CREATE_AUTORELEASE_POOL(arp);
    NSUInteger count = [directories count];
    NSString *dir;
    NSDictionary *attributes;
    BOOL dirok;
    NSUInteger i;
  
    if (count == 0)
      {
	RELEASE(arp);
	return;
      }

    if ((dirpos >= count) || (dirpos < 0))
      dirpos = 0;
  
    dir = [directories objectAtIndex: dirpos];
    attributes = [fm fileAttributesAtPath: dir traverseLink: NO];
    dirok = (attributes && ([attributes fileType] == NSFileTypeDirectory));
  
    if (dirok) {
      NSArray *contents = [self filteredDirectoryContentsAtPath: dir escapeEntries: YES];
      NSMutableDictionary *dbcontents = [NSMutableDictionary dictionary];
      NSArray *dbpaths = nil;
      NSString *qdir = stringForQuery(dir);
      NSString *sep = path_separator();
      NSString *query;
      SQLitePreparedStatement *statement;
      NSArray *results;
      
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
    
    RELEASE (arp);
  }
}

@end


@implementation GMDSExtractor (update_notifications)

- (void)setupUpdateNotifications
{
  ASSIGN (notifDate, [NSDate date]);
  
  notificationsTimer = [NSTimer scheduledTimerWithTimeInterval: NOTIF_TIME
						                                 target: self 
                                           selector: @selector(notifyUpdates:) 
																           userInfo: nil 
                                            repeats: YES];
  RETAIN (notificationsTimer);     
}

- (void)notifyUpdates:(id)sender
{
  if (extracting == NO) {
    CREATE_AUTORELEASE_POOL(arp);
    NSMutableArray *removed = [NSMutableArray array];
    NSTimeInterval lastStamp;
    NSString *query;
    NSArray *results;
    NSDictionary *info;
    unsigned i;

    [sqlite executeQuery: @"BEGIN"];

    query = @"SELECT path FROM removed_paths;";
    results = [sqlite resultsOfQuery: query];

    query = @"DELETE FROM removed_paths;";
    [sqlite executeQuery: query];

    lastStamp = [notifDate timeIntervalSinceReferenceDate];
    query = [NSString stringWithFormat: @"DELETE FROM updated_paths "
                                        @"WHERE timestamp < %f;", lastStamp];
    [sqlite executeQuery: query];

    [sqlite executeQuery: @"COMMIT"];

    ASSIGN (notifDate, [NSDate date]);

    for (i = 0; i < [results count]; i++) {
      [removed addObject: [[results objectAtIndex: i] objectForKey: @"path"]];
    }

    info = [NSDictionary dictionaryWithObject: [removed makeImmutableCopyOnFail: NO]
                                       forKey: @"removed"];

    [dnc postNotificationName: @"GWMetadataDidUpdateNotification"
                       object: nil 
                     userInfo: info];

    RELEASE (arp);
  }
}

@end

















