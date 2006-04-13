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
#include "mdextractor.h"
#include "config.h"

#define GWDebugLog(format, args...) \
  do { if (GW_DEBUG_LOG) \
    NSLog(format , ## args); } while (0)

#define PERFORM_QUERY(d, q, r) \
do { \
  if (performWriteQuery(d, q) == NO) { \
    NSLog(@"error at: %@", q); \
    return r; \
  } \
} while (0)

#define SKIP_EXPIRE (1.0)
#define USER_MDATA_EXPIRE (10.0)


@implementation GMDSExtractor (updater)

- (void)setupUpdaters
{
  [self setupFswatcherUpdater];
}

- (BOOL)addPath:(NSString *)path
{
  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];
      
  if (attributes) {
    id extractor = nil;
    int path_id;
    
    performWriteQuery(db, @"BEGIN");
    
    path_id = [self insertOrUpdatePath: path withAttributes: attributes];
    
    if (path_id == -1) {
      performWriteQuery(db, @"COMMIT");
      return NO;
    }

    extractor = [self extractorForPath: path withAttributes: attributes];

    if (extractor) {
      if ([extractor extractMetadataAtPath: path
                                    withID: path_id
                                attributes: attributes
                              usingStemmer: stemmer
                                 stopWords: stopWords] == NO) {
        performWriteQuery(db, @"COMMIT");
        return NO;
      }
    }
    
    performWriteQuery(db, @"COMMIT");
    
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

          skip = (isDotFile(subpath) 
                    || inTreeFirstPartOfPath(subpath, excludedPathsTree));
        
          attributes = [fm fileAttributesAtPath: subpath traverseLink: NO];
        
          if (attributes) {
            if (skip == NO) {
              performWriteQuery(db, @"BEGIN");
              
              path_id = [self insertOrUpdatePath: subpath withAttributes: attributes];
    
              if (path_id == -1) {
                RELEASE (arp);
                performWriteQuery(db, @"COMMIT");
                return NO;
              }

              extractor = [self extractorForPath: subpath withAttributes: attributes];
                  
              if (extractor) {
                if ([extractor extractMetadataAtPath: subpath
                                              withID: path_id
                                          attributes: attributes
                                        usingStemmer: stemmer
                                           stopWords: stopWords] == NO) {
                  performWriteQuery(db, @"COMMIT");
                  RELEASE (arp);
                  return NO;
                }
              }
              
              performWriteQuery(db, @"COMMIT");
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
    
    performWriteQuery(db, @"BEGIN");
    
    path_id = [self insertOrUpdatePath: path withAttributes: attributes];
    
    if (path_id == -1) {
      performWriteQuery(db, @"COMMIT");
      return NO;
    }

    extractor = [self extractorForPath: path withAttributes: attributes];

    if (extractor) {
      if ([extractor extractMetadataAtPath: path
                                    withID: path_id
                                attributes: attributes
                              usingStemmer: stemmer
                                 stopWords: stopWords] == NO) {
        performWriteQuery(db, @"COMMIT");
        return NO;
      }
    }
    
    performWriteQuery(db, @"COMMIT");
  }
  
  return YES;
}

- (BOOL)updateRenamedPath:(NSString *)path 
                  oldPath:(NSString *)oldpath
{
  NSString *qpath = stringForQuery(path);
  NSString *qoldpath = stringForQuery(oldpath);
  NSString *query;
    
  PERFORM_QUERY (db, @"BEGIN", 0);

  query = [NSString stringWithFormat: @"CREATE TABLE paths_tmp "
                                      @"(id INTEGER PRIMARY KEY, "
                                      @"path TEXT, "
                                      @"base TEXT DEFAULT '%@', "
                                      @"oldbase TEXT DEFAULT '%@')", 
                                      qpath, qoldpath];
  PERFORM_QUERY (db, query, 0);

  query = @"CREATE TRIGGER paths_tmp_trigger AFTER INSERT ON paths_tmp "
          @"BEGIN "
          @"UPDATE paths "
          @"SET path = pathMoved(new.oldbase, new.base, new.path) "
          @"WHERE id = new.id; "
          @"END";
  PERFORM_QUERY (db, query, 0);
  
  query = [NSString stringWithFormat: @"INSERT INTO paths_tmp (id, path) "
                                      @"SELECT paths.id, paths.path "
                                      @"FROM paths "
                                      @"WHERE path = '%@'", qoldpath];
  PERFORM_QUERY (db, query, 0);

  query = [NSString stringWithFormat: @"INSERT INTO paths_tmp (id, path) "
                                      @"SELECT paths.id, paths.path "
                                      @"FROM paths "
                                      @"WHERE path > '%@%@' "
                                      @"AND path < '%@0'", 
                                      qoldpath, path_separator(), qoldpath];
  PERFORM_QUERY (db, query, 0);

  PERFORM_QUERY (db, @"DROP TRIGGER paths_tmp_trigger", 0);
  PERFORM_QUERY (db, @"DROP TABLE paths_tmp", 0);

  PERFORM_QUERY (db, @"COMMIT", 0);

  return YES;
}

- (BOOL)removePath:(NSString *)path
{
  NSString *qpath = stringForQuery(path);
  NSString *query;
  NSArray *userattrs;
  unsigned i;
    
  PERFORM_QUERY (db, @"BEGIN", 0);

  PERFORM_QUERY (db, @"CREATE TABLE id_tmp (id INTEGER PRIMARY KEY)", 0);
  
  query = [NSString stringWithFormat: @"INSERT INTO id_tmp (id) "
                                      @"SELECT id FROM paths "
                                      @"WHERE path = '%@'", 
                                      qpath];
  PERFORM_QUERY (db, query, 0);
  
  query = [NSString stringWithFormat: @"INSERT INTO id_tmp (id) "
                                      @"SELECT id FROM paths "
                                      @"WHERE path > '%@%@' "
                                      @"AND path < '%@0'",
                                      qpath, path_separator(), qpath];
  PERFORM_QUERY (db, query, 0);

  query = @"SELECT paths.path, attributes.key, attributes.attribute " 
          @"FROM paths, attributes "
          @"WHERE paths.id IN (SELECT id FROM id_tmp) "
          @"AND attributes.path_id = paths.id "                                    
          @"AND isUserMdataKey(attributes.key)";                                     

  userattrs = performQuery(db, query);
    
  for (i = 0; i < [userattrs count]; i++) {
    NSDictionary *dict = [userattrs objectAtIndex: i];
    NSData *data = [dict objectForKey: @"path"];
    NSString *path = [NSString stringWithUTF8String: [data bytes]];
    NSMutableDictionary *mdatadict = [lastRemovedUserMdata objectForKey: path];
    NSMutableArray *attrs;
    
    if (mdatadict == nil) {
      mdatadict = [NSMutableDictionary dictionary];
      attrs = [NSMutableArray array];
      [mdatadict setObject: attrs forKey: @"attributes"];
      [mdatadict setObject: [NSDate date] forKey: @"stamp"];
      [lastRemovedUserMdata setObject: mdatadict forKey: path];
    } else {
      attrs = [mdatadict objectForKey: @"attributes"];
    }
    
    [attrs addObject: dict];
  }

  PERFORM_QUERY (db, @"DELETE FROM attributes WHERE path_id IN (SELECT id FROM id_tmp)", 0);
  PERFORM_QUERY (db, @"DELETE FROM postings WHERE path_id IN (SELECT id FROM id_tmp)", 0);
  PERFORM_QUERY (db, @"DELETE FROM paths WHERE id IN (SELECT id FROM id_tmp)", 0);

  PERFORM_QUERY (db, @"DROP TABLE id_tmp", 0);

  PERFORM_QUERY (db, @"COMMIT", 0);

  return YES;
}

- (void)checkLastRemovedUserMdata:(id)sender
{
  CREATE_AUTORELEASE_POOL(arp);  
  NSArray *paths = [lastRemovedUserMdata allKeys];
  NSDate *now = [NSDate date];
  unsigned i;

  RETAIN (paths);
  
  for (i = 0; i < [paths count]; i++) {
    NSString *path = [paths objectAtIndex: i];
    NSDictionary *dict = [lastRemovedUserMdata objectForKey: path];
    NSDate *stamp = [dict objectForKey: @"stamp"];
  
    if ([now timeIntervalSinceDate: stamp] > USER_MDATA_EXPIRE) {
      [lastRemovedUserMdata removeObjectForKey: path];
      GWDebugLog(@"expired user-mdata %@", path);
    }
  }
  
  RELEASE (paths);
  RELEASE (arp);
}

@end


@implementation GMDSExtractor (fswatcher_update)

- (void)setupFswatcherUpdater
{
  fswupdatePaths = [NSMutableArray new];
  fswupdateSkipBuff = [NSMutableDictionary new];
     
  fswupdateTimer = [NSTimer scheduledTimerWithTimeInterval: 1.0 
						                         target: self 
                                   selector: @selector(processPendingChanges:) 
																   userInfo: nil 
                                    repeats: YES];
  RETAIN (fswupdateTimer);     
     
  lastRemovedUserMdata = [NSMutableDictionary new];
     
  userMdataTimer = [NSTimer scheduledTimerWithTimeInterval: USER_MDATA_EXPIRE
						                         target: self 
                                   selector: @selector(checkLastRemovedUserMdata:) 
																   userInfo: nil 
                                    repeats: YES];
  RETAIN (userMdataTimer);     
     
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
      
      if ([exists isEqual: didexists]) {
        caninsert = NO;
      } else {
        skipInfo = [NSDictionary dictionaryWithObjectsAndKeys: event, @"event", 
                                                  exists, @"exists",
                                                  [NSDate date], @"stamp", nil];     
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
      GWDebugLog(@"inserting: %@ - %@", path, event);
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
      GWDebugLog(@"db update: %@", path);
      
      if ([self updatePath: path] == NO) {      
        NSLog(@"An error occurred while processing %@", path);
      }
      
    } else if ([event isEqual: @"GWWatchedPathDeleted"]) {
      GWDebugLog(@"db remove: %@", path);
      
      [self removePath: path];

    } else if ([event isEqual: @"GWWatchedPathRenamed"]) {
      NSString *oldpath = [dict objectForKey: @"oldpath"];
 
      if (oldpath != nil) {
        GWDebugLog(@"db rename: %@ -> %@", oldpath, path);
        
        if ([self updateRenamedPath: path oldPath: oldpath] == NO) { 
          NSLog(@"An error occurred while processing %@", path);
        }
        
      } else {
        GWDebugLog(@"db update renamed: %@", path);
        
        if ([self addPath: path] == NO) {      
          NSLog(@"An error occurred while processing %@", path);
        }
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
        GWDebugLog(@"expired skip-info %@", path);
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










